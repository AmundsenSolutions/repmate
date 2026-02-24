import Foundation

/// How long an exercise takes to set up and perform each set
enum SetupTime: String, Codable, CaseIterable {
    case fast = "fast"     // ~30s - Machine exercises, cables
    case medium = "medium" // ~60s - Dumbbells, accessories
    case slow = "slow"     // ~90s - Barbell compounds (RDL, Squat, Bench)
    
    var setDurationSeconds: Int {
        switch self {
        case .fast: return 30
        case .medium: return 45
        case .slow: return 70
        }
    }
    
    var transitionSeconds: Int {
        switch self {
        case .fast: return 30   // Walk + quick adjust
        case .medium: return 60 // Walk + setup
        case .slow: return 90   // Walk + load plates + warmup
        }
    }
    
    var displayName: String {
        switch self {
        case .fast: return "Fast"
        case .medium: return "Medium"
        case .slow: return "Slow"
        }
    }
    
    var icon: String {
        switch self {
        case .fast: return "hare"
        case .medium: return "figure.walk"
        case .slow: return "tortoise"
        }
    }
}

struct Exercise: Identifiable, Codable {
    var id: UUID
    var name: String
    var category: String
    var secondaryMuscle: String? // Optional secondary muscle group (counted at 50% in heatmap)
    var setupTime: SetupTime = .medium // How long the exercise takes to set up/perform
}
