
import Foundation

struct TemplateTarget: Codable, Hashable {
    var sets: Int
    var reps: String
    var rir: String // Reps in Reserve (String to support ranges like "0-1")
    var rest: Int // Seconds (optional, maybe standard Int representing seconds)
}

struct ActiveSetRow: Codable, Hashable, Identifiable {
    var id: UUID = UUID() // Unique ID for list stability
    var weight: String = ""
    var reps: String = ""
    var rir: String = ""
    var isCompleted: Bool = false
}

struct WorkoutTemplate: Identifiable, Codable {
    let id: UUID
    var name: String
    var exerciseIds: [UUID]
    var targets: [UUID: TemplateTarget]? = nil // Mapping ExerciseID -> Target
    var note: String? = nil // General workout instructions/notes
    var category: String? = nil // e.g. "Full Body", "Upper", "Lower"
}

extension WorkoutTemplate {
    static var empty: WorkoutTemplate {
        WorkoutTemplate(
            id: UUID(),
            name: "New Workout",
            exerciseIds: []
        )
    }
    
    /// Generates a shareable deep-link URL for this template.
    func shareURL(exercises: [Exercise]) -> URL? {
        let shareable = ShareableTemplate(from: self, exercises: exercises)
        guard let data = try? JSONEncoder().encode(shareable) else { return nil }
        let base64 = data.base64EncodedString()
        // URL-safe base64 (replace +/ with -_ and remove padding)
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        return URL(string: "repmate://import?t=\(urlSafe)")
    }
}

enum WorkoutNavigation: Hashable {
    case exerciseLibrary
    case templateDetail(UUID)
}

enum GhostDataSource: String, Codable, CaseIterable {
    case latest = "Last Entry"
    case routine = "This Template"
}

// MARK: - Shareable Template (for deep-link sharing)

/// A portable representation of a workout template.
/// Uses exercise names instead of UUIDs so it can be shared between users.
struct ShareableTemplate: Codable {
    struct ShareableExercise: Codable {
        var name: String
        var category: String? // Changed to optional for backwards compatibility
        var sets: Int?
        var reps: String?
        var rir: String?
    }
    
    var name: String
    var category: String?
    var note: String?
    var exercises: [ShareableExercise]
    
    /// Create from a WorkoutTemplate + exercise library
    init(from template: WorkoutTemplate, exercises: [Exercise]) {
        self.name = template.name
        self.category = template.category
        self.note = template.note
        self.exercises = template.exerciseIds.compactMap { id in
            guard let exercise = exercises.first(where: { $0.id == id }) else { return nil }
            let target = template.targets?[id]
            return ShareableExercise(
                name: exercise.name,
                category: exercise.category,
                sets: target?.sets,
                reps: target?.reps,
                rir: target?.rir
            )
        }
    }
    
    /// Decode from a deep-link URL
    static func fromURL(_ url: URL) -> ShareableTemplate? {
        guard url.scheme == "repmate",
              url.host == "import",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let base64 = components.queryItems?.first(where: { $0.name == "t" })?.value
        else { return nil }
        
        // Restore standard base64 from URL-safe variant
        var restored = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        // Restore padding
        let remainder = restored.count % 4
        if remainder > 0 { restored += String(repeating: "=", count: 4 - remainder) }
        
        guard let data = Data(base64Encoded: restored) else { return nil }
        return try? JSONDecoder().decode(ShareableTemplate.self, from: data)
    }
    
    /// Convert to a WorkoutTemplate, matching or creating exercises in the library.
    /// The `addExercise` closure should add the exercise and is called with (name, category).
    func toWorkoutTemplate(exerciseLibrary: [Exercise], addExercise: (String, String) -> Exercise) -> WorkoutTemplate {
        var exerciseIds: [UUID] = []
        var targets: [UUID: TemplateTarget] = [:]
        // Take a mutable copy so we can track exercises we've already created
        var knownExercises = exerciseLibrary
        
        for shared in exercises {
            // Try to find existing exercise by name (case-insensitive)
            let existing = knownExercises.first { $0.name.lowercased() == shared.name.lowercased() }
            
            let exerciseId: UUID
            if let found = existing {
                exerciseId = found.id
            } else {
                // Create the exercise via the store and get the authoritative object
                // If the QR/Deep Link didn't provide a category, default to "Other"
                let newExercise = addExercise(shared.name, shared.category ?? "Other")
                knownExercises.append(newExercise)
                exerciseId = newExercise.id
            }
            
            exerciseIds.append(exerciseId)
            
            if let sets = shared.sets {
                targets[exerciseId] = TemplateTarget(
                    sets: sets,
                    reps: shared.reps ?? "",
                    rir: shared.rir ?? "",
                    rest: 0
                )
            }
        }
        
        return WorkoutTemplate(
            id: UUID(),
            name: name,
            exerciseIds: exerciseIds,
            targets: targets.isEmpty ? nil : targets,
            note: note,
            category: category
        )
    }
}

