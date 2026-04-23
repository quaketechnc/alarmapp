import AVFoundation
import os
import SwiftUI
import UIKit
import UserNotifications

private let log = Logger(subsystem: "com.alarm", category: "app")

/// Shared state between `alarmEventsLoop` and `rescueLoop`, avoiding async
/// snapshot calls into `AlarmManager.alarmUpdates` (which only yields on
/// change — a fresh subscriber would block forever waiting for the first
/// event). `alarmEventsLoop` maintains these in response to stream events.
@MainActor
private final class AlarmKitLocalState {
    /// Is any alarm currently `.alerting`?
    var isAlerting: Bool = false
    /// Fire date of the currently queued rescue alarm, or nil if none.
    var rescueFireDate: Date? = nil
    var rescuePending: Bool {
        guard let d = rescueFireDate else { return false }
        return d > Date()
    }
}

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()
    @State private var kitState = AlarmKitLocalState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { SoundInstaller.installIfNeeded() }
                .task { primeAudioSession() }
                .task { await alarmEventsLoop() }
                .task { await rescueLoop() }
        }
    }

    /// Pre-configure the audio session at launch so it's ready the moment an
    /// alarm fires. `.mixWithOthers` means we don't fight anyone for priority.
    private func primeAudioSession() {
        let s = AVAudioSession.sharedInstance()
        do {
            try s.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            log.info("🎚 primeAudioSession OK")
        } catch {
            log.error("🎚 primeAudioSession failed: \(error)")
        }
    }

    // MARK: - Alarm events (AlarmKit → store)

    private func alarmEventsLoop() async {
        log.info("alarmEventsLoop: started")
        for await firingID in AlarmService.shared.alertingAlarmIDStream {
            await handleStreamEvent(firingID: firingID)
        }
        log.info("alarmEventsLoop: ended")
    }

    @MainActor
    private func handleStreamEvent(firingID: String?) async {
        guard let id = firingID else {
            if kitState.isAlerting {
                log.info("🔕 AlarmKit no longer alerting")
            }
            kitState.isAlerting = false
            return
        }

        kitState.isAlerting = true

        // Rescue fired → clear rescue fireDate; pendingMission should already be set.
        if id == AlarmService.rescueSlotID.uuidString {
            log.info("🔔 rescue alarm fired")
            kitState.rescueFireDate = nil
            return
        }

        // Primary fire: adopt item as pendingMission.
        guard let item = store.items.first(where: { $0.alarmKitID == id }) else {
            log.warning("⚠ orphaned alerting alarm id=\(id) — cancelling")
            try? AlarmService.shared.cancel(alarmKitID: id)
            return
        }
        log.info("✓ adopted pendingMission id=\(item.id) time=\(item.timeString)")
        store.firingAlarmID = id
        store.pendingMission = item
        // Any prior rescue is stale — this primary just woke the user.
        AlarmService.shared.cancelRescue()
        kitState.rescueFireDate = nil
    }

    // MARK: - Rescue loop

    private static let rescueTickSeconds: UInt64 = 3

    private func rescueLoop() async {
        log.info("rescueLoop: started")

        // Cold-launch catch-up.
        await MainActor.run {
            store.reloadPersistedTransients()
        }
        if await store.pendingMission == nil {
            if let missed = await store.detectMissedAlarm() {
                log.info("🔁 rescueLoop: adopting missed alarm id=\(missed.id)")
                await MainActor.run { store.pendingMission = missed }
            }
        }

        while !Task.isCancelled {
            await rescueTick()
            try? await Task.sleep(nanoseconds: Self.rescueTickSeconds * 1_000_000_000)
        }
    }

    @MainActor
    private func rescueTick() async {
        store.reloadPersistedTransients()
        guard let item = store.pendingMission else { return }

        let isAlerting = kitState.isAlerting
        let rescuePending = kitState.rescuePending
        let isForeground = UIApplication.shared.applicationState == .active

        log.info("⏱ rescueTick item=\(item.id) alerting=\(isAlerting) rescuePending=\(rescuePending) fg=\(isForeground) audio=\(AudioService.shared.isPlaying) missionScreen=\(self.store.isOnMissionScreen)")

        // (A) Push system volume (idempotent; no-op without key window).
        AudioService.shared.setVolume(item.volume)

        // (B) Foreground audio fallback. Skip while AlarmKit is alerting —
        // they'd fight over the audio session.
        if isForeground, !isAlerting, !AudioService.shared.isPlaying {
            log.info("🔊 rescueTick: starting foreground audio")
            AudioService.shared.play(toneID: item.toneID, volume: item.volume, loops: -1)
        }

        // (C) Queue a rescue alarm iff: AlarmKit not alerting, no rescue
        // currently pending, and the user isn't already on the mission screen.
        if !isAlerting, !rescuePending, !store.isOnMissionScreen {
            do {
                _ = try await AlarmService.shared.scheduleRescue(for: item)
                kitState.rescueFireDate = Date().addingTimeInterval(AlarmService.rescueDelaySeconds)
                log.info("✓ rescueTick: rescue queued, fires at \(self.kitState.rescueFireDate!)")
            } catch {
                log.error("✗ rescueTick: scheduleRescue failed \(error)")
            }
        }
    }
}
