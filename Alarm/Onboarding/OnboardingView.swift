import SwiftUI
import UserNotifications

struct OnboardingView: View {
    @State private var coord = OnboardingCoordinator()
    @State private var goingBack = false
    @Environment(\.scenePhase) private var scenePhase
    let onComplete: (AlarmItem?) -> Void

    var body: some View {
        ScreenShell(
            step: coord.step.rawValue,
            totalSteps: OnboardingStep.allCases.count,
            showBack: coord.step != .intro,
            padding: 24,
            onBack: navigateBack
        ) {
            switch coord.step {
            case .intro:
                IntroScreen()
                    .transition(slideTransition)

            case .setAlarm:
                SetAlarmScreen(
                    hour: $coord.alarmHour,
                    minute: $coord.alarmMinute,
                    selectedDays: $coord.selectedDays
                )
                .transition(slideTransition)

            case .ringtone:
                RingtoneScreen(
                    selectedToneID: $coord.selectedToneID,
                    volume: $coord.volume,
                    playTone: coord.playTone,
                    stopTone: coord.stopTone
                )
                .transition(slideTransition)

            case .mission:
                MissionScreen(selectedMission: $coord.selectedMission)
                    .transition(slideTransition)

            case .permAlarm:
                PermAlarmScreen(state: $coord.alarmPermState)
                    .transition(slideTransition)

//            case .permNotif:
//                PermNotifScreen(state: $coord.notifPermState)
//                    .transition(slideTransition)
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            primaryButtonArea
        }
        .animation(.easeInOut(duration: 0.25), value: coord.step)
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            handleSceneActive()
        }
        .onChange(of: coord.step) { _, step in
            handleStepAppear(step)
        }
    }

    // MARK: - Primary button

    @ViewBuilder
    private var primaryButtonArea: some View {
        VStack(spacing: 8) {
            if coord.step == .permAlarm && coord.alarmPermState == .denied && !coord.alarmGrantedViaSettings {
                Button(action: buildAndComplete) {
                    Text("Continue anyway →")
                        .font(.system(size: 13))
                        .foregroundStyle(OB.ink3)
                        .padding(.vertical, 4)
                }
                .frame(maxWidth: .infinity)
                .transition(.opacity)
            }
            OBButton(label: primaryButtonLabel, variant: primaryButtonVariant, action: primaryButtonAction)
        }
        .padding(.horizontal, 22)
        .background(OB.bg)
        .animation(.easeInOut(duration: 0.15), value: primaryButtonLabel)
    }

    private var primaryButtonLabel: String {
        switch coord.step {
        case .intro:    return "Let's do this"
        case .setAlarm: return "Set Alarm"
        case .ringtone: return "Continue"
        case .mission:  return "Finish setup"
        case .permAlarm:
            if coord.alarmGrantedViaSettings   { return "Continue" }
            if coord.alarmPermState == .denied  { return "Open Settings" }
            return "Allow Alarms"
//        case .permNotif:
//            if coord.notifGrantedViaSettings   { return "Continue" }
//            if coord.notifPermState == .denied  { return "Open Settings" }
//            return "Allow Notifications"
        }
    }

    private var primaryButtonVariant: OBButton.Variant {
        switch coord.step {
        case .setAlarm, .mission: return .accent
        case .permAlarm where coord.alarmPermState == .denied && !coord.alarmGrantedViaSettings: return .secondary
//        case .permNotif where coord.notifPermState == .denied && !coord.notifGrantedViaSettings: return .secondary
        default: return .primary
        }
    }

    private func primaryButtonAction() {
        switch coord.step {
        case .intro:
            navigateNext()
        case .setAlarm:
            navigateNext()
        case .ringtone:
            coord.stopTone()
            navigateNext()
        case .mission:
            navigateNext()
        case .permAlarm:
            if coord.alarmGrantedViaSettings {
//                navigateNext()
                buildAndComplete()
            } else if coord.alarmPermState == .denied {
                openSettings()
            } else {
                coord.requestAlarmPermission(onGranted: navigateNext)
            }
//        case .permNotif:
//            if coord.notifGrantedViaSettings {
//                buildAndComplete()
//            } else if coord.notifPermState == .denied {
//                openSettings()
//            } else {
//                coord.requestNotifPermission(onGranted: buildAndComplete)
//            }
        }
    }

    // MARK: - Navigation

    private func navigateNext() { goingBack = false; coord.next() }
    private func navigateBack() { goingBack = true; coord.back() }

    private func buildAndComplete() {
        let item = AlarmItem(
            hour: coord.alarmHour,
            minute: coord.alarmMinute,
            days: coord.selectedDays,
            isEnabled: true,
            selectedMissions: [coord.selectedMission],
            toneID: coord.selectedToneID,
            volume: coord.volume,
            vibration: true
        )
        onComplete(item)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }

    // MARK: - Permission lifecycle

    private func handleStepAppear(_ step: OnboardingStep) {
        switch step {
        case .permAlarm:
            if AlarmService.shared.isAuthorized {
                withAnimation { coord.alarmPermState = .granted }
                coord.alarmGrantedViaSettings = true
            }
//        case .permNotif:
//            guard coord.notifPermState == .prompt else { return }
//            UNUserNotificationCenter.current().getNotificationSettings { settings in
//                DispatchQueue.main.async {
//                    if case .authorized = settings.authorizationStatus {
//                        withAnimation { coord.notifPermState = .granted }
//                    }
//                }
//            }
        default: break
        }
    }

    private func handleSceneActive() {
        switch coord.step {
        case .permAlarm:
            switch AlarmService.shared.authState {
            case .authorized:
                withAnimation { coord.alarmPermState = .granted }
                coord.alarmGrantedViaSettings = true
            case .denied:
                withAnimation { coord.alarmPermState = .denied }
                coord.alarmGrantedViaSettings = false
            case .notDetermined: break
            }
//        case .permNotif:
//            UNUserNotificationCenter.current().getNotificationSettings { settings in
//                DispatchQueue.main.async {
//                    switch settings.authorizationStatus {
//                    case .authorized, .provisional, .ephemeral:
//                        withAnimation { coord.notifPermState = .granted }
//                        coord.notifGrantedViaSettings = true
//                    case .denied:
//                        withAnimation { coord.notifPermState = .denied }
//                        coord.notifGrantedViaSettings = false
//                    default: break
//                    }
//                }
//            }
        default: break
        }
    }

    // MARK: - Transition

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
