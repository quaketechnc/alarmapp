import SwiftUI

struct OnboardingView: View {
    @State private var coord = OnboardingCoordinator()
    @State private var goingBack = false
    let onComplete: (AlarmItem?) -> Void

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()

            switch coord.step {
            case .intro:
                IntroScreen(onNext: navigateNext)
                    .transition(slideTransition)

            case .setAlarm:
                SetAlarmScreen(
                    hour: $coord.alarmHour,
                    minute: $coord.alarmMinute,
                    selectedDays: $coord.selectedDays,
                    onNext: navigateNext,
                    onSkip: { onComplete(nil) },
                    onBack: navigateBack
                )
                .transition(slideTransition)

            case .ringtone:
                RingtoneScreen(
                    selectedToneID: $coord.selectedToneID,
                    volume: $coord.volume,
                    onNext: navigateNext,
                    onBack: navigateBack,
                    playTone: coord.playTone,
                    stopTone: coord.stopTone
                )
                .transition(slideTransition)
                
            case .permAlarm:
                PermAlarmScreen(
                    state: $coord.alarmPermState,
                    onNext: navigateNext,
                    onBack: navigateBack
                )
                .transition(slideTransition)

            case .permNotif:
                PermNotifScreen(
                    state: $coord.notifPermState,
                    onNext: navigateNext,
                    onBack: navigateBack
                )
                .transition(slideTransition)

            case .mission:
                MissionScreen(
                    selectedMissionID: $coord.selectedMissionID,
                    onFinish: buildAndComplete,
                    onBack: navigateBack
                )
                .transition(slideTransition)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: coord.step)
    }

    private func navigateNext() { goingBack = false; coord.next() }
    private func navigateBack() { goingBack = true; coord.back() }

    private func buildAndComplete() {
        let missions = coord.selectedMissionID == "off" ? [] : [coord.selectedMissionID]
        let item = AlarmItem(
            hour: coord.alarmHour,
            minute: coord.alarmMinute,
            days: coord.selectedDays,
            isEnabled: true,
            missionIDs: missions,
            toneID: coord.selectedToneID,
            volume: coord.volume,
            vibration: true
        )
        onComplete(item)
    }

    private var slideTransition: AnyTransition {
        goingBack
            ? .asymmetric(
                insertion: .move(edge: .leading).combined(with: .opacity),
                removal: .move(edge: .trailing).combined(with: .opacity)
              )
            : .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .move(edge: .leading).combined(with: .opacity)
              )
    }
}

#Preview {
    OnboardingView(onComplete: { _ in })
}
