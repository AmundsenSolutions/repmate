//
//  ProteinEntry.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 11/12/2025.
//


import Foundation

/// A single logged protein intake.
struct ProteinEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var grams: Int
    var note: String?

    /// Creates a new protein log with current time.
    init(id: UUID = UUID(),
         date: Date = Date(),
         grams: Int,
         note: String? = nil) {
        self.id = id
        self.date = date
        self.grams = grams
        self.note = note
    }
}

/// Custom barcode mapping for unresolved items.
struct CustomBarcodeEntry: Codable, Hashable {
    var name: String
    var proteinGrams: Int
}

/// Saved quick-add protein item.
struct FavoriteProtein: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var grams: Int
    var note: String?
}

// Persistent user settings for the app.
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
