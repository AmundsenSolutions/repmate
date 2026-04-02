import Foundation

struct AppConfig {
    static let aiProteinEndpoint = URL(string: "https://a5xnl4z4nhlqmp6tspvrne4wzq0avaga.lambda-url.us-east-1.on.aws/")!

    /// Shared app secret sent as `x-app-key` on every AI request.
    /// Value lives in the gitignored Secrets.swift — never hardcoded here.
    static var appSecretKey: String { Secrets.appSecretKey }
}
