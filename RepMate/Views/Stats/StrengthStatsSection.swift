import SwiftUI
import Charts

struct StrengthStatsSection: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var weightStore: WeightStore // For Correlation Engine
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    @EnvironmentObject var storeManager: StoreManager
    let days: Int
    @Binding var showPaywall: Bool
    
    @State private var selectedExerciseId: UUID? // nil = General Volume / All Exercises
    @State private var showingExercisePicker = false
    
    private var isGeneralVolume: Bool {
        selectedExerciseId == nil
    }
    

    
    private var selectedExercise: Exercise? {
        guard let id = selectedExerciseId else { return nil }
        return store.exerciseLibrary.first(where: { $0.id == id })
    }
    
    private var strengthProgression: [(date: Date, value: Double)] {
        if let id = selectedExerciseId {
            return store.workoutManager.prProgression(sessions: store.workoutSessions, exerciseId: id, days: days)
                .map { (date: $0.date, value: $0.est1RM) }
        } else {
            return store.workoutManager.totalVolumeProgression(sessions: store.workoutSessions, days: days)
                .map { (date: $0.date, value: $0.volume) }
        }
    }
    
    private var weightTrend: [WeightStore.TrendPoint] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: today) else { return weightStore.trendLine() }
        return weightStore.trendLine().filter { $0.date >= cutoff }
    }
    
    private var topLift: Double {
        if let id = selectedExerciseId {
            let records = store.workoutManager.maxWeightProgression(sessions: store.workoutSessions, exerciseId: id, days: days)
            return records.map { $0.maxWeight }.max() ?? 0
        } else {
            return 0
        }
    }
    
    private var newPRsCount: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        if let id = selectedExerciseId {
            let allPRs = store.workoutManager.personalRecords(sessions: store.workoutSessions, exerciseId: id)
            return allPRs.filter { $0.date >= startDate }.count
        } else {
            // Count total PRs across all exercises in the period
            var total = 0
            for ex in store.exerciseLibrary {
                let prs = store.workoutManager.personalRecords(sessions: store.workoutSessions, exerciseId: ex.id)
                total += prs.filter { $0.date >= startDate }.count
            }
            return total
        }
    }
    
    private var totalVolume: Double {
        if let id = selectedExerciseId {
            let progression = store.workoutManager.volumeProgression(sessions: store.workoutSessions, exerciseId: id, days: days)
            return progression.reduce(0) { $0 + $1.volume }
        } else {
            return store.workoutManager.calculateTotalVolume(sessions: store.workoutSessions, days: days)
        }
    }
    
    private var totalVolumeFormatted: String {
        if totalVolume >= 1000 {
            return String(format: "%.1fk kg", totalVolume / 1000)
        } else {
            return String(format: "%.0f kg", totalVolume)
        }
    }
    
    var body: some View {
        GlassSection(title: isGeneralVolume ? "General Progress" : "Strength & PR") {
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
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Mode")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                Text("All Exercises / General Volume")
                                    .font(.headline)
                                    .foregroundColor(themeManager.palette.accent)
                            }
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
                    if !isGeneralVolume {
                        StatCard(
                            title: "Top Lift (\(days)d)",
                            value: topLift > 0 ? String(format: "%.1f kg", topLift) : "—",
                            icon: "arrow.up.right.circle.fill",
                            color: themeManager.palette.accent
                        )
                    } else {
                        StatCard(
                            title: "Total Workouts",
                            value: "\(store.workoutManager.getWorkoutCount(sessions: store.workoutSessions, days: days))",
                            icon: "figure.strengthtraining.traditional",
                            color: themeManager.palette.accent
                        )
                    }
                    
                    StatCard(
                        title: isGeneralVolume ? "Total PRs" : "New PRs",
                        value: "\(newPRsCount)",
                        icon: "medal.fill",
                        color: .yellow
                    )
                    
                    StatCard(
                        title: "Total Volume",
                        value: totalVolume > 0 ? totalVolumeFormatted : "—",
                        icon: "scalemass.fill",
                        color: Theme.Colors.cyberGold
                    )
                }
                
                // Chart — mode-specific rendering
                if storeManager.isPro {
                    if !strengthProgression.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            if isGeneralVolume {
                                buildVolumeChart(volumeData: strengthProgression)
                            } else {
                                buildStrengthChart(strengthData: strengthProgression, weightData: weightTrend)
                                // Legend only in 1RM mode (bodyweight overlay)
                                chartLegend
                            }
                        }
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
                VStack(spacing: 0) {
                    // Quick Action for General Volume
                    Button {
                        selectedExerciseId = nil
                        showingExercisePicker = false
                        HapticManager.shared.selection()
                    } label: {
                        HStack {
                            Image(systemName: "chart.bar.fill")
                                .foregroundColor(themeManager.palette.accent)
                            Text("All Exercises / General Volume")
                                .fontWeight(.semibold)
                            Spacer()
                            if isGeneralVolume {
                                Image(systemName: "checkmark")
                                    .foregroundColor(themeManager.palette.accent)
                            }
                        }
                        .padding()
                        .background(Theme.Colors.cardBackground.opacity(0.5))
                        .cornerRadius(12)
                        .padding()
                    }
                    
                    ExerciseLibraryView(onSelect: { exercise in
                        selectedExerciseId = exercise.id
                        showingExercisePicker = false
                    }, isForStats: true)
                }
                .navigationTitle("Select Exercise")
                .navigationBarTitleDisplayMode(.inline)
            }
        }
        .onAppear {
            if selectedExerciseId == nil {
                loadMostFrequentExerciseId()
            }
        }
        .onChange(of: days) { _, _ in
            // When user changes the filter (7d, 30d, 1y), we keep the currently selected exercise.
            // But if they haven't manually selected one, we could optionally recalculate the top one.
        }
    }
    
    // MARK: - Logic
    
    private func loadMostFrequentExerciseId() {
        let sessions = store.workoutSessions
        let library = store.exerciseLibrary
        let currentDate = store.currentDate
        let currentDays = days
        
        Task.detached {
            let calendar = Calendar.current
            let startDate = calendar.date(byAdding: .day, value: -currentDays, to: currentDate) ?? Date.distantPast
            
            var counts: [UUID: Int] = [:]
            var allTimeCounts: [UUID: Int] = [:]
            
            for session in sessions {
                let uniqueExercises = Set(session.sets.map { $0.exerciseId })
                if (session.endedAt ?? session.date) > startDate {
                    for exerciseId in uniqueExercises {
                        counts[exerciseId, default: 0] += 1
                    }
                }
                for exerciseId in uniqueExercises {
                    allTimeCounts[exerciseId, default: 0] += 1
                }
            }
            
            let id = counts.max(by: { $0.value < $1.value })?.key 
                     ?? allTimeCounts.max(by: { $0.value < $1.value })?.key 
                     ?? library.first?.id
            
            await MainActor.run {
                self.selectedExerciseId = id
            }
        }
    }
    
    // MARK: - Subviews
    

    
    // MARK: - Strength Chart (1RM Mode) — B2, D2
    
    @ViewBuilder
    private func buildStrengthChart(
        strengthData: [(Date, Double)],
        weightData: [WeightStore.TrendPoint]
    ) -> some View {
        let sortedStrength = strengthData.sorted { $0.0 < $1.0 }
        let sortedWeight = weightData.sorted { $0.date < $1.date }
        let strengthMin = sortedStrength.map(\.1).min() ?? 0
        let yFloor = max(0, strengthMin - 5)
        
        VStack(alignment: .leading, spacing: 8) {
            Text("Strength Progression (Est. 1RM)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                // D2: 1RM data — linear interpolation + PointMark
                ForEach(sortedStrength, id: \.0) { item in
                    LineMark(
                        x: .value("Date", item.0, unit: .day),
                        y: .value("Est. 1RM", item.1),
                        series: .value("Series", "Est. 1RM")
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(themeManager.palette.accent)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    
                    PointMark(
                        x: .value("Date", item.0, unit: .day),
                        y: .value("Est. 1RM", item.1)
                    )
                    .symbol(Circle())
                    .symbolSize(30)
                    .foregroundStyle(themeManager.palette.accent)
                    
                    // B2: AreaMark with dynamic floor
                    AreaMark(
                        x: .value("Date", item.0, unit: .day),
                        yStart: .value("Min", yFloor),
                        yEnd: .value("Est. 1RM", item.1)
                    )
                    .interpolationMethod(.linear)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [themeManager.palette.accent.opacity(0.2), .clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }
                
                // B3: Bodyweight overlay — only in 1RM mode where scales are compatible
                ForEach(sortedWeight) { point in
                    LineMark(
                        x: .value("Date", point.date, unit: .day),
                        y: .value("Bodyweight", point.value),
                        series: .value("Series", "Bodyweight")
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Theme.Colors.prGold)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5, 5]))
                }
            }
            .chartYScale(domain: .automatic(includesZero: false))
            .chartYAxis {
                AxisMarks(position: .leading) { _ in
                    AxisGridLine().foregroundStyle(Color.gray.opacity(0.15))
                    AxisValueLabel().foregroundStyle(Color.gray)
                }
                AxisMarks(position: .trailing, values: .automatic) { _ in
                    AxisValueLabel().foregroundStyle(Theme.Colors.prGold.opacity(0.8))
                }
            }
            .chartXAxis {
                AxisMarks(values: .automatic) { _ in
                    AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(Color.gray)
                }
            }
            .frame(height: 200)
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.compact)
        }
    }
    
    // MARK: - Volume Chart (General Volume Mode) — D2, B3
    
    @ViewBuilder
    private func buildVolumeChart(
        volumeData: [(Date, Double)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Total Volume per Session (kg)")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                // D2: BarMark for volume — rest days are naturally empty
                ForEach(volumeData, id: \.0) { item in
                    BarMark(
                        x: .value("Date", item.0, unit: .day),
                        y: .value("Volume", item.1)
                    )
                    .foregroundStyle(
                        themeManager.palette.accent.gradient
                    )
                    .cornerRadius(4)
                }
            }
            .chartYScale(domain: .automatic(includesZero: true))
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
            .frame(height: 200)
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.compact)
        }
    }
    
    // MARK: - Chart Legend (1RM mode only)
    
    private var chartLegend: some View {
        HStack(spacing: 16) {
            HStack(spacing: 4) {
                Circle().fill(themeManager.palette.accent).frame(width: 8, height: 8)
                Text("Est. 1RM")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            HStack(spacing: 4) {
                Capsule()
                    .stroke(Theme.Colors.prGold, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
                    .frame(width: 12, height: 4)
                Text("Bodyweight Trend (SMA)")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 4)
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
                BarMark(x: .value("D", "Man"), y: .value("V", 100))
                BarMark(x: .value("D", "Tir"), y: .value("V", 150))
                BarMark(x: .value("D", "Ons"), y: .value("V", 120))
                BarMark(x: .value("D", "Tor"), y: .value("V", 200))
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
    @FocusState private var focusedField: CalcField?
    
    private enum CalcField {
        case weight, reps
    }
    
    private var estimated1RM: Double? {
        guard let w = weight.parseDoubleFlexible(),
              let r = reps.parseIntFlexible(), r > 0 else { return nil }
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
                            .focused($focusedField, equals: .weight)
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
                            .focused($focusedField, equals: .reps)
                            .padding(10)
                            .background(Theme.Colors.cardBackground)
                            .cornerRadius(Theme.Spacing.tight)
                            .foregroundColor(.white)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Est. 1RM")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Text(estimated1RM.map { String(format: "%.1f kg", $0) } ?? "—")
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
