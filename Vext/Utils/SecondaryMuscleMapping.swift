import Foundation

/// Auto-mapping of secondary muscles based on exercise name patterns.
/// Used to migrate existing exercises and suggest secondary muscles for new ones.
struct SecondaryMuscleMapping {
    
    /// Returns suggested secondary muscle for an exercise based on its name and primary category.
    /// Returns nil if no secondary muscle is applicable.
    static func suggestSecondaryMuscle(exerciseName: String, primaryCategory: String) -> String? {
        let name = exerciseName.lowercased()
        let primary = primaryCategory.lowercased()
        
        // Chest exercises often hit Triceps or Shoulders
        if primary == "chest" {
            if name.contains("press") || name.contains("push") {
                return "Triceps"
            }
            if name.contains("fly") || name.contains("crossover") {
                return "Shoulders"
            }
        }
        
        // Back exercises often hit Biceps
        if primary == "back" {
            if name.contains("row") || name.contains("pull") {
                return "Biceps"
            }
            if name.contains("deadlift") {
                return "Hamstrings"
            }
        }
        
        // Shoulder presses hit Triceps
        if primary == "shoulders" {
            if name.contains("press") {
                return "Triceps"
            }
        }
        
        // Leg compounds hit Core/Hamstrings
        if primary == "quads" || primary == "hamstrings" || primary == "glutes" {
            if name.contains("squat") || name.contains("deadlift") || name.contains("lunge") {
                return "Core"
            }
        }
        
        // Dips hit Chest or Triceps depending on primary
        if name.contains("dip") {
            if primary == "triceps" {
                return "Chest"
            }
            if primary == "chest" {
                return "Triceps"
            }
        }
        
        // Chin-ups hit Biceps
        if name.contains("chin") {
            return "Biceps"
        }
        
        return nil
    }
    
    /// Applies secondary muscle mapping to an array of exercises.
    /// Only sets secondary muscle if it's currently nil.
    static func applyMappings(to exercises: inout [Exercise]) {
        for index in exercises.indices {
            if exercises[index].secondaryMuscle == nil {
                exercises[index].secondaryMuscle = suggestSecondaryMuscle(
                    exerciseName: exercises[index].name,
                    primaryCategory: exercises[index].category
                )
            }
        }
    }
}
