import SwiftUI

struct QuickAlarmSheet: View {
    let onStart: () -> Void

    @Environment(AlarmStore.self) private var store

    @AppStorage(.keyDefaultToneID)    private var defaultToneID    = defaultAlarmToneID
    @AppStorage(.keyDefaultVolume)    private var defaultVolume    = 70.0
    @AppStorage(.keyDefaultVibration) private var defaultVibration = true

    @State private var selectedMinutes = 15
    @State private var vibration = true
    @State private var volume: Double = 70

    private let presets = [1, 5, 10, 15, 30, 60]

    private var ringAtString: String {
        let date = Date().addingTimeInterval(Double(selectedMinutes) * 60)
        let cal = Calendar.current
        let h = cal.component(.hour, from: date)
        let m = cal.component(.minute, from: date)
        return String(format: "%d:%02d", h, m)
    }

    var body: some View {
        VStack(spacing: 0) {
            grabber

            header
                .padding(.horizontal, 22)
                .padding(.bottom, 16)

            previewCard
                .padding(.horizontal, 22)

            presetGrid
                .padding(.horizontal, 22)
                .padding(.top, 12)

            soundSection
                .padding(.horizontal, 22)
                .padding(.top, 16)

            OBButton(label: "Start alarm", variant: .primary, action: startAlarm)
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 28)
        }
        .onAppear {
            volume = defaultVolume
            vibration = defaultVibration
        }
    }

    // MARK: - Subviews

    private var grabber: some View {
        Capsule()
            .fill(OB.ink.opacity(0.15))
            .frame(width: 36, height: 4)
            .padding(.top, 10)
            .padding(.bottom, 16)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Quick alarm")
                    .font(.system(size: 22, weight: .bold))
                    .kerning(-0.5)
                    .foregroundStyle(OB.ink)
                Text("Ring me in…")
                    .font(.system(size: 13))
                    .foregroundStyle(OB.ink3)
            }
            Spacer()
        }
    }

    private var previewCard: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Ring in")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text("\(selectedMinutes) min")
                    .font(.system(size: 46, weight: .bold))
                    .kerning(-2)
                    .foregroundStyle(.white)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.spring(response: 0.25), value: selectedMinutes)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("AT")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundStyle(.white.opacity(0.5))
                Text(ringAtString)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .monospacedDigit()
            }
        }
        .padding(20)
        .background(OB.ink, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private var presetGrid: some View {
        LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(presets, id: \.self) { n in
                Button {
                    withAnimation(.spring(response: 0.25)) { selectedMinutes = n }
                } label: {
                    Text("\(n)m")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .foregroundStyle(selectedMinutes == n ? .white : OB.ink)
                        .background(
                            selectedMinutes == n ? OB.ink : OB.card,
                            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }

    private var soundSection: some View {
        VStack(spacing: 8) {
            HStack {
                Text("SOUND")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.6)
                    .foregroundStyle(OB.ink3)
                Spacer()
                Text(allTones.first { $0.id == defaultToneID }?.name ?? "Default")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(OB.ink3)
            }
            .padding(.horizontal, 4)

            HStack(spacing: 12) {
                Image(systemName: "speaker.wave.2")
                    .font(.system(size: 15))
                    .foregroundStyle(OB.ink2)
                Slider(value: $volume, in: 0...100)
                    .tint(OB.accent)
                Image(systemName: "waveform")
                    .font(.system(size: 15))
                    .foregroundStyle(vibration ? OB.ink2 : OB.ink3)
                Toggle("", isOn: $vibration)
                    .tint(OB.accent)
                    .labelsHidden()
                    .fixedSize()
            }
            .padding(14)
            .background(OB.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
    }

    // MARK: - Action

    private func startAlarm() {
        let fireDate = Date().addingTimeInterval(Double(selectedMinutes) * 60)
        let cal = Calendar.current
        let item = AlarmItem(
            hour: cal.component(.hour, from: fireDate),
            minute: cal.component(.minute, from: fireDate),
            days: Array(repeating: false, count: 7),
            isEnabled: true,
            missionIDs: ["off"],
            toneID: defaultToneID,
            volume: volume,
            vibration: vibration,
            isQuick: true
        )
        store.add(item)
        let idx = store.items.count - 1
        Task {
            if let uuid = try? await AlarmService.shared.schedule(item) {
                store.items[idx].alarmKitID = uuid.uuidString
                store.update(store.items[idx])
            }
        }
        onStart()
    }
}

#Preview {
    QuickAlarmSheet {}
        .background(OB.bg)
        .environment(AlarmStore())
}
