//
//  AppSettings.swift
//  RepMate
//

import Foundation

// MARK: - Stats Dashboard Order

/// Defines the order/visibility of sections in the Stats dashboard.
enum StatCardType: String, CaseIterable, Identifiable, Codable {
    case overview
    case strength
    case activity
    case nutrition
    case muscleMap
    case insights
    case oneRM
    case allTimePRs

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .overview:   return "Overview"
        case .strength:   return "Strength & PR"
        case .activity:   return "Activity & Habits"
        case .nutrition:  return "Nutrition"
        case .muscleMap:  return "Muscle Map"
        case .insights:   return "Smart Insights"
        case .oneRM:      return "1RM Calculator"
        case .allTimePRs: return "All-Time Best Lifts"
        }
    }

    var icon: String {
        switch self {
        case .overview:   return "square.grid.2x2"
        case .strength:   return "dumbbell.fill"
        case .activity:   return "flame.fill"
        case .nutrition:  return "fork.knife"
        case .muscleMap:  return "figure.arms.open"
        case .insights:   return "brain.head.profile"
        case .oneRM:      return "scalemass.fill"
        case .allTimePRs: return "trophy.fill"
        }
    }
}

// MARK: - AI Coach Profile

enum ExperienceLevel: String, CaseIterable, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

enum EquipmentAccess: String, CaseIterable, Codable {
    case bodyweightAndBands = "Bodyweight & Bands"
    case homeGym = "Home Gym"
    case fullGym = "Full Gym"
}

// MARK: - App Settings

/// Persistent user settings for the app.
struct AppSettings: Codable {
    var dailyProteinTarget: Int
    var defaultRestTime: Int? // Optional for backward compatibility with existing JSON

    enum CodingKeys: String, CodingKey {
        case dailyProteinTarget
        case defaultRestTime
        case optShowRIR
        case optExperienceLevel
        case optEquipmentAccess
        case targetMinReps
        case targetMaxReps
        case neglectedStatsMuscles
        case hasSeededDefaults
        case optWorkoutReminderEnabled
        case optWorkoutReminderTime
        case optWorkoutReminderDays
        case optProteinReminderEnabled
        case optProteinReminderTime
        case statsOrder
        case migrationVersion
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Mandatory fields with default fallbacks if corrupted
        self.dailyProteinTarget = (try? container.decode(Int.self, forKey: .dailyProteinTarget)) ?? 150
        self.hasSeededDefaults = (try? container.decode(Bool.self, forKey: .hasSeededDefaults)) ?? false
        
        // Optional/New fields - use decodeIfPresent and wrap in try? for total safety
        self.defaultRestTime = try? container.decodeIfPresent(Int.self, forKey: .defaultRestTime) ?? nil
        self.optShowRIR = try? container.decodeIfPresent(Bool.self, forKey: .optShowRIR) ?? nil
        self.optExperienceLevel = try? container.decodeIfPresent(ExperienceLevel.self, forKey: .optExperienceLevel) ?? nil
        self.optEquipmentAccess = try? container.decodeIfPresent(EquipmentAccess.self, forKey: .optEquipmentAccess) ?? nil
        self.targetMinReps = try? container.decodeIfPresent(Int.self, forKey: .targetMinReps) ?? nil
        self.targetMaxReps = try? container.decodeIfPresent(Int.self, forKey: .targetMaxReps) ?? nil
        self.neglectedStatsMuscles = try? container.decodeIfPresent([String].self, forKey: .neglectedStatsMuscles) ?? nil
        
        self.optWorkoutReminderEnabled = try? container.decodeIfPresent(Bool.self, forKey: .optWorkoutReminderEnabled) ?? nil
        self.optWorkoutReminderTime = try? container.decodeIfPresent(Date.self, forKey: .optWorkoutReminderTime) ?? nil
        self.optWorkoutReminderDays = try? container.decodeIfPresent([Int].self, forKey: .optWorkoutReminderDays) ?? nil
        self.optProteinReminderEnabled = try? container.decodeIfPresent(Bool.self, forKey: .optProteinReminderEnabled) ?? nil
        self.optProteinReminderTime = try? container.decodeIfPresent(Date.self, forKey: .optProteinReminderTime) ?? nil
        
        self.statsOrder = try? container.decodeIfPresent([StatCardType].self, forKey: .statsOrder) ?? nil
        self.migrationVersion = try? container.decodeIfPresent(Int.self, forKey: .migrationVersion) ?? nil
    }

    // Default initializer for manual creation (e.g., .default)
    init(dailyProteinTarget: Int,
         defaultRestTime: Int? = nil,
         optShowRIR: Bool? = nil,
         optExperienceLevel: ExperienceLevel? = nil,
         optEquipmentAccess: EquipmentAccess? = nil,
         targetMinReps: Int? = nil,
         targetMaxReps: Int? = nil,
         neglectedStatsMuscles: [String]? = nil,
         hasSeededDefaults: Bool = false,
         optWorkoutReminderEnabled: Bool? = nil,
         optWorkoutReminderTime: Date? = nil,
         optWorkoutReminderDays: [Int]? = nil,
         optProteinReminderEnabled: Bool? = nil,
         optProteinReminderTime: Date? = nil,
         statsOrder: [StatCardType]? = nil,
         migrationVersion: Int? = nil) {
        self.dailyProteinTarget = dailyProteinTarget
        self.defaultRestTime = defaultRestTime
        self.optShowRIR = optShowRIR
        self.optExperienceLevel = optExperienceLevel
        self.optEquipmentAccess = optEquipmentAccess
        self.targetMinReps = targetMinReps
        self.targetMaxReps = targetMaxReps
        self.neglectedStatsMuscles = neglectedStatsMuscles
        self.hasSeededDefaults = hasSeededDefaults
        self.optWorkoutReminderEnabled = optWorkoutReminderEnabled
        self.optWorkoutReminderTime = optWorkoutReminderTime
        self.optWorkoutReminderDays = optWorkoutReminderDays
        self.optProteinReminderEnabled = optProteinReminderEnabled
        self.optProteinReminderTime = optProteinReminderTime
        self.statsOrder = statsOrder
        self.migrationVersion = migrationVersion
    }

    var restTime: Int {
        get { defaultRestTime ?? 90 }
        set { defaultRestTime = newValue }
    }
    
    // Feature Toggles
    var optShowRIR: Bool?

    // AI Coach Profile
    var optExperienceLevel: ExperienceLevel?
    var optEquipmentAccess: EquipmentAccess?
    
    var showRIR: Bool {
        get { optShowRIR ?? false }
        set { optShowRIR = newValue }
    }

    var experienceLevel: ExperienceLevel {
        get { optExperienceLevel ?? .beginner }
        set { optExperienceLevel = newValue }
    }

    var equipmentAccess: EquipmentAccess {
        get { optEquipmentAccess ?? .fullGym }
        set { optEquipmentAccess = newValue }
    }

    // Progressive Overload Targets
    var targetMinReps: Int?
    var targetMaxReps: Int?

    var minReps: Int {
        get { targetMinReps ?? 4 }
        set { targetMinReps = newValue }
    }

    var maxReps: Int {
        get { targetMaxReps ?? 8 }
        set { targetMaxReps = newValue }
    }

    // Muscles to display in the Neglected Stats view.
    var neglectedStatsMuscles: [String]?

    var trackedMuscles: [String] {
        get { neglectedStatsMuscles ?? ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves"] }
        set { neglectedStatsMuscles = newValue }
    }

    var hasSeededDefaults: Bool = false

    // Reminders
    var optWorkoutReminderEnabled: Bool?
    var optWorkoutReminderTime: Date?
    var optWorkoutReminderDays: [Int]?
    var optProteinReminderEnabled: Bool?
    var optProteinReminderTime: Date?

    var workoutReminderEnabled: Bool {
        get { optWorkoutReminderEnabled ?? false }
        set { optWorkoutReminderEnabled = newValue }
    }

    var workoutReminderTime: Date {
        get { optWorkoutReminderTime ?? Calendar.current.date(from: DateComponents(hour: 17, minute: 0)) ?? Date() }
        set { optWorkoutReminderTime = newValue }
    }

    var workoutReminderDays: [Int] {
        get { optWorkoutReminderDays ?? [] }
        set { optWorkoutReminderDays = newValue }
    }

    var proteinReminderEnabled: Bool {
        get { optProteinReminderEnabled ?? false }
        set { optProteinReminderEnabled = newValue }
    }

    var proteinReminderTime: Date {
        get { optProteinReminderTime ?? Calendar.current.date(from: DateComponents(hour: 20, minute: 0)) ?? Date() }
        set { optProteinReminderTime = newValue }
    }

    // Customizable Stats dashboard order.
    var statsOrder: [StatCardType]?

    var activeStatsOrder: [StatCardType] {
        statsOrder ?? StatCardType.allCases
    }

    var migrationVersion: Int?

    /// Fallback settings for first launch.
    static let `default` = AppSettings(
        dailyProteinTarget: 150,
        defaultRestTime: 90,
        optShowRIR: false,
        optExperienceLevel: .beginner,
        optEquipmentAccess: .fullGym,
        targetMinReps: 4,
        targetMaxReps: 8,
        neglectedStatsMuscles: ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves"],
        hasSeededDefaults: false
    )
}
