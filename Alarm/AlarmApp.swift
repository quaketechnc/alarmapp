import AVFoundation
import os
import SwiftUI
import UserNotifications

private let log = Logger(subsystem: "com.alarm", category: "app")

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { SoundInstaller.installIfNeeded() }
                .task { primeAudioSession() }
                .task { await watchAlarms() }
                .task { await watchdog() }
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

    // MARK: - Watchdog
    //
    // While the app is alive and the user is mid-mission we keep a duplicate
    // alarm scheduled `backupDelaySeconds` in the future. Each tick we cancel
    // the previous duplicate and schedule a fresh one, so the duplicate is
    // always "about to fire in ≤ backupDelaySeconds".
    //
    // If the app dies between ticks, iOS still owns the duplicate via
    // AlarmKit and fires it, re-launching us into the ringing/mission flow.
    // The duplicate is cancelled on successful mission completion.

    private static let watchdogTickSeconds: UInt64 = 10

    private func watchdog() async {
        while !Task.isCancelled {
            await refreshBackupIfRinging()
            try? await Task.sleep(nanoseconds: Self.watchdogTickSeconds * 1_000_000_000)
        }
    }

    @MainActor
    private func refreshBackupIfRinging() async {
        guard let item = store.pendingMission else { return }
        AlarmService.shared.cancelBackup()
        do {
            let id = try await AlarmService.shared.scheduleBackup(for: item)
            store.backupAlarmKitID = id.uuidString
            log.info("✓ watchdog: backup refreshed id=\(id)")
        } catch {
            log.error("✗ watchdog: backup failed \(error)")
        }
    }

    // MARK: - Alarm watcher

    private func watchAlarms() async {
        log.info("watchAlarms: stream started")
        for await firingID in AlarmService.shared.alertingAlarmIDStream {
            guard let id = firingID else {
                // Stream yielded nil. Two possibilities:
                //  a) completeMission() just ran → pendingMission is cleared
                //     → nothing to do (expected).
                //  b) AlarmKit was silenced externally (hardware volume-down
                //     on lock screen, "Stop" swipe on the system banner, etc.)
                //     while the user still owes the mission. In that case
                //     pendingMission is still set — AlarmKit has released its
                //     audio session, so WE pick up the ringing via
                //     AudioService (UIBackgroundModes:audio keeps it playing
                //     even if the app is still backgrounded) and refresh the
                //     backup alarm so app-kill still recovers.
                if let item = store.pendingMission {
                    log.info("🔕 external silence detected — taking over audio (item=\(item.id))")
                    await AudioService.shared.playAsync(
                        toneID: item.toneID,
                        volume: item.volume,
                        loops: -1
                    )
                    await refreshBackupIfRinging()
                } else {
                    log.debug("watchAlarms: stream yielded nil (expected after completeMission)")
                }
                continue
            }
            log.info("🔔 alarm alerting: alarmKitID=\(id)")

            let item = store.items.first { $0.alarmKitID == id }
                ?? (id == store.backupAlarmKitID ? store.pendingMission : nil)

            guard let item else {
                log.warning("⚠ orphaned alarm — cancelling alarmKitID=\(id)")
                try? AlarmService.shared.cancel(alarmKitID: id)
                continue
            }
            log.info("✓ resolved item id=\(item.id) time=\(item.timeString)")

            // Do NOT stop AlarmKit and do NOT start our AudioService here.
            // AlarmKit plays the real tone at alarm-priority (bypasses media
            // volume = 0), which is the only way to guarantee the user wakes.
            // Our AudioService only kicks in after the user has interacted —
            // see SolveMissionIntent (slide-stop) and MissionExecutionView,
            // both of which run with the app in foreground where
            // MPVolumeView / AVAudioSession work reliably.
            store.firingAlarmID = id
            store.pendingMission = item

            // The primary just fired; whatever backup we had is now stale.
            AlarmService.shared.cancelBackup()
            store.backupAlarmKitID = nil
        }
        log.info("watchAlarms: stream ended")
    }
}
