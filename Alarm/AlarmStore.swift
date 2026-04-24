import os
import SwiftUI

private let log = Logger(subsystem: "com.alarm", category: "store")

@Observable
final class AlarmStore {
    var items: [AlarmItem] = []
    var firingAlarmID: String?

    /// Transient: true while `MissionExecutionView` is on screen. The
    /// rescue-loop suppresses new AlarmKit rescues while solving, so we don't
    /// interrupt the user mid-mission with a fresh system alert.
    var isOnMissionScreen: Bool = false

    // Persisted: survives app kill so the backup alarm can show the mission on relaunch.
    var pendingMission: AlarmItem? {
        didSet {
            log.info("~ pendingMission → \(self.pendingMission.map { $0.id.uuidString } ?? "nil")")
            persist(pendingMission, key: Self.udMission)
        }
    }
    /// item.id.uuidString → Date of last successful completion. Used for
    /// cold-launch missed-alarm detection so we don't treat an already-solved
    /// alarm as pending.
    var lastCompletedFireDate: [String: Date] = [:] {
        didSet { persistLastCompleted() }
    }

    private static let udKey    = "alarmItems"
    private static let udMission = "pendingMission"
    private static let udLastCompleted = "lastCompletedFireDate"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.udKey),
           let saved = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            items = saved
            log.info("init: loaded \(saved.count) alarm(s) from UserDefaults")
        } else {
            items = []
            log.info("init: no saved alarms")
        }
        pendingMission = load(AlarmItem.self, key: Self.udMission)
        lastCompletedFireDate = (load([String: Date].self, key: Self.udLastCompleted)) ?? [:]
        if let m = pendingMission {
            log.info("init: restored pendingMission id=\(m.id) time=\(m.timeString)")
        }
        if !lastCompletedFireDate.isEmpty {
            log.info("init: restored lastCompletedFireDate (\(self.lastCompletedFireDate.count) entries)")
        }
    }

    /// Re-read pendingMission from UserDefaults. Call on scene activation:
    /// `SolveMissionIntent` writes it from outside the @Observable store, so
    /// without a reload the UI stays stale — e.g. RingingView doesn't appear
    /// after an intent-driven return to foreground.
    @MainActor
    func reloadPersistedTransients() {
        let freshMission = load(AlarmItem.self, key: Self.udMission)
        if freshMission != pendingMission {
            log.info("↻ reload: pendingMission \(self.pendingMission?.id.uuidString ?? "nil") → \(freshMission?.id.uuidString ?? "nil")")
            pendingMission = freshMission
        }
    }

    /// Scan enabled alarms for a recent past fire that doesn't have a
    /// corresponding AlarmKit-scheduled alarm (= already fired) and wasn't
    /// completed (`lastCompletedFireDate` older than the fire time). If one
    /// matches within the last 10 minutes, return it so the rescue-loop can
    /// adopt it as `pendingMission`.
    ///
    /// Handles the case where the user dismissed a system alarm with the
    /// hardware volume button on the lock screen while the app was killed:
    /// the intent never ran, so nothing was persisted, but the alarm clearly
    /// fired and wasn't solved.
    @MainActor
    func detectMissedAlarm() async -> AlarmItem? {
        let scheduled = await AlarmService.shared.scheduledAlarmIDs()
        let now = Date()
        let cutoff: TimeInterval = 10 * 60  // 10 min

        for item in items where item.isEnabled {
            guard let prev = AlarmService.shared.previousFireDate(for: item) else { continue }
            let age = now.timeIntervalSince(prev)
            guard age >= 0, age < cutoff else { continue }
            // Still scheduled in AlarmKit → hasn't fired yet (or is currently alerting, handled separately).
            if let kitID = item.alarmKitID, scheduled.contains(kitID) { continue }
            // Already completed at-or-after this fire time.
            if let last = lastCompletedFireDate[item.id.uuidString], last >= prev { continue }
            log.info("⚠ detectMissedAlarm: item=\(item.id) prevFire=\(prev) age=\(Int(age))s")
            return item
        }
        return nil
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
        AlarmService.shared.cancelRescue()
        AudioService.shared.stop()

        if let mission = pendingMission {
            // Record completion so cold-launch missed-alarm detection won't
            // re-trigger this alarm.
            lastCompletedFireDate[mission.id.uuidString] = Date()
            AnalyticsService.track(.missionCompleted, props: [
                "item_id": mission.id.uuidString,
                "missions": mission.selectedMissions.map { $0.id.rawValue }.joined(separator: ","),
            ])
        }

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

    private func persistLastCompleted() {
        persist(lastCompletedFireDate, key: Self.udLastCompleted)
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
