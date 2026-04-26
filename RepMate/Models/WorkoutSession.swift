import Foundation

struct SetLog: Identifiable, Codable, Hashable {
    var id: UUID
    var exerciseId: UUID
    var setIndex: Int
    var reps: Int
    var weight: Double?
    var rir: String? // Added Reps in Reserve
    
    enum CodingKeys: String, CodingKey {
        case id, exerciseId, setIndex, reps, weight, rir
    }
    
    init(id: UUID, exerciseId: UUID, setIndex: Int, reps: Int, weight: Double?, rir: String?) {
        self.id = id
        self.exerciseId = exerciseId
        self.setIndex = setIndex
        self.reps = reps
        self.weight = weight
        self.rir = rir
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.exerciseId = (try? container.decode(UUID.self, forKey: .exerciseId)) ?? UUID()
        self.setIndex = (try? container.decode(Int.self, forKey: .setIndex)) ?? 1
        self.reps = (try? container.decode(Int.self, forKey: .reps)) ?? 0
        self.weight = try? container.decodeIfPresent(Double.self, forKey: .weight)
        self.rir = try? container.decodeIfPresent(String.self, forKey: .rir)
    }
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

    enum CodingKeys: String, CodingKey {
        case id, templateId, date, notes, sets, startedAt, endedAt, exerciseNotes
    }
    
    init(id: UUID, templateId: UUID, date: Date, notes: String?, sets: [SetLog], startedAt: Date?, endedAt: Date?, exerciseNotes: [UUID: String]?) {
        self.id = id
        self.templateId = templateId
        self.date = date
        self.notes = notes
        self.sets = sets
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exerciseNotes = exerciseNotes
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = (try? container.decode(UUID.self, forKey: .id)) ?? UUID()
        self.templateId = (try? container.decode(UUID.self, forKey: .templateId)) ?? UUID()
        self.date = (try? container.decode(Date.self, forKey: .date)) ?? Date()
        self.notes = try? container.decodeIfPresent(String.self, forKey: .notes)
        self.sets = (try? container.decode([SetLog].self, forKey: .sets)) ?? []
        self.startedAt = try? container.decodeIfPresent(Date.self, forKey: .startedAt)
        self.endedAt = try? container.decodeIfPresent(Date.self, forKey: .endedAt)
        self.exerciseNotes = try? container.decodeIfPresent([UUID: String].self, forKey: .exerciseNotes)
    }
}
