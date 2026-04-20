import SwiftUI
import AVFoundation

struct RingtonePickerView: View {
    let selectedID: String
    let onDone: (String) -> Void
    let onBack: () -> Void

    @State private var playing: String
    @State private var audioPlayer: AVAudioPlayer?

    init(selectedID: String, onDone: @escaping (String) -> Void, onBack: @escaping () -> Void) {
        self.selectedID = selectedID
        self.onDone = onDone
        self.onBack = onBack
        _playing = State(initialValue: selectedID)
    }

    private var currentTone: AlarmTone {
        allTones.first { $0.id == playing } ?? allTones[0]
    }

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                navBar
                playerChip
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
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
        .onDisappear { stopAudio() }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack {
            Button(action: { stopAudio(); onBack() }) {
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
            Button("Done") { stopAudio(); onDone(playing) }
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(OB.accent)
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
        .padding(.bottom, 12)
    }

    // MARK: - Player chip

    private var playerChip: some View {
        HStack(spacing: 12) {
            Button {
                if audioPlayer?.isPlaying == true { stopAudio() }
                else { playAudio(playing) }
            } label: {
                ZStack {
                    Circle().fill(OB.accent).frame(width: 40, height: 40)
                    Image(systemName: audioPlayer?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .buttonStyle(ScaleButtonStyle())

            VStack(alignment: .leading, spacing: 2) {
                Text(currentTone.name)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                Text("now playing · preview")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()

            // Mini waveform bars
            HStack(spacing: 2) {
                ForEach(0..<8, id: \.self) { i in
                    WaveBar(index: i, isPlaying: audioPlayer?.isPlaying == true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(OB.ink, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            LinearGradient(
                colors: [OB.accent.opacity(0.2), .clear],
                startPoint: .leading,
                endPoint: .trailing
            )
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        )
    }

    // MARK: - Tone row

    private func toneRow(tone: AlarmTone, isLast: Bool) -> some View {
        let isSelected = playing == tone.id
        return HStack(spacing: 14) {
            Button {
                playing = tone.id
                playAudio(tone.id)
            } label: {
                ZStack {
                    Circle()
                        .fill(isSelected ? OB.accent : OB.ink.opacity(0.06))
                        .frame(width: 36, height: 36)
                    Image(systemName: isSelected && audioPlayer?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isSelected ? .white : OB.ink)
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
        .onTapGesture { playing = tone.id; playAudio(tone.id) }
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

    // MARK: - Audio

    private func playAudio(_ id: String) {
        guard let tone = allTones.first(where: { $0.id == id }),
              let url = Bundle.main.url(forResource: tone.fileName, withExtension: "mp3")
        else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            stopAudio()
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.play()
        } catch {}
    }

    private func stopAudio() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

private struct WaveBar: View {
    let index: Int
    let isPlaying: Bool

    @State private var height: CGFloat = 4

    var body: some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(OB.accent)
            .frame(width: 2, height: height)
            .onAppear { animate() }
            .onChange(of: isPlaying) { _, _ in animate() }
    }

    private func animate() {
        guard isPlaying else { height = 4; return }
        let maxH: CGFloat = CGFloat(8 + (index % 4) * 4)
        withAnimation(
            .easeInOut(duration: 0.3 + Double(index) * 0.04)
            .repeatForever(autoreverses: true)
        ) {
            height = maxH
        }
    }
}

#Preview {
    RingtonePickerView(selectedID: "sunrise", onDone: { _ in }, onBack: {})
}
