import Foundation

struct DefaultData {
    static let categories = ["Chest", "Back", "Shoulders", "Biceps", "Triceps", "Quads", "Hamstrings", "Glutes", "Calves", "Core", "Other"]
    
    static let workoutCategories = ["Full Body", "Upper", "Lower", "Push", "Pull", "Cardio", "Other"]
    
    static let exercises: [Exercise] = [
        // Chest
        Exercise(id: UUID(), name: "Bench Press", category: "Chest", setupTime: .slow),
        Exercise(id: UUID(), name: "Incline Bench Press", category: "Chest", setupTime: .slow),
        Exercise(id: UUID(), name: "Dumbbell Flyes", category: "Chest", setupTime: .medium),
        Exercise(id: UUID(), name: "Push-ups", category: "Chest", setupTime: .fast),
        Exercise(id: UUID(), name: "Cable Crossover", category: "Chest", setupTime: .fast),

        // Back
        Exercise(id: UUID(), name: "Pull-ups", category: "Back", setupTime: .medium),
        Exercise(id: UUID(), name: "Barbell Rows", category: "Back", setupTime: .slow),
        Exercise(id: UUID(), name: "Lat Pulldown", category: "Back", setupTime: .fast),
        Exercise(id: UUID(), name: "Deadlift", category: "Back", setupTime: .slow),
        Exercise(id: UUID(), name: "T-Bar Row", category: "Back", setupTime: .slow),

        // Quads, Hamstrings, Glutes, Calves
        Exercise(id: UUID(), name: "Squats", category: "Quads", setupTime: .slow),
        Exercise(id: UUID(), name: "Leg Press", category: "Quads", setupTime: .medium),
        Exercise(id: UUID(), name: "Romanian Deadlift", category: "Hamstrings", setupTime: .slow),
        Exercise(id: UUID(), name: "Leg Curls", category: "Hamstrings", setupTime: .fast),
        Exercise(id: UUID(), name: "Calf Raises", category: "Calves", setupTime: .fast),

        // Shoulders
        Exercise(id: UUID(), name: "Overhead Press", category: "Shoulders", setupTime: .slow),
        Exercise(id: UUID(), name: "Lateral Raises", category: "Shoulders", setupTime: .medium),
        Exercise(id: UUID(), name: "Front Raises", category: "Shoulders", setupTime: .medium),
        Exercise(id: UUID(), name: "Rear Delt Flyes", category: "Shoulders", setupTime: .medium),

        // Biceps
        Exercise(id: UUID(), name: "Bicep Curls", category: "Biceps", setupTime: .medium),
        Exercise(id: UUID(), name: "Hammer Curls", category: "Biceps", setupTime: .medium),

        // Triceps
        Exercise(id: UUID(), name: "Tricep Dips", category: "Triceps", setupTime: .medium),
        Exercise(id: UUID(), name: "Tricep Extensions", category: "Triceps", setupTime: .fast),

        // Core
        Exercise(id: UUID(), name: "Plank", category: "Core", setupTime: .fast),
        Exercise(id: UUID(), name: "Russian Twists", category: "Core", setupTime: .fast),
        Exercise(id: UUID(), name: "Leg Raises", category: "Core", setupTime: .fast),
        Exercise(id: UUID(), name: "Crunches", category: "Core", setupTime: .fast),

        // Other
        Exercise(id: UUID(), name: "Burpees", category: "Other", setupTime: .fast),
        Exercise(id: UUID(), name: "Mountain Climbers", category: "Other", setupTime: .fast)
    ]
    
    static let workouts: [(name: String, category: String, note: String?, exercises: [(name: String, cat: String, sets: Int, reps: String, rir: String)])] = [
        (
            name: "FULLBODY",
            category: "Full Body",
            note: "1–3 sett per muskelgruppe, 0–1 RIR",
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
                ("Standing calf raise", "Calves", 1, "6-10", "0-1"),
                ("Cable crunch", "Core", 1, "8-12", "0-1")
            ]
        ),
        (
            name: "UPPER",
            category: "Upper",
            note: "2–5 sett per muskelgruppe, 0–1 RIR",
            exercises: [
                ("Incline chest press", "Chest", 2, "6-10", "0-1"),
                ("Pec deck", "Chest", 2, "8-12", "0-1"),
                ("Wide grip pulldown", "Back", 2, "6-10", "0-1"),
                ("Chest-supported row", "Back", 2, "6-10", "0-1"),
                ("Shoulder press", "Shoulders", 2, "6-10", "0-1"),
                ("Cable lateral raise", "Shoulders", 2, "10-15", "0-1"),
                ("Preacher dumbbell curl", "Biceps", 2, "8-12", "0-1"),
                ("Reverse cable curl", "Biceps", 2, "8-12", "0-1"),
                ("Cable extension", "Triceps", 2, "8-12", "0-1"),
                ("Overhead cable extension", "Triceps", 2, "8-12", "0-1")
            ]
        ),
        (
            name: "LOWER",
            category: "Lower",
            note: "2–5 sett per muskelgruppe, 0–1 RIR",
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
