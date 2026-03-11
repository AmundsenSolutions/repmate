import SwiftUI

struct ActivityHeatmapView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeManager: StoreManager
    var days: Int
    @Binding var showPaywall: Bool
    
    private let calendar = Calendar.current
    private let columns = 52 // 52 weeks
    private let rows = 7 // 7 days
    
    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }
    
    // Yearly data for the grid (always shows full year context)
    private var workoutDates: Set<Date> {
        store.workoutManager.workoutDates(sessions: store.workoutSessions, year: currentYear)
    }
    
    // Dynamic count based on filter
    private var totalWorkouts: Int {
        store.workoutManager.getWorkoutCount(sessions: store.workoutSessions, days: days)
    }
    
    private var avgWorkouts: Double {
        store.workoutManager.avgWorkoutsPerWeek(sessions: store.workoutSessions, days: days)
    }
    
    private var longestStreak: Int {
        store.workoutManager.longestWorkoutStreak(sessions: store.workoutSessions, days: days)
    }
    
    private var perfectDays: Int {
        store.workoutManager.perfectDays(
            sessions: store.workoutSessions,
            proteinEntries: store.proteinEntries,
            target: store.settings.dailyProteinTarget,
            days: days
        )
    }
    
    // Header text helper
    private var periodText: String {
        if days == 365 { return "in \(currentYear)" }
        return "in last \(days) days"
    }
    
    var body: some View {
        GlassSection(title: "Activity & Habits") {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Spacer()
                    Text("\(totalWorkouts) workouts \(periodText)")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                // Highlight Cards
                HStack(spacing: 8) {
                    StatCard(title: "Avg / Week", value: String(format: "%.1f", avgWorkouts), icon: "calendar", color: Theme.Colors.accent)
                    StatCard(title: "Longest Streak", value: "\(longestStreak) days", icon: "flame.fill", color: .orange)
                     
                    if storeManager.isPro {
                        StatCard(title: "Perfect Days", value: "\(perfectDays)", icon: "star.fill", color: Theme.Colors.cyberGold)
                    } else {
                        Button(action: {
                            showPaywall = true
                            HapticManager.shared.lightImpact()
                        }) {
                            StatCard(title: "Perfect Days", value: "Pro", icon: "crown.fill", color: .yellow)
                        }
                    }
                }
                
                // Adaptive Content
                Group {
                    if days == 7 {
                        weeklyView
                    } else if days == 30 {
                        monthlyView
                    } else {
                        yearlyView
                    }
                }
                .padding(12)
                .background(Color(uiColor: .tertiarySystemFill))
                .cornerRadius(12)
                
                // Legend (only for grids)
                if days > 7 {
                    HStack(spacing: 8) {
                        Text("Less")
                            .font(.caption2)
                            .foregroundColor(.gray)
                        
                        ForEach([0.1, 0.3, 0.6, 1.0], id: \.self) { opacity in
                            Rectangle()
                                .fill(Theme.Colors.heatmapHigh.opacity(opacity))
                                .frame(width: 12, height: 12)
                                .cornerRadius(2)
                        }
                        
                        Text("More")
                            .font(.caption2)
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(Theme.Spacing.standard)
        }
    }
    
    // MARK: - Views
    
    // 7 Days: Horizontal Pills
    private var weeklyView: some View {
        HStack(spacing: 4) {
            ForEach(0..<7, id: \.self) { dayOffset in
                let date = calendar.date(byAdding: .day, value: -6 + dayOffset, to: Date()) ?? Date()
                let hasWorkout = workoutDates.contains(calendar.startOfDay(for: date))
                let isToday = calendar.isDateInToday(date)
                
                VStack(spacing: 4) {
                     RoundedRectangle(cornerRadius: 4)
                        .fill(hasWorkout ? Theme.Colors.accent : Color.white.opacity(0.1))
                        .frame(height: 32) // Taller pill
                        .overlay(
                            isToday ? Circle().fill(.white).frame(width: 4, height: 4) : nil
                        )
                    
                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
    
    // 30 Days: Full Width Grid (10 cols x 3 rows)
    private var monthlyView: some View {
        let columnsConfig = Array(repeating: GridItem(.flexible(), spacing: 6), count: 10)
        let daysToDisplay = 30
        
        return LazyVGrid(columns: columnsConfig, spacing: 6) {
            // Show last 30 days. We want them ordered naturally?
            // Usually heatmaps go left-right, top-down.
            // If we want "Last 30 days" typically we start from 29 days ago -> today.
            
            ForEach(0..<daysToDisplay, id: \.self) { offset in
                // offset 0 = 29 days ago. offset 29 = today.
                let dayAgo = daysToDisplay - 1 - offset
                let date = calendar.date(byAdding: .day, value: -dayAgo, to: Date())
                cellView(for: date)
                    .frame(height: 24) // Taller/Bigger cells
            }
        }
    }
    
    // 1 Year: Full Scrollable Grid
    private var yearlyView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: 3) {
                ForEach(0..<columns, id: \.self) { week in
                    VStack(spacing: 3) {
                        ForEach(0..<rows, id: \.self) { day in
                            let date = dateFor(week: week, day: day)
                            cellView(for: date)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
        .frame(height: CGFloat(rows * 12 + (rows - 1) * 3)) // Fixed height
    }
    
    private func cellView(for date: Date?) -> some View {
        let normalizedDate = date.map { calendar.startOfDay(for: $0) }
        let hasWorkout = normalizedDate.map { workoutDates.contains($0) } ?? false
        let isFuture = date.map { $0 > Date() } ?? false
        
        return Rectangle()
            .fill(cellColor(hasWorkout: hasWorkout, isFuture: isFuture))
            .cornerRadius(4)
            // Removed fixed frame to allow flexibility in Grid
    }
    
    // MARK: - Date Helpers
    
    private func dateFor(week: Int, day: Int) -> Date? {
        var components = DateComponents()
        components.year = currentYear
        components.weekOfYear = week + 1
        components.weekday = day + 1 // Sunday = 1
        return calendar.date(from: components)
    }
    
    private func dateForRecentGrid(weekOffset: Int, dayIndex: Int) -> Date? {
        // 5 weeks back.
        // weekOffset 0 = 4 weeks ago. weekOffset 4 = this week.
        // This is tricky to align perfectly with "Last 30 days".
        // Alternative: Just render last 30 days in a flat grid 7 cols x 5 rows.
        // Let's do 7 cols (weeks) x ? no.
        // Let's stick to the GitHub generic style: Columns are Weeks.
        // We show last 5 weeks.
        
        // Find date of "Start of 4 weeks ago" (Same weekday as today 4 weeks ago? No, start of week).
        let today = Date()
        let currentWeek = calendar.component(.weekOfYear, from: today)
        let targetWeek = currentWeek - 4 + weekOffset
        
        var components = DateComponents()
        components.year = currentYear
        components.weekOfYear = targetWeek
        components.weekday = dayIndex + 1
        
        return calendar.date(from: components)
    }
    
    private func cellColor(hasWorkout: Bool, isFuture: Bool) -> Color {
        if isFuture {
            return Color.gray.opacity(0.1)
        } else if hasWorkout {
            return Theme.Colors.accent // Use Theme Blue
        } else {
            return Color.gray.opacity(0.2)
        }
    }
}
