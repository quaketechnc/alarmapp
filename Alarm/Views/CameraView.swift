//
//  CameraView.swift
//  Alarm
//
//  Created by Oleksii on 17.04.2026.
//

import SwiftUI
import UIKit

// MARK: - Scan State

private enum ScanState {
    case shooting
    case analyzing(UIImage)
    case success(UIImage)
    case failure(UIImage, String)
}

private extension ScanState {
    var capturedImage: UIImage? {
        switch self {
        case .shooting:               return nil
        case .analyzing(let img):     return img
        case .success(let img):       return img
        case .failure(let img, _):    return img
        }
    }

    var isSuccess: Bool {
        if case .success = self { return true }
        return false
    }

    var isAnalyzing: Bool {
        if case .analyzing = self { return true }
        return false
    }
}

// MARK: - Camera View (Photo Mission)

struct CameraView: View {
    var onComplete: (() -> Void)? = nil
    /// Whitelist of task IDs the rotation should draw from. `nil` = full catalog.
    var allowedTaskIDs: [String]? = nil

    @State private var currentTask: AlarmTask = TaskService.shared.current
    @State private var scanState: ScanState = .shooting
    @State private var captureTrigger = 0
    @State private var cameraError: String?

    var body: some View {
        VStack(spacing: 0) {
            headerLabel
            taskBanner
                .padding(.top, 12)

            previewCard
                .padding(.horizontal, 22)
                .padding(.top, 20)

            statusRow
                .padding(.top, 14)
                .frame(minHeight: 22)

            Spacer(minLength: 12)
            actionButton
                .padding(.horizontal, 22)
                .padding(.bottom, 24)
        }
        .overlay {
            if scanState.isAnalyzing { analyzingOverlay }
        }
        .onAppear {
            TaskService.shared.setAllowed(ids: allowedTaskIDs)
            currentTask = TaskService.shared.current
        }
        .alert("Camera Error", isPresented: .constant(cameraError != nil), actions: {
            Button("OK", role: .cancel) {
                cameraError = nil
                resetToShooting()
            }
        }, message: {
            Text(cameraError ?? "")
        })
    }

    // MARK: - Header

    private var headerLabel: some View {
        Text("SCAN")
            .font(.system(size: 13, weight: .bold))
            .kerning(0.5)
            .foregroundStyle(OB.ink3)
            .textCase(.uppercase)
            .padding(.top, 20)
    }

    private var taskBanner: some View {
        HStack(spacing: 10) {
            Button {
                skipToNextTask()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(OB.ink3)
                    .padding(10)
                    .background(OB.card, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())

            Text(currentTask.instruction)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
                .multilineTextAlignment(.leading)
                .id(currentTask.id)
                .transition(.opacity)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 22)
    }

    // MARK: - Preview

    private var previewCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(OB.card)

            cameraContent
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(borderColor, lineWidth: scanState.isSuccess ? 3 : 1)
                .animation(.easeInOut(duration: 0.25), value: scanState.isSuccess)

            if scanState.isSuccess {
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
        .animation(.spring(response: 0.4, dampingFraction: 0.75), value: scanState.isSuccess)
    }

    @ViewBuilder
    private var cameraContent: some View {
        if let image = scanState.capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
        } else {
            PhotoCaptureView(
                captureTrigger: $captureTrigger,
                onCapture: handleCapture,
                onError: { cameraError = $0 }
            )
        }
    }

    private var borderColor: Color {
        switch scanState {
        case .success: return OB.ok
        case .failure: return OB.accent.opacity(0.8)
        default:       return OB.line
        }
    }

    // MARK: - Status

    @ViewBuilder
    private var statusRow: some View {
        switch scanState {
        case .shooting:
            Text("Hold steady and tap to capture")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.ink3)
                .multilineTextAlignment(.center)

        case .analyzing:
            EmptyView()

        case .success:
            Text("Task complete!")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(OB.ok)

        case .failure(_, let message):
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(OB.accent)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 22)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionButton: some View {
        switch scanState {
        case .shooting:
            captureCircle
                .frame(maxWidth: .infinity)

        case .analyzing:
            EmptyView()

        case .success:
            primaryButton(title: "Next Task", color: OB.ok) {
                if let onComplete { onComplete() } else { skipToNextTask() }
            }

        case .failure:
            primaryButton(title: "Try Again", color: OB.accent) {
                resetToShooting()
            }
        }
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

    private var captureCircle: some View {
        Button {
            captureTrigger += 1
        } label: {
            Circle()
                .fill(OB.accent)
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 4)
                        .padding(6)
                }
                .shadow(color: OB.accent.opacity(0.35), radius: 10, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Analyzing Overlay

    private var analyzingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.3)
            Text("Analyzing…")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.55))
        .ignoresSafeArea()
    }

    // MARK: - Logic

    private func handleCapture(_ image: UIImage) {
        scanState = .analyzing(image)
        Task {
            let result = await NetworkingService.recognizeMissionPhoto(image: image, task: currentTask)
            await MainActor.run {
                switch result {
                case .success(let recognition):
                    withAnimation {
                        if recognition.detected {
                            scanState = .success(image)
                        } else {
                            let label = recognition.topLabel
                                .components(separatedBy: ",")
                                .first ?? recognition.topLabel
                            let tail = label.isEmpty ? "" : "Saw '\(label)'. "
                            scanState = .failure(image, "\(tail)Try again!")
                        }
                    }
                case .failure(let error):
                    scanState = .failure(image, error.localizedDescription)
                }
            }
        }
    }

    private func resetToShooting() {
        captureTrigger = 0
        scanState = .shooting
    }

    private func skipToNextTask() {
        TaskService.shared.randomNext()
        withAnimation {
            currentTask = TaskService.shared.current
        }
        captureTrigger = 0
        scanState = .shooting
    }
}
