import SwiftUI

struct AlarmItem: Identifiable, Codable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var days: [Bool]  // 7 elements: Mon–Sun
    var isEnabled: Bool = true
    var missionIDs: [String] = ["math"]
    var toneID: String = "sunrise"
    var volume: Double = 70
    var vibration: Bool = true
    var alarmKitID: String?

    var timeString: String { String(format: "%d:%02d", hour, minute) }

    var daysLabel: String {
        let abbr = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        let active = days.enumerated().filter(\.element).map { abbr[$0.offset] }
        if active.count == 7 { return "Every day" }
        if active == ["Mon","Tue","Wed","Thu","Fri"] { return "Weekdays" }
        if active == ["Sat","Sun"] { return "Weekends" }
        return active.isEmpty ? "Once" : active.joined(separator: ", ")
    }

    var primaryMissionName: String {
        guard let first = missionIDs.first else { return "None" }
        return allMissions.first { $0.id == first }?.name ?? "None"
    }

    var toneName: String {
        allTones.first { $0.id == toneID }?.name ?? toneID.capitalized
    }
}

@Observable
final class AlarmStore {
    var items: [AlarmItem] = []
    var firingAlarmID: String?
    var pendingSnooze: AlarmItem?

    private static let udKey = "alarmItems"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.udKey),
           let saved = try? JSONDecoder().decode([AlarmItem].self, from: data) {
            items = saved
        } else {
            items = Self.demoItems
        }
    }

    private static var demoItems: [AlarmItem] { [] }

    private func save() {
        if let data = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(data, forKey: Self.udKey)
        }
    }

    func toggle(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].isEnabled.toggle()
        save()
    }

    func add(_ item: AlarmItem) {
        items.append(item)
        save()
    }

    func update(_ item: AlarmItem) {
        guard let i = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[i] = item
        save()
    }

    func delete(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
        save()
    }
}
