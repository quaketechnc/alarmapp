import os
import SwiftUI
import Combine

private let log = Logger(subsystem: "com.alarm", category: "ringing")

private let nightBg = Color(red: 0.102, green: 0.086, blue: 0.071)

struct RingingView: View {
    let missions: [AlarmMission]
    let toneID: String?
    var volume: Double = 70
    let onDismiss: () -> Void

    @Environment(AlarmStore.self) private var store

    @State private var now = Date()
    @State private var showMission = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var selectedMission:AlarmMission

    init(missions: [AlarmMission], toneID: String?, volume: Double = 70, onDismiss: @escaping () -> Void,) {
        self.missions = missions
        self.toneID = toneID
        self.volume = volume
        self.onDismiss = onDismiss
        self.selectedMission = missions.randomElement() ?? AlarmMission(from: .off)
    }
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
            background

            VStack(spacing: 0) {
                timeHeader

                Spacer()
                animatedRingBell
                currentMissionConteiner()
                    .padding(.top, 24)

                Spacer()

                Button {
                    if selectedMission.id == .off{
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
            .padding(.top, 25)
        }
        .onAppear {
            // Suppress rescue-loop reschedules while the alarm UI is on screen.
            store.isOnMissionScreen = true
            pulseScale = 1.3
            if let toneID = toneID {
                log.info("🔔 RingingView appear — toneID='\(toneID)' volume=\(Int(volume))% audio.isPlaying=\(AudioService.shared.isPlaying)")
                // Foreground + key window — MPVolumeView push works here.
                AudioService.shared.setVolume(volume)
                // Belt-and-braces: if rescue-loop hasn't started audio yet,
                // start it now so the user doesn't sit in silence.
                Task {
                    try? await Task.sleep(nanoseconds: 200_000_000)
                    if !AudioService.shared.isPlaying {
                        log.info("🔔 RingingView fallback play")
                        AudioService.shared.play(toneID: toneID, volume: volume, loops: -1)
                    }
                }
            } else {
                log.info("🔔 RingingView appear without tone")
            }
        }
        .onDisappear {
            store.isOnMissionScreen = false
        }
        .onReceive(timer) { now = $0 }
        .fullScreenCover(isPresented: $showMission) {
            MissionExecutionView(
                missions: missions,
                startingMission: selectedMission,
                onComplete: {
                    showMission = false
                    onDismiss()
                }
            )
        }
    }
    
    
    private var timeHeader: some View  {
        VStack(spacing: 0) {
            Text(dateLabel)
                .font(.system(size: 13, weight: .semibold))
                .kerning(0.5)
                .foregroundStyle(.white.opacity(0.6))
                .textCase(.uppercase)

            Text(timeString)
                .font(.system(size: 92, weight: .ultraLight))
                .kerning(-5)
                .monospacedDigit()
                .foregroundStyle(.white)
        }
    }
    private var animatedRingBell: some View {
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
    }
    
    @ViewBuilder
    private func currentMissionConteiner() -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bolt.fill")
            Text(selectedMission.desc)
        }
        .font(.system(size: 13, weight: .medium))
        .foregroundStyle(.white.opacity(0.75))
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.white.opacity(0.12), in: Capsule())
    }
    
    private var background: some View {
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
        }
    }
}

#Preview {
    RingingView(missions: [
        AlarmMission(from: .math),
        AlarmMission(from: .off),
        AlarmMission(from: .photo),
        AlarmMission(from: .shake),
        AlarmMission(from: .tiles),
        AlarmMission(from: .type)
    ],
                toneID: nil) { print("done") }
    .environment(AlarmStore())
}
