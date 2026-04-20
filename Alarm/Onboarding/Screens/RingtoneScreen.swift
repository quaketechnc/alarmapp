import SwiftUI

struct RingtoneScreen: View {
    @Binding var selectedToneID: String
    @Binding var volume: Double
    @State private var playingID: String? = nil
    let onNext: () -> Void
    let onBack: () -> Void
    let playTone: (String) -> Void
    let stopTone: () -> Void

    var body: some View {
        ScreenShell(step: 4, totalSteps: 6, onBack: onBack) {
            VStack(alignment: .leading, spacing: 0) {
                Text("Pick a sound.")
                    .font(.system(size: 28, weight: .bold))
                    .kerning(-0.8)
                    .foregroundStyle(OB.ink)
                    .padding(.top, 24)

                Text("You'll hear it every day. Choose wisely.")
                    .font(.system(size: 14))
                    .foregroundStyle(OB.ink2)
                    .padding(.top, 6)

                // Volume card
                VStack(spacing: 10) {
                    HStack {
                        Text("Volume")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OB.ink2)
                        Spacer()
                        Text("\(Int(volume))%")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(OB.ink)
                            .monospacedDigit()
                    }
                    Slider(value: $volume, in: 0...100)
                        .tint(OB.accent)
                }
                .padding(16)
                .background(OB.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.top, 18)

                // Tone list
                VStack(spacing: 0) {
                    ForEach(Array(allTones.enumerated()), id: \.element.id) { index, tone in
                        toneRow(tone: tone, isLast: index == allTones.count - 1)
                    }
                }
                .background(OB.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
                .padding(.top, 14)

                Spacer()

                OBButton(label: "Continue", variant: .primary, action: {
                    stopTone()
                    onNext()
                })
                .padding(.top, 14)
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 22)
        }
    }

    private func toneRow(tone: AlarmTone, isLast: Bool) -> some View {
        let selected = tone.id == selectedToneID
        let isPlaying = playingID == tone.id

        return HStack(spacing: 12) {
            // Play/pause button
            Button {
                if isPlaying {
                    stopTone()
                    playingID = nil
                } else {
                    stopTone()
                    playingID = tone.id
                    playTone(tone.id)
                }
            } label: {
                ZStack {
                    Circle()
                        .fill(isPlaying ? OB.accent : OB.ink.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isPlaying ? .white : OB.ink)
                }
            }
            .buttonStyle(PlainButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(tone.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OB.ink)
                Text(tone.hint)
                    .font(.system(size: 12))
                    .foregroundStyle(OB.ink3)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Selection indicator
            ZStack {
                Circle()
                    .fill(selected ? OB.ink : .clear)
                    .frame(width: 22, height: 22)
                Circle()
                    .stroke(selected ? Color.clear : OB.ink.opacity(0.15), lineWidth: 1.5)
                    .frame(width: 22, height: 22)
                if selected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(selected ? OB.accent2 : .clear)
        .contentShape(Rectangle())
        .onTapGesture { selectedToneID = tone.id }
        .overlay(alignment: .bottom) {
            if !isLast {
                Rectangle()
                    .fill(OB.line)
                    .frame(height: 0.5)
                    .padding(.leading, 16)
            }
        }
        .animation(.easeInOut(duration: 0.15), value: selected)
    }
}

#Preview {
    RingtoneScreen(
        selectedToneID: .constant("sunrise"),
        volume: .constant(70),
        onNext: {}, onBack: {},
        playTone: { _ in }, stopTone: {}
    )
}
