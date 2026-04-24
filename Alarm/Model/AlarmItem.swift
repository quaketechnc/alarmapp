//
//  AlarmItem.swift
//  Alarm
//
//  Created by Oleksii on 23.04.2026.
//

import Foundation

struct AlarmItem: Identifiable, Codable, Equatable {
    var id = UUID()
    var hour: Int
    var minute: Int
    var days: [Bool]  // 7 elements: Mon–Sun
    var isEnabled: Bool = true
    var selectedMissions: [AlarmMission] = []
    var toneID: String = defaultAlarmToneID
    var volume: Double = 70
    var vibration: Bool = true
    var alarmKitID: String?
    var isQuick: Bool = false  // ephemeral: created via QuickAlarmSheet, removed after firing
    /// Per-alarm photo-mission whitelist. `nil` or empty = all objects in the
    /// catalog are eligible. Populated via `PhotoTaskPickerView` when the user
    /// includes the Photo mission.
    var photoTaskIDs: [String]? = nil

    var timeString: String { String(format: "%d:%02d", hour, minute) }

    var daysLabel: String {
        let abbr = ["Mon","Tue","Wed","Thu","Fri","Sat","Sun"]
        let active = days.enumerated().filter(\.element).map { abbr[$0.offset] }
        if active.count == 7 { return "Every day" }
        if active == ["Mon","Tue","Wed","Thu","Fri"] { return "Weekdays" }
        if active == ["Sat","Sun"] { return "Weekends" }
        return active.isEmpty ? "Once" : active.joined(separator: ", ")
    }

    var primaryMissionName: String { selectedMissions.first?.name ?? "None" }

    var toneName: String {
        allTones.first { $0.id == toneID }?.name ?? toneID.capitalized
    }
}
struct AlarmMission: Identifiable, Codable, Equatable {
    let id: AlarmMissionType
    let name: String
    let desc: String
    let level: String
    
    init(from id: AlarmMissionType) {
        if let mission = allMissions.first(where: {$0.id == id}) {
            self.id = id
            self.name = mission.name
            self.desc = mission.desc
            self.level = mission.desc
        } else {
            self.id = .off
            self.name = "off"
            self.desc = "Just dismiss. For the brave."
            self.level = "None"
        }
    }
    
    init(id: AlarmMissionType, name: String, desc: String, level: String) {
        self.id = id
        self.name = name
        self.desc = desc
        self.level = level
    }
    
}

enum AlarmMissionType:String, Codable {
    case math
    case type
    case tiles
    case shake
    case photo
    case off
}

let allMissions: [AlarmMission] = [
    AlarmMission(id: .math,   name: "Math",             desc: "Solve problems to dismiss.",       level: "Hard"),
    AlarmMission(id: .type,   name: "Typing",           desc: "Type a passage word-for-word.",    level: "Medium"),
    AlarmMission(id: .tiles,  name: "Find color tiles", desc: "Tap tiles in the right order.",    level: "Medium"),
    AlarmMission(id: .shake,  name: "Shake",            desc: "Shake your phone. A lot.",         level: "Easy"),
    AlarmMission(id: .photo,  name: "Photo",            desc: "Seek object and make photo.",      level: "Hard"),
    AlarmMission(id: .off,    name: "Off",              desc: "Just dismiss. For the brave.",     level: "None"),
]
