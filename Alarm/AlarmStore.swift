import os
import SwiftUI

private let log = Logger(subsystem: "com.alarm", category: "store")

@Observable
final class AlarmStore {
    var items: [AlarmItem] = []
    var firingAlarmID: String?

    // Persisted: survives app kill so the backup alarm can show the mission on relaunch.
    var pendingMission: AlarmItem? {
        didSet {
            log.info("~ pendingMission → \(self.pendingMission.map { $0.id.uuidString } ?? "nil")")
            persist(pendingMission, key: Self.udMission)
        }
    }
    // Persisted: lets us cancel the backup alarm even after app relaunch.
    var backupAlarmKitID: String? {
        didSet {
            log.info("~ backupAlarmKitID → \(self.backupAlarmKitID ?? "nil")")
            UserDefaults.standard.set(backupAlarmKitID, forKey: Self.udBackup)
        }
    }

    private static let udKey    = "alarmItems"
    private static let udMission = "pendingMission"
    private static let udBackup  = "backupAlarmKitID"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.udKey),
           let saved = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            items = saved
            log.info("init: loaded \(saved.count) alarm(s) from UserDefaults")
        } else {
            items = []
            log.info("init: no saved alarms")
        }
        pendingMission   = load(AlarmItem.self, key: Self.udMission)
        backupAlarmKitID = UserDefaults.standard.string(forKey: Self.udBackup)
        if let m = pendingMission {
            log.info("init: restored pendingMission id=\(m.id) time=\(m.timeString)")
        }
        if let b = backupAlarmKitID {
            log.info("init: restored backupAlarmKitID=\(b)")
        }
    }

    /// Re-read pendingMission/backupAlarmKitID from UserDefaults. Call on
    /// scene activation: `SolveMissionIntent` writes these from outside the
    /// @Observable store, so without a reload the main UI stays stale — e.g.
    /// RingingView doesn't appear after an intent-driven return to foreground.
    @MainActor
    func reloadPersistedTransients() {
        let freshMission = load(AlarmItem.self, key: Self.udMission)
        if freshMission != pendingMission {
            log.info("↻ reload: pendingMission \(self.pendingMission?.id.uuidString ?? "nil") → \(freshMission?.id.uuidString ?? "nil")")
            pendingMission = freshMission
        }
        let freshBackup = UserDefaults.standard.string(forKey: Self.udBackup)
        if freshBackup != backupAlarmKitID {
            log.info("↻ reload: backupAlarmKitID \(self.backupAlarmKitID ?? "nil") → \(freshBackup ?? "nil")")
            backupAlarmKitID = freshBackup
        }
    }

    // MARK: CRUD

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isEnabled.toggle()
        log.info("⇄ toggle id=\(id) → isEnabled=\(self.items[i].isEnabled)")
        save()
    }

    func add(_ item: AlarmItem) {
        items.append(item)
        log.info("+ add id=\(item.id) time=\(item.timeString) tone='\(item.toneID)' missions=\(item.selectedMissions.map({$0.id}))")
        save()
    }

    func update(_ item: AlarmItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = item
        log.debug("↻ update id=\(item.id) alarmKitID=\(item.alarmKitID ?? "nil")")
        save()
    }

    func delete(at offsets: IndexSet) {
        let deleted = offsets.map { items[$0] }
        items.remove(atOffsets: offsets)
        for d in deleted {
            log.info("− delete id=\(d.id) time=\(d.timeString) alarmKitID=\(d.alarmKitID ?? "nil")")
        }
        save()
    }

    // MARK: Mission completion

    /// Finalize a successful mission run:
    ///   1. cancel the firing primary alarm (prevent AlarmKit re-fire),
    ///   2. cancel the backup duplicate (prevent fallback re-fire),
    ///   3. reschedule recurring alarms for the next occurrence / disable one-time alarms,
    ///   4. clear transient state so the UI dismisses.
    @MainActor
    func completeMission() async {
        log.info("✓ completeMission start")

        if let firingID = firingAlarmID {
            try? AlarmService.shared.cancel(alarmKitID: firingID)
        }
        AlarmService.shared.cancelBackup()
        backupAlarmKitID = nil

        if let mission = pendingMission,
           let idx = items.firstIndex(where: { $0.id == mission.id }) {
            let item = items[idx]
            let isOneTime = item.days.allSatisfy { !$0 }
            if item.isQuick {
                log.info("− quick alarm fired — removing id=\(item.id)")
                items.remove(at: idx)
                save()
            } else if isOneTime {
                items[idx].isEnabled = false
                items[idx].alarmKitID = nil
                update(items[idx])
            } else {
                if let uuid = try? await AlarmService.shared.schedule(item) {
                    items[idx].alarmKitID = uuid.uuidString
                    update(items[idx])
                }
            }
        }

        firingAlarmID = nil
        pendingMission = nil
        log.info("✓ completeMission done")
    }

    // MARK: Private persistence helpers

    private func save() {
        persist(items, key: Self.udKey)
    }

    private func persist<T: Encodable>(_ value: T?, key: String) {
        if let value, let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        } else {
            UserDefaults.standard.removeObject(forKey: key)
        }
    }

    private func load<T: Decodable>(_ type: T.Type, key: String) -> T? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
