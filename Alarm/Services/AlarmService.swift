import ActivityKit
import AlarmKit
import os
import SwiftUI
import UserNotifications

private let log = Logger(subsystem: "com.alarm", category: "service")

// MARK: - Tone model

struct AlarmTone: Identifiable, Hashable {
    let id: String        // stem, e.g. "MorningPark_1"
    let fileName: String  // full bundle filename, e.g. "MorningPark_1.mp3"
    let name: String      // display, e.g. "Morning Park 1"
    let hint: String      // category, e.g. "Morning Park"; empty for singletons

    var bundleURL: URL? {
        let stem = (fileName as NSString).deletingPathExtension
        let ext  = (fileName as NSString).pathExtension
        return Bundle.main.url(forResource: stem, withExtension: ext)
    }
}

// MARK: - Tone catalog (bundle-discovered)

/// ID used when no user selection exists, or stored selection is stale.
/// Matches the stem of the default audio file in the bundle.
let defaultAlarmToneID = "LiveTheMoment"

/// All audio tones discovered in the app bundle, alphabetized with
/// `Awakening` pinned first. Evaluated once at process start.
let allTones: [AlarmTone] = {
    guard let root = Bundle.main.resourcePath else { return [] }
    let supported: Set<String> = ["mp3", "m4a", "caf", "wav", "aiff", "aif"]
    let items = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
    let files = items
        .filter { supported.contains(($0 as NSString).pathExtension.lowercased()) }
        .filter { ($0 as NSString).deletingPathExtension != "NoSound" }  // internal silent tone handed to AlarmKit
        .sorted(by: toneOrder)
    return files.map(makeTone(fileName:))
}()

private func makeTone(fileName: String) -> AlarmTone {
    let stem = (fileName as NSString).deletingPathExtension
    return AlarmTone(
        id: stem,
        fileName: fileName,
        name: prettyName(from: stem),
        hint: categoryHint(for: stem)
    )
}

/// "MorningPark_1" → "Morning Park 1", "loud3" → "Loud 3", "HappyClaps" → "Happy Claps".
private func prettyName(from stem: String) -> String {
    var out = ""
    var prev: Character = " "
    for ch in stem {
        if ch == "_" {
            out.append(" ")
        } else {
            if (ch.isUppercase && prev.isLowercase) || (ch.isNumber && prev.isLetter) {
                out.append(" ")
            }
            out.append(ch)
        }
        prev = ch
    }
    // Upper-case the first visible letter.
    if let first = out.firstIndex(where: { !$0.isWhitespace }) {
        out.replaceSubrange(first...first, with: String(out[first]).uppercased())
    }
    return out
}

/// Strip the trailing `_N` or `N` suffix; return base name if different.
private func categoryHint(for stem: String) -> String {
    if let under = stem.firstIndex(of: "_") {
        return prettyName(from: String(stem[..<under]))
    }
    let trailing = stem.reversed().prefix(while: { $0.isNumber }).count
    if trailing > 0, trailing < stem.count {
        return prettyName(from: String(stem.dropLast(trailing)))
    }
    return ""
}

/// "Awakening" pinned first, then case-insensitive natural sort.
private func toneOrder(_ a: String, _ b: String) -> Bool {
    let aw = "Awakening"
    let aIsAw = a.hasPrefix(aw)
    let bIsAw = b.hasPrefix(aw)
    if aIsAw != bIsAw { return aIsAw }
    return a.localizedStandardCompare(b) == .orderedAscending
}

// MARK: - Authorization state

enum AlarmAuthState: Equatable {
    case authorized, denied, notDetermined
}

private extension AlarmAuthState {
    init(_ raw: AlarmManager.AuthorizationState) {
        switch raw {
        case .authorized: self = .authorized
        case .denied:     self = .denied
        default:          self = .notDetermined
        }
    }
}

// MARK: - AlarmMeta

struct AlarmMeta: AlarmMetadata {}

// MARK: - AlarmService

@Observable
final class AlarmService {
    static let shared = AlarmService()

    private(set) var authState: AlarmAuthState = .notDetermined
    var isAuthorized: Bool { authState == .authorized }

    private let alertPresentation = AlarmPresentation(
        alert: AlarmPresentation.Alert(title: "Time to wake up!")
    )

    private init() {
        authState = AlarmAuthState(AlarmManager.shared.authorizationState)
        Task { await watchAuth() }
    }

    // MARK: Authorization

    func requestAuthorization() async throws -> Bool {
        log.info("⚙ requestAuthorization")
        let state = try await AlarmManager.shared.requestAuthorization()
        authState = AlarmAuthState(state)
        log.info("⚙ authState → \(String(describing: self.authState))")
        return state == .authorized
    }

    // MARK: Alerting stream

    /// Yields the alarmKitID string of the currently alerting alarm, or nil when none.
    var alertingAlarmIDStream: AsyncStream<String?> {
        AsyncStream { continuation in
            Task {
                for await alarms in AlarmManager.shared.alarmUpdates {
                    let alerting = alarms.first { $0.state == .alerting }
                    continuation.yield(alerting?.id.uuidString)
                }
                continuation.finish()
            }
        }
    }

    // MARK: Scheduling

    // Fixed slot for the backup/duplicate alarm — only one backup exists at a time.
    // Stable UUID so we can cancel it even after app relaunch without persisting the ID.
    static let backupSlotID = UUID(uuidString: "BACA1A12-0000-0000-0000-000000000001")!

    // Spec: 10–30s window. 20s gives the user enough time to re-open the app
    // before the duplicate fires, while still being short enough that a killed
    // app recovers the mission flow quickly.
    nonisolated static let backupDelaySeconds: TimeInterval = 20

    /// Reschedule a duplicate of `item` `delay` seconds from now. If the app is
    /// killed while the user is mid-mission, this duplicate re-triggers the flow
    /// via AlarmKit's system-level alerting. The caller is responsible for
    /// cancelling it on successful mission completion.
    func scheduleBackup(for item: AlarmItem, delay: TimeInterval = backupDelaySeconds) async throws -> UUID {
        let backupID = AlarmService.backupSlotID
        log.info("+ scheduleBackup itemID=\(item.id) delay=\(Int(delay))s backupID=\(backupID)")
        let fireDate = Date().addingTimeInterval(delay)
        // Intent resolves the item via pendingMission fallback when the backup fires.
        let intent = SolveMissionIntent(alarmIDString: item.alarmKitID ?? item.id.uuidString)
        let config = AlarmManager.AlarmConfiguration<AlarmMeta>.alarm(
            schedule: .fixed(fireDate),
            attributes: AlarmAttributes<AlarmMeta>(
                presentation: alertPresentation,
                metadata: nil,
                tintColor: .orange
            ),
            stopIntent: intent,
            secondaryIntent: nil,
            sound: alertSound(for: item)
        )
        _ = try await AlarmManager.shared.schedule(id: backupID, configuration: config)
        log.info("✓ backup scheduled backupID=\(backupID)")
        return backupID
    }

    func schedule(_ item: AlarmItem) async throws -> UUID {
        // Use item.id as the AlarmKit ID so re-scheduling updates in place, preventing accumulation.
        let alarmID = item.id
        log.info("+ schedule itemID=\(item.id) time=\(item.timeString) tone='\(item.toneID)' days=\(item.days) alarmKitID=\(alarmID)")
        let attrs = AlarmAttributes<AlarmMeta>(
            presentation: alertPresentation,
            metadata: nil,
            tintColor: .orange
        )
        let activeDays = weekdays(from: item.days)
        let schedule: Alarm.Schedule = activeDays.isEmpty
            ? .fixed(nextFireDate(for: item))
            : .relative(Alarm.Schedule.Relative(
                time: .init(hour: item.hour, minute: item.minute),
                repeats: .weekly(activeDays)
            ))

        let intent = SolveMissionIntent(alarmIDString: alarmID.uuidString)
        let config = AlarmManager.AlarmConfiguration<AlarmMeta>.alarm(
            schedule: schedule,
            attributes: attrs,
            stopIntent: intent,
            secondaryIntent: nil,
            sound: alertSound(for: item)
        )
        _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: config)
        log.info("✓ scheduled alarmKitID=\(alarmID)")
        return alarmID
    }

    func cancel(alarmKitID: String) throws {
        guard let uuid = UUID(uuidString: alarmKitID) else {
            log.warning("✗ cancel skipped — invalid UUID '\(alarmKitID)'")
            return
        }
        log.info("✗ cancel alarmKitID=\(alarmKitID)")
        try AlarmManager.shared.cancel(id: uuid)
    }

    /// Silence the system-level alert without removing the alarm.
    /// For `.relative(.weekly)` alarms AlarmKit returns to `.scheduled`; for
    /// `.fixed` alarms it transitions to completed. Callers rely on this to
    /// stop the OS alarm sound while the in-app `AudioService` takes over —
    /// otherwise both would play simultaneously.
    func stop(alarmKitID: String) {
        guard let uuid = UUID(uuidString: alarmKitID) else { return }
        do {
            try AlarmManager.shared.stop(id: uuid)
            log.info("◼ stop alarmKitID=\(alarmKitID)")
        } catch {
            log.warning("◼ stop failed alarmKitID=\(alarmKitID) err=\(error)")
        }
    }

    /// Idempotent — safe even if no backup is currently scheduled.
    func cancelBackup() {
        try? AlarmManager.shared.cancel(id: AlarmService.backupSlotID)
    }

    private func alertSound(for item: AlarmItem) -> AlertConfiguration.AlertSound {
        // AlarmKit plays the real tone — alarm-priority audio bypasses the
        // user's media-volume setting, so a user with vol=0 still wakes up.
        // This is the only reliable path when the app is backgrounded/killed.
        let tone = allTones.first { $0.id == item.toneID }
            ?? allTones.first { $0.id == defaultAlarmToneID }
        return tone.map { .named($0.fileName) } ?? .default
    }

    func nextFireDate(for item: AlarmItem) -> Date {
        let cal = Calendar.current
        let now = Date()
        let activeOffsets = item.days.enumerated().filter(\.element).map(\.offset)

        if activeOffsets.isEmpty {
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = item.hour
            comps.minute = item.minute
            comps.second = 0
            if let d = cal.date(from: comps), d > now { return d }
            return cal.date(byAdding: .day, value: 1, to: cal.date(from: comps)!)!
        }

        // days[0]=Mon … days[6]=Sun; Calendar .weekday: 1=Sun,2=Mon…7=Sat
        let todayWeekday = cal.component(.weekday, from: now)
        let todayIdx = (todayWeekday + 5) % 7

        for offset in 0..<8 {
            let dayIdx = (todayIdx + offset) % 7
            guard activeOffsets.contains(dayIdx) else { continue }
            var comps = cal.dateComponents([.year, .month, .day], from: now)
            comps.hour = item.hour
            comps.minute = item.minute
            comps.second = 0
            let base = cal.date(from: comps)!
            let candidate = base.addingTimeInterval(TimeInterval(offset * 86400))
            if candidate > now { return candidate }
        }
        return now.addingTimeInterval(7 * 86400)
    }

    // MARK: Debug

    #if DEBUG
    func cancelAllAlarms() async {
        var totalCancelled = 0
        for await alarms in AlarmManager.shared.alarmUpdates {
            guard !alarms.isEmpty else {
                log.warning("🗑 DEBUG cancelAllAlarms: done, total cancelled=\(totalCancelled)")
                break
            }
            log.warning("🗑 DEBUG cancelAllAlarms: batch of \(alarms.count)")
            for alarm in alarms {
                log.debug("🗑   cancel \(alarm.id)")
                try? AlarmManager.shared.cancel(id: alarm.id)
                totalCancelled += 1
            }
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        UNUserNotificationCenter.current().removeAllDeliveredNotifications()
        log.warning("🗑 DEBUG cancelAllAlarms: UNUserNotificationCenter cleared")
    }
    #endif

    // MARK: Private

    private func watchAuth() async {
        for await state in AlarmManager.shared.authorizationUpdates {
            authState = AlarmAuthState(state)
        }
    }

    private func weekdays(from days: [Bool]) -> [Locale.Weekday] {
        let map: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        return days.enumerated().compactMap { i, on in on ? map[i] : nil }
    }
}
