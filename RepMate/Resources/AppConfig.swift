import Foundation

struct AppConfig {
    /// Existing protein analysis Lambda endpoint.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var aiProteinEndpoint: URL { URL(string: Secrets.aiProteinEndpointString)! }

    /// AI plan generation Lambda endpoint.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var aiPlanEndpoint: URL { URL(string: Secrets.aiPlanEndpointString)! }

    /// Shared app secret sent as `x-app-key` on every AI request.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var appSecretKey: String { Secrets.appSecretKey }
}
