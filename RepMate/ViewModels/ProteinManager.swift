import Foundation

/// Core logic for protein tracking and statistics.
class ProteinManager {
    
    // MARK: - Core Logic
    
    func proteinStreak(entries: [ProteinEntry], target: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var streak = 0
        var currentDate = today
        
        // Check today first
        let todayTotal = totalProtein(for: currentDate, in: entries)
        if todayTotal >= target {
            streak += 1
        }
        
        // Always check yesterday to see if the past streak is maintained
        if let previousDay = calendar.date(byAdding: .day, value: -1, to: currentDate) {
            currentDate = calendar.startOfDay(for: previousDay)
            
            while true {
                let total = totalProtein(for: currentDate, in: entries)
                if total >= target {
                    streak += 1
                    guard let nextPrev = calendar.date(byAdding: .day, value: -1, to: currentDate) else { break }
                    currentDate = calendar.startOfDay(for: nextPrev)
                } else {
                    break
                }
            }
        }
        
        return streak
    }
    
    func totalProtein(for date: Date, in entries: [ProteinEntry]) -> Int {
        entriesFor(date: date, in: entries).reduce(0) { $0 + $1.grams }
    }
    
    func entriesFor(date: Date, in entries: [ProteinEntry]) -> [ProteinEntry] {
        let calendar = Calendar.current
        return entries.filter { calendar.isDate($0.date, inSameDayAs: date) }
    }
    
    func getRecentUniqueEntries(from entries: [ProteinEntry]) -> [ProteinEntry] {
        var seen = Set<String>()
        var uniqueEntries: [ProteinEntry] = []
        
        for entry in entries.reversed() {
            let key = "\(entry.grams)-\(entry.note ?? "")"
            if !seen.contains(key) {
                seen.insert(key)
                uniqueEntries.append(entry)
                if uniqueEntries.count >= 5 { break }
            }
        }
        
        return uniqueEntries
    }

    func resolveIdsToDelete(at offsets: IndexSet, in filteredEntries: [ProteinEntry]) -> [UUID] {
        offsets.compactMap { index in
            guard index >= 0 && index < filteredEntries.count else { return nil }
            return filteredEntries[index].id
        }
    }
    
    // MARK: - Stats Methods
    
    /// Precomputes daily protein totals.
    private func precomputeDailyTotals(from entries: [ProteinEntry], since startDate: Date) -> [Date: Int] {
        let calendar = Calendar.current
        var totals: [Date: Int] = [:]
        for entry in entries where entry.date >= startDate {
            let day = calendar.startOfDay(for: entry.date)
            totals[day, default: 0] += entry.grams
        }
        return totals
    }
    
    /// Calculates daily average protein.
    func dailyAverage(entries: [ProteinEntry], days: Int) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        let filteredEntries = entries.filter { $0.date >= startDate }
        let totalGrams = filteredEntries.reduce(0) { $0 + $1.grams }
        
        return days > 0 ? Double(totalGrams) / Double(days) : 0
    }
    
    /// Calculates target success rate.
    func targetSuccessRate(entries: [ProteinEntry], target: Int, days: Int) -> Double {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        let dailyTotalsMap = precomputeDailyTotals(from: entries, since: startDate)
        var successDays = 0
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let total = dailyTotalsMap[date] ?? 0
            if total >= target {
                successDays += 1
            }
        }
        
        return days > 0 ? (Double(successDays) / Double(days)) * 100 : 0
    }
    
    /// Finds most frequent protein source.
    func mostConsumedNote(entries: [ProteinEntry], days: Int) -> String? {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return nil }
        
        let filteredEntries = entries.filter { $0.date >= startDate && $0.note != nil && !$0.note!.isEmpty }
        
        var noteCounts: [String: Int] = [:]
        for entry in filteredEntries {
            if let note = entry.note {
                noteCounts[note, default: 0] += 1
            }
        }
        
        return noteCounts.max(by: { $0.value < $1.value })?.key
    }
    
    /// Gets daily totals for charting.
    func dailyTotals(entries: [ProteinEntry], days: Int) -> [(date: Date, grams: Int)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
        
        let dailyTotalsMap = precomputeDailyTotals(from: entries, since: startDate)
        var result: [(date: Date, grams: Int)] = []
        
        for dayOffset in (0..<days).reversed() {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let total = dailyTotalsMap[date] ?? 0
            result.append((date: date, grams: total))
        }
        
        return result
    }
    
    /// Compares training vs. rest day protein.
    func trainingVsRestDayProtein(entries: [ProteinEntry], sessions: [WorkoutSession], days: Int) -> (trainingAvg: Double, restAvg: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return (0, 0) }
        
        let dailyTotalsMap = precomputeDailyTotals(from: entries, since: startDate)
        let workoutDates = Set(sessions.filter { $0.date >= startDate }.map { calendar.startOfDay(for: $0.date) })
        
        var trainingDaysCount = 0
        var restDaysCount = 0
        var trainingProtein = 0
        var restProtein = 0
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let total = dailyTotalsMap[date] ?? 0
            
            if workoutDates.contains(date) {
                trainingDaysCount += 1
                trainingProtein += total
            } else {
                restDaysCount += 1
                restProtein += total
            }
        }
        
        let trainingAvg = trainingDaysCount > 0 ? Double(trainingProtein) / Double(trainingDaysCount) : 0
        let restAvg = restDaysCount > 0 ? Double(restProtein) / Double(restDaysCount) : 0
        
        return (trainingAvg, restAvg)
    }
}

