//
//  PhotoTaskTestSheet.swift
//  Alarm
//
//  Pre-alarm verification: user picks one object from their current selection,
//  snaps a photo, and sees whether the backend would unlock the alarm. Uses
//  the exact same `NetworkingService.recognizeMissionPhoto` endpoint that runs
//  in production, so the result is representative.
//
//  Layout mirrors `CameraView` so the preview card keeps a stable size across
//  states (shooting → analyzing → result). The frame never reflows when the
//  captured photo replaces the live feed — only the content inside the card
//  swaps and the action row beneath it changes.
//

import SwiftUI
import UIKit

struct PhotoTaskTestSheet: View {
    let candidates: [AlarmTask]
    let onClose: () -> Void

    private enum Phase {
        case choosing
        case testing(AlarmTask)
    }

    /// Inner state of the camera stage — mirrors `CameraView.ScanState`.
    private enum TestState {
        case shooting
        case analyzing(UIImage)
        case success(UIImage, MissionRecognitionResult)
        case failure(UIImage, String)

        var capturedImage: UIImage? {
            switch self {
            case .shooting:               return nil
            case .analyzing(let img),
                 .success(let img, _),
                 .failure(let img, _):    return img
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

    @State private var phase: Phase = .choosing
    @State private var state: TestState = .shooting
    @State private var captureTrigger = 0
    @State private var cameraError: String?

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                switch phase {
                case .choosing:         chooser
                case .testing(let t):   testingStage(task: t)
                }
            }
        }
        .alert("Camera Error", isPresented: .constant(cameraError != nil), actions: {
            Button("OK", role: .cancel) {
                cameraError = nil
                reset()
            }
        }, message: { Text(cameraError ?? "") })
    }

    // MARK: - Header

    private var header: some View {
        Text("Test detection")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(OB.ink)
            .frame(maxWidth: .infinity, alignment: .center)
            .overlay(alignment: .leading) { closeButton }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 10)
    }

    private var closeButton: some View {
        Button(action: onClose) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OB.ink2)
                .frame(width: 36, height: 36)
                .background(OB.card, in: Circle())
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Chooser

    private var chooser: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Pick an object to test")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(OB.ink2)
                .padding(.horizontal, 20)

            ScrollView {
                let cols = Array(repeating: GridItem(.flexible(), spacing: 10), count: 3)
                LazyVGrid(columns: cols, spacing: 10) {
                    ForEach(candidates) { task in
                        Button {
                            startTesting(task)
                        } label: {
                            VStack(spacing: 8) {
                                Text(task.emoji).font(.system(size: 36))
                                Text(task.name)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(OB.ink)
                                    .lineLimit(2)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .background(OB.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        }
                        .buttonStyle(ScaleButtonStyle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
        }
    }

    // MARK: - Testing stage

    private func testingStage(task: AlarmTask) -> some View {
        VStack(spacing: 0) {
            instructionBanner(task: task)
                .padding(.horizontal, 22)
                .padding(.top, 12)

            previewCard(task: task)
                .padding(.horizontal, 22)
                .padding(.top, 20)

            statusRow
                .padding(.top, 14)
                .frame(minHeight: 44)

            Spacer(minLength: 12)
            actionRow(task: task)
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
        }
    }

    private func instructionBanner(task: AlarmTask) -> some View {
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
        .onTapGesture {
            guard !state.isAnalyzing else { return }
            phase = .choosing
        }
    }

    // MARK: - Preview card (fixed-size container)

    /// Stable-sized frame: both live camera and captured photo fill the same
    /// 3:4 card so the layout never reflows between states.
    private func previewCard(task: AlarmTask) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OB.card)

            cameraContent(task: task)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            if state.isAnalyzing {
                ScanningOverlay()
                    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                    .transition(.opacity)
            }

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: state.isSuccess ? 3 : 1)
                .animation(.easeInOut(duration: 0.25), value: state.isSuccess)

            if state.isSuccess {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: state.isSuccess)
    }

    @ViewBuilder
    private func cameraContent(task: AlarmTask) -> some View {
        if let image = state.capturedImage {
            // `.scaledToFill()` on a `Image(uiImage:)` reports the bitmap's
            // natural pixel size as its ideal size, which causes the parent
            // `ZStack` to grow past the `.aspectRatio` constraint and stretch
            // the whole screen. Pinning the frame to the proposed size (via
            // `maxWidth/maxHeight: .infinity`) and clipping forces the image
            // to respect the preview card's bounds — live feed and captured
            // photo then occupy the exact same rect.
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
                onCapture: { img in handleCapture(task: task, image: img) },
                onError: { cameraError = $0 }
            )
        }
    }

    private var borderColor: Color {
        switch state {
        case .success(_, let r): return r.detected ? OB.ok : OB.accent.opacity(0.8)
        case .failure:           return OB.accent.opacity(0.8)
        default:                 return OB.line
        }
    }

    // MARK: - Status row

    @ViewBuilder
    private var statusRow: some View {
        switch state {
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
    private func actionRow(task: AlarmTask) -> some View {
        switch state {
        case .shooting:
            captureCircle(enabled: true).frame(maxWidth: .infinity)
        case .analyzing:
            // Keep the same capture button in place so the action row's height
            // doesn't collapse — greyed out and non-interactive during analyze.
            captureCircle(enabled: false).frame(maxWidth: .infinity)
        case .success(_, let r):
            primaryButton(title: "Retake",
                          color: r.detected ? OB.ok : OB.accent) {
                reset()
            }
        case .failure:
            primaryButton(title: "Try Again", color: OB.accent) {
                reset()
            }
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

    private func startTesting(_ task: AlarmTask) {
        state = .shooting
        captureTrigger = 0
        phase = .testing(task)
    }

    private func reset() {
        captureTrigger = 0
        state = .shooting
    }

    private func handleCapture(task: AlarmTask, image: UIImage) {
        state = .analyzing(image)
        Task {
            let result = await NetworkingService.recognizeMissionPhoto(image: image, task: task)
            await MainActor.run {
                withAnimation {
                    switch result {
                    case .success(let r):
                        state = .success(image, r)
                    case .failure(let err):
                        state = .failure(image, err.localizedDescription)
                    }
                }
            }
        }
    }
}

// MARK: - Scanning overlay
//
// Sits on top of the captured photo while the server verifies it. Visual
// language mirrors a sci-fi "scanning" HUD:
//  • translucent green vertical gradient tinting the photo,
//  • four green L-shaped corner brackets (classic viewfinder),
//  • a horizontal line sweeping top → bottom on a 1.6s loop,
//  • a subtle chip with spinner + "Analyzing…" label docked at the bottom.
// The whole thing is clipped by the preview card's rounded rect, so it always
// matches the photo's geometry.

struct ScanningOverlay: View {
    @State private var sweep: CGFloat = 0

    private let accent = Color(red: 0.20, green: 0.85, blue: 0.45)

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // (1) Green gradient wash over the whole photo.
                LinearGradient(
                    colors: [
                        accent.opacity(0.28),
                        accent.opacity(0.10),
                        accent.opacity(0.28),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )


                // (3) Sweeping scan line.
                scanLine(width: geo.size.width)
                    .frame(height: 3)
                    .position(x: geo.size.width / 2,
                              y: max(1.5, sweep * geo.size.height))

                // (4) Analyzing chip at bottom.
                VStack {
                    Spacer()
                    HStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(0.8)
                        Text("Analyzing…")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(.black.opacity(0.55), in: Capsule())
                    .padding(.bottom, 14)
                }
            }
            .onAppear {
                sweep = 0
                withAnimation(
                    .easeInOut(duration: 1.6).repeatForever(autoreverses: true)
                ) {
                    sweep = 1
                }
            }
        }
        .allowsHitTesting(false)
    }

    private func scanLine(width: CGFloat) -> some View {
        LinearGradient(
            colors: [
                accent.opacity(0),
                accent.opacity(0.9),
                Color.white.opacity(0.95),
                accent.opacity(0.9),
                accent.opacity(0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width)
        .shadow(color: accent.opacity(0.9), radius: 6, y: 0)
    }
}
