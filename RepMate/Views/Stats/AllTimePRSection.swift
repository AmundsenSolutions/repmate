import SwiftUI

struct AllTimePRSection: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var isShowingAll = false
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()
    
    struct PRDisplay: Identifiable {
        let id = UUID()
        let exerciseName: String
        let weight: Double
        let reps: Int
        let est1RM: Double
        let date: Date
    }
    
    private var allTimeResults: [PRDisplay] {
        let sessions = store.workoutSessions
        let library = store.exerciseLibrary
        
        var bestRecords: [UUID: WorkoutManager.PersonalRecord] = [:]
        
        for exercise in library {
            if let pr = store.workoutManager.currentPR(sessions: sessions, exerciseId: exercise.id) {
                bestRecords[exercise.id] = pr
            }
        }
        
        // Sorter på dato (nyeste PR øverst) som er mer motiverende
        let sortedIds = bestRecords.keys.sorted { id1, id2 in
            (bestRecords[id1]?.date ?? .distantPast) > (bestRecords[id2]?.date ?? .distantPast)
        }
        
        return sortedIds.compactMap { id -> PRDisplay? in
            guard let pr = bestRecords[id],
                  let name = library.first(where: { $0.id == id })?.name else { return nil }
            return PRDisplay(
                exerciseName: name,
                weight: pr.weight,
                reps: pr.reps,
                est1RM: pr.estimated1RM,
                date: pr.date
            )
        }
    }

    private var allTimeBestLifts: [PRDisplay] {
        if isShowingAll {
            return allTimeResults
        } else {
            return Array(allTimeResults.prefix(3))
        }
    }
    
    var body: some View {
        GlassSection(title: "All-Time Best Lifts") {
            VStack(spacing: 12) {
                if allTimeResults.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "medal.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No records yet")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 30)
                    .background(Theme.Colors.cardBackground.opacity(0.5))
                    .cornerRadius(Theme.Spacing.standard)
                } else {
                    VStack(spacing: 12) {
                        ForEach(allTimeBestLifts) { pr in
                            HStack(spacing: 16) {
                                // Icon/Badge
                                ZStack {
                                    Circle()
                                        .fill(themeManager.palette.accent.opacity(0.1))
                                        .frame(width: 44, height: 44)
                                    
                                    Image(systemName: "medal")
                                        .foregroundColor(Theme.Colors.prGold)
                                        .font(.system(size: 20, weight: .bold))
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(pr.exerciseName)
                                        .font(.system(size: 16, weight: .bold))
                                        .foregroundColor(.white)
                                    
                                    Text("\(Self.dateFormatter.string(from: pr.date))")
                                        .font(.caption2)
                                        .foregroundColor(.gray)
                                }
                                
                                Spacer()
                                
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text(String(format: "%.1f kg", pr.weight))
                                        .font(.system(size: 16, weight: .black, design: .rounded))
                                        .foregroundColor(themeManager.palette.accent)
                                    
                                    Text("\(pr.reps) reps")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                // Est 1RM Badge
                                VStack(alignment: .center, spacing: 0) {
                                    Text("1RM")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundColor(.black)
                                    Text(String(format: "%.0f", pr.est1RM))
                                        .font(.system(size: 12, weight: .heavy))
                                        .foregroundColor(.black)
                                }
                                .frame(width: 32, height: 32)
                                .background(Theme.Colors.cyberGold)
                                .clipShape(Circle())
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.Spacing.standard)
                        }
                        
                        // Show More / Show Less Button
                        let totalCount = allTimeResults.count
                        if totalCount > 3 {
                            Button {
                                withAnimation(.spring()) {
                                    isShowingAll.toggle()
                                }
                                HapticManager.shared.lightImpact()
                            } label: {
                                Text(isShowingAll ? "Show Less" : "Show All (\(totalCount))")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(themeManager.palette.accent)
                                    .padding(.vertical, 8)
                                    .frame(maxWidth: .infinity)
                                    .background(Theme.Colors.cardBackground.opacity(0.5))
                                    .cornerRadius(Theme.Spacing.compact)
                            }
                        }
                    }
                }
            }
            .padding(Theme.Spacing.standard)
        }
    }
}
