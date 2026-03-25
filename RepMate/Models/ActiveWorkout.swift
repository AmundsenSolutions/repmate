import Foundation

struct ActiveWorkout: Identifiable, Codable, Equatable {
    var id: UUID
    var templateId: UUID
    var startedAt: Date
    
    // Ordered list of exercises (allows adding/removing/reordering)
    var exerciseIds: [UUID]

    // exerciseId -> rows (sets)
    var rowsByExercise: [UUID: [ActiveSetRow]]
    
    // exerciseId -> note
    var notesByExercise: [UUID: String]

    // “dirty flag” for exit confirmation
    var isDirty: Bool
    
    var timerTargetDate: Date? // Persisted target time for rest timer recovery
    
    var note: String? // Session note copied from template
    var targets: [UUID: TemplateTarget]? = nil // Targets copied from template

    static func start(from template: WorkoutTemplate) -> ActiveWorkout {
        // Start with 1 empty row per exercise
        var dict: [UUID: [ActiveSetRow]] = [:]
        for exId in template.exerciseIds {
            // Parse target sets to find the maximum requested rows
            let setsString = template.targets?[exId]?.sets ?? "1"
            let numbers = setsString.components(separatedBy: CharacterSet.decimalDigits.inverted)
                .compactMap { Int($0) }
            
            let requestedSets = numbers.max() ?? 1
            // Cap at 20 sets per exercise to prevent UI freezes
            let count = min(max(1, requestedSets), 20)
            
            var rows: [ActiveSetRow] = []
            for _ in 0..<count {
                rows.append(ActiveSetRow())
            }
            dict[exId] = rows
        }
        return ActiveWorkout(
            id: UUID(),
            templateId: template.id,
            startedAt: Date(),
            exerciseIds: template.exerciseIds,
            rowsByExercise: dict,
            notesByExercise: [:],
            isDirty: false,
            note: template.note,
            targets: template.targets
        )
    }

    static func startEmpty() -> ActiveWorkout {
        return ActiveWorkout(
            id: UUID(),
            templateId: UUID(), // Random ID as it's not based on a template
            startedAt: Date(),
            exerciseIds: [],
            rowsByExercise: [:],
            notesByExercise: [:],
            isDirty: false,
            note: nil,
            targets: nil
        )
    }
}


