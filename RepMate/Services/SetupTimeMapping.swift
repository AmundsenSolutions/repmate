import Foundation

/// Maps exercise names to their appropriate setup time based on exercise type
struct SetupTimeMapping {
    
    /// Returns the appropriate SetupTime for an exercise based on its name
    static func suggestSetupTime(exerciseName: String) -> SetupTime {
        let name = exerciseName.lowercased()
        
        // SLOW (~70s per set, ~90s transition) - Heavy barbell compounds
        let slowExercises = [
            // Barbell compounds
            "deadlift", "romanian deadlift", "rdl", "stiff-leg deadlift", "sldl",
            "squat", "back squat", "front squat", "hack squat",
            "bench press", "incline bench press", "decline bench press",
            "barbell row", "barbell rows", "bent over row", "pendlay row",
            "overhead press", "military press", "barbell shoulder press",
            "hip thrust", "barbell hip thrust",
            "t-bar row",
            "rack pull", "block pull",
            "clean", "snatch", "power clean"
        ]
        
        // FAST (~30s per set, ~30s transition) - Machines and cables (pin-select, no plates)
        let fastExercises = [
            // Machine exercises (pin-select)
            "leg extension", "leg curl", "seated leg curl", "lying leg curl",
            "pec deck", "chest press", "machine chest press",
            "lat pulldown", "wide grip pulldown", "close grip pulldown",
            "cable crossover", "cable fly", "cable flyes",
            "cable crunch", "cable lateral raise", "cable extension", "overhead cable extension",
            "cable curl", "reverse cable curl", "cable tricep",
            "hip adductor", "hip abductor",
            "seated row", "machine row", "chest-supported row",
            "calf raise", "standing calf raise", "seated calf raise",
            "tricep pushdown", "rope pushdown",
            "face pull",
            "smith machine"
        ]
        
        // Check for slow exercises first (barbell compounds take priority)
        for slowKeyword in slowExercises {
            if name.contains(slowKeyword) {
                return .slow
            }
        }
        
        // Check for fast exercises (machines and cables)
        for fastKeyword in fastExercises {
            if name.contains(fastKeyword) {
                return .fast
            }
        }
        
        // Additional pattern matching
        if name.contains("machine") || name.contains("cable") {
            return .fast
        }
        
        if name.contains("barbell") && !name.contains("curl") {
            return .slow
        }
        
        // Default to medium for dumbbells, bodyweight, and accessories
        return .medium
    }
}
