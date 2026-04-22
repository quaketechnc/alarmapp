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
                .task { await watchAlarms() }
                .task { await watchdog() }
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
                // Do NOT clear store.firingAlarmID here: we ourselves call
                // AlarmManager.stop() below, which causes the stream to yield
                // nil while the user is still mid-mission. Only
                // completeMission() is allowed to clear firingAlarmID.
                log.debug("watchAlarms: stream yielded nil (expected after stop)")
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

            // Silence AlarmKit's system-level alert so it doesn't play on top
            // of the in-app AudioService. For recurring alarms this leaves the
            // schedule intact for the next occurrence; for one-time alarms it
            // simply completes. The in-app ringing experience is driven by
            // `RingingView` + `AudioService` from here on.
            AlarmService.shared.stop(alarmKitID: id)

            store.firingAlarmID = id
            store.pendingMission = item

            // The primary just fired; whatever backup we had is now stale.
            AlarmService.shared.cancelBackup()
            store.backupAlarmKitID = nil
        }
        log.info("watchAlarms: stream ended")
    }
}
