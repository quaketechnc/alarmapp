import SwiftUI
import Combine
import AVFoundation

private let nightBg = Color(red: 0.102, green: 0.086, blue: 0.071)

struct RingingView: View {
    let missions: [String]
    let toneID: String
    var snoozeDuration: Int = 5
    let onDismiss: () -> Void
    let onSnooze: () -> Void

    @State private var now = Date()
    @State private var showMission = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var audioPlayer: AVAudioPlayer?

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var timeString: String {
        let h = Calendar.current.component(.hour, from: now)
        let m = Calendar.current.component(.minute, from: now)
        return String(format: "%02d:%02d", h, m)
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return "Alarm · \(f.string(from: now))"
    }

    var body: some View {
        ZStack {
            nightBg.ignoresSafeArea()
            RadialGradient(
                colors: [OB.accent.opacity(0.35), .clear],
                center: .init(x: 0.3, y: 0.2),
                startRadius: 0, endRadius: 300
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Color(red: 1, green: 0.55, blue: 0.26).opacity(0.25), .clear],
                center: .init(x: 0.75, y: 0.85),
                startRadius: 0, endRadius: 250
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Text(dateLabel)
                    .font(.system(size: 13, weight: .semibold))
                    .kerning(0.5)
                    .foregroundStyle(.white.opacity(0.6))
                    .textCase(.uppercase)
                    .padding(.top, 68)

                Text(timeString)
                    .font(.system(size: 92, weight: .ultraLight))
                    .kerning(-5)
                    .monospacedDigit()
                    .foregroundStyle(.white)
                    .padding(.top, 10)

                Spacer()

                ZStack {
                    Circle()
                        .fill(OB.accent.opacity(0.3))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    Circle()
                        .fill(OB.accent.opacity(0.5))
                        .frame(width: 96, height: 96)
                        .scaleEffect(max(1, pulseScale * 0.9))
                        .animation(
                            .easeInOut(duration: 1.6).delay(0.3).repeatForever(autoreverses: true),
                            value: pulseScale
                        )
                    Circle()
                        .fill(OB.accent)
                        .frame(width: 80, height: 80)
                        .overlay {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 32, weight: .medium))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: OB.accent.opacity(0.5), radius: 20, y: 8)
                }

                if !missions.isEmpty {
                    let name = allMissions.first { $0.id == missions[0] }?.name ?? "Mission"
                    HStack(spacing: 8) {
                        Image(systemName: "bolt.fill")
                        Text("Solve \(name) to dismiss")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.75))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: Capsule())
                    .padding(.top, 28)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        showMission = true
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "arrow.right")
                                .font(.system(size: 16, weight: .semibold))
                                .opacity(0.7)
                            Text("Slide to start mission")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 64)
                        .foregroundStyle(.white)
                        .background(
                            .white.opacity(0.1),
                            in: RoundedRectangle(cornerRadius: 32, style: .continuous)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 32, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 2)
                        )
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .padding(.horizontal, 22)

                    Button(action: onSnooze) {
                        Text("Snooze · \(snoozeDuration) min")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.white.opacity(0.55))
                    }
                    .frame(height: 32)
                }
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            pulseScale = 1.3
            playTone()
        }
        .onDisappear { stopTone() }
        .onReceive(timer) { now = $0 }
        .fullScreenCover(isPresented: $showMission) {
            MissionExecutionView(
                missions: missions,
                onComplete: {
                    showMission = false
                    onDismiss()
                },
                onCancel: {
                    showMission = false
                }
            )
        }
    }

    private func playTone() {
        guard let tone = allTones.first(where: { $0.id == toneID }),
              let url = Bundle.main.url(forResource: tone.fileName, withExtension: "mp3")
        else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.numberOfLoops = -1
            audioPlayer?.play()
        } catch {}
    }

    private func stopTone() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

#Preview {
    RingingView(missions: ["math", "typing"], toneID: "sunrise", onDismiss: {}, onSnooze: {})
}
