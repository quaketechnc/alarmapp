//
//  PhotoTaskTestSheet.swift
//  Alarm
//
//  Pre-alarm verification: user picks one object from their current selection,
//  snaps a photo, and sees whether the backend would unlock the alarm.
//  Uses the exact same `NetworkingService.recognizeMissionPhoto` endpoint that
//  runs in production, so the result is representative.
//

import SwiftUI
import UIKit

struct PhotoTaskTestSheet: View {
    let candidates: [AlarmTask]
    let onClose: () -> Void

    private enum Phase {
        case choosing
        case shooting(AlarmTask)
        case analyzing(AlarmTask, UIImage)
        case result(AlarmTask, UIImage, MissionRecognitionResult)
        case failure(AlarmTask, UIImage, String)
    }

    @State private var phase: Phase = .choosing
    @State private var captureTrigger = 0
    @State private var cameraError: String?

    var body: some View {
        ZStack {
            OB.bg.ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch phase {
                    case .choosing:                         chooser
                    case .shooting(let t):                  shooter(task: t)
                    case .analyzing(let t, let img):        analyzing(task: t, image: img)
                    case .result(let t, let img, let r):    resultView(task: t, image: img, result: r)
                    case .failure(let t, let img, let msg): failureView(task: t, image: img, message: msg)
                    }
                }
                .frame(maxHeight: .infinity)
            }
        }
        .alert("Camera Error", isPresented: .constant(cameraError != nil), actions: {
            Button("OK", role: .cancel) {
                cameraError = nil
                phase = .choosing
            }
        }, message: { Text(cameraError ?? "") })
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: backOrClose) {
                Image(systemName: backIcon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(OB.ink2)
                    .padding(10)
                    .background(OB.card, in: Circle())
            }
            .buttonStyle(ScaleButtonStyle())
            Spacer()
            Text("Test detection")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(OB.ink)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 10)
    }

    private var backIcon: String {
        switch phase {
        case .choosing: return "xmark"
        default:        return "chevron.left"
        }
    }

    private func backOrClose() {
        switch phase {
        case .choosing:
            onClose()
        default:
            phase = .choosing
        }
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
                            phase = .shooting(task)
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

    // MARK: - Shooter

    private func shooter(task: AlarmTask) -> some View {
        VStack(spacing: 16) {
            instructionBanner(task: task)
                .padding(.horizontal, 20)

            previewFrame {
                PhotoCaptureView(
                    captureTrigger: $captureTrigger,
                    onCapture: { img in handleCapture(task: task, image: img) },
                    onError: { cameraError = $0 }
                )
            }
            .padding(.horizontal, 20)

            Spacer()

            Button {
                captureTrigger += 1
            } label: {
                Circle()
                    .fill(OB.accent)
                    .frame(width: 72, height: 72)
                    .overlay(Circle().stroke(.white, lineWidth: 4).padding(6))
                    .shadow(color: OB.accent.opacity(0.35), radius: 10, y: 4)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.bottom, 30)
        }
    }

    // MARK: - Analyzing

    private func analyzing(task: AlarmTask, image: UIImage) -> some View {
        VStack(spacing: 16) {
            instructionBanner(task: task).padding(.horizontal, 20)
            previewFrame { Image(uiImage: image).resizable().scaledToFill() }
                .padding(.horizontal, 20)

            HStack(spacing: 10) {
                ProgressView().tint(OB.accent)
                Text("Analyzing…")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(OB.ink2)
            }
            .padding(.top, 12)
            Spacer()
        }
    }

    // MARK: - Result

    private func resultView(task: AlarmTask, image: UIImage, result: MissionRecognitionResult) -> some View {
        VStack(spacing: 16) {
            instructionBanner(task: task).padding(.horizontal, 20)
            previewFrame { Image(uiImage: image).resizable().scaledToFill() }
                .padding(.horizontal, 20)

            VStack(spacing: 6) {
                Image(systemName: result.detected ? "checkmark.seal.fill" : "xmark.seal.fill")
                    .font(.system(size: 36))
                    .foregroundStyle(result.detected ? OB.ok : OB.accent)
                Text(result.detected ? "Detected!" : "Not detected")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(result.detected ? OB.ok : OB.accent)
                Text(detailLine(result: result))
                    .font(.system(size: 13))
                    .foregroundStyle(OB.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 14)

            Spacer()
            retakeButton(task: task)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
    }

    private func detailLine(result: MissionRecognitionResult) -> String {
        let label = result.topLabel.isEmpty ? "—" : result.topLabel
        let pct = Int((result.confidence * 100).rounded())
        return "Saw: \(label)   •   confidence \(pct)%"
    }

    // MARK: - Failure

    private func failureView(task: AlarmTask, image: UIImage, message: String) -> some View {
        VStack(spacing: 16) {
            instructionBanner(task: task).padding(.horizontal, 20)
            previewFrame { Image(uiImage: image).resizable().scaledToFill() }
                .padding(.horizontal, 20)

            VStack(spacing: 6) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(OB.accent)
                Text("Test failed")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(OB.ink)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(OB.ink3)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(.top, 14)

            Spacer()
            retakeButton(task: task)
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
        }
    }

    private func retakeButton(task: AlarmTask) -> some View {
        Button {
            phase = .shooting(task)
        } label: {
            Text("Retake")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 54)
                .background(OB.ink, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    // MARK: - Shared UI bits

    private func instructionBanner(task: AlarmTask) -> some View {
        HStack(spacing: 10) {
            Text(task.emoji).font(.system(size: 28))
            Text(task.instruction)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(OB.ink)
            Spacer()
        }
        .padding(14)
        .background(OB.card, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    @ViewBuilder
    private func previewFrame<V: View>(@ViewBuilder content: () -> V) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(OB.card)
            content()
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(OB.line, lineWidth: 1)
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
    }

    // MARK: - Logic

    private func handleCapture(task: AlarmTask, image: UIImage) {
        phase = .analyzing(task, image)
        Task {
            let result = await NetworkingService.recognizeMissionPhoto(image: image, task: task)
            await MainActor.run {
                switch result {
                case .success(let r):
                    phase = .result(task, image, r)
                case .failure(let err):
                    phase = .failure(task, image, err.localizedDescription)
                }
            }
        }
    }
}
