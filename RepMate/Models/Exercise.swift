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
    
    enum CodingKeys: String, CodingKey {
        case id, name, category, secondaryMuscle, setupTime
    }
    
    init(id: UUID, name: String, category: String, secondaryMuscle: String? = nil, setupTime: SetupTime = .medium) {
        self.id = id
        self.name = name
        self.category = category
        self.secondaryMuscle = secondaryMuscle
        self.setupTime = setupTime
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(UUID.self, forKey: .id)
        self.name = try container.decode(String.self, forKey: .name)
        self.category = try container.decode(String.self, forKey: .category)
        self.secondaryMuscle = try container.decodeIfPresent(String.self, forKey: .secondaryMuscle)
        
        // Fail-safe for setupTime enum changes
        if let setupStr = try container.decodeIfPresent(String.self, forKey: .setupTime),
           let parsedSetup = SetupTime(rawValue: setupStr) {
            self.setupTime = parsedSetup
        } else {
            self.setupTime = .medium
        }
    }
}
