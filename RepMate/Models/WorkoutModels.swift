
import Foundation

struct TemplateTarget: Codable, Hashable {
    var sets: String
    var reps: String
    var rir: String // Reps in Reserve (String to support ranges like "0-1")
    var rest: Int // Seconds (optional, maybe standard Int representing seconds)
    
    enum CodingKeys: String, CodingKey {
        case sets, reps, rir, rest
    }
    
    init(sets: String, reps: String, rir: String, rest: Int) {
        self.sets = sets
        self.reps = reps
        self.rir = rir
        self.rest = rest
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.reps = try container.decode(String.self, forKey: .reps)
        self.rir = try container.decode(String.self, forKey: .rir)
        self.rest = try container.decode(Int.self, forKey: .rest)
        
        // Try decoding 'sets' as String first.
        if let setsString = try? container.decode(String.self, forKey: .sets) {
            self.sets = setsString
        } else {
            // Fallback: decode as Int and convert to String to support old local saves
            let setsInt = try container.decode(Int.self, forKey: .sets)
            self.sets = String(setsInt)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sets, forKey: .sets)
        try container.encode(reps, forKey: .reps)
        try container.encode(rir, forKey: .rir)
        try container.encode(rest, forKey: .rest)
    }
}

struct ActiveSetRow: Codable, Hashable, Identifiable {
    var id: UUID = UUID() // Unique ID for list stability
    var weight: String = ""
    var reps: String = ""
    var rir: String = ""
    var isCompleted: Bool = false
}

enum WorkoutFieldFocus: Hashable {
    case weight(setId: UUID)
    case reps(setId: UUID)
    case rir(setId: UUID)
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
    
    /// Generates template deep-link URL.
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

/// Portable workout template model for deep-link sharing.
struct ShareableTemplate: Codable {
    struct ShareableExercise: Codable {
        var name: String
        var category: String? // Changed to optional for backwards compatibility
        var sets: String?
        var reps: String?
        var rir: String?
        
        enum CodingKeys: String, CodingKey {
            case name, category, sets, reps, rir
        }
        
        init(name: String, category: String? = nil, sets: String? = nil, reps: String? = nil, rir: String? = nil) {
            self.name = name
            self.category = category
            self.sets = sets
            self.reps = reps
            self.rir = rir
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.name = try container.decode(String.self, forKey: .name)
            self.category = try container.decodeIfPresent(String.self, forKey: .category)
            self.reps = try container.decodeIfPresent(String.self, forKey: .reps)
            self.rir = try container.decodeIfPresent(String.self, forKey: .rir)
            
            if let setsString = try? container.decodeIfPresent(String.self, forKey: .sets) {
                self.sets = setsString
            } else if let setsInt = try? container.decodeIfPresent(Int.self, forKey: .sets) {
                self.sets = String(setsInt)
            } else {
                self.sets = nil
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(sets, forKey: .sets)
            try container.encodeIfPresent(reps, forKey: .reps)
            try container.encodeIfPresent(rir, forKey: .rir)
        }
    }
    
    var name: String
    var category: String?
    var note: String?
    var exercises: [ShareableExercise]
    
    /// Creates from local template.
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
    
    /// Decodes from deep-link URL.
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
    
    /// Converts to a local WorkoutTemplate, creating missing exercises.
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

