import Foundation

/// Setup duration categories for exercises.
enum SetupTime: String, Codable, CaseIterable {
    case fast = "fast"     // 50s work set - Isolations, cables
    case medium = "medium" // 60s work set - Dumbbells, accessories
    case slow = "slow"     // 90s work set - Barbell compounds (RDL, Squat, Bench)
    
    // Transition times
    var transitionSeconds: Int {
        switch self {
        case .fast: return 60
        case .medium: return 100
        case .slow: return 150
        }
    }
    
    // Warmup Set duration
    var warmupSetSeconds: Int {
        switch self {
        case .fast: return 25
        case .medium: return 40
        case .slow: return 60
        }
    }
    
    // Rest after warmup
    var warmupRestSeconds: Int {
        switch self {
        case .fast: return 60
        case .medium: return 90
        case .slow: return 120
        }
    }
    
    // Work Set duration
    var setDurationSeconds: Int {
        switch self {
        case .fast: return 50
        case .medium: return 60
        case .slow: return 90
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
