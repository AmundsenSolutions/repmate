import Foundation

enum OverloadDirection {
    case none
    case up
    case down
}

/// Determines weight progression/deload suggestions.
struct ProgressiveOverloadHelper {
    
    /// Returns progression direction (.up or .down) based on past performance.
    static func checkOverloadStatus(
        for exerciseId: UUID,
        in sessions: [WorkoutSession],
        settings: AppSettings
    ) -> OverloadDirection {
        // Need at least one previous session with this exercise
        let relevantSessions = sessions.filter { session in
            session.sets.contains { $0.exerciseId == exerciseId && $0.weight != nil }
        }
        
        guard let lastSession = relevantSessions.first else { return .none }
        
        // Get sets from last session
        let lastSessionSets = lastSession.sets.filter { $0.exerciseId == exerciseId }
        
        guard !lastSessionSets.isEmpty else { return .none }
        
        // --- UP ARROW LOGIC ---
        // Criteria 1: RIR >= 3 on any set (set was too easy)
        let rirValues = lastSessionSets.compactMap { set -> Int? in
            guard let rir = set.rir else { return nil }
            let cleaned = rir.replacingOccurrences(of: " ", with: "")
            if cleaned.contains("-") {
                let parts = cleaned.split(separator: "-").compactMap { Int($0) }
                return parts.max()
            }
            return Int(cleaned)
        }
        
        if !rirValues.isEmpty {
            if rirValues.contains(where: { $0 >= 3 }) {
                return .up
            }
        }
        
        // Criteria 2: Reps > user's max target rep range
        let repValues = lastSessionSets.map { $0.reps }
        if repValues.contains(where: { $0 > settings.maxReps }) {
            return .up
        }
        
        // --- DOWN ARROW LOGIC (DELOAD) ---
        // Criteria: RIR == 0 AND Reps < user's min target rep range
        if rirValues.contains(where: { $0 == 0 }) && repValues.contains(where: { $0 < settings.minReps }) {
            return .down
        }
        
        return .none
    }
    
    /// Formats the suggested weight change string.
    static func getSuggestion(
        for exerciseId: UUID,
        in sessions: [WorkoutSession],
        settings: AppSettings
    ) -> String? {
        let status = checkOverloadStatus(for: exerciseId, in: sessions, settings: settings)
        guard status != .none else { return nil }
        
        // Get the best weight from last session
        let relevantSessions = sessions.filter { session in
            session.sets.contains { $0.exerciseId == exerciseId && $0.weight != nil }
        }
        
        guard let lastSession = relevantSessions.first else { return nil }
        
        let lastSessionSets = lastSession.sets.filter { $0.exerciseId == exerciseId }
        let maxWeight = lastSessionSets.compactMap { $0.weight }.max() ?? 0
        
        if status == .up {
            // Suggest 2.5kg increase
            let suggestedWeight = maxWeight + 2.5
            return String(format: "%.1f kg", suggestedWeight)
        } else {
            // Suggest 2.5kg decrease for deload
            let suggestedWeight = max(0, maxWeight - 2.5)
            return String(format: "%.1f kg", suggestedWeight)
        }
    }
}
