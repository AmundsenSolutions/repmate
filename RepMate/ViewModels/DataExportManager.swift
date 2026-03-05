import Foundation
import Combine
import SwiftUI
import UniformTypeIdentifiers

/// Handles CSV generation for data export.
final class DataExportManager {
    
    /// Converts workout sessions to CSV format.
    static func generateWorkoutsCSV(sessions: [WorkoutSession], exerciseLibrary: [Exercise]) -> String {
        var csv = "Session Date,Session Duration (s),Exercise Name,Set Number,Weight (kg),Reps,RIR\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for session in sessions.sorted(by: { $0.date > $1.date }) {
            let sessionDate = dateFormatter.string(from: session.date)
            let duration = session.endedAt?.timeIntervalSince(session.startedAt ?? session.date) ?? 0
            
            for set in session.sets {
                let exerciseName = exerciseLibrary.first(where: { $0.id == set.exerciseId })?.name ?? "Unknown"
                let weight = set.weight ?? 0.0
                let reps = set.reps
                let rir = set.rir ?? "0"
                
                csv += "\(sessionDate),\(Int(duration)),\"\(exerciseName)\",\(set.setIndex),\(weight),\(reps),\(rir)\n"
            }
        }
        
        return csv
    }
    
    /// Converts protein entries to CSV format.
    static func generateProteinCSV(entries: [ProteinEntry]) -> String {
        var csv = "Date,Grams,Note\n"
        
        let dateFormatter = ISO8601DateFormatter()
        
        for entry in entries.sorted(by: { $0.date > $1.date }) {
            let date = dateFormatter.string(from: entry.date)
            let note = entry.note?.replacingOccurrences(of: "\"", with: "\"\"") ?? ""
            
            csv += "\(date),\(entry.grams),\"\(note)\"\n"
        }
        
        return csv
    }
    
    // Modern approach using Transferable for ShareLink
    struct CSVExport: Transferable {
        let csvText: String
        
        static var transferRepresentation: some TransferRepresentation {
            DataRepresentation(exportedContentType: .commaSeparatedText) { export in
                export.csvText.data(using: .utf8) ?? Data()
            }
            .suggestedFileName("RepMate_Workouts.csv")
        }
    }
}
