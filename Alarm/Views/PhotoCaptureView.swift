//
//  PhotoCaptureView.swift
//  Alarm
//
//  Created by Oleksii on 17.04.2026.
//

import SwiftUI
import UIKit
import AVFoundation

// MARK: - SwiftUI Wrapper

struct PhotoCaptureView: UIViewControllerRepresentable {
    class Coordinator {
        var triggerValue = 0
    }

    @Binding var captureTrigger: Int
    let onCapture: (UIImage) -> Void
    let onError: (String) -> Void

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIViewController(context: Context) -> PhotoCaptureViewController {
        let controller = PhotoCaptureViewController()
        controller.onCapture = onCapture
        controller.onError = onError
        return controller
    }

    func updateUIViewController(_ uiViewController: PhotoCaptureViewController, context: Context) {
        uiViewController.onCapture = onCapture
        uiViewController.onError = onError
        if captureTrigger != context.coordinator.triggerValue {
            context.coordinator.triggerValue = captureTrigger
            uiViewController.capturePhoto()
        }
    }
}

// MARK: - Camera View Controller

final class PhotoCaptureViewController: UIViewController, AVCapturePhotoCaptureDelegate {
    var onCapture: ((UIImage) -> Void)?
    var onError: ((String) -> Void)?

    // nonisolated(unsafe) - accessed from sessionQueue; AVCapture types handle their own thread safety.
    nonisolated(unsafe) private let captureSession = AVCaptureSession()
    nonisolated(unsafe) private let photoOutput = AVCapturePhotoOutput()
    nonisolated(unsafe) private var previewLayer: AVCaptureVideoPreviewLayer?
    private let sessionQueue = DispatchQueue(label: "photo.capture.session")

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        setupCamera()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    private func setupCamera() {
        sessionQueue.async { [weak self] in
            guard let self else { return }

            guard let videoDevice = AVCaptureDevice.default(
                .builtInWideAngleCamera,
                for: .video,
                position: .back
            ) else {
                DispatchQueue.main.async {
                    self.onError?("Camera not available on this device.")
                }
                return
            }

            do {
                let videoInput = try AVCaptureDeviceInput(device: videoDevice)

                self.captureSession.beginConfiguration()
                if self.captureSession.canAddInput(videoInput) {
                    self.captureSession.addInput(videoInput)
                }
                if self.captureSession.canAddOutput(self.photoOutput) {
                    self.captureSession.addOutput(self.photoOutput)
                }
                self.captureSession.commitConfiguration()

                DispatchQueue.main.async {
                    let layer = AVCaptureVideoPreviewLayer(session: self.captureSession)
                    layer.videoGravity = .resizeAspectFill
                    layer.frame = self.view.bounds
                    self.view.layer.addSublayer(layer)
                    self.previewLayer = layer
                    self.captureSession.startRunning()
                }
            } catch {
                DispatchQueue.main.async {
                    self.onError?("Failed to access the camera.")
                }
            }
        }
    }

    func capturePhoto() {
        let settings = AVCapturePhotoSettings()
        photoOutput.capturePhoto(with: settings, delegate: self)
    }

    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        if let error {
            DispatchQueue.main.async { self.onError?(error.localizedDescription) }
            return
        }
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            DispatchQueue.main.async { self.onError?("Failed to capture image.") }
            return
        }
        DispatchQueue.main.async { self.onCapture?(image) }
    }

    deinit {
        captureSession.stopRunning()
    }
}
