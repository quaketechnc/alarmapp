import os
import SwiftUI

private let log = Logger(subsystem: "com.alarm", category: "app")

@main
struct AlarmApp: App {
    @State private var store = AlarmStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .task { SoundInstaller.installIfNeeded() }
                .task { await watchAlarms() }
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .inactive:
                // Covers both normal background and force-quit (.background is not guaranteed on kill).
                guard let mission = store.pendingMission else { return }
                log.info("⬇ inactive — arming backup for itemID=\(mission.id)")
                Task {
                    do {
                        let backupID = try await AlarmService.shared.scheduleBackup(for: mission)
                        store.backupAlarmKitID = backupID.uuidString
                    } catch {
                        log.error("✗ scheduleBackup on inactive failed: \(error)")
                    }
                }
            case .active:
                // App foregrounded — disarm the backup, user can solve the mission directly.
                if let backupID = store.backupAlarmKitID {
                    log.info("⬆ active — cancelling backup=\(backupID)")
                    try? AlarmService.shared.cancel(alarmKitID: backupID)
                    store.backupAlarmKitID = nil
                }
            default:
                break
            }
        }
    }

    private func watchAlarms() async {
        log.info("watchAlarms: stream started")
        for await firingID in AlarmService.shared.alertingAlarmIDStream {
            guard let id = firingID else {
                log.debug("watchAlarms: alarm stopped (firingID=nil)")
                store.firingAlarmID = nil
                continue
            }
            log.info("🔔 alarm alerting: alarmKitID=\(id)")

            // Resolve the item: regular alarm, snooze, or re-fire of a backup alarm.
            let item = store.items.first { $0.alarmKitID == id }
                ?? store.pendingSnooze
                ?? (id == store.backupAlarmKitID ? store.pendingMission : nil)

            guard let item else {
                // Alarm exists in AlarmKit but not in our store — orphaned.
                log.warning("⚠ orphaned alarm — cancelling alarmKitID=\(id)")
                try? AlarmService.shared.cancel(alarmKitID: id)
                continue
            }
            log.info("✓ resolved item id=\(item.id) time=\(item.timeString)")

            // Set firingAlarmID only after we have a valid item — this triggers showRinging.
            store.firingAlarmID = id

            // Persist so the mission screen survives an app kill.
            store.pendingMission = item

            // Cancel any stale backup from a previous cycle.
            if let oldBackup = store.backupAlarmKitID {
                log.info("✗ cancelling stale backup=\(oldBackup)")
                try? AlarmService.shared.cancel(alarmKitID: oldBackup)
                store.backupAlarmKitID = nil
            }

            // Backup is NOT scheduled here — only when app goes to background.
        }
        log.info("watchAlarms: stream ended")
    }
}
