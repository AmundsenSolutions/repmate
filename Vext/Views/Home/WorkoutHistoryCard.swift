import SwiftUI

struct WorkoutHistoryCard: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    // Action closure for navigation to detail
    let onSelectSession: (WorkoutSession) -> Void
    let onDeleteSession: (IndexSet) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { // Compact spacing
            Text("Workout History")
                .sectionHeader()
            
            
            List {
                ForEach(store.sortedWorkoutSessions.prefix(5)) { session in
                    WorkoutHistoryRow(session: session)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSelectSession(session)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                if let mainIndex = store.workoutSessions.firstIndex(where: { $0.id == session.id }) {
                                    onDeleteSession(IndexSet(integer: mainIndex))
                                    HapticManager.shared.success()
                                }
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .frame(minHeight: CGFloat(min(store.sortedWorkoutSessions.count, 5) * 80))
        }
    }
}

struct WorkoutHistoryRow: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    let session: WorkoutSession
    
    // Static DateFormatters for performance
    private static let monthFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    var body: some View {
        HStack(spacing: 0) {
            // Date Box
            VStack(spacing: 2) {
                Text(Self.monthFormatter.string(from: session.date))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(themeManager.palette.accent.opacity(0.7))
                    .textCase(.uppercase)
                
                Text(Self.dayFormatter.string(from: session.date))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(width: 50, height: 50)
            .background(themeManager.palette.accent.opacity(0.15))
            .cornerRadius(8)
            .padding(.trailing, 16)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(store.workoutTemplates.first(where: { $0.id == session.templateId })?.name ?? "Workout")
                    .font(.headline)
                    .foregroundColor(.white)
                
                if let duration = formatDurationShort(session) {
                    Text(duration)
                        .font(.subheadline)
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(themeManager.palette.accent.opacity(0.5))
                .font(.caption)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(themeManager.palette.accent.opacity(0.15), lineWidth: 1)
        )
        .frame(minHeight: 1) // Prevent console errors
    }
    
    private func formatDurationShort(_ session: WorkoutSession) -> String? {
        guard let startedAt = session.startedAt,
              let endedAt = session.endedAt else {
            return nil
        }
        let durationInSeconds = endedAt.timeIntervalSince(startedAt)
        let durationInMinutes = max(1, Int(durationInSeconds / 60))
        return "\(durationInMinutes) min"
    }
}

struct ExerciseSummary: View {
    @EnvironmentObject var store: AppDataStore
    let sets: [SetLog]
    
    var body: some View {
        let exercises = formatExercisesCompact(sets)
        let maxDisplay = 2 // Compact mode
        
        VStack(alignment: .leading, spacing: 2) {
            ForEach(Array(exercises.prefix(maxDisplay).enumerated()), id: \.offset) { _, text in
                Text(text)
                    .font(.caption)
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
            
            if exercises.count > maxDisplay {
                Text("+\(exercises.count - maxDisplay) more")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
    
    private func formatExercisesCompact(_ sets: [SetLog]) -> [String] {
        var setsByExercise: [UUID: [SetLog]] = [:]
        for set in sets {
            setsByExercise[set.exerciseId, default: []].append(set)
        }
        
        var orderedIds: [UUID] = []
        var seen = Set<UUID>()
        for set in sets {
            if !seen.contains(set.exerciseId) {
                seen.insert(set.exerciseId)
                orderedIds.append(set.exerciseId)
            }
        }
        
        return orderedIds.compactMap { id in
            guard let name = store.exerciseLibrary.first(where: { $0.id == id })?.name else { return nil }
            let count = setsByExercise[id]?.count ?? 0
            return "\(count)x \(name)"
        }
    }
}
