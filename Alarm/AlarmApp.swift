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
    /// UUID string of the currently alerting alarm (if any).
    var alertingAlarmID: String? = nil
    /// When the current `.alerting` state began. Used to detect AlarmKit's
    /// "silent-but-still-alerting" limbo (hardware volume press on rescue
    /// doesn't always fire a state transition).
    var alertingSince: Date? = nil
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
                .task { await configureAppTasks() }
                .task { SoundInstaller.installIfNeeded() }
                .task { primeAudioSession() }
                .task { await alarmEventsLoop() }
                .task { await rescueLoop() }
                .task { await volumeLoop() }
                
        }
    }

    private func configureAppTasks() async {
        await FirebaseService.startup()
//        await purchaseService.configure(for: FirebaseService.userID)
//        try? await purchaseService.restore()
//        withAnimation { isAppLocked.toggle() }
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
                AnalyticsService.track(.alarmSilenced, props: [
                    "alarm_id": kitState.alertingAlarmID ?? "nil",
                    "duration_s": kitState.alertingSince.map { Int(Date().timeIntervalSince($0)) } ?? -1,
                ])
            }
            kitState.isAlerting = false
            kitState.alertingAlarmID = nil
            kitState.alertingSince = nil
            return
        }

        // Only stamp alertingSince on the false→true transition.
        if !kitState.isAlerting || kitState.alertingAlarmID != id {
            kitState.alertingSince = Date()
            AnalyticsService.track(.alarmAlerting, props: [
                "alarm_id": id,
                "is_rescue": id == AlarmService.rescueSlotID.uuidString,
            ])
        }
        kitState.isAlerting = true
        kitState.alertingAlarmID = id

        // Rescue fired → clear rescue fireDate; pendingMission should already be set.
        if id == AlarmService.rescueSlotID.uuidString {
            log.info("🔔 rescue alarm fired")
            AnalyticsService.track(.rescueFired)
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
        AnalyticsService.track(.missionAdopted, props: [
            "item_id": item.id.uuidString,
            "tone": item.toneID,
            "volume": Int(item.volume),
        ])
        store.firingAlarmID = id
        store.pendingMission = item
        // Any prior rescue is stale — this primary just woke the user.
        AlarmService.shared.cancelRescue()
        kitState.rescueFireDate = nil
    }

    // MARK: - Volume loop
    //
    // Independent, fast (1s) ticker. Keeps re-asserting system volume to
    // `item.volume` while a mission is pending. In background iOS usually
    // blocks programmatic volume changes via MPVolumeView — but the moment
    // the app transitions to foreground active (unlock, AlarmKit UI, intent
    // return) this loop has the best chance of sticking a push. On foreground
    // entry we also do a short ramp for the visible "climbing" effect.

    private func volumeLoop() async {
        var wasForeground = false
        while !Task.isCancelled {
            if let item = await store.pendingMission {
                let isForeground = await MainActor.run {
                    UIApplication.shared.applicationState == .active
                }
                if isForeground && !wasForeground {
                    // Ramp from 0 → target over ~1.5s for a visible climb.
                    await rampVolume(to: item.volume, steps: 8, totalSeconds: 1.5)
                } else {
                    await MainActor.run { AudioService.shared.setVolume(item.volume) }
                }
                wasForeground = isForeground
            } else {
                wasForeground = false
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }
    }

    private func rampVolume(to target: Double, steps: Int, totalSeconds: Double) async {
        let stepDelay = UInt64((totalSeconds / Double(steps)) * 1_000_000_000)
        for i in 1...steps {
            let v = target * Double(i) / Double(steps)
            await MainActor.run { AudioService.shared.setVolume(v) }
            try? await Task.sleep(nanoseconds: stepDelay)
        }
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
                AnalyticsService.track(.missedAlarmDetected, props: [
                    "item_id": missed.id.uuidString,
                ])
                await MainActor.run { store.pendingMission = missed }
            }
        }

        while !Task.isCancelled {
            await rescueTick()
            try? await Task.sleep(nanoseconds: Self.rescueTickSeconds * 1_000_000_000)
        }
    }

    /// If a rescue alarm stays in `.alerting` for longer than this, AlarmKit
    /// is likely stuck in silent-alerting limbo (hardware volume-press
    /// side-effect). Force-cancel so the next tick can queue a fresh rescue.
    private static let rescueStuckTimeout: TimeInterval = 20

    @MainActor
    private func rescueTick() async {
        store.reloadPersistedTransients()
        guard let item = store.pendingMission else { return }

        var isAlerting = kitState.isAlerting
        let rescuePending = kitState.rescuePending
        let isForeground = UIApplication.shared.applicationState == .active

        // Stuck-rescue detection: AlarmKit sometimes reports a rescue as
        // .alerting indefinitely after the user silenced it with the hardware
        // volume button — no audio, no state transition. Force-cancel so the
        // next tick re-queues.
        if isAlerting,
           kitState.alertingAlarmID == AlarmService.rescueSlotID.uuidString,
           !store.isOnMissionScreen,
           let since = kitState.alertingSince,
           Date().timeIntervalSince(since) > Self.rescueStuckTimeout {
            log.info("⚠ rescue stuck in .alerting >\(Int(Self.rescueStuckTimeout))s — force cancel")
            AnalyticsService.track(.rescueStuckCancelled, props: [
                "stuck_s": Int(Date().timeIntervalSince(since)),
            ])
            try? AlarmService.shared.cancel(alarmKitID: AlarmService.rescueSlotID.uuidString)
            kitState.isAlerting = false
            kitState.alertingAlarmID = nil
            kitState.alertingSince = nil
            kitState.rescueFireDate = nil
            isAlerting = false
        }

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
                AnalyticsService.track(.rescueScheduled, props: [
                    "item_id": item.id.uuidString,
                    "delay_s": Int(AlarmService.rescueDelaySeconds),
                    "foreground": isForeground,
                ])
            } catch {
                log.error("✗ rescueTick: scheduleRescue failed \(error)")
            }
        }
    }
}
