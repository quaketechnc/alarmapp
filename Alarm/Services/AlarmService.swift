import ActivityKit
import AlarmKit
import AudioToolbox
import os
import SwiftUI
import UserNotifications

private let log = Logger(subsystem: "com.alarm", category: "service")

// MARK: - Tone model

struct AlarmTone: Identifiable {
    let id: String
    let name: String
    let hint: String
    let systemSoundName: String
    let systemSoundID: SystemSoundID  // AudioServices fallback when file path is inaccessible

    var previewURL: URL? {
        // Library/Sounds is writable and readable by AlarmKit — check there first.
        let installed = SoundInstaller.soundsDir.appendingPathComponent("\(systemSoundName).caf")
        if FileManager.default.fileExists(atPath: installed.path) { return installed }
        return AlarmTone.findSystemSound(named: systemSoundName)
    }

    // Candidate paths across iOS versions; we pick the first that exists at runtime.
    static func findSystemSound(named name: String) -> URL? {
        let candidates: [String] = [
            "/System/Library/Audio/UISounds/New/\(name).caf",
            "/System/Library/Audio/UISounds/New/\(name).m4r",
            "/System/Library/Audio/UISounds/\(name).caf",
            "/System/Library/Ringtones/\(name).m4r",
            "/Library/Ringtones/\(name).m4r",
        ]
        return candidates
            .map { URL(fileURLWithPath: $0) }
            .first { FileManager.default.fileExists(atPath: $0.path) }
    }

    #if DEBUG
    static func discoverSoundPaths() {
        let log = Logger(subsystem: "com.alarm", category: "sound-discovery")
        let roots = [
            "/System/Library/Audio/UISounds",
            "/System/Library/Audio/UISounds/New",
            "/System/Library/Ringtones",
            "/Library/Ringtones",
        ]
        for root in roots {
            let items = (try? FileManager.default.contentsOfDirectory(atPath: root)) ?? []
            if items.isEmpty {
                log.debug("🔍 \(root) — not accessible or empty")
            } else {
                log.info("🔍 \(root): \(items.prefix(10).joined(separator: ", "))\(items.count > 10 ? " …+\(items.count-10)" : "")")
            }
        }
    }
    #endif
}

let allTones: [AlarmTone] = [
    AlarmTone(id: "radar",       name: "Radar",        hint: "classic alarm",    systemSoundName: "Radar",      systemSoundID: 1304),
    AlarmTone(id: "apex",        name: "Apex",         hint: "rising tones",     systemSoundName: "Apex",       systemSoundID: 1305),
    AlarmTone(id: "beacon",      name: "Beacon",       hint: "soft pulses",      systemSoundName: "Beacon",     systemSoundID: 1306),
    AlarmTone(id: "chimes",      name: "Chimes",       hint: "gentle bells",     systemSoundName: "Chimes",     systemSoundID: 1307),
    AlarmTone(id: "cosmic",      name: "Cosmic",       hint: "deep space",       systemSoundName: "Cosmic",     systemSoundID: 1308),
    AlarmTone(id: "hillside",    name: "Hillside",     hint: "nature",           systemSoundName: "Hillside",   systemSoundID: 1309),
    AlarmTone(id: "night-owl",   name: "Night Owl",    hint: "mellow",           systemSoundName: "Night Owl",  systemSoundID: 1310),
    AlarmTone(id: "ripples",     name: "Ripples",      hint: "water",            systemSoundName: "Ripples",    systemSoundID: 1311),
    AlarmTone(id: "sencha",      name: "Sencha",       hint: "calm",             systemSoundName: "Sencha",     systemSoundID: 1312),
    AlarmTone(id: "slow-rise",   name: "Slow Rise",    hint: "gradual build",    systemSoundName: "Slow Rise",  systemSoundID: 1313),
    AlarmTone(id: "uplift",      name: "Uplift",       hint: "energetic",        systemSoundName: "Uplift",     systemSoundID: 1314),
    AlarmTone(id: "waves",       name: "Waves",        hint: "ocean",            systemSoundName: "Waves",      systemSoundID: 1315),
]

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
        alert: AlarmPresentation.Alert(
            title: "Time to wake up!",
            secondaryButton: AlarmButton(
                text: "Solve Mission",
                textColor: .orange,
                systemImageName: "bolt.fill"
            ),
            secondaryButtonBehavior: .custom
        )
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

    /// One-time alarm `delay` seconds from now with the same tone/missions as `item`.
    /// Cancel when the user solves the mission so it doesn't fire unnecessarily.
    // Fixed slot for the backup alarm — only one backup exists at a time, so one ID suffices.
    static let backupSlotID = UUID(uuidString: "BACA1A12-0000-0000-0000-000000000001")!

    func scheduleBackup(for item: AlarmItem, delay: TimeInterval = 10) async throws -> UUID {
        let backupID = AlarmService.backupSlotID
        log.info("+ scheduleBackup itemID=\(item.id) delay=\(Int(delay))s backupID=\(backupID)")
        let fireDate = Date().addingTimeInterval(delay)
        let sound: AlertConfiguration.AlertSound = allTones
            .first(where: { $0.id == item.toneID })
            .map { .named($0.systemSoundName) } ?? .default
        let intent = SolveMissionIntent()
        let config = AlarmManager.AlarmConfiguration<AlarmMeta>.alarm(
            schedule: .fixed(fireDate),
            attributes: AlarmAttributes<AlarmMeta>(
                presentation: alertPresentation,
                metadata: nil,
                tintColor: .orange
            ),
            stopIntent: intent,
            secondaryIntent: intent,
            sound: sound
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
        let sound: AlertConfiguration.AlertSound = allTones
            .first(where: { $0.id == item.toneID })
            .map { .named($0.systemSoundName) } ?? .default

        let intent = SolveMissionIntent()
        let config = AlarmManager.AlarmConfiguration<AlarmMeta>.alarm(
            schedule: schedule,
            attributes: attrs,
            stopIntent: intent,
            secondaryIntent: intent,
            sound: sound
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
