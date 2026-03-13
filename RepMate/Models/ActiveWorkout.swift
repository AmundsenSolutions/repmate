//
//  ActiveWorkout.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 13/12/2025.
//


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
            // Check for target sets
            let targetSets = template.targets?[exId]?.sets ?? 1
            // Ensure at least 1 set
            let count = max(1, targetSets)
            
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


