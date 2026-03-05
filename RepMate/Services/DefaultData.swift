import Foundation

struct DefaultData {
    static let categories = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves", "Core"]
    
    static let workoutCategories = ["Full Body", "Upper", "Lower", "Push", "Pull", "Cardio", "Other"]
    
    static let exercises: [Exercise] = [
        // --- Chest ---
        Exercise(id: UUID(), name: "Incline chest press", category: "Chest", secondaryMuscle: "Shoulders", setupTime: .slow),
        Exercise(id: UUID(), name: "Pec deck", category: "Chest", secondaryMuscle: "Shoulders", setupTime: .fast),
        Exercise(id: UUID(), name: "Bench press", category: "Chest", secondaryMuscle: "Triceps", setupTime: .slow),
        Exercise(id: UUID(), name: "Cable crossover", category: "Chest", secondaryMuscle: "Shoulders", setupTime: .fast),
        Exercise(id: UUID(), name: "Push-ups", category: "Chest", secondaryMuscle: "Triceps", setupTime: .fast),

        // --- Back ---
        Exercise(id: UUID(), name: "Wide grip pulldown", category: "Back", secondaryMuscle: "Biceps", setupTime: .fast),
        Exercise(id: UUID(), name: "Chest-supported row", category: "Back", secondaryMuscle: "Biceps", setupTime: .medium),
        Exercise(id: UUID(), name: "Barbell row", category: "Back", secondaryMuscle: "Biceps", setupTime: .slow),
        Exercise(id: UUID(), name: "Pull-ups", category: "Back", secondaryMuscle: "Biceps", setupTime: .fast),
        Exercise(id: UUID(), name: "Deadlift", category: "Back", secondaryMuscle: "Hamstrings", setupTime: .slow),

        // --- Shoulders ---
        Exercise(id: UUID(), name: "Shoulder press", category: "Shoulders", secondaryMuscle: "Triceps", setupTime: .slow),
        Exercise(id: UUID(), name: "Cable lateral raise", category: "Shoulders", setupTime: .fast),
        Exercise(id: UUID(), name: "Lateral raise", category: "Shoulders", setupTime: .fast),
        Exercise(id: UUID(), name: "Front raise", category: "Shoulders", secondaryMuscle: "Chest", setupTime: .fast),
        Exercise(id: UUID(), name: "Rear delt flyes", category: "Shoulders", secondaryMuscle: "Back", setupTime: .fast),

        // --- Biceps ---
        Exercise(id: UUID(), name: "Preacher dumbbell curl", category: "Biceps", setupTime: .medium),
        Exercise(id: UUID(), name: "Reverse cable curl", category: "Biceps", setupTime: .fast),
        Exercise(id: UUID(), name: "Bicep curl", category: "Biceps", setupTime: .medium),
        Exercise(id: UUID(), name: "Hammer curl", category: "Biceps", setupTime: .medium),

        // --- Triceps ---
        Exercise(id: UUID(), name: "Cable extension", category: "Triceps", setupTime: .fast),
        Exercise(id: UUID(), name: "Overhead cable extension", category: "Triceps", setupTime: .fast),
        Exercise(id: UUID(), name: "Tricep dips", category: "Triceps", secondaryMuscle: "Chest", setupTime: .medium),

        // --- Quads ---
        Exercise(id: UUID(), name: "Hack squat", category: "Quads", secondaryMuscle: "Glutes", setupTime: .slow),
        Exercise(id: UUID(), name: "Leg extension", category: "Quads", setupTime: .fast),
        Exercise(id: UUID(), name: "Squat", category: "Quads", secondaryMuscle: "Glutes", setupTime: .slow),
        Exercise(id: UUID(), name: "Leg press", category: "Quads", secondaryMuscle: "Glutes", setupTime: .medium),
        Exercise(id: UUID(), name: "Hip adductor", category: "Quads", setupTime: .fast),

        // --- Hamstrings ---
        Exercise(id: UUID(), name: "Stiff-leg deadlift", category: "Hamstrings", secondaryMuscle: "Glutes", setupTime: .slow),
        Exercise(id: UUID(), name: "Seated leg curl", category: "Hamstrings", setupTime: .fast),
        Exercise(id: UUID(), name: "Romanian deadlift", category: "Hamstrings", secondaryMuscle: "Glutes", setupTime: .slow),

        // --- Calves ---
        Exercise(id: UUID(), name: "Standing calf raise", category: "Calves", setupTime: .fast),
        
        // --- Core ---
        Exercise(id: UUID(), name: "Cable crunch", category: "Core", setupTime: .fast)
    ]
    
    static let workouts: [(name: String, category: String, note: String?, exercises: [(name: String, cat: String, sets: Int, reps: String, rir: String)])] = [
        (
            name: "FULLBODY",
            category: "Full Body",
            note: nil,
            exercises: [
                ("Incline chest press", "Chest", 1, "6-10", "0-1"),
                ("Pec deck", "Chest", 1, "8-12", "0-1"),
                ("Wide grip pulldown", "Back", 1, "6-10", "0-1"),
                ("Chest-supported row", "Back", 1, "6-10", "0-1"),
                ("Shoulder press", "Shoulders", 1, "6-10", "0-1"),
                ("Preacher dumbbell curl", "Biceps", 1, "8-12", "0-1"),
                ("Cable extension", "Triceps", 1, "8-12", "0-1"),
                ("Stiff-leg deadlift", "Hamstrings", 1, "8-12", "0-1"),
                ("Leg extension", "Quads", 1, "10-15", "0-1"),
                ("Seated leg curl", "Hamstrings", 1, "6-10", "0-1"),
                ("Standing calf raise", "Calves", 1, "6-10", "0-1")
            ]
        ),
        (
            name: "UPPER",
            category: "Upper",
            note: nil,
            exercises: [
                ("Incline chest press", "Chest", 2, "6-10", "0-1"),
                ("Pec deck", "Chest", 2, "8-12", "0-1"),
                ("Wide grip pulldown", "Back", 2, "6-10", "0-1"),
                ("Chest-supported row", "Back", 2, "6-10", "0-1"),
                ("Shoulder press", "Shoulders", 2, "6-10", "0-1"),
                ("Cable lateral raise", "Shoulders", 2, "10-15", "0-1"),
                ("Preacher dumbbell curl", "Biceps", 2, "8-12", "0-1"),
                ("Cable extension", "Triceps", 2, "8-12", "0-1")
            ]
        ),
        (
            name: "LOWER",
            category: "Lower",
            note: nil,
            exercises: [
                ("Hack squat", "Quads", 1, "6-10", "0-1"),
                ("Leg extension", "Quads", 2, "10-15", "0-1"),
                ("Seated leg curl", "Hamstrings", 2, "6-10", "0-1"),
                ("Stiff-leg deadlift", "Hamstrings", 1, "8-12", "0-1"),
                ("Hip adductor", "Quads", 2, "8-12", "0-1"),
                ("Standing calf raise", "Calves", 2, "10-15", "0-1"),
                ("Cable crunch", "Core", 2, "10-15", "0-1")
            ]
        )
    ]
}
