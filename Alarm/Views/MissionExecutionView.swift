import AVFoundation
import SwiftUI
import Combine
import CoreMotion

// MARK: - Shell
#Preview {
    MissionExecutionView(missions: [
        AlarmMission(from: .math),
        AlarmMission(from: .off),
        AlarmMission(from: .photo),
        AlarmMission(from: .shake),
        AlarmMission(from: .tiles),
        AlarmMission(from: .type)
    ],
                         startingMission: AlarmMission(from: .photo)) {
        print("done")
    }
    // PhotoMissionView reads @Environment(AlarmStore.self); without this the
    // preview crashes with SIGTRAP the moment .photo is the active mission.
    .environment(AlarmStore())
}

struct MissionExecutionView: View {
    let missions: [AlarmMission]
    @State var activeMission: AlarmMission
    let onComplete: () -> Void

    @Environment(AlarmStore.self) private var store
    /// The single object the user currently has to photograph. Selected in
    /// `.onAppear` from the per-alarm whitelist and re-rolled whenever the
    /// user taps "Take Other Mission" (so they effectively get both the
    /// "new mission" and the "new object" behaviour through one button).
    @State private var photoTask: AlarmTask = TaskCatalog.all.first ?? TaskCatalog.all[0]
    
    init(missions: [AlarmMission], startingMission: AlarmMission, onComplete: @escaping () -> Void) {
        // Drop `.off` unconditionally (it's a "no mission" sentinel). In
        // release, also drop `.photo` whenever the camera permission isn't
        // granted — `CameraView` would otherwise strand the user on a
        // permission wall they can't resolve without leaving the alarm.
        // In DEBUG we keep `.photo` so the simulator/preview path still works.
        let filtered: [AlarmMission] = missions.filter { m in
            if m.id == .off { return false }
            #if !DEBUG
            if m.id == .photo,
               AVCaptureDevice.authorizationStatus(for: .video) != .authorized {
                return false
            }
            #endif
            return true
        }

        // If the caller-provided `startingMission` was filtered out (e.g. the
        // only saved mission was `.photo` and camera access is now revoked),
        // fall back to the first available one, or to `.math` if the list is
        // empty — `.math` is guaranteed solvable without any permissions, so
        // the user can always silence the alarm.
        let resolvedStart: AlarmMission = {
            if filtered.contains(where: { $0.id == startingMission.id }) {
                return startingMission
            }
            return filtered.first ?? AlarmMission(from: .math)
        }()

        // Ensure `missions` is never empty so "Take Other Mission" has
        // something to pick from.
        self.missions = filtered.isEmpty ? [resolvedStart] : filtered
        self.activeMission = resolvedStart
        self.onComplete = onComplete
    }
    
    @State private var currentIndex = 0
    @State private var now = Date()
    private let clock = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    @State private var showChangeMissionButton = false
    @State private var showgiveUpButton = false
    
    private var ringingLabel: String {
        let cal = Calendar.current
        let h = cal.component(.hour, from: now)
        let m = cal.component(.minute, from: now)
        return String(format: "%d:%02d · ringing", h, m)
    }
    
    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                missionHeader
                missionContent
            }
        }
        .overlay(alignment: .topLeading, content: {
            changeMissionButton
                .padding(.leading, 20)
        })
        .overlay(alignment: .topTrailing, content: {
            giveUpButton
                .padding(.trailing, 20)
        })
        .onAppear{
            // Scope TaskService to the user's per-alarm whitelist and seed
            // the first object. `selectRandomMission` re-rolls from the
            // same pool.
            TaskService.shared.setAllowed(ids: store.pendingMission?.photoTaskIDs)
            photoTask = TaskService.shared.current

            withAnimation(.easeInOut(duration: 1).delay(30)) {
                showChangeMissionButton = true
            }
            withAnimation(.easeInOut(duration: 1).delay(120)) {
                showgiveUpButton = true
            }
        }
        .onReceive(clock) { now = $0 }
    }
    
    // Task completion is the only way out — no cancel escape (spec requirement).
    private var missionHeader: some View {
        HStack {
            Spacer()
            Text(ringingLabel)
                .font(.system(size: 12, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(OB.ink3)
                .textCase(.uppercase)
            Spacer()
        }
        .padding(.horizontal, 22)
        .padding(.top, 58)
        .padding(.bottom, 10)
    }
    
    @ViewBuilder
    private var missionContent: some View {
        switch activeMission.id {
        case .math:
            MathMissionView(onSolve: onComplete)
        case .type:
            TypingMissionView(onSolve: onComplete)
        case .tiles:
            TilesMissionView(onSolve: onComplete)
        case .shake:
            ShakeMissionView(onSolve: onComplete)
        case .photo:
            PhotoMissionView(task: photoTask, onSolve: onComplete)
        case .off:
            // No mission — complete immediately
            Color.clear.onAppear { onComplete() }
        }
    }
    
    private var changeMissionButton: some View {
        Button(action: selectRandomMission, label: {
            Text("Take Other Mission")
                .foregroundStyle(.black)
                .opacity(showChangeMissionButton ? 0.4 : 0)
        })
    }
    
    
    private var giveUpButton: some View {
        Button(action: onComplete, label: {
            Text("Give up")
                .foregroundStyle(.black)
                .opacity(showgiveUpButton ? 0.4 : 0)
        })
    }
    
    private func selectRandomMission() {
        activeMission = missions.randomElement() ?? AlarmMission(from: .off)
        // Re-roll the photo object too so "Take Other Mission" offers either
        // a new mission or (when the pool is photo-only) a new object.
        TaskService.shared.randomNext()
        photoTask = TaskService.shared.current
    }
}


// MARK: - Math Mission

struct MathMissionView: View {
    let onSolve: () -> Void
    
    @State private var a = Int.random(in: 10...30)
    @State private var b = Int.random(in: 2...12)
    @State private var input = ""
    @State private var shakeOffset: CGFloat = 0
    
    private var answer: Int { a * b }
    private var displayInput: String { input.isEmpty ? "—" : input }
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("SOLVE")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(OB.ink3)
                .textCase(.uppercase)
            
            Text("\(a) × \(b)")
                .font(.system(size: 72, weight: .bold))
                .kerning(-3)
                .foregroundStyle(OB.ink)
                .monospacedDigit()
            
            // Input display
            Text(displayInput)
                .font(.system(size: 32, weight: .bold))
                .kerning(-1)
                .monospacedDigit()
                .foregroundStyle(input.isEmpty ? OB.ink3 : OB.ink)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(OB.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                .padding(.horizontal, 22)
                .offset(x: shakeOffset)
            
            Spacer()
            numpad
                .padding(.horizontal, 22)
        }
    }
    
    private var numpad: some View {
        let keys: [String] = ["1","2","3","4","5","6","7","8","9","⌫","0","✓"]
        return LazyVGrid(
            columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3),
            spacing: 8
        ) {
            ForEach(keys, id: \.self) { key in
                Button {
                    handleKey(key)
                } label: {
                    Text(key)
                        .font(.system(size: 22, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .foregroundStyle(key == "✓" ? .white : OB.ink)
                        .background(
                            key == "✓" ? OB.accent : OB.card,
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
                        )
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
    }
    
    private func handleKey(_ key: String) {
        switch key {
        case "⌫":
            if !input.isEmpty { input.removeLast() }
        case "✓":
            if Int(input) == answer {
                onSolve()
            } else {
                withAnimation(.default) { shakeOffset = 12 }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                    withAnimation(.default) { shakeOffset = -12 }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                        withAnimation(.spring) { shakeOffset = 0 }
                    }
                }
                input = ""
            }
        default:
            if input.count < 6 { input += key }
        }
    }
}

// MARK: - Typing Mission

struct TypingMissionView: View {
    let onSolve: () -> Void
    
    @State private var phrase: String = ""
    
    private let phrases: [String] = [
        "The early bird catches the worm",
        "Practice makes perfect",
        "Stay hungry stay foolish",
        "Knowledge is power",
        "Time is money",
        "Never stop learning",
        "Simplicity is the ultimate sophistication",
        "Action speaks louder than words",
        "Fortune favors the bold",
        "Dream big work hard",
        "Focus on what matters",
        "Consistency beats intensity",
        "Small steps every day",
        "Think different",
        "Code is poetry",
        "Less is more",
        "Make it happen",
        "Keep it simple",
        "Done is better than perfect",
        "Build measure learn",
        "Move fast and fix things",
        "Stay curious",
        "Design is intelligence made visible",
        "Hard work pays off",
        "Quality over quantity",
        "Keep pushing forward",
        "Discipline equals freedom",
        "Progress over perfection",
        "Clarity over complexity",
        "Ship it"
    ]
    
    @State private var typed = ""
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            Text("RETYPE")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(OB.ink3)
                .textCase(.uppercase)
                .padding(.top, 20)
            
            // Phrase display with character coloring
            phraseDisplay
                .padding(.horizontal, 22)
                .padding(.top, 14)
            
            Text("\(typed.count) / \(phrase.count) characters")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.ink3)
                .monospacedDigit()
                .padding(.top, 12)
            
            Spacer()
            // Hidden text field + fake keyboard hint
            ZStack {
                TextField("", text: $typed)
                    .focused($isFocused)
                    .opacity(0.01)
                    .frame(height: 1)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .onChange(of: typed) { _, newValue in
                        if newValue.count > phrase.count {
                            typed = String(newValue.prefix(phrase.count))
                        }
                    }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 20)
            .onAppear { isFocused = true }
            
        }
        .onAppear {
            phrase = phrases.randomElement() ?? ""
            isFocused = true
        }
    }
    
    private var phraseDisplay: some View {
        let chars = Array(phrase)
        return FlowText(chars: chars, typed: typed)
            .padding(20)
            .background(OB.card, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
struct FlowText: View {
    let chars: [Character]
    let typed: String
    
    var body: some View {
        let typedArr = Array(typed.lowercased())
        return Text(chars.enumerated().reduce(AttributedString()) { result, pair in
            let (i, c) = pair
            var a = AttributedString(String(c))
            if i < typedArr.count {
                a.foregroundColor = typedArr[i].lowercased() == c.lowercased() ? OB.ok : OB.accent
                a.font = .system(size: 22, weight: .semibold)
            } else if i == typedArr.count {
                a.foregroundColor = OB.ink3
                a.font = .system(size: 22, weight: .regular)
                a.underlineStyle = Text.LineStyle(pattern: .solid, color: OB.accent)
            } else {
                a.foregroundColor = OB.ink3
                a.font = .system(size: 22, weight: .regular)
            }
            return result + a
        })
        .lineSpacing(6)
    }
}

// MARK: - Tiles Mission

struct TilesMissionView: View {
    let onSolve: () -> Void
    
    private let colors: [Color] = [
        .init(red: 1, green: 0.353, blue: 0.122),
        .init(red: 0.18, green: 0.561, blue: 0.353),
        .init(red: 0.243, green: 0.455, blue: 0.831),
        .init(red: 0.831, green: 0.690, blue: 0.243),
        .init(red: 0.557, green: 0.243, blue: 0.831),
        .init(red: 0.831, green: 0.243, blue: 0.553),
    ]
    @State private var sequence: [Int] = []
    @State private var gridIndices: [Int] = []
    @State private var step = 0
    
    var body: some View {
        VStack(spacing: 0) {
            Text("TAP IN ORDER")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(OB.ink3)
                .padding(.top, 20)
            
            // Sequence preview
            HStack(spacing: 8) {
                ForEach(Array(sequence.enumerated()), id: \.offset) { i, ci in
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(colors[ci].opacity(i < step ? 0.25 : 1))
                        .frame(width: 38, height: 38)
                        .overlay {
                            if i < step {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(.white)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .strokeBorder(i == step ? OB.ink : .clear, lineWidth: 2)
                        )
                        .animation(.easeInOut(duration: 0.15), value: step)
                }
            }
            .padding(.top, 16)
            
            // Tile grid
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 3),
                spacing: 10
            ) {
                ForEach(Array(gridIndices.enumerated()), id: \.offset) { _, ci in
                    Button {
                        guard step < sequence.count else { return }
                        if ci == sequence[step] {
                            withAnimation(.spring(response: 0.25)) { step += 1 }
                            if step >= sequence.count { onSolve() }
                        }
                    } label: {
                        colors[ci]
                            .aspectRatio(1, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                            .shadow(color: colors[ci].opacity(0.4), radius: 6, y: 4)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
            .padding(.horizontal, 22)
            .padding(.top, 32)
            Spacer()
        }
        .onAppear {
            sequence = Array(0..<colors.count).shuffled().prefix(5).map { $0 }
            gridIndices = Array(0..<colors.count).shuffled()
        }
    }
}

// MARK: - Shake Mission
struct ShakeMissionView: View {
    let onSolve: () -> Void
    
    @State private var progress: Double = 0
    @State private var motionManager = CMMotionManager()
    @State private var shakeAnim = false
    
    private let target: Double = 100
    
    var body: some View {
        VStack(spacing: 0) {
            Text("KEEP SHAKING")
                .font(.system(size: 13, weight: .bold))
                .kerning(0.5)
                .foregroundStyle(OB.ink3)
                .padding(.top, 20)
            
            // Circular progress dial
            ZStack {
                Circle()
                    .stroke(OB.ink.opacity(0.06), lineWidth: 7)
                Circle()
                    .trim(from: 0, to: min(1, progress / target))
                    .stroke(
                        OB.accent,
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(response: 0.3), value: progress)
                
                VStack(spacing: 4) {
                    Text("\(Int(progress))%")
                        .font(.system(size: 32, weight: .bold))
                        .kerning(-1)
                        .monospacedDigit()
                        .foregroundStyle(OB.ink)
                        .contentTransition(.numericText())
                    Text("shaken")
                        .font(.system(size: 12, weight: .semibold))
                        .kerning(0.4)
                        .foregroundStyle(OB.ink3)
                        .textCase(.uppercase)
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 30)
            
            // Phone illustration
            Text("📱")
                .font(.system(size: 56))
                .rotationEffect(.degrees(shakeAnim ? -10 : 10))
                .animation(
                    .easeInOut(duration: 0.2).repeatForever(autoreverses: true),
                    value: shakeAnim
                )
                .padding(.top, 28)
            
#if DEBUG
            // Manual tap button (for simulator / accessibility)
            Button {
                addProgress(10)
            } label: {
                Text("Tap to shake (simulator)")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OB.ink2)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(OB.card, in: Capsule())
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.top, 24)
#endif
            Spacer()
        }
        .onAppear {
            shakeAnim = true
            startMotion()
        }
        .onDisappear { motionManager.stopAccelerometerUpdates() }
    }
    
    private func startMotion() {
        guard motionManager.isAccelerometerAvailable else { return }
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { data, _ in
            guard let data else { return }
            let magnitude = sqrt(
                pow(data.acceleration.x, 2) +
                pow(data.acceleration.y, 2) +
                pow(data.acceleration.z, 2)
            )
            if magnitude > 2.0 { addProgress(Double(magnitude) * 0.5) }
        }
    }
    
    private func addProgress(_ amount: Double) {
        progress = min(target, progress + amount)
        if progress >= target { onSolve() }
    }
}


// MARK: - Photo Mission
//
// Visual/behavioural twin of `PhotoTaskTestSheet`: fixed-size 3:4 preview card,
// the same green scanning overlay while the backend verifies the shot, the
// same capture button that stays in place (just disabled) during analyze.
// Differences from the test sheet:
//  • the object to photograph comes from the parent (no internal rotation —
//    parent's "Take Other Mission" handles reroll);
//  • on a detected result we show a primary "Done" button that calls
//    `onSolve` — the only path that silences the alarm;
//  • on a non-detected or network-error result we offer "Try Again", which
//    resets the camera back to shooting.

struct PhotoMissionView: View {
    let task: AlarmTask
    let onSolve: () -> Void

    private enum Stage {
        case shooting
        case analyzing(UIImage)
        case success(UIImage, MissionRecognitionResult)
        case failure(UIImage, String)

        var capturedImage: UIImage? {
            switch self {
            case .shooting:                  return nil
            case .analyzing(let img),
                 .success(let img, _),
                 .failure(let img, _):       return img
            }
        }
        var isAnalyzing: Bool {
            if case .analyzing = self { return true }
            return false
        }
        var isSuccess: Bool {
            if case .success(_, let r) = self { return r.detected }
            return false
        }
    }

    @State private var stage: Stage = .shooting
    @State private var captureTrigger = 0
    @State private var cameraError: String?

    var body: some View {
        VStack(spacing: 0) {
            instructionBanner
                .padding(.horizontal, 22)
                .padding(.top, 12)

            previewCard
                .padding(.horizontal, 22)
                .padding(.top, 20)

            statusRow
                .padding(.top, 14)
                .frame(minHeight: 44)

            Spacer(minLength: 12)
            actionRow
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
        }
        .onChange(of: task.id) { _, _ in
            // Parent swapped the object — reset the camera stage.
            reset()
        }
        .alert("Camera Error", isPresented: .constant(cameraError != nil), actions: {
            Button("OK", role: .cancel) {
                cameraError = nil
                reset()
            }
        }, message: { Text(cameraError ?? "") })
    }

    // MARK: - Instruction banner

    private var instructionBanner: some View {
        HStack(spacing: 10) {
            Text(task.emoji).font(.system(size: 28))
            Text(task.instruction)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(OB.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Preview card (fixed 3:4)

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OB.card)

            cameraContent
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            if stage.isAnalyzing {
                ScanningOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .transition(.opacity)
            }

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: stage.isSuccess ? 3 : 1)
                .animation(.easeInOut(duration: 0.25), value: stage.isSuccess)

            if stage.isSuccess {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(OB.ok)
                        .shadow(color: .black.opacity(0.2), radius: 6, y: 2)
                        .padding(.bottom, 22)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: stage.isSuccess)
    }

    @ViewBuilder
    private var cameraContent: some View {
        if let image = stage.capturedImage {
            // Pin the image to the card's exact rect (see PhotoTaskTestSheet
            // for rationale — `.scaledToFill()` otherwise reports the photo's
            // natural pixel size and stretches the parent).
            GeometryReader { geo in
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geo.size.width, height: geo.size.height)
                    .clipped()
            }
        } else {
            PhotoCaptureView(
                captureTrigger: $captureTrigger,
                onCapture: handleCapture,
                onError: { cameraError = $0 }
            )
        }
    }

    private var borderColor: Color {
        switch stage {
        case .success(_, let r): return r.detected ? OB.ok : OB.accent.opacity(0.8)
        case .failure:           return OB.accent.opacity(0.8)
        default:                 return OB.line
        }
    }

    // MARK: - Status row

    @ViewBuilder
    private var statusRow: some View {
        switch stage {
        case .shooting:
            Text("Hold steady and tap to capture")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.ink3)
                .multilineTextAlignment(.center)

        case .analyzing:
            EmptyView()

        case .success(_, let r):
            VStack(spacing: 4) {
                Text(r.detected ? "Detected!" : "Not detected")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(r.detected ? OB.ok : OB.accent)
                Text(detailLine(result: r))
                    .font(.system(size: 12))
                    .foregroundStyle(OB.ink3)
            }
            .multilineTextAlignment(.center)
            .padding(.horizontal, 22)

        case .failure(_, let message):
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
    }

    private func detailLine(result: MissionRecognitionResult) -> String {
        let label = result.topLabel.isEmpty ? "—" : result.topLabel
        let pct = Int((result.confidence * 100).rounded())
        return "Saw: \(label)   •   confidence \(pct)%"
    }

    // MARK: - Action row

    @ViewBuilder
    private var actionRow: some View {
        switch stage {
        case .shooting:
            captureCircle(enabled: true).frame(maxWidth: .infinity)
        case .analyzing:
            captureCircle(enabled: false).frame(maxWidth: .infinity)
        case .success(_, let r):
            if r.detected {
                primaryButton(title: "Done", color: OB.ok, action: onSolve)
            } else {
                primaryButton(title: "Try Again", color: OB.accent) { reset() }
            }
        case .failure:
            primaryButton(title: "Try Again", color: OB.accent) { reset() }
        }
    }

    private func captureCircle(enabled: Bool) -> some View {
        Button {
            captureTrigger += 1
        } label: {
            Circle()
                .fill(enabled ? OB.accent : OB.ink3.opacity(0.35))
                .frame(width: 72, height: 72)
                .overlay(Circle().stroke(.white, lineWidth: 4).padding(6))
                .shadow(color: enabled ? OB.accent.opacity(0.35) : .clear, radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(!enabled)
    }

    private func primaryButton(title: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(color, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Logic

    private func reset() {
        captureTrigger = 0
        stage = .shooting
    }

    private func handleCapture(_ image: UIImage) {
        stage = .analyzing(image)
        Task {
            let result = await NetworkingService.recognizeMissionPhoto(image: image, task: task)
            await MainActor.run {
                withAnimation {
                    switch result {
                    case .success(let r):
                        stage = .success(image, r)
                    case .failure(let err):
                        stage = .failure(image, err.localizedDescription)
                    }
                }
            }
        }
    }
}

