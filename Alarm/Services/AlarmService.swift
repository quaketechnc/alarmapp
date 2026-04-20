import AlarmKit
import Foundation
import SwiftUI

struct AlarmMeta: AlarmMetadata {}

final class AlarmService {
    static let shared = AlarmService()

    private let alertPresentation = AlarmPresentation(
        alert: AlarmPresentation.Alert(title: "Time to wake up!")
    )

    func schedule(_ item: AlarmItem) async throws -> UUID {
        let alarmID = UUID()
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
        let config = AlarmManager.AlarmConfiguration<AlarmMeta>.alarm(
            schedule: schedule,
            attributes: attrs
        )
        _ = try await AlarmManager.shared.schedule(id: alarmID, configuration: config)
        return alarmID
    }

    func cancel(alarmKitID: String) throws {
        guard let uuid = UUID(uuidString: alarmKitID) else { return }
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

    private func weekdays(from days: [Bool]) -> [Locale.Weekday] {
        let map: [Locale.Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
        return days.enumerated().compactMap { i, on in on ? map[i] : nil }
    }
}
