import SwiftUI
import Charts

struct ProteinSummaryCard: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    
    // Animation state for the "Today" bar pulse
    @State private var todayPulse = false
    
    // Flame bounce animation
    @State private var flameBounce: CGFloat = 1.0
    @State private var previousGoalMet = false
    
    // Cached weekly data for performance
    @State private var cachedWeeklyData: [DayData] = []
    
    // Gold color for goal-met state
    private let goalGold = Color(hue: 0.12, saturation: 0.85, brightness: 0.95)
    
    private var streakCount: Int { store.proteinStreak() }
    private var goalMetToday: Bool {
        store.totalProteinFor(date: Date()) >= store.settings.dailyProteinTarget
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            // 1. Streak & Header
            HStack {
                HStack(spacing: 4) {
                    Text("🔥")
                        .scaleEffect(flameBounce)
                    Text("\(streakCount) day streak")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((goalMetToday ? goalGold : Theme.active.accent).opacity(0.2))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke((goalMetToday ? goalGold : Theme.active.accent).opacity(0.3), lineWidth: 1)
                )
                Spacer()
                
                Image(systemName: "chart.bar.fill")
                     .foregroundColor(Theme.active.accent.opacity(0.7))
                     .font(.caption)
            }
            
            Text("Today's Protein")
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(Theme.Colors.textSecondary)
            
            // 2. Large Glowing Protein Value
            proteinValueDisplay
            
            // 3. 7-Day Bar Chart
            weeklyBarChart
                .frame(height: 100)
            
            // 4. Day labels
            dayLabels
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 20)
        .glassCard(style: .primary)
        .onAppear {
            cachedWeeklyData = getWeeklyData()
            previousGoalMet = goalMetToday
        }
        .onChange(of: store.proteinEntries.count) { _, _ in
            cachedWeeklyData = getWeeklyData()
            checkGoalTransition()
        }
    }
    
    // MARK: - Flame Bounce
    
    private func checkGoalTransition() {
        let nowMet = goalMetToday
        if nowMet && !previousGoalMet {
            // Just crossed the goal — bounce the flame!
            withAnimation(.spring(response: 0.3, dampingFraction: 0.3, blendDuration: 0)) {
                flameBounce = 1.6
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.5)) {
                    flameBounce = 1.0
                }
            }
            HapticManager.shared.success()
        }
        previousGoalMet = nowMet
    }
    
    // MARK: - Protein Value Display
    
    private var proteinValueDisplay: some View {
        let today = Date()
        let total = store.totalProteinFor(date: today)
        
        return HStack(alignment: .firstTextBaseline, spacing: 2) {
            // Main number with heavy glow
            Text("\(total)")
                .font(.system(size: 64, weight: .regular, design: .rounded)) // Slightly lighter weight
                .foregroundColor(.white)
                .shadow(color: Theme.active.accent.opacity(0.8), radius: 10, x: 0, y: 0) // Direct text glow
            
            // Boxed 'g' unit (as seen in reference idea, or just glowing text)
            // Reference shows a boxy "0g". Let's style the 'g' distinctly.
            Text("g")
                .font(.system(size: 32, weight: .medium, design: .rounded))
                .foregroundColor(Theme.active.accent)
                .padding(.bottom, 4)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - Weekly Bar Chart
    
    private var weeklyBarChart: some View {
        let chartData = cachedWeeklyData.isEmpty ? getWeeklyData() : cachedWeeklyData
        let maxValue = max(chartData.map { $0.value }.max() ?? 100, Double(store.settings.dailyProteinTarget))
        
        return HStack(alignment: .bottom, spacing: 12) {
            ForEach(chartData) { day in
                VStack(spacing: 4) {
                    // Bar
                    chartBar(for: day, maxValue: maxValue)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }
    
    private func chartBar(for day: DayData, maxValue: Double) -> some View {
        let normalizedHeight = day.value > 0 ? max(day.value / maxValue, 0.05) : 0.05
        let minHeight: CGFloat = 8
        let maxHeight: CGFloat = 80
        let barHeight = minHeight + CGFloat(normalizedHeight) * (maxHeight - minHeight)
        
        // Color logic: gold if goal met, accent if today but not met, glow for past days
        let barColor: Color = day.metGoal
            ? goalGold
            : (day.isToday ? Theme.active.accent : Theme.active.glow)
        
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(
                LinearGradient(
                    colors: day.value > 0 
                        ? [barColor.opacity(0.3), barColor]
                        : [Color.gray.opacity(0.1), Color.gray.opacity(0.2)],
                    startPoint: .bottom,
                    endPoint: .top
                )
            )
            .frame(height: barHeight)
            .overlay(
                // Glow effect for today's bar
                Group {
                    if day.isToday {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(day.metGoal ? goalGold : Theme.active.accent)
                            .blur(radius: 6)
                            .opacity(todayPulse ? 0.6 : 0.3)
                    }
                }
            )
            .onAppear {
                if day.isToday {
                    withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                        todayPulse = true
                    }
                }
            }
            .onDisappear {
                todayPulse = false
            }
    }
    
    private var dayLabels: some View {
        let days = ["S", "M", "T", "W", "T", "F", "S"]
        let todayIndex = Calendar.current.component(.weekday, from: Date()) - 1 // 0 = Sunday
        
        return HStack(spacing: 12) {
            ForEach(0..<7, id: \.self) { index in
                Text(days[index])
                    .font(.system(size: 12, weight: index == todayIndex ? .bold : .regular))
                    .foregroundColor(index == todayIndex ? themeManager.palette.accent : .gray)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }
    
    // MARK: - Data Helpers
    
    private func getWeeklyData() -> [DayData] {
        let calendar = Calendar.current
        let today = Date()
        let todayWeekday = calendar.component(.weekday, from: today) - 1 // 0 = Sunday
        
        var data: [DayData] = []
        
        let target = store.settings.dailyProteinTarget
        
        for dayOffset in 0..<7 {
            // Calculate the date for this weekday
            let daysFromToday = dayOffset - todayWeekday
            guard let date = calendar.date(byAdding: .day, value: daysFromToday, to: today) else {
                continue
            }
            
            let total = store.totalProteinFor(date: date)
            let isToday = calendar.isDateInToday(date)
            
            data.append(DayData(
                id: dayOffset,
                dayIndex: dayOffset,
                value: Double(total),
                isToday: isToday,
                metGoal: total >= target
            ))
        }
        
        return data
    }
}

// MARK: - Day Data Model

private struct DayData: Identifiable {
    let id: Int
    let dayIndex: Int
    let value: Double
    let isToday: Bool
    let metGoal: Bool
}

// MARK: - Ghost Chart (for empty/Day 0 state)

struct GhostChart: View {
    @EnvironmentObject var themeManager: ThemeManager // Fix: Inject ThemeManager
    @State private var isBlinking = false
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 12) {
            // 6 Ghost Bars (Past days)
            ForEach(0..<6, id: \.self) { index in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.05), Color.gray.opacity(0.15)],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: CGFloat.random(in: 20...50))
            }
            
            // "Today" Bar (Blinking)
            RoundedRectangle(cornerRadius: 4)
                .fill(
                    LinearGradient(
                        colors: [themeManager.palette.accent.opacity(0.2), themeManager.palette.accent.opacity(0.5)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 30)
                .opacity(isBlinking ? 0.4 : 1.0)
                .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isBlinking)
                .onAppear {
                    isBlinking = true
                }
        }
    }
}

// MARK: - Quick Add Button (Extracted Sub-Component)

struct QuickAddButton: View {
    @EnvironmentObject var store: AppDataStore
    let note: String?
    let grams: Int
    let isFavorite: Bool
    
    var displayName: String {
        guard let n = note, !n.isEmpty else { return "Protein" }
        return n
    }
    
    var body: some View {
        Button {
            store.addProteinEntry(grams: grams, note: note)
            HapticManager.shared.lightImpact()
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(displayName)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                    if isFavorite {
                        Image(systemName: "star.fill")
                            .font(.system(size: 8))
                            .foregroundColor(.yellow)
                    }
                }
                Text("\(grams)g")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .pillButton()
        }
        .contextMenu {
            if isFavorite {
                Button(role: .destructive) {
                    let entry = ProteinEntry(grams: grams, note: note)
                    store.toggleFavorite(entry: entry)
                    HapticManager.shared.success()
                } label: {
                    Label("Remove from Favorites", systemImage: "star.slash")
                }
            } else {
                Button {
                    let entry = ProteinEntry(grams: grams, note: note)
                    store.toggleFavorite(entry: entry)
                    HapticManager.shared.success()
                } label: {
                    Label("Add to Favorites", systemImage: "star")
                }
                Button(role: .destructive) {
                    if let entryToDelete = store.proteinEntries.first(where: { $0.grams == grams && $0.note == note }) {
                        store.deleteProteinEntry(withID: entryToDelete.id)
                        HapticManager.shared.success()
                    }
                } label: {
                    Label("Remove Entry", systemImage: "trash")
                }
                .foregroundColor(.red)
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        ProteinSummaryCard()
            .environmentObject(AppDataStore())
            .environmentObject(ThemeManager.shared)
            .padding()
    }
}
