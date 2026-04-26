import Foundation
import UIKit

/// Handles calling the AI plan generation Lambda endpoint.
class AIPlanService {

    // MARK: - Errors

    enum AIPlanError: Error, LocalizedError {
        case networkError(Error)
        case serverError(statusCode: Int, message: String? = nil)
        case rateLimitReached(isPro: Bool)
        case decodingError
        case noEndpoint

        var errorDescription: String? {
            switch self {
            case .networkError(let e):    return "Network error: \(e.localizedDescription)"
            case .serverError(let code, let msg):
                return msg ?? "Server returned status \(code). Please try again."
            case .rateLimitReached(let isPro):
                return isPro ? "You've reached your 50 daily Pro sessions. Take some rest and come back tomorrow!"
                             : "You've used your 5 free AI sessions for today. Upgrade to RepMate Pro for 50 daily sessions!"
            case .decodingError:          return "Could not read the plan response. Please try again."
            case .noEndpoint:             return "Service endpoint not yet configured."
            }
        }
    }

    // MARK: - Configuration

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        config.timeoutIntervalForRequest = 60  // Allow longer for AI inference
        config.timeoutIntervalForResource = 60
        return URLSession(configuration: config)
    }()

    // MARK: - Public API

    /// Sends the user's onboarding answers to the Lambda and returns a structured AI plan.
    ///
    /// - Parameters:
    ///   - answers: A human-readable string of the user's selected answers.
    /// - Returns: A decoded `AIPlanResponse` from the server.
    func generateAIPlan(answers: String, isPro: Bool) async throws -> AIPlanResponse {
        // Fail early if endpoint is still a placeholder
        let endpointString = AppConfig.aiPlanEndpoint.absoluteString
        guard !endpointString.contains("PLACEHOLDER") else {
            throw AIPlanError.noEndpoint
        }

        let userId = KeychainManager.shared.getClientUUID()
        let body: [String: Any] = [
            "userId": userId,
            "answers": answers,
            "isPro": isPro
        ]

        var request = URLRequest(url: AppConfig.aiPlanEndpoint)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(AppConfig.appSecretKey, forHTTPHeaderField: "x-app-key")
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        #if DEBUG
        print("🤖 [AIPlanService] Sending request — userId: \(userId)")
        print("🤖 [AIPlanService] Answers: \(answers)")
        #endif

        let data: Data
        let urlResponse: URLResponse
        do {
            (data, urlResponse) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("🔴 [AIPlanService] Network Error: \(error.localizedDescription)")
            #endif
            throw AIPlanError.networkError(error)
        }

        guard let http = urlResponse as? HTTPURLResponse else {
            throw AIPlanError.networkError(URLError(.badServerResponse))
        }

        #if DEBUG
        print("🟢 [AIPlanService] HTTP Status: \(http.statusCode)")
        if let raw = String(data: data, encoding: .utf8) {
            print("🟢 [AIPlanService] Raw response: \(raw)")
        }
        #endif

        guard (200...299).contains(http.statusCode) else {
            #if DEBUG
            print("🔴 [AIPlanService] HTTP Status Error: \(http.statusCode)")
            if let rawError = String(data: data, encoding: .utf8) {
                print("🔴 [AIPlanService] Raw Error Payload: \(rawError)")
            }
            #endif

            // Priority check: API Gateway Throttling or Lambda Rate Limit
            if http.statusCode == 429 {
                throw AIPlanError.rateLimitReached(isPro: isPro)
            }

            // Try to decode the Lambda error body for user-friendly messages
            if let errorBody = try? JSONDecoder().decode([String: String].self, from: data),
               let code = errorBody["error"] {
                switch code {
                case "RATE_LIMITED":
                    throw AIPlanError.rateLimitReached(isPro: isPro)
                case "FORBIDDEN":
                    throw AIPlanError.serverError(statusCode: http.statusCode,
                        message: "App authentication failed. Please update the app.")
                default:
                    break
                }
            }
            throw AIPlanError.serverError(statusCode: http.statusCode)
        }

        do {
            return try JSONDecoder().decode(AIPlanResponse.self, from: data)
        } catch {
            #if DEBUG
            print("🔴 [AIPlanService] Decoding Error: \(error)")
            #endif
            throw AIPlanError.decodingError
        }
    }
}
