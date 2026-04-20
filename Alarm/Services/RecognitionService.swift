//
//  RecognitionService.swift
//  Alarm
//
//  Created by Oleksii on 17.04.2026.
//

import UIKit
import Vision
import CoreML

// MARK: - Recognition Result

struct RecognitionResult {
    let detected: Bool
    let topLabel: String
    let confidence: Float
}

// MARK: - Recognition Error

enum RecognitionError: LocalizedError {
    case modelUnavailable
    case processingError(String)

    var errorDescription: String? {
        switch self {
        case .modelUnavailable:
            return "Recognition model is unavailable."
        case .processingError(let message):
            return message
        }
    }
}

// MARK: - Recognition Service

final class RecognitionService {
    static let shared = RecognitionService()
    private init() {}

    /// Name of the compiled CoreML model in the bundle (without extension).
    /// To swap the model: drop a new .mlpackage into the project and update this name.
//    private let modelName = "FastViTT8F16" +-
//    private let modelName = "YOLOv3FP16" //coslassfounc
    private let modelName = "Resnet50FP16"

    /// Runs CoreML classification on the captured image and checks whether
    /// any of the task's keywords appear in the top-5 predicted labels.
    func analyze(image: UIImage, task: AlarmTask) async -> Result<RecognitionResult, RecognitionError> {
        guard let cgImage = image.cgImage else {
            return .failure(.processingError("Cannot process image."))
        }

        let keywords = task.keywords
        let modelName = self.modelName

        return await Task.detached(priority: .userInitiated) {
            guard let modelURL = Bundle.main.url(
                forResource: modelName,
                withExtension: "mlmodelc"
            ) else {
                return .failure(.modelUnavailable)
            }

            do {
                let mlModel = try MLModel(contentsOf: modelURL)
                let vnModel = try VNCoreMLModel(for: mlModel)

                var result: Result<RecognitionResult, RecognitionError> =
                    .failure(.processingError("No result."))

                let request = VNCoreMLRequest(model: vnModel) { req, error in
                    if let error {
                        result = .failure(.processingError(error.localizedDescription))
                        return
                    }
                    guard let observations = req.results as? [VNClassificationObservation],
                          let top = observations.first else {
                        result = .failure(.processingError("No classifications found."))
                        return
                    }

                    // Match any of the top-5 predictions against task keywords
                    let matched = observations.prefix(5).contains { obs in
                        let label = obs.identifier.lowercased()
                        return keywords.contains { label.contains($0.lowercased()) }
                    }

                    result = .success(RecognitionResult(
                        detected: matched,
                        topLabel: top.identifier,
                        confidence: top.confidence
                    ))
                }
                request.imageCropAndScaleOption = .centerCrop

                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                try handler.perform([request])

                return result
            } catch {
                return .failure(.processingError(error.localizedDescription))
            }
        }.value
    }
}
