import Foundation

// MARK: - AI Plan API Response Models

/// Top-level response from the AI plan generation Lambda.
struct AIPlanResponse: Codable {
    let plan_name: String
    let rationale: String
    let workouts: [AIPlanWorkout]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.plan_name = (try? container.decode(String.self, forKey: .plan_name)) ?? "AI Plan"
        self.rationale = (try? container.decode(String.self, forKey: .rationale)) ?? ""
        self.workouts = (try? container.decode([AIPlanWorkout].self, forKey: .workouts)) ?? []
    }
}

/// A single training day within an AI-generated plan.
struct AIPlanWorkout: Codable {
    let day_name: String
    let exercises: [AIPlanExercise]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.day_name = (try? container.decode(String.self, forKey: .day_name)) ?? "Workout"
        self.exercises = (try? container.decode([AIPlanExercise].self, forKey: .exercises)) ?? []
    }
}

/// A single exercise prescription within a workout day.
struct AIPlanExercise: Codable {
    let name: String
    let sets: Int
    let reps: String   // String to support ranges like "8-12"
    let rir: Int
    let notes: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = (try? container.decode(String.self, forKey: .name)) ?? "Exercise"
        self.sets = (try? container.decode(Int.self, forKey: .sets)) ?? 3
        self.reps = (try? container.decode(String.self, forKey: .reps)) ?? "8-12"
        self.rir = (try? container.decode(Int.self, forKey: .rir)) ?? 2
        self.notes = (try? container.decode(String.self, forKey: .notes)) ?? ""
    }
}

// MARK: - Onboarding Answer Model

/// Represents the user's answers from the AI onboarding flow.
struct AIOnboardingAnswers {
    enum ExperienceLevel: String, CaseIterable {
        case beginner     = "Beginner (0-1 yrs)"
        case intermediate = "Intermediate (1-3 yrs)"
        case advanced     = "Advanced (3+ yrs)"
    }

    enum TrainingDays: String, CaseIterable {
        case light    = "2-3 Days / Week"
        case moderate = "4 Days / Week"
        case high     = "5-6 Days / Week"
    }

    enum Equipment: String, CaseIterable {
        case fullGym    = "Full Commercial Gym"
        case homeGym    = "Home Gym"
        case bodyweight = "Bodyweight & Bands"
    }

    var experienceLevel: ExperienceLevel
    var trainingDays: TrainingDays
    var equipment: Equipment

    /// Formats all answers into a structured string for the Lambda payload.
    var formattedString: String {
        "Experience: \(experienceLevel.rawValue) | Days: \(trainingDays.rawValue) | Equipment: \(equipment.rawValue)"
    }
}
