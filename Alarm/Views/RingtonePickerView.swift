import SwiftUI

struct RingtonePickerView: View {
    let onDone: (String) -> Void
    let onBack: () -> Void

    @State private var currentID: String

    private let audio = AudioService.shared

    init(selectedID: String, onDone: @escaping (String) -> Void, onBack: @escaping () -> Void) {
        self.onDone = onDone
        self.onBack = onBack
        _currentID = State(initialValue: selectedID)
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(allTones.enumerated()), id: \.element.id) { idx, tone in
                            toneRow(tone: tone, isLast: idx == allTones.count - 1)
                        }
                    }
                    .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal, 20)
                    .padding(.top, 14)
                    .padding(.bottom, 32)
                }
            }
        }
        .onDisappear { audio.stop() }
    }

    
    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button(action: { audio.stop(); onBack() }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                    Text("Back")
                }
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(OB.ink2)
            }
            Spacer()
            Text("Ringtone")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
            Spacer()
            Button("Done") { audio.stop(); onDone(currentID) }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(OB.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Tone row

    private func toneRow(tone: AlarmTone, isLast: Bool) -> some View {
        let isSelected = currentID == tone.id
        let isThisPlaying = audio.currentToneID == tone.id && audio.isPlaying
        return HStack(spacing: 14) {
            Button {
                currentID = tone.id
                audio.play(toneID: tone.id)
            } label: {
                ZStack {
                    Circle()
                        .fill(isSelected ? OB.accent : OB.ink.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: isThisPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : OB.ink)
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tone.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OB.ink)
                if !tone.hint.isEmpty {
                    Text(tone.hint)
                        .font(.system(size: 12))
                        .foregroundStyle(OB.ink3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                Circle()
                    .fill(isSelected ? OB.ink : Color.clear)
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(isSelected ? Color.clear : OB.ink.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(isSelected ? OB.accent2 : .clear)
        .contentShape(Rectangle())
        .onTapGesture { currentID = tone.id; audio.play(toneID: tone.id) }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }
}

#Preview {
    RingtonePickerView(selectedID: defaultAlarmToneID, onDone: { _ in }, onBack: {})
}
