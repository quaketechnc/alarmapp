import SwiftUI
import UserNotifications
import AVFoundation

// MARK: - Data models

enum OnboardingStep: Int, CaseIterable {
    case intro, setAlarm, ringtone,  mission, permAlarm, permNotif
}

enum PermState { case prompt, granted, denied }

struct AlarmTone: Identifiable {
    let id: String
    let name: String
    let hint: String
    let fileName: String
}

let allTones: [AlarmTone] = [
    AlarmTone(id: "bells",   name: "Soft Bells",    hint: "gentle chimes",    fileName: "Bell"),
    AlarmTone(id: "sunrise", name: "Sunrise",        hint: "warm pads rising", fileName: "ReadyForTheNewDawn_1"),
    AlarmTone(id: "digital", name: "Digital Beep",   hint: "classic, urgent",  fileName: "Beep"),
    AlarmTone(id: "rooster", name: "Rooster",         hint: "farm energy",      fileName: "Rooster"),
    AlarmTone(id: "water",   name: "Waterfall",       hint: "white noise",      fileName: "Noise_1"),
    AlarmTone(id: "siren",   name: "Siren",           hint: "hard to ignore",   fileName: "Siren"),
]

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
    var selectedToneID: String = "sunrise"
    var volume: Double = 70 {
        didSet { audioPlayer?.volume = Float(volume / 100) }
    }
    var selectedMissionID: String = "math"

    @ObservationIgnored private var audioPlayer: AVAudioPlayer?

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

    // MARK: Notifications
    func requestNotificationPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                self.notifPermState = granted ? .granted : .denied
                completion(granted)
            }
        }
    }

    // MARK: Audio preview
    func playTone(_ toneID: String) {
        guard let tone = allTones.first(where: { $0.id == toneID }),
              let url = Bundle.main.url(forResource: tone.fileName, withExtension: "mp3") else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer?.stop()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = Float(volume / 100)
            audioPlayer?.play()
        } catch {}
    }

    func stopTone() {
        audioPlayer?.stop()
    }
}
