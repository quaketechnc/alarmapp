//
//  NetworkingService.swift
//  Alarm
//
//

import Foundation
import UIKit
import FirebaseCore
import FirebaseAppCheck


// MARK: - Public model

struct MissionRecognitionResult: Sendable {
    let detected: Bool
    let topLabel: String
    let confidence: Double
}

// MARK: - Errors

enum NetworkingServiceError: LocalizedError {
    case invalidURL
    case invalidPayload
    case imageEncodingFailed
    case serverError(statusCode: Int, payload: String)
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Failed to build URL for Firebase Function."
        case .invalidPayload: return "Failed to serialize request payload."
        case .imageEncodingFailed: return "Failed to encode photo."
        case .serverError(let code, let payload):
            return "Server responded with code \(code). Payload: \(payload)"
        case .decodingFailed: return "Failed to decode server response."
        }
    }
}


// MARK: - Service

enum NetworkingService {
    private enum FirebaseFunction: String {
        case recognizeMissionPhoto
    }

    private static let region = "us-central1"
    private static let jsonDecoder = JSONDecoder()
    private static let logPrefix = "[NetworkingService]"
    
    private static let urlSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.timeoutIntervalForRequest = 30
        c.timeoutIntervalForResource = 60
        return URLSession(configuration: c)
    }()

    /// Upload `image` and the mission `task.instruction` to the backend,
    /// receive a verdict whether the photo satisfies the instruction.
    static func recognizeMissionPhoto(
        image: UIImage,
        task: AlarmTask
    ) async -> Result<MissionRecognitionResult, NetworkingServiceError> {
        
        guard let jpeg = image.jpegData(compressionQuality: 0.7) else {
            return .failure(.imageEncodingFailed)
        }
        
        let base64 = jpeg.base64EncodedString()
        
        let specificPayload: [String: Any] = [
            "requestType": "missionPhoto",
            "taskInstruction": task.instruction,
            "taskId": task.id,
            "photoBase64": base64
        ]
        
        do {
            let payload = buildPayload(from: specificPayload)
            
            var redacted = payload
            redacted["photoBase64"] = "<\(jpeg.count) bytes>"
            log("Prepared payload: \(stringify(redacted))")
            
            let data = try await performFirebaseRequest(.recognizeMissionPhoto, payload: payload)
            
            log("Raw response: \(describe(data: data))")
            
            let decoded = try decodeResult(from: data)
            
            log("Decoded: \(decoded.detected) \(decoded.topLabel) \(decoded.confidence)")
            
            return .success(decoded)
            
        } catch let error as NetworkingServiceError {
            log("⚠️ failed: \(error.localizedDescription)")
            return .failure(error)
        } catch {
            log("⚠️ failed: \(error.localizedDescription)")
            return .failure(.serverError(statusCode: -1, payload: error.localizedDescription))
        }
    }
}

// MARK: - Networking

private extension NetworkingService {

    static func buildPayload(from specific: [String: Any]) -> [String: Any] {
        var payload = specific
        payload["userId"] = UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
        payload["locale"] = Locale.current.identifier
        payload["appVersion"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
        payload["buildNumber"] = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        payload["timestamp"] = ISO8601DateFormatter().string(from: Date())
        return payload
    }

    private static func performFirebaseRequest(
        _ function: FirebaseFunction,
        payload: [String: Any]
    ) async throws -> Data {

        guard let url = cloudFunctionURL(for: function) else {
            throw NetworkingServiceError.invalidURL
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
//        let appCheckToken = try await FirebaseService.refreshAppCheckTokenToken()
//        request.setValue(appCheckToken.token, forHTTPHeaderField: "X-Firebase-AppCheck")

        guard JSONSerialization.isValidJSONObject(payload),
              let body = try? JSONSerialization.data(withJSONObject: payload) else {
            throw NetworkingServiceError.invalidPayload
        }

        request.httpBody = body

        log("➡️ \(function.rawValue) @ \(url.absoluteString)")

        let (data, response) = try await urlSession.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkingServiceError.serverError(statusCode: -1, payload: "No response")
        }

        log("⬅️ status: \(http.statusCode)")

        guard (200..<300).contains(http.statusCode) else {
            let payloadString = String(data: data, encoding: .utf8) ?? "empty"
            throw NetworkingServiceError.serverError(statusCode: http.statusCode, payload: payloadString)
        }

        return data
    }

    static func decodeResult(from data: Data) throws -> MissionRecognitionResult {

        if let direct = try? jsonDecoder.decode(MissionRecognitionRemote.self, from: data) {
            return direct.domainModel
        }

        if let wrapped = try? jsonDecoder.decode(FirebaseCallableEnvelope<MissionRecognitionRemote>.self, from: data),
           let inner = wrapped.result ?? wrapped.data {
            return inner.domainModel
        }

        throw NetworkingServiceError.decodingFailed
    }

    private static func cloudFunctionURL(for function: FirebaseFunction) -> URL? {
        guard let projectId = FirebaseApp.app()?.options.projectID else {
            return nil
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "\(region)-\(projectId).cloudfunctions.net"
        components.path = "/\(function.rawValue)"

        return components.url
    }
}

// MARK: - Logging helpers

private extension NetworkingService {

    static func log(_ message: String) {
        print("\(logPrefix) \(message)")
    }

    static func stringify(_ payload: [String: Any]) -> String {
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.prettyPrinted]),
              let string = String(data: data, encoding: .utf8) else {
            return "\(payload)"
        }
        return string
    }

    static func describe(data: Data) -> String {
        if let s = String(data: data, encoding: .utf8), !s.isEmpty {
            return s.count > 500 ? "\(s.prefix(500))…" : s
        }
        return "binary \(data.count) bytes"
    }
}

// MARK: - DTOs

private struct MissionRecognitionRemote: Decodable {
    let detected: Bool?
    let label: String?
    let confidence: Double?

    var domainModel: MissionRecognitionResult {
        MissionRecognitionResult(
            detected: detected ?? false,
            topLabel: label ?? "",
            confidence: confidence ?? 0
        )
    }
}

private struct FirebaseCallableEnvelope<T: Decodable>: Decodable {
    let data: T?
    let result: T?
}
