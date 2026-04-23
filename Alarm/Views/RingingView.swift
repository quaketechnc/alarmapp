import os
import SwiftUI
import Combine

private let log = Logger(subsystem: "com.alarm", category: "ringing")

private let nightBg = Color(red: 0.102, green: 0.086, blue: 0.071)

struct RingingView: View {
    let missions: [String]
    let toneID: String
    var volume: Double = 70
    let onDismiss: () -> Void

    @State private var now = Date()
    @State private var showMission = false
    @State private var pulseScale: CGFloat = 1.0

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

                Button {
                    if missions.isEmpty {
                        onDismiss()
                    } else {
                        guard !showMission else { return }
                        showMission = true
                    }
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: missions.isEmpty ? "checkmark" : "arrow.right")
                            .font(.system(size: 16, weight: .semibold))
                            .opacity(0.7)
                        Text(missions.isEmpty ? "Dismiss alarm" : "Solve mission to dismiss")
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
                .padding(.bottom, 44)
            }
        }
        .onAppear {
            pulseScale = 1.3
            log.info("🔔 RingingView appear — toneID='\(toneID)' volume=\(Int(volume))% missions=\(missions) audio.isPlaying=\(AudioService.shared.isPlaying)")
            // watchAlarms starts audio synchronously when alerting is detected.
            // Only kick off here as a safety net for cold-launch via intent,
            // where watchAlarms hasn't observed an alerting event.
            // Small delay lets watchAlarms' async play() settle isPlaying=true first.
            Task {
                try? await Task.sleep(nanoseconds: 400_000_000)
                if !AudioService.shared.isPlaying {
                    log.info("🔔 RingingView cold-launch fallback play")
                    AudioService.shared.play(toneID: toneID, volume: volume, loops: -1)
                }
            }
        }
        .onDisappear {
            log.info("🔕 RingingView disappear")
            AudioService.shared.stop()
        }
        .onReceive(timer) { now = $0 }
        .fullScreenCover(isPresented: $showMission) {
            MissionExecutionView(
                missions: missions,
                onComplete: {
                    showMission = false
                    onDismiss()
                }
            )
        }
    }
}

#Preview {
    RingingView(missions: ["math", "typing"], toneID: defaultAlarmToneID, onDismiss: {})
}
