import SwiftUI

// MARK: - AppStorage Keys

extension String {
    static let keyDefaultToneID    = "defaultToneID"
    static let keyDefaultVolume    = "defaultVolume"
    static let keyDefaultVibration = "defaultVibration"
    static let keySnoozeDuration   = "snoozeDuration"
}

// MARK: - Settings View

struct SettingsView: View {
    let onBack: () -> Void

    @Environment(AlarmStore.self) private var store

    @AppStorage(.keyDefaultToneID)    private var defaultToneID    = "radar"
    @AppStorage(.keyDefaultVolume)    private var defaultVolume    = 70.0
    @AppStorage(.keyDefaultVibration) private var defaultVibration = true
    @AppStorage(.keySnoozeDuration)   private var snoozeDuration   = 5

    @State private var showRingtonePicker = false
    #if DEBUG
    @State private var debugClearing = false
    #endif

    private let alarmService = AlarmService.shared

    private var defaultToneName: String {
        allTones.first { $0.id == defaultToneID }?.name ?? defaultToneID.capitalized
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                ScrollView {
                    VStack(spacing: 24) {
                        defaultsSection
                        snoozeSection
                        permissionsSection
                        legalSection
                        #if DEBUG
                        debugSection
                        #endif
                    }
                    .padding(.top, 16)
                    .padding(.bottom, 40)
                }
            }
        }
        .sheet(isPresented: $showRingtonePicker) {
            RingtonePickerView(
                selectedID: defaultToneID,
                onDone: { id in
                    defaultToneID = id
                    showRingtonePicker = false
                },
                onBack: { showRingtonePicker = false }
            )
            .presentationDetents([.large])
            .presentationBackground(OB.bg)
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button {
                onBack()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OB.ink2)
            }
            Spacer()
            Text("Settings")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
            Spacer()
            Color.clear.frame(width: 60, height: 20)
        }
        .padding(.horizontal, 20)
        .padding(.top, 58)
        .padding(.bottom, 10)
    }

    // MARK: - Defaults section

    private var defaultsSection: some View {
        sectionCard(header: "DEFAULTS FOR NEW ALARMS") {
            settingsRow(isLast: false) {
                Text("Default ringtone")
                    .font(.system(size: 16))
                    .foregroundStyle(OB.ink)
                Spacer()
                Text(defaultToneName)
                    .font(.system(size: 15))
                    .foregroundStyle(OB.ink3)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(OB.ink3)
            }
            .contentShape(Rectangle())
            .onTapGesture { showRingtonePicker = true }

            settingsRow(isLast: false) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Default volume")
                            .font(.system(size: 16))
                            .foregroundStyle(OB.ink)
                        Spacer()
                        Text("\(Int(defaultVolume))%")
                            .font(.system(size: 14, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(OB.ink3)
                    }
                    HStack(spacing: 10) {
                        Image(systemName: "speaker")
                            .font(.system(size: 13))
                            .foregroundStyle(OB.ink3)
                        Slider(value: $defaultVolume, in: 0...100)
                            .tint(OB.accent)
                        Image(systemName: "speaker.wave.3")
                            .font(.system(size: 13))
                            .foregroundStyle(OB.ink3)
                    }
                }
            }

            settingsRow(isLast: true) {
                Text("Vibration")
                    .font(.system(size: 16))
                    .foregroundStyle(OB.ink)
                Spacer()
                Toggle("", isOn: $defaultVibration)
                    .tint(OB.accent)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Snooze section

    private var snoozeSection: some View {
        sectionCard(header: "SNOOZE DURATION") {
            settingsRow(isLast: true) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Duration")
                        .font(.system(size: 16))
                        .foregroundStyle(OB.ink)
                    Picker("Snooze", selection: $snoozeDuration) {
                        ForEach([5, 10, 15, 20], id: \.self) { n in
                            Text("\(n) min").tag(n)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    // MARK: - Permissions section

    private var permissionsSection: some View {
        sectionCard(header: "PERMISSIONS") {
            settingsRow(isLast: true) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(authBadgeColor.opacity(0.12))
                            .frame(width: 36, height: 36)
                        Image(systemName: authBadgeIcon)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(authBadgeColor)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Alarm access")
                            .font(.system(size: 16))
                            .foregroundStyle(OB.ink)
                        Text(authStatusLabel)
                            .font(.system(size: 12))
                            .foregroundStyle(OB.ink3)
                    }
                    Spacer()
                    if alarmService.authState != .authorized {
                        Button("Open Settings") {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(OB.accent)
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
            }
        }
    }

    private var authBadgeColor: Color {
        switch alarmService.authState {
        case .authorized:    return OB.ok
        case .denied:        return OB.accent
        case .notDetermined: return OB.ink3
        }
    }

    private var authBadgeIcon: String {
        switch alarmService.authState {
        case .authorized:    return "checkmark"
        case .denied:        return "xmark"
        case .notDetermined: return "questionmark"
        }
    }

    private var authStatusLabel: String {
        switch alarmService.authState {
        case .authorized:    return "Authorized"
        case .denied:        return "Denied — tap to open Settings"
        case .notDetermined: return "Not yet requested"
        }
    }

    // MARK: - Debug section

    #if DEBUG
    private var debugSection: some View {
        sectionCard(header: "DEBUG") {
            settingsRow(isLast: true) {
                Button {
                    guard !debugClearing else { return }
                    debugClearing = true
                    Task {
                        await AlarmService.shared.cancelAllAlarms()
                        store.backupAlarmKitID = nil
                        store.pendingMission = nil
                        store.firingAlarmID = nil
                        store.pendingSnooze = nil
                        for item in store.items {
                            var mutable = item
                            mutable.alarmKitID = nil
                            store.update(mutable)
                        }
                        debugClearing = false
                    }
                } label: {
                    HStack {
                        Text(debugClearing ? "Clearing…" : "🗑 Cancel ALL alarms")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(debugClearing ? OB.ink3 : OB.accent)
                        Spacer()
                    }
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(debugClearing)
            }
        }
    }
    #endif

    // MARK: - Legal section

    private var legalSection: some View {
        sectionCard(header: "LEGAL") {
            legalRow(title: "Terms of Use", isLast: false) {
                if let url = URL(string: "https://example.com/terms") {
                    UIApplication.shared.open(url)
                }
            }
            legalRow(title: "Privacy Policy", isLast: true) {
                if let url = URL(string: "https://example.com/privacy") {
                    UIApplication.shared.open(url)
                }
            }
        }
    }

    private func legalRow(title: String, isLast: Bool, action: @escaping () -> Void) -> some View {
        settingsRow(isLast: isLast) {
            Button(action: action) {
                HStack {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(OB.ink)
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(OB.ink3)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }

    // MARK: - Layout helpers

    private func sectionCard<Content: View>(header: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(header)
                .font(.system(size: 11, weight: .bold))
                .kerning(0.6)
                .foregroundStyle(OB.ink3)
                .padding(.horizontal, 22)
            VStack(spacing: 0) {
                content()
            }
            .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder
    private func settingsRow<Content: View>(isLast: Bool, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 0) {
            HStack { content() }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            if !isLast {
                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
    }
}

#Preview {
    SettingsView(onBack: {})
        .environment(AlarmStore())
}
