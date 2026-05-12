
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
        // Fail-safe: use decodeIfPresent with defaults so a single corrupt field
        // doesn't nuke the entire targets dictionary.
        self.reps = (try? container.decode(String.self, forKey: .reps)) ?? ""
        self.rir = (try? container.decode(String.self, forKey: .rir)) ?? ""
        self.rest = (try? container.decode(Int.self, forKey: .rest)) ?? 90
        
        // Try decoding 'sets' as String first.
        if let setsString = try? container.decode(String.self, forKey: .sets) {
            self.sets = setsString
        } else if let setsInt = try? container.decode(Int.self, forKey: .sets) {
            // Fallback: decode as Int and convert to String to support old local saves
            self.sets = String(setsInt)
        } else {
            self.sets = "3"
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

struct ActiveSetRow: Hashable, Identifiable, Codable {
    var id: UUID = UUID() // Unique ID for list stability
    var weight: String = ""
    var reps: String = ""
    var rir: String = ""
    var isCompleted: Bool = false
    
    enum CodingKeys: String, CodingKey {
        case id, weight, reps, rir, isCompleted
    }
    
    init(id: UUID = UUID(), weight: String = "", reps: String = "", rir: String = "", isCompleted: Bool = false) {
        self.id = id
        self.weight = weight
        self.reps = reps
        self.rir = rir
        self.isCompleted = isCompleted
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.weight = (try? container.decode(String.self, forKey: .weight)) ?? ""
        self.reps = (try? container.decode(String.self, forKey: .reps)) ?? ""
        self.rir = (try? container.decode(String.self, forKey: .rir)) ?? ""
        self.isCompleted = (try? container.decode(Bool.self, forKey: .isCompleted)) ?? false
    }
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
    ///
    /// **Pipeline:** JSON (compact keys) → zlib compress → URL-safe Base64 → path-based URL.
    /// Path-based format (`repmate://import/BASE64`) prevents iMessage from truncating
    /// the link at query-parameter boundaries.
    func shareURL(exercises: [Exercise]) -> URL? {
        let shareable = ShareableTemplate(from: self, exercises: exercises)
        guard let jsonData = try? JSONEncoder().encode(shareable) else { return nil }
        
        // Compress with zlib for significantly shorter URLs
        guard let compressed = try? (jsonData as NSData).compressed(using: .zlib) as Data else {
            // Fallback to uncompressed if compression fails
            return Self.buildPathURL(from: jsonData)
        }
        return Self.buildPathURL(from: compressed)
    }
    
    /// Builds a path-based deep-link URL from raw data.
    private static func buildPathURL(from data: Data) -> URL? {
        let base64 = data.base64EncodedString()
        let urlSafe = base64
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
        // Path-based URL: no query params → iMessage treats entire string as one link
        return URL(string: "repmate://import/\(urlSafe)")
    }
    
    /// Formatted share message for a polished sharing experience.
    func shareMessage(exercises: [Exercise]) -> String? {
        guard let url = shareURL(exercises: exercises) else { return nil }
        let exerciseCount = exerciseIds.count
        return "Try this workout on RepMate: \(name) 💪\n\(exerciseCount) exercises\n\n\(url.absoluteString)"
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
///
/// **Encoding pipeline:** Compact JSON keys → zlib → URL-safe Base64 → path-based URL.
/// **Key mapping (encode → decode):**
/// - `n` = name, `c` = category, `s` = sets, `r` = reps
/// - `i` = rir, `t` = rest (time), `e` = exercises, `o` = note
struct ShareableTemplate: Codable {
    struct ShareableExercise: Codable {
        var name: String
        var category: String?
        var sets: String?
        var reps: String?
        var rir: String?
        var rest: Int?
        
        // Compact keys for minimal URL size
        enum CodingKeys: String, CodingKey {
            case name = "n", category = "c", sets = "s", reps = "r", rir = "i", rest = "t"
        }
        
        // Legacy keys for backward compatibility with old shared links
        private enum LegacyKeys: String, CodingKey {
            case name, category, sets, reps, rir, rest
        }
        
        init(name: String, category: String? = nil, sets: String? = nil, reps: String? = nil, rir: String? = nil, rest: Int? = nil) {
            self.name = name
            self.category = category
            self.sets = sets
            self.reps = reps
            self.rir = rir
            self.rest = rest
        }
        
        init(from decoder: Decoder) throws {
            // Try compact keys first (new links)
            if let c = try? decoder.container(keyedBy: CodingKeys.self), c.contains(.name) {
                self.name = try c.decode(String.self, forKey: .name)
                self.category = try c.decodeIfPresent(String.self, forKey: .category)
                self.reps = try c.decodeIfPresent(String.self, forKey: .reps)
                self.rir = try c.decodeIfPresent(String.self, forKey: .rir)
                self.rest = try c.decodeIfPresent(Int.self, forKey: .rest)
                if let s = try? c.decode(String.self, forKey: .sets) {
                    self.sets = s
                } else if let si = try? c.decode(Int.self, forKey: .sets) {
                    self.sets = String(si)
                } else {
                    self.sets = nil
                }
            } else {
                // Fall back to legacy keys (old links)
                let c = try decoder.container(keyedBy: LegacyKeys.self)
                self.name = try c.decode(String.self, forKey: .name)
                self.category = try c.decodeIfPresent(String.self, forKey: .category)
                self.reps = try c.decodeIfPresent(String.self, forKey: .reps)
                self.rir = try c.decodeIfPresent(String.self, forKey: .rir)
                self.rest = try c.decodeIfPresent(Int.self, forKey: .rest)
                if let s = try? c.decode(String.self, forKey: .sets) {
                    self.sets = s
                } else if let si = try? c.decode(Int.self, forKey: .sets) {
                    self.sets = String(si)
                } else {
                    self.sets = nil
                }
            }
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(category, forKey: .category)
            try container.encodeIfPresent(sets, forKey: .sets)
            try container.encodeIfPresent(reps, forKey: .reps)
            try container.encodeIfPresent(rir, forKey: .rir)
            try container.encodeIfPresent(rest, forKey: .rest)
        }
    }
    
    var name: String
    var category: String?
    var note: String?
    var exercises: [ShareableExercise]
    
    // Compact keys for minimal URL size
    enum CodingKeys: String, CodingKey {
        case name = "n", category = "c", note = "o", exercises = "e"
    }
    
    // Legacy keys for backward compatibility with old shared links
    private enum LegacyKeys: String, CodingKey {
        case name, category, note, exercises
    }
    
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
                rir: target?.rir,
                rest: target?.rest
            )
        }
    }
    
    init(from decoder: Decoder) throws {
        // Try compact keys first (new links)
        if let c = try? decoder.container(keyedBy: CodingKeys.self), c.contains(.name) {
            self.name = try c.decode(String.self, forKey: .name)
            self.category = try c.decodeIfPresent(String.self, forKey: .category)
            self.note = try c.decodeIfPresent(String.self, forKey: .note)
            self.exercises = try c.decode([ShareableExercise].self, forKey: .exercises)
        } else {
            // Fall back to legacy keys (old links)
            let c = try decoder.container(keyedBy: LegacyKeys.self)
            self.name = try c.decode(String.self, forKey: .name)
            self.category = try c.decodeIfPresent(String.self, forKey: .category)
            self.note = try c.decodeIfPresent(String.self, forKey: .note)
            self.exercises = try c.decode([ShareableExercise].self, forKey: .exercises)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(name, forKey: .name)
        try container.encodeIfPresent(category, forKey: .category)
        try container.encodeIfPresent(note, forKey: .note)
        try container.encode(exercises, forKey: .exercises)
    }
    
    // MARK: - Deep-Link Decoding (supports both new and legacy formats)
    
    /// Decodes from deep-link URL.
    ///
    /// Supports two URL formats:
    /// - **New (v2):** `repmate://import/COMPRESSED_BASE64` — path-based, zlib-compressed, compact keys.
    /// - **Legacy (v1):** `repmate://import?t=BASE64` — query-param, uncompressed, full keys.
    static func fromURL(_ url: URL) -> ShareableTemplate? {
        guard url.scheme == "repmate", url.host == "import" else { return nil }
        
        // 1. Extract Base64 payload from path (new) or query (legacy)
        let base64: String
        let pathPayload = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if !pathPayload.isEmpty {
            // New path-based format: repmate://import/BASE64
            base64 = pathPayload
        } else if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
                  let queryValue = components.queryItems?.first(where: { $0.name == "t" })?.value {
            // Legacy query-param format: repmate://import?t=BASE64
            base64 = queryValue
        } else {
            return nil
        }
        
        // Security: Prevent malicious payload memory bloat
        guard base64.count < 50_000 else { return nil }
        
        // 2. Restore standard Base64 from URL-safe variant
        var restored = base64
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let remainder = restored.count % 4
        if remainder > 0 { restored += String(repeating: "=", count: 4 - remainder) }
        
        guard let rawData = Data(base64Encoded: restored) else { return nil }
        
        // 3. Try zlib-decompressed decode first (new v2 format)
        if let decompressed = try? (rawData as NSData).decompressed(using: .zlib) as Data,
           let template = try? JSONDecoder().decode(ShareableTemplate.self, from: decompressed) {
            return template
        }
        
        // 4. Fall back to direct decode (legacy v1 uncompressed format)
        return try? JSONDecoder().decode(ShareableTemplate.self, from: rawData)
    }
    
    /// Converts to a local WorkoutTemplate, creating missing exercises.
    func toWorkoutTemplate(exerciseLibrary: [Exercise], addExercise: (String, String) -> Exercise) -> WorkoutTemplate? {
        guard exercises.count <= 50 else { return nil } // H5 Fix: limit to 50 exercises
        
        var exerciseIds: [UUID] = []
        var targets: [UUID: TemplateTarget] = [:]
        // Take a mutable copy so we can track exercises we've already created
        var knownExercises = exerciseLibrary
        
        // H5 Fix: Truncate template name to 100 characters
        let safeTemplateName = String(name.prefix(100))
        
        for shared in exercises {
            // H5 Fix: Truncate exercise name to 100 characters
            let safeName = String(shared.name.prefix(100))
            
            // Try to find existing exercise by name (case-insensitive)
            let existing = knownExercises.first { $0.name.lowercased() == safeName.lowercased() }
            
            let exerciseId: UUID
            if let found = existing {
                exerciseId = found.id
            } else {
                // Create the exercise via the store and get the authoritative object
                // If the QR/Deep Link didn't provide a category, default to "Other"
                let newExercise = addExercise(safeName, shared.category ?? "Other")
                knownExercises.append(newExercise)
                exerciseId = newExercise.id
            }
            
            exerciseIds.append(exerciseId)
            
            // Create target if ANY field has data (not just sets)
            let hasTargetData = shared.sets != nil || shared.reps != nil || shared.rir != nil || (shared.rest != nil && shared.rest != 0)
            if hasTargetData {
                targets[exerciseId] = TemplateTarget(
                    sets: shared.sets ?? "",
                    reps: shared.reps ?? "",
                    rir: shared.rir ?? "",
                    rest: shared.rest ?? 120
                )
            }
        }
        
        return WorkoutTemplate(
            id: UUID(),
            name: safeTemplateName,
            exerciseIds: exerciseIds,
            targets: targets.isEmpty ? nil : targets,
            note: note,
            category: category
        )
    }
}

