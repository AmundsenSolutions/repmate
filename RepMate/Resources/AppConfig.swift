import Foundation

struct AppConfig {
    /// Statically initialized fallback URL — guaranteed safe, no force unwrap needed.
    private static let fallbackURL = URL(string: "https://localhost")!  // Known-valid literal, will never crash
    
    /// Existing protein analysis Lambda endpoint.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var aiProteinEndpoint: URL {
        guard let url = URL(string: Secrets.aiProteinEndpointString) else {
            assertionFailure("Invalid aiProteinEndpointString in Secrets.swift")
            return fallbackURL
        }
        return url
    }

    /// AI plan generation Lambda endpoint.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var aiPlanEndpoint: URL {
        guard let url = URL(string: Secrets.aiPlanEndpointString) else {
            assertionFailure("Invalid aiPlanEndpointString in Secrets.swift")
            return fallbackURL
        }
        return url
    }

    /// Shared app secret sent as `x-app-key` on every AI request.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var appSecretKey: String { Secrets.appSecretKey }
}
