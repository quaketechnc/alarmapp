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
        case .shooting:                         return nil
        case .analyzing(let img):               return img
        case .success(let img):                 return img
        case .failure(let img, _):              return img
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

// MARK: - Camera View

struct CameraView: View {
    var onComplete: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var currentTask: AlarmTask = TaskService.shared.current
    @State private var scanState: ScanState = .shooting
    @State private var captureTrigger = 0
    @State private var cameraError: String?

    var body: some View {
        ZStack {
            VStack(spacing: 20) {
                header
                taskBanner
                previewSection
                statusRow
                actionButton
                Spacer()
            }
            .padding(24)

            if scanState.isAnalyzing {
                analyzingOverlay
            }
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

    private var header: some View {
        HStack {
            // Top-left: skip to a different task
            Button {
                skipToNextTask()
            } label: {
                Image(systemName: "shuffle")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.accent)
            }
            Spacer()
            Text("Scan")
                .foregroundStyle(.accent)
            Spacer()
            Color.clear.frame(width: 32, height: 32)
        }
    }

    // MARK: - Task Banner

    private var taskBanner: some View {
        Text(currentTask.instruction)
            .font(.headline)
            .foregroundStyle(.accent)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
            .id(currentTask.id)
            .transition(.opacity)
    }

    // MARK: - Preview Section

    private var previewSection: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.black.opacity(0.2))

            cameraContent

            // Border - green on success, red on failure, white otherwise
            RoundedRectangle(cornerRadius: 24)
                .stroke(borderColor, lineWidth: scanState.isSuccess ? 4 : 2)
                .animation(.easeInOut(duration: 0.3), value: scanState.isSuccess)

            // Success checkmark overlay
            if scanState.isSuccess {
                VStack {
                    Spacer()
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.green)
                        .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 2)
                        .padding(.bottom, 24)
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: scanState.isSuccess)
        .clipShape(RoundedRectangle(cornerRadius: 24))
    }

    @ViewBuilder
    private var cameraContent: some View {
        if let image = scanState.capturedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .clipShape(RoundedRectangle(cornerRadius: 24))
        } else {
            PhotoCaptureView(
                captureTrigger: $captureTrigger,
                onCapture: handleCapture,
                onError: { cameraError = $0 }
            )
            .clipShape(RoundedRectangle(cornerRadius: 24))
        }
    }

    private var borderColor: Color {
        switch scanState {
        case .success:          return .green
        case .failure:          return .red.opacity(0.7)
        default:                return .white.opacity(0.6)
        }
    }

    // MARK: - Status Row

    @ViewBuilder
    private var statusRow: some View {
        switch scanState {
        case .shooting:
            Text("Hold steady and tap to capture")
                .foregroundStyle(.secondaryText)
                .multilineTextAlignment(.center)

        case .analyzing:
            EmptyView()

        case .success:
            Text("Task complete!")
                .font(.headline)
                .foregroundStyle(.green)

        case .failure(_, let message):
            Text(message)
                .foregroundStyle(.red)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    // MARK: - Action Button

    @ViewBuilder
    private var actionButton: some View {
        switch scanState {
        case .shooting:
            captureCircle

        case .analyzing:
            EmptyView()

        case .success:
            Button {
                if let onComplete { onComplete() } else { skipToNextTask() }
            } label: {
                Text("Next Task")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }

        case .failure:
            Button {
                resetToShooting()
            } label: {
                Text("Try Again")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    private var captureCircle: some View {
        Button {
            captureTrigger += 1
        } label: {
            Circle()
                .fill(Color(.accent))
                .frame(width: 72, height: 72)
                .overlay {
                    Circle()
                        .stroke(Color.white, lineWidth: 4)
                        .padding(6)
                }
        }
    }

    // MARK: - Analyzing Overlay

    private var analyzingOverlay: some View {
        VStack(spacing: 16) {
            ProgressView()
                .tint(.white)
                .scaleEffect(1.4)
            Text("Analyzing…")
                .foregroundStyle(.white)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black.opacity(0.6))
        .ignoresSafeArea()
    }

    // MARK: - Logic

    private func handleCapture(_ image: UIImage) {
        scanState = .analyzing(image)
        Task {
            let result = await RecognitionService.shared.analyze(image: image, task: currentTask)
            switch result {
            case .success(let recognition):
                withAnimation {
                    if recognition.detected {
                        scanState = .success(image)
                    } else {
                        let label = recognition.topLabel
                            .components(separatedBy: ",")
                            .first ?? recognition.topLabel
                        scanState = .failure(image, "Saw '\(label)'. Try again!")
                    }
                }
            case .failure(let error):
                scanState = .failure(image, error.localizedDescription)
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
