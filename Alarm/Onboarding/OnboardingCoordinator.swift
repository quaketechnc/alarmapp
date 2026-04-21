import SwiftUI
import UserNotifications

// MARK: - Data models

enum OnboardingStep: Int, CaseIterable {
    case intro, setAlarm, ringtone, mission, permAlarm, permNotif
}

enum PermState { case prompt, granted, denied }

struct AlarmMission: Identifiable {
    let id: String
    let name: String
    let desc: String
    let level: String
}

let allMissions: [AlarmMission] = [
    AlarmMission(id: "math",   name: "Math",             desc: "Solve problems to dismiss.",       level: "Hard"),
    AlarmMission(id: "type",   name: "Typing",           desc: "Type a passage word-for-word.",    level: "Medium"),
    AlarmMission(id: "tiles",  name: "Find color tiles", desc: "Tap tiles in the right order.",    level: "Medium"),
    AlarmMission(id: "shake",  name: "Shake",            desc: "Shake your phone. A lot.",         level: "Easy"),
    AlarmMission(id: "off",    name: "Off",              desc: "Just dismiss. For the brave.",     level: "None"),
]

// MARK: - Coordinator

@Observable
final class OnboardingCoordinator {
    var step: OnboardingStep = .intro
    var alarmHour: Int = 7
    var alarmMinute: Int = 0
    var selectedDays: [Bool] = [true, true, true, true, true, false, false]
    var alarmPermState: PermState = .prompt
    var notifPermState: PermState = .prompt
    var alarmGrantedViaSettings = false
    var notifGrantedViaSettings = false
    var selectedToneID: String = "sunrise"
    var volume: Double = 70 {
        didSet { AudioService.shared.setVolume(volume) }
    }
    var selectedMissionID: String = "math"

    func next() {
        let nextRaw = step.rawValue + 1
        guard nextRaw < OnboardingStep.allCases.count else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            step = OnboardingStep(rawValue: nextRaw)!
        }
    }

    func back() {
        guard step.rawValue > 0 else { return }
        withAnimation(.easeInOut(duration: 0.25)) {
            step = OnboardingStep(rawValue: step.rawValue - 1)!
        }
    }

    func toggleDay(_ index: Int) {
        selectedDays[index].toggle()
    }

    // MARK: Permissions

    func requestAlarmPermission(onGranted: @escaping () -> Void) {
        Task {
            do {
                let granted = try await AlarmService.shared.requestAuthorization()
                await MainActor.run {
                    withAnimation { alarmPermState = granted ? .granted : .denied }
                    if granted { onGranted() }
                }
            } catch {
                await MainActor.run { withAnimation { alarmPermState = .denied } }
            }
        }
    }

    func requestNotifPermission(onGranted: @escaping () -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                withAnimation { self.notifPermState = granted ? .granted : .denied }
                if granted { onGranted() }
            }
        }
    }

    // MARK: Audio preview

    func playTone(_ toneID: String) {
        AudioService.shared.play(toneID: toneID, volume: volume)
    }

    func stopTone() {
        AudioService.shared.stop()
    }
}
