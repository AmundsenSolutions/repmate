import Foundation

struct SetLog: Identifiable, Codable, Hashable {
    var id: UUID
    var exerciseId: UUID
    var setIndex: Int
    var reps: Int
    var weight: Double?
    var rir: String? // Added Reps in Reserve
}

struct WorkoutSession: Identifiable, Codable, Hashable {
    var id: UUID
    var templateId: UUID
    var date: Date
    var notes: String?
    var sets: [SetLog]
    var startedAt: Date?
    var endedAt: Date?
    
    // Per-exercise notes (exerciseId -> note)
    var exerciseNotes: [UUID: String]?
}
