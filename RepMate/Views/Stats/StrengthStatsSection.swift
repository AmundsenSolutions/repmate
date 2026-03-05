import SwiftUI
import Charts

struct StrengthStatsSection: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    @EnvironmentObject var storeManager: StoreManager
    let days: Int
    @Binding var showPaywall: Bool
    
    @State private var selectedExerciseId: UUID?
    @State private var showingExercisePicker = false
    

    
    private var selectedExercise: Exercise? {
        guard let id = selectedExerciseId else { return nil }
        return store.exerciseLibrary.first(where: { $0.id == id })
    }
    
    private var currentPR: WorkoutManager.PersonalRecord? {
        guard let id = selectedExerciseId else { return nil }
        return store.workoutManager.currentPR(sessions: store.workoutSessions, exerciseId: id)
    }
    
    private var prProgression: [(date: Date, est1RM: Double)] {
        guard let id = selectedExerciseId else { return [] }
        return store.workoutManager.prProgression(sessions: store.workoutSessions, exerciseId: id, days: days)
    }
    
    private var topLift: Double {
        let records = store.workoutManager.maxWeightProgression(sessions: store.workoutSessions, exerciseId: selectedExerciseId ?? UUID(), days: days)
        return records.map { $0.maxWeight }.max() ?? 0
    }
    
    private var newPRsCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        let allPRs = store.workoutManager.personalRecords(sessions: store.workoutSessions, exerciseId: selectedExerciseId ?? UUID())
        return allPRs.filter { $0.date >= startDate }.count
    }
    
    private var consistencyScore: Int {
        store.workoutManager.consistencyScore(sessions: store.workoutSessions, days: days)
    }
    
    var body: some View {
        GlassSection(title: "Strength & PR") {
            VStack(alignment: .leading, spacing: 16) {
                // Exercise Selector
                Button {
                    showingExercisePicker = true
                } label: {
                    HStack {
                        if let exercise = selectedExercise {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Exercise")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(.white)
                            }
                        } else {
                            Text("Select Exercise")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.gray)
                    }
                    .padding()
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.Spacing.compact)
                }
                
                // PR Card Row
                HStack(spacing: 8) {
                    StatCard(
                        title: "Top Lift (\(days)d)",
                        value: topLift > 0 ? String(format: "%.1f kg", topLift) : "—",
                        icon: "arrow.up.right.circle.fill",
                        color: themeManager.palette.accent
                    )
                    
                    StatCard(
                        title: "New PRs",
                        value: "\(newPRsCount)",
                        icon: "medal.fill",
                        color: .yellow
                    )
                    
                    if storeManager.isPro {
                        StatCard(
                            title: "Consistency",
                            value: "\(consistencyScore)",
                            icon: "target",
                            color: Theme.Colors.cyberGold
                        )
                    } else {
                        Button(action: {
                            showPaywall = true
                            HapticManager.shared.lightImpact()
                        }) {
                            StatCard(title: "Consistency", value: "Locked", icon: "lock.fill", color: .gray.opacity(0.5))
                        }
                    }
                }
                
                // 1RM Trend Chart
                if storeManager.isPro {
                    if !prProgression.isEmpty {
                        buildLineChart(title: "Est. 1RM Trend (kg)", data: prProgression.map { ($0.date, $0.est1RM) }, yLabel: "Est. 1RM")
                    } else {
                        emptyChartState
                    }
                } else {
                    ProLockedOverlay(isPro: false, paywallAction: { showPaywall = true }) {
                        blurredChartPreview
                    }
                }
            }
            .padding(Theme.Spacing.standard)
        }
        .sheet(isPresented: $showingExercisePicker) {
            NavigationStack {
                ExerciseLibraryView(onSelect: { exercise in
                    selectedExerciseId = exercise.id
                }, isForStats: true)
            }
        }
        .onAppear {
            if selectedExerciseId == nil {
                selectedExerciseId = getMostFrequentExerciseId()
            }
        }
        .onChange(of: days) { _, _ in
            // When user changes the filter (7d, 30d, 1y), we keep the currently selected exercise.
            // But if they haven't manually selected one, we could optionally recalculate the top one.
        }
    }
    
    // MARK: - Logic
    
    private func getMostFrequentExerciseId() -> UUID? {
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -days, to: store.currentDate) ?? Date.distantPast
        
        // Count frequencies of exercises in the active timeframe
        var counts: [UUID: Int] = [:]
        
        for session in store.workoutSessions where (session.endedAt ?? session.date) > startDate {
            let uniqueExercises = Set(session.sets.map { $0.exerciseId })
            for exerciseId in uniqueExercises {
                counts[exerciseId, default: 0] += 1
            }
        }
        
        // Find the one with the highest count
        if let topExerciseId = counts.max(by: { $0.value < $1.value })?.key {
            return topExerciseId
        }
        
        // Fallback to absolute most frequent of all time if nothing in timeframe
        var allTimeCounts: [UUID: Int] = [:]
        for session in store.workoutSessions {
            let uniqueExercises = Set(session.sets.map { $0.exerciseId })
            for exerciseId in uniqueExercises {
                allTimeCounts[exerciseId, default: 0] += 1
            }
        }
        
        if let topAllTimeId = allTimeCounts.max(by: { $0.value < $1.value })?.key {
            return topAllTimeId
        }
        
        // Absolute fallback to first in library
        return store.exerciseLibrary.first?.id
    }
    
    // MARK: - Subviews
    

    
    @ViewBuilder
    private func buildLineChart(title: String, data: [(Date, Double)], yLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart(data, id: \.0) { item in
                LineMark(
                    x: .value("Date", item.0, unit: .day),
                    y: .value(yLabel, item.1)
                )
                .symbol(Circle())
                .symbolSize(30)
                .interpolationMethod(.catmullRom)
                .foregroundStyle(themeManager.palette.accent)
                .lineStyle(StrokeStyle(lineWidth: 2))
                
                AreaMark(
                    x: .value("Date", item.0, unit: .day),
                    yStart: .value("Min", 0),
                    yEnd: .value(yLabel, item.1)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.palette.accent.opacity(0.3), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.15))
                    AxisValueLabel().foregroundStyle(Color.gray)
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(Color.gray)
                }
            }
            .frame(height: 180)
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.compact)
        }
    }
    

    
    private var emptyChartState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.downtrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.3))
            Text("No data for selected period")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 180)
        .background(Theme.Colors.cardBackground.opacity(0.5))
        .cornerRadius(Theme.Spacing.compact)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.gray.opacity(0.2), lineWidth: 1))
    }
    
    private var blurredChartPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Pro Insight")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                BarMark(x: .value("D", "Mon"), y: .value("V", 100))
                BarMark(x: .value("D", "Tue"), y: .value("V", 150))
                BarMark(x: .value("D", "Wed"), y: .value("V", 120))
                BarMark(x: .value("D", "Thu"), y: .value("V", 200))
            }
            .foregroundStyle(themeManager.palette.accent.opacity(0.5))
            .frame(height: 180)
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.compact)
        }
    }
}

// MARK: - 1RM Calculator Card
struct OneRMCalculatorCard: View {
    @EnvironmentObject var store: AppDataStore
    @State private var weight: String = ""
    @State private var reps: String = ""
    
    private var estimated1RM: Double? {
        guard let w = Double(weight.replacingOccurrences(of: ",", with: ".")),
              let r = Int(reps), r > 0 else { return nil }
        return store.workoutManager.calculate1RM(weight: w, reps: r)
    }
    
    var body: some View {
        GlassSection(title: "1RM Calculator") {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weight")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("kg", text: $weight)
                            .keyboardType(.decimalPad)
                            .padding(10)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.Spacing.tight)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Reps")
                            .font(.caption)
                            .foregroundColor(.gray)
                        TextField("reps", text: $reps)
                            .keyboardType(.numberPad)
                            .padding(10)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.Spacing.tight)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Est. 1RM")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(estimated1RM != nil ? String(format: "%.1f kg", estimated1RM!) : "—")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundColor(Theme.Colors.cyberGold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(10)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.Spacing.tight)
                    }
                }
            }
            .padding(Theme.Spacing.standard)
        }
    }
}
