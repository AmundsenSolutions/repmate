//
//  ProteinEntry.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 11/12/2025.
//


import Foundation

/// Represents a single logged protein intake with optional note and timestamp.
struct ProteinEntry: Identifiable, Codable {
    let id: UUID
    var date: Date
    var grams: Int
    var note: String?

    /// Creates a protein entry, defaulting to a new UUID and the current time.
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

/// A custom local mapping for a barcode not found in OpenFoodFacts.
struct CustomBarcodeEntry: Codable, Hashable {
    var name: String
    var proteinGrams: Int
}

/// A saved favorite protein item for quick entry.
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
    
    /// Default settings used on first launch or when loading fails.
    static let `default` = AppSettings(
        dailyProteinTarget: 150,
        defaultRestTime: 90,
        targetMinReps: 4,
        targetMaxReps: 8,
        neglectedStatsMuscles: ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves"],
        hasSeededDefaults: false
    )
}
