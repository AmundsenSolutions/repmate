//
//  WorkoutManager.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 2026.
//

import Foundation

struct WorkoutManager {
    
    // Hardcoded minimums for fallbacks if needed, but we now prefer Exercise-specific SetupTime
    static let kWalkTime: Int = 30
    static let kRiggingTime: Int = 30
    static var kTransitionTime: Int { kWalkTime + kRiggingTime }
    
    // MARK: - Duration Estimation
    
    /// Core per-exercise time contribution.
    private func exerciseSeconds(
        setupTime: SetupTime,
        setCount: Int,
        userRestTime: Int,
        isFirst: Bool,
        isLast: Bool
    ) -> Int {
        var seconds = 0
        if !isFirst { seconds += setupTime.transitionSeconds }
        seconds += setupTime.warmupSetSeconds + setupTime.warmupRestSeconds
        for setIndex in 0..<setCount {
            seconds += setupTime.setDurationSeconds
            let isLastSet = (setIndex == setCount - 1)
            if !(isLast && isLastSet) { seconds += userRestTime }
        }
        return seconds
    }
    
    func estimateTotalDuration(for template: WorkoutTemplate, userRestTime: Int, exerciseLibrary: [Exercise]) -> Int {
        let ids = template.exerciseIds
        guard !ids.isEmpty else { return 0 }
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseLibrary.map { ($0.id, $0) })
        var total = 0
        for (index, exId) in ids.enumerated() {
            let sets = max(1, template.targets?[exId]?.sets ?? 3)
            let setup = exerciseMap[exId]?.setupTime ?? .medium
            total += exerciseSeconds(setupTime: setup, setCount: sets, userRestTime: userRestTime,
                                     isFirst: index == 0, isLast: index == ids.count - 1)
        }
        return total / 60
    }
    
    func estimateTotalDuration(for activeWorkout: ActiveWorkout, userRestTime: Int, exerciseLibrary: [Exercise]) -> Int {
        let ids = activeWorkout.exerciseIds
        guard !ids.isEmpty else { return 0 }
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseLibrary.map { ($0.id, $0) })
        var total = 0
        for (index, exId) in ids.enumerated() {
            let sets = max(1, activeWorkout.rowsByExercise[exId]?.count ?? 1)
            let setup = exerciseMap[exId]?.setupTime ?? .medium
            total += exerciseSeconds(setupTime: setup, setCount: sets, userRestTime: userRestTime,
                                     isFirst: index == 0, isLast: index == ids.count - 1)
        }
        return total / 60
    }
    
    func estimateRemainingDuration(for activeWorkout: ActiveWorkout, userRestTime: Int, exerciseLibrary: [Exercise], overtimeSeconds: Int = 0) -> Int {
        let exerciseIds = activeWorkout.exerciseIds
        guard !exerciseIds.isEmpty else { return 0 }
        let exerciseMap = Dictionary(uniqueKeysWithValues: exerciseLibrary.map { ($0.id, $0) })
        
        // Build list of remaining (exerciseId, count) — skip fully completed
        let remaining: [(id: UUID, sets: Int)] = exerciseIds.compactMap { exId in
            let rem = (activeWorkout.rowsByExercise[exId] ?? []).filter { !$0.isCompleted }.count
            return rem > 0 ? (exId, rem) : nil
        }
        guard !remaining.isEmpty else { return 0 }
        
        var total = 0
        for (offset, item) in remaining.enumerated() {
            let setup = exerciseMap[item.id]?.setupTime ?? .medium
            total += exerciseSeconds(setupTime: setup, setCount: item.sets, userRestTime: userRestTime,
                                     isFirst: offset == 0, isLast: offset == remaining.count - 1)
        }
        
        return max(1, max(0, total - overtimeSeconds) / 60)
    }
    
    // MARK: - Session Generation
    
    /// Converts an active workout into a completed workout session.
    func generateSession(from activeWorkout: ActiveWorkout, templates: [WorkoutTemplate], availableExerciseIds: Set<UUID>) -> (session: WorkoutSession?, zombieIds: [UUID]) {
        guard let template = templates.first(where: { $0.id == activeWorkout.templateId }) else { 
            return (nil, [])
        }

        var setLogs: [SetLog] = []
        var setIndexByExercise: [UUID: Int] = [:]
        var zombieExerciseIds: [UUID] = []

        let exercisesToLog = activeWorkout.exerciseIds.isEmpty ? template.exerciseIds : activeWorkout.exerciseIds

        for exerciseId in exercisesToLog {
            if !availableExerciseIds.contains(exerciseId) {
                zombieExerciseIds.append(exerciseId)
                continue
            }
            
            let rows = activeWorkout.rowsByExercise[exerciseId] ?? []

            for row in rows {
                let normalizedReps = row.reps.replacingOccurrences(of: ",", with: ".")
                let repsValue: Int? = Int(row.reps) ?? (Double(normalizedReps).map { Int($0) })
                guard let reps = repsValue, reps > 0 else { continue }
                let normalizedWeight = row.weight.replacingOccurrences(of: ",", with: ".")
                let weight = normalizedWeight.isEmpty ? nil : Double(normalizedWeight)

                let nextIndex = (setIndexByExercise[exerciseId] ?? 0) + 1
                setIndexByExercise[exerciseId] = nextIndex

                setLogs.append(
                    SetLog(
                        id: UUID(),
                        exerciseId: exerciseId,
                        setIndex: nextIndex,
                        reps: reps,
                        weight: weight,
                        rir: row.rir.isEmpty ? nil : row.rir
                    )
                )
            }
        }

        guard !setLogs.isEmpty else { return (nil, zombieExerciseIds) }

        let endedAt = Date()
        
        let session = WorkoutSession(
            id: UUID(),
            templateId: template.id,
            date: endedAt,
            notes: nil,
            sets: setLogs,
            startedAt: activeWorkout.startedAt,
            endedAt: endedAt,
            exerciseNotes: activeWorkout.notesByExercise
        )
        
        return (session, zombieExerciseIds)
    }
    
    // MARK: - Stats & PR Methods
    
    /// Structure representing a personal record
    struct PersonalRecord {
        let date: Date
        let weight: Double
        let reps: Int
        let estimated1RM: Double
    }
    
    /// Calculates estimated 1RM using the Brzycki formula.
    func calculate1RM(weight: Double, reps: Int) -> Double {
        guard reps > 0 && reps < 37 else { return weight }
        return weight * (36.0 / (37.0 - Double(reps)))
    }
    
    /// Gets chronological personal records for an exercise.
    func personalRecords(sessions: [WorkoutSession], exerciseId: UUID) -> [PersonalRecord] {
        var records: [PersonalRecord] = []
        
        for session in sessions {
            let exerciseSets = session.sets.filter { $0.exerciseId == exerciseId && $0.weight != nil }
            
            for set in exerciseSets {
                guard let weight = set.weight, weight > 0, set.reps > 0 else { continue }
                
                let est1RM = calculate1RM(weight: weight, reps: set.reps)
                records.append(PersonalRecord(
                    date: session.date,
                    weight: weight,
                    reps: set.reps,
                    estimated1RM: est1RM
                ))
            }
        }
        
        return records.sorted { $0.date < $1.date }
    }
    
    /// Gets the highest estimated 1RM for an exercise.
    func currentPR(sessions: [WorkoutSession], exerciseId: UUID) -> PersonalRecord? {
        let allRecords = personalRecords(sessions: sessions, exerciseId: exerciseId)
        return allRecords.max(by: { $0.estimated1RM < $1.estimated1RM })
    }
    
    /// Gets daily max 1RM progression for charting.
    func prProgression(sessions: [WorkoutSession], exerciseId: UUID, days: Int) -> [(date: Date, est1RM: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
        
        let allRecords = personalRecords(sessions: sessions, exerciseId: exerciseId)
        let filtered = allRecords.filter { $0.date >= startDate }
        
        // Group by day and take max 1RM per day
        var dailyMax: [Date: Double] = [:]
        for record in filtered {
            let day = calendar.startOfDay(for: record.date)
            if dailyMax[day] == nil || record.estimated1RM > dailyMax[day]! {
                dailyMax[day] = record.estimated1RM
            }
        }
        
        return dailyMax.map { (date: $0.key, est1RM: $0.value) }.sorted { $0.date < $1.date }
    }
    
    /// Gets daily volume progression for charting.
    func volumeProgression(sessions: [WorkoutSession], exerciseId: UUID, days: Int) -> [(date: Date, volume: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
        
        let filteredSessions = sessions.filter { $0.date >= startDate }
        
        // Group by day and calculate total volume (Weight * Reps) per day
        var dailyVolume: [Date: Double] = [:]
        for session in filteredSessions {
            let day = calendar.startOfDay(for: session.date)
            let exerciseSets = session.sets.filter { $0.exerciseId == exerciseId && $0.weight != nil && $0.reps > 0 }
            
            var sessionVolume = 0.0
            for set in exerciseSets {
                if let weight = set.weight {
                    sessionVolume += weight * Double(set.reps)
                }
            }
            
            if sessionVolume > 0 {
                dailyVolume[day, default: 0] += sessionVolume
            }
        }
        
        return dailyVolume.map { (date: $0.key, volume: $0.value) }.sorted { $0.date < $1.date }
    }
    
    /// Gets maximum weight lifted per day for charting.
    func maxWeightProgression(sessions: [WorkoutSession], exerciseId: UUID, days: Int) -> [(date: Date, maxWeight: Double)] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [] }
        
        let filteredSessions = sessions.filter { $0.date >= startDate }
        
        var dailyMax: [Date: Double] = [:]
        for session in filteredSessions {
            let day = calendar.startOfDay(for: session.date)
            let exerciseSets = session.sets.filter { $0.exerciseId == exerciseId && $0.weight != nil }
            
            let maxWeight = exerciseSets.compactMap { $0.weight }.max() ?? 0
            if maxWeight > 0 {
                if dailyMax[day] == nil || maxWeight > dailyMax[day]! {
                    dailyMax[day] = maxWeight
                }
            }
        }
        
        return dailyMax.map { (date: $0.key, maxWeight: $0.value) }.sorted { $0.date < $1.date }
    }
    
    /// Gets all active workout dates in a given year.
    func workoutDates(sessions: [WorkoutSession], year: Int) -> Set<Date> {
        let calendar = Calendar.current
        var dates = Set<Date>()
        
        for session in sessions {
            let sessionYear = calendar.component(.year, from: session.date)
            if sessionYear == year {
                let dayStart = calendar.startOfDay(for: session.date)
                dates.insert(dayStart)
            }
        }
        
        return dates
    }
    
    /// Counts workouts per week for a given year.
    func weeklyWorkoutCounts(sessions: [WorkoutSession], year: Int) -> [Int: Int] {
        let calendar = Calendar.current
        var counts: [Int: Int] = [:]
        
        for session in sessions {
            let sessionYear = calendar.component(.year, from: session.date)
            if sessionYear == year {
                let weekOfYear = calendar.component(.weekOfYear, from: session.date)
                counts[weekOfYear, default: 0] += 1
            }
        }
        
        return counts
    }
    
    // MARK: - Dynamic Stats Aggregation
    
    /// Calculates recent set volume per muscle category (secondary muscles count as 0.5).
    func getCategoryVolume(sessions: [WorkoutSession], exerciseLibrary: [Exercise], days: Int) -> [String: Double] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return [:] }
        
        // Create maps: exerciseId -> (primaryCategory, secondaryCategory?)
        var categoryMap: [UUID: String] = [:]
        var secondaryMap: [UUID: String?] = [:]
        for ex in exerciseLibrary {
            categoryMap[ex.id] = ex.category
            secondaryMap[ex.id] = ex.secondaryMuscle
        }
        
        var volumeMap: [String: Double] = [:]
        
        // Filter sessions
        let filteredSessions = sessions.filter { $0.date >= startDate }
        
        for session in filteredSessions {
            for setLog in session.sets {
                // Primary category: 1.0 set
                if let category = categoryMap[setLog.exerciseId] {
                    let key = category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                    volumeMap[key, default: 0] += 1.0
                }
                
                // Secondary category: 0.5 set
                if let secondary = secondaryMap[setLog.exerciseId], let secondaryCategory = secondary {
                    let key = secondaryCategory.trimmingCharacters(in: .whitespacesAndNewlines).capitalized
                    volumeMap[key, default: 0] += 0.5
                }
            }
        }
        
        return volumeMap
    }
    
    /// Counts total workouts over a period.
    func getWorkoutCount(sessions: [WorkoutSession], days: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        return sessions.filter { $0.date >= startDate }.count
    }
    
    // MARK: - Habit & Consistency Analytics
    
    func longestWorkoutStreak(sessions: [WorkoutSession], days: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        let validDates = Set(sessions.filter { $0.date >= startDate }.map { calendar.startOfDay(for: $0.date) })
        var longestStreak = 0
        var currentStreak = 0
        
        for dayOffset in 0..<days {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            if validDates.contains(date) {
                currentStreak += 1
                longestStreak = max(longestStreak, currentStreak)
            } else {
                currentStreak = 0
            }
        }
        
        return longestStreak
    }
    
    func perfectDays(sessions: [WorkoutSession], proteinEntries: [ProteinEntry], target: Int, days: Int) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        
        var proteinPerDay: [Date: Int] = [:]
        for entry in proteinEntries.filter({ $0.date >= startDate }) {
            let day = calendar.startOfDay(for: entry.date)
            proteinPerDay[day, default: 0] += entry.grams
        }
        
        let workoutDates = Set(sessions.filter({ $0.date >= startDate }).map { calendar.startOfDay(for: $0.date) })
        
        var perfectCount = 0
        for day in workoutDates {
            if let protein = proteinPerDay[day], protein >= target {
                perfectCount += 1
            }
        }
        
        return perfectCount
    }
    
    func consistencyScore(sessions: [WorkoutSession], days: Int) -> Int {
        let workouts = getWorkoutCount(sessions: sessions, days: days)
        let weeks = Double(days) / 7.0
        guard weeks > 0 else { return 0 }
        
        let targetWorkouts = weeks * 3.0 // Target is 3x a week
        let score = (Double(workouts) / targetWorkouts) * 100.0
        return min(100, Int(score.rounded()))
    }
    
    func avgWorkoutsPerWeek(sessions: [WorkoutSession], days: Int) -> Double {
        let workouts = getWorkoutCount(sessions: sessions, days: days)
        let weeks = Double(days) / 7.0
        guard weeks > 0 else { return 0 }
        return Double(workouts) / weeks
    }
    
    // MARK: - Recovery Analytics
    
    func muscleRecoveryStatus(sessions: [WorkoutSession], exerciseLibrary: [Exercise]) -> [String: Int] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        
        var categoryMap: [UUID: [String]] = [:]
        for ex in exerciseLibrary {
            var cats = [ex.category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized]
            if let sec = ex.secondaryMuscle {
                cats.append(sec.trimmingCharacters(in: .whitespacesAndNewlines).capitalized)
            }
            categoryMap[ex.id] = cats
        }
        
        var lastTrained: [String: Date] = [:]
        
        for session in sessions {
            let day = calendar.startOfDay(for: session.date)
            for set in session.sets {
                if let cats = categoryMap[set.exerciseId] {
                    for cat in cats {
                        if lastTrained[cat] == nil {
                            lastTrained[cat] = day
                        }
                    }
                }
            }
        }
        
        var daysSince: [String: Int] = [:]
        for (muscle, date) in lastTrained {
            if let diff = calendar.dateComponents([.day], from: date, to: today).day {
                daysSince[muscle] = diff
            }
        }
        
        return daysSince
    }
}
