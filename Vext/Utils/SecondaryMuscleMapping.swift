import Foundation

/// Auto-mapping of secondary muscles based on exercise name patterns.
/// Used to migrate existing exercises and suggest secondary muscles for new ones.
///
/// Valid muscle groups: Chest, Back, Shoulders, Biceps, Triceps, Quads, Hamstrings, Glutes, Calves, Core
struct SecondaryMuscleMapping {
    
    /// Returns suggested secondary muscle for an exercise based on its name and primary category.
    /// Returns nil if no secondary muscle is applicable (isolation exercises).
    static func suggestSecondaryMuscle(exerciseName: String, primaryCategory: String) -> String? {
        let name = exerciseName.lowercased()
        let primary = primaryCategory.lowercased()
        
        // --- Chest exercises ---
        if primary == "chest" {
            // Presses and push-ups → Triceps
            if name.contains("press") || name.contains("push") {
                return "Triceps"
            }
            // Flyes and crossovers → Shoulders (front delt stretch)
            if name.contains("fly") || name.contains("flye") || name.contains("crossover") || name.contains("pec deck") {
                return "Shoulders"
            }
            // Dips → Triceps
            if name.contains("dip") {
                return "Triceps"
            }
        }
        
        // --- Back exercises ---
        if primary == "back" {
            // Deadlifts → Hamstrings
            if name.contains("deadlift") {
                return "Hamstrings"
            }
            // All pulls and rows → Biceps
            if name.contains("row") || name.contains("pull") || name.contains("chin") {
                return "Biceps"
            }
        }
        
        // --- Shoulder exercises ---
        if primary == "shoulders" {
            // Presses → Triceps
            if name.contains("press") {
                return "Triceps"
            }
            // Front raises → Chest (anterior delt + chest tie-in)
            if name.contains("front raise") {
                return "Chest"
            }
            // Rear delt work → Back
            if name.contains("rear") || name.contains("face pull") || name.contains("reverse fly") {
                return "Back"
            }
            // Lateral raises, shrugs → no secondary (isolation)
            return nil
        }
        
        // --- Quad exercises ---
        if primary == "quads" {
            // Squats and lunges → Glutes
            if name.contains("squat") || name.contains("lunge") || name.contains("leg press") || name.contains("hack") || name.contains("split") {
                return "Glutes"
            }
            // Leg extensions → isolation, no secondary
            return nil
        }
        
        // --- Hamstring exercises ---
        if primary == "hamstrings" {
            // Deadlift variations → Glutes
            if name.contains("deadlift") || name.contains("rdl") || name.contains("stiff") || name.contains("good morning") {
                return "Glutes"
            }
            // Leg curls → isolation, no secondary
            return nil
        }
        
        // --- Glute exercises ---
        if primary == "glutes" {
            // Hip thrusts → Hamstrings
            if name.contains("hip thrust") || name.contains("bridge") {
                return "Hamstrings"
            }
            // Squats / lunges under glutes → Quads
            if name.contains("squat") || name.contains("lunge") {
                return "Quads"
            }
            return nil
        }
        
        // --- Tricep exercises ---
        if primary == "triceps" {
            // Dips → Chest
            if name.contains("dip") {
                return "Chest"
            }
            // Close-grip bench → Chest
            if name.contains("close grip") || name.contains("close-grip") {
                return "Chest"
            }
            // Extensions, pushdowns → isolation
            return nil
        }
        
        // --- Bicep exercises ---
        // All curls are isolation — no secondary
        if primary == "biceps" {
            return nil
        }
        
        // --- Calves ---
        // All calf exercises are isolation — no secondary
        if primary == "calves" {
            return nil
        }
        
        // --- Core ---
        if primary == "core" {
            return nil
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
