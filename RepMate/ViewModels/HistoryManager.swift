//
//  HistoryManager.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 2026.
//

import Foundation

/// Retrieves historical workout data.
struct HistoryManager {
    
    /// Gets previous set performance.
    func previousSetData(for exerciseId: UUID, setIndex: Int, in sessions: [WorkoutSession]) -> (weight: Double, reps: Int, rir: String)? {
        // We assume sessions are maintained in sorted order by AppDataStore (newest first).
        
        for session in sessions {
            // Find sets for this exercise in this session
            let exerciseSets = session.sets.filter { $0.exerciseId == exerciseId }
            
            // Look for the specific set index
            if let match = exerciseSets.first(where: { $0.setIndex == setIndex + 1 }) { // setIndex is 0-based in View, 1-based in Model
                // Return if we have valid data
                let rirValue = match.rir ?? ""
                if let w = match.weight {
                    return (w, match.reps, rirValue)
                }
                 // If weight is nil (bodyweight), we still might want to return reps
                return (0, match.reps, rirValue)
            }
        }
        return nil
    }

    /// Gets latest exercise note.
    func previousExerciseNote(for exerciseId: UUID, in sessions: [WorkoutSession]) -> String? {
        for session in sessions {
            if let note = session.exerciseNotes?[exerciseId], !note.isEmpty {
                return note
            }
        }
        return nil
    }
    
    /// Generates max weight chart data.
    func chartData(for exerciseId: UUID, months: Int, in sessions: [WorkoutSession]) -> [(date: Date, weight: Double)] {
        var filteredSessions = sessions
        
        if months > 0 {
            if let startDate = Calendar.current.date(byAdding: .month, value: -months, to: Date()) {
                filteredSessions = sessions.filter { $0.date >= startDate }
            }
        }
        
        var data: [(Date, Double)] = []
        
        // Iterate reversed (Oldest first) for correct chart drawing order
        // Sessions given are Newest First.
        for session in filteredSessions.reversed() {
            let sets = session.sets.filter { $0.exerciseId == exerciseId }
            // Find max weight for this session
            if let maxWeight = sets.compactMap({ $0.weight }).max() {
                data.append((session.date, maxWeight))
            }
        }
        
        return data
    }
}
