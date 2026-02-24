import SwiftUI

struct SmartInsightsRow: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    let days: Int
    
    // Auto-generate some fun facts based on data
    private var insights: [InsightCardData] {
        var results: [InsightCardData] = []
        
        let validSessions = store.workoutSessions.filter { 
            if let date = Calendar.current.date(byAdding: .day, value: -days, to: Date()) {
                return $0.date >= date
            }
            return false
        }
        
        guard !validSessions.isEmpty else {
            return [InsightCardData(title: "Not Enough Data", text: "Log more workouts to see insights.", icon: "chart.bar.doc.horizontal", color: .gray)]
        }
        
        // 1. Favorite Day of Week
        let calendar = Calendar.current
        var dayCounts: [Int: Int] = [:]
        for session in validSessions {
            let weekday = calendar.component(.weekday, from: session.date)
            dayCounts[weekday, default: 0] += 1
        }
        if let bestDay = dayCounts.max(by: { $0.value < $1.value })?.key {
            let dayName = calendar.weekdaySymbols[bestDay - 1]
            results.append(InsightCardData(title: "Favorite Day", text: "You train mostly on \(dayName)s.", icon: "calendar.badge.clock", color: themeManager.palette.accent))
        }
        
        // 2. Consistency vs Target
        let avgWorkouts = store.workoutManager.avgWorkoutsPerWeek(sessions: validSessions, days: days)
        if avgWorkouts >= 3 {
            results.append(InsightCardData(title: "Beast Mode", text: "Averaging \(String(format: "%.1f", avgWorkouts)) workouts/week.", icon: "flame.fill", color: .orange))
        } else {
            results.append(InsightCardData(title: "Room to Grow", text: "Averaging \(String(format: "%.1f", avgWorkouts)) workouts/week.", icon: "chart.line.uptrend.xyaxis", color: .blue))
        }
        
        // 3. Nutrition Adherence
        let adherence = store.proteinManager.targetSuccessRate(entries: store.proteinEntries, target: store.settings.dailyProteinTarget, days: days)
        if adherence >= 80 {
            results.append(InsightCardData(title: "Protein King", text: "You hit your goal \(String(format: "%.0f%%", adherence)) of the time.", icon: "crown.fill", color: Theme.Colors.cyberGold))
        } else if adherence >= 50 {
            results.append(InsightCardData(title: "Solid Fuel", text: "You hit your goal \(String(format: "%.0f%%", adherence)) of the time.", icon: "fork.knife", color: .green))
        }
        
        return results
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SMART INSIGHTS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
                .padding(.horizontal)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(insights, id: \.title) { insight in
                        InsightCard(data: insight)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

struct InsightCardData {
    let title: String
    let text: String
    let icon: String
    let color: Color
}

struct InsightCard: View {
    let data: InsightCardData
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: data.icon)
                    .font(.caption)
                    .foregroundColor(data.color)
                
                Text(data.title)
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            Text(data.text)
                .font(.caption2)
                .foregroundColor(.gray)
                .fixedSize(horizontal: false, vertical: true)
                .lineLimit(2)
        }
        .padding(12)
        .frame(width: 160, height: 80, alignment: .topLeading)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Spacing.compact)
    }
}
