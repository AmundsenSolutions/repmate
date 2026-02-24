//
//  ActiveWorkoutHeaderView.swift
//  Vext
//
//  Created by Auto-Agent on 02/02/2026.
//

import SwiftUI

struct ActiveWorkoutHeaderView: View {
    @EnvironmentObject var store: AppDataStore
    
    // Derived state passed from parent if needed, or computed from store
    // Using store directly ensures sync
    
    @State private var showRemainingTime = true
    
    private var active: ActiveWorkout? { store.activeWorkout }
    
    private var exercises: [Exercise] {
        guard let aw = active else { return [] }
        return aw.exerciseIds.compactMap { id in
            store.exerciseLibrary.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        HStack {
            StatItem(value: "\(exercises.count)", label: "Exercises")
            Spacer()
            StatItem(value: "\(countTotalSets())", label: "Sets")
            Spacer()
            
            Button {
                showRemainingTime.toggle()
                HapticManager.shared.lightImpact()
            } label: {
                StatItem(
                    value: showRemainingTime ? estimateRemainingDuration() : estimateTotalDuration(),
                    label: showRemainingTime ? "Time Left" : "Est. Total"
                )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }
    
    // MARK: - Helpers (Copied & Adapted)
    
    private func countTotalSets() -> Int {
        guard let aw = active else { return 0 }
        return aw.rowsByExercise.values.reduce(0) { $0 + $1.count }
    }
    
    // Constants
    private let kWorkSetDuration: Int = 30
    private let kWarmupSetDuration: Int = 30
    private let kWalkTime: Int = 30
    private let kRiggingTime: Int = 30
    private var kTransitionTime: Int { kWalkTime + kRiggingTime }
    
    private var userRestTime: Int {
        store.settings.restTime
    }
    
    private func estimateTotalDuration() -> String {
        guard let aw = active else { return "0 min" }
        
        let exerciseCount = aw.exerciseIds.count
        guard exerciseCount > 0 else { return "0 min" }
        
        var totalSeconds = 0
        
        for (index, exerciseId) in aw.exerciseIds.enumerated() {
            let sets = aw.rowsByExercise[exerciseId] ?? []
            let setCount = max(1, sets.count) // At least 1 set per exercise
            let exercise = store.exerciseLibrary.first(where: { $0.id == exerciseId })
            let setupTime = exercise?.setupTime ?? .medium
            
            // Transition (walk + setup based on exercise type)
            if index > 0 {
                totalSeconds += setupTime.transitionSeconds
            }
            
            // Warmup set
            totalSeconds += setupTime.setDurationSeconds + userRestTime
            
            // Work sets
            for setIndex in 0..<setCount {
                totalSeconds += setupTime.setDurationSeconds
                
                let isLastExercise = (index == exerciseCount - 1)
                let isLastSet = (setIndex == setCount - 1)
                if !(isLastExercise && isLastSet) {
                    totalSeconds += userRestTime
                }
            }
        }
        
        let minutes = totalSeconds / 60
        return "\(minutes) min"
    }
    
    private func estimateRemainingDuration() -> String {
        guard let aw = active else { return "0 min" }
        
        let exerciseIds = aw.exerciseIds
        guard !exerciseIds.isEmpty else { return "0 min" }
        
        var remainingSetsByExercise: [(exerciseId: UUID, remaining: Int, total: Int)] = []
        for exerciseId in exerciseIds {
            let rows = aw.rowsByExercise[exerciseId] ?? []
            let remaining = rows.filter { !$0.isCompleted }.count
            remainingSetsByExercise.append((exerciseId, remaining, rows.count))
        }
        
        guard let firstIncompleteIndex = remainingSetsByExercise.firstIndex(where: { $0.remaining > 0 }) else {
            return "0 min"
        }
        
        var totalSeconds = 0
        let totalExercises = remainingSetsByExercise.count
        
        for (offsetIndex, item) in remainingSetsByExercise.enumerated() {
            if item.remaining == 0 { continue }
            
            let isFirstRemaining = (offsetIndex == firstIncompleteIndex)
            let exercise = store.exerciseLibrary.first(where: { $0.id == item.exerciseId })
            let setupTime = exercise?.setupTime ?? .medium
            
            // Transition + warmup for non-first exercises
            if !isFirstRemaining {
                totalSeconds += setupTime.transitionSeconds
                totalSeconds += setupTime.setDurationSeconds + userRestTime
            }
            
            // Work sets
            for setIndex in 0..<item.remaining {
                totalSeconds += setupTime.setDurationSeconds
                
                let isLastSetOfExercise = (setIndex == item.remaining - 1)
                let isLastExercise = (offsetIndex == totalExercises - 1)
                
                if !(isLastExercise && isLastSetOfExercise) {
                    totalSeconds += userRestTime
                }
            }
        }
        
        let minutes = max(1, totalSeconds / 60)
        return "~\(minutes) min"
    }
}
