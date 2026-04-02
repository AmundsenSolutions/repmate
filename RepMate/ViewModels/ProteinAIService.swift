import Foundation
import UIKit

struct ProteinResponse: Codable {
    let food_item: String
    let protein_grams: Int
    let description: String
}

struct AIErrorResponse: Codable {
    let error: String
    let message: String
}

class ProteinAIService {
    private let endpoint = AppConfig.aiProteinEndpoint

    // Persistent session: skips cache checks, keeps TCP alive, fails fast at 15 s.
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 15
        config.timeoutIntervalForResource = 30
        config.httpAdditionalHeaders = ["Connection": "keep-alive"]
        return URLSession(configuration: config)
    }()

    enum AIError: Error {
        case serverError(code: String, message: String)
        case invalidImage
        case noInput
        case networkError(Error)
        case decodingError
    }

    /// Fire-and-forget HEAD request — establishes DNS + TCP + TLS while the user
    /// is still looking at CameraView, so the pipe is warm when the image arrives.
    func warmUpConnection() {
        var req = URLRequest(url: endpoint)
        req.httpMethod = "HEAD"
        req.timeoutInterval = 5
        Task { _ = try? await session.data(for: req)
            #if DEBUG
            print("🔌 [ProteinAIService] Connection warmed up.")
            #endif
        }
    }
    
    // MARK: - Unified entry point
    /// Sends either an image, free-text, or both to the Lambda endpoint.
    /// At least one of `image` or `text` must be non-nil.
    func analyzeInput(image: UIImage? = nil, text: String? = nil) async throws -> ProteinResponse {
        guard image != nil || (text != nil && !text!.trimmingCharacters(in: .whitespaces).isEmpty) else {
            throw AIError.noInput
        }

        #if DEBUG
        print("🔵 [ProteinAIService] Starting analysis — image: \(image != nil), text: \(text != nil)")
        #endif

        // Build JSON body — include base64 image only when an image is provided
        var bodyDict: [String: String] = [:]

        if let img = image {
            let uploadImage: UIImage = {
                let maxWidth: CGFloat = 750
                guard img.size.width > maxWidth else { return img }
                let scale = maxWidth / img.size.width
                let newSize = CGSize(width: maxWidth, height: img.size.height * scale)
                let renderer = UIGraphicsImageRenderer(size: newSize)
                return renderer.image { _ in img.draw(in: CGRect(origin: .zero, size: newSize)) }
            }()

            guard let imageData = uploadImage.jpegData(compressionQuality: 0.9) else {
                throw AIError.invalidImage
            }
            bodyDict["image"] = imageData.base64EncodedString()
            #if DEBUG
            print("🔵 [ProteinAIService] Upload size: \(imageData.count / 1024) KB (original: \(Int(img.size.width))×\(Int(img.size.height)))")
            #endif
        }

        if let txt = text, !txt.trimmingCharacters(in: .whitespaces).isEmpty {
            bodyDict["text"] = txt
            #if DEBUG
            print("🔵 [ProteinAIService] Text payload: \"\(txt)\"")
            #endif
        }

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppConfig.appSecretKey, forHTTPHeaderField: "x-app-key")
        request.httpBody = try? JSONEncoder().encode(bodyDict)

        let data: Data
        let urlResponse: URLResponse

        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("🔴 [ProteinAIService] Network Error: \(error.localizedDescription)")
            #endif
            throw AIError.networkError(error)
        }

        guard let httpResponse = urlResponse as? HTTPURLResponse else {
            throw AIError.networkError(URLError(.badServerResponse))
        }

        #if DEBUG
        print("🟢 [ProteinAIService] AWS Status Code: \(httpResponse.statusCode)")
        #endif

        guard (200...299).contains(httpResponse.statusCode) else {
            if let errorResponse = try? JSONDecoder().decode(AIErrorResponse.self, from: data) {
                #if DEBUG
                print("🔴 [ProteinAIService] Server Error Code: \(errorResponse.error)")
                #endif
                throw AIError.serverError(code: errorResponse.error, message: errorResponse.message)
            }

            #if DEBUG
            if let errorString = String(data: data, encoding: .utf8) {
                print("🔴 [ProteinAIService] Raw Server Error: \(errorString)")
            }
            #endif
            throw AIError.networkError(URLError(.badServerResponse))
        }

        do {
            let responseModel = try JSONDecoder().decode(ProteinResponse.self, from: data)
            #if DEBUG
            print("✅ [ProteinAIService] Successfully analyzed: \(responseModel.food_item)")
            #endif
            return responseModel
        } catch {
            #if DEBUG
            print("🔴 [ProteinAIService] Decoding Error: \(error)")
            if let rawJson = String(data: data, encoding: .utf8) {
                print("🔹 [ProteinAIService] Raw JSON: \(rawJson)")
            }
            #endif
            throw AIError.decodingError
        }
    }

    // MARK: - Convenience wrapper (camera flow — unchanged callers)
    func analyzeImage(_ image: UIImage) async throws -> ProteinResponse {
        try await analyzeInput(image: image)
    }
}
