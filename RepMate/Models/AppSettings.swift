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

// MARK: - App Settings

/// Persistent user settings for the app.
struct AppSettings: Codable {
    var dailyProteinTarget: Int
    var defaultRestTime: Int? // Optional for backward compatibility with existing JSON

    var restTime: Int {
        get { defaultRestTime ?? 90 }
        set { defaultRestTime = newValue }
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

    /// Fallback settings for first launch.
    static let `default` = AppSettings(
        dailyProteinTarget: 150,
        defaultRestTime: 90,
        targetMinReps: 4,
        targetMaxReps: 8,
        neglectedStatsMuscles: ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves"],
        hasSeededDefaults: false
    )
}
