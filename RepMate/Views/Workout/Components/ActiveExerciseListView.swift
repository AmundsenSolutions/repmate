//
//  ActiveExerciseListView.swift
//  RepMate
//
//  Created by Auto-Agent on 02/02/2026.
//

import SwiftUI
import Combine

/// Parses an Int from a string that may contain decimals (e.g. "5.0" or "5,0").
/// Returns nil only if the string is not a valid number at all.
private func parseIntFlexible(_ s: String) -> Int? {
    if let i = Int(s) { return i }
    let normalized = s.replacingOccurrences(of: ",", with: ".")
    if let d = Double(normalized) { return Int(d) }
    return nil
}

/// Parses a Double from a string, handling both "." and "," as decimal separators.
private func parseDoubleFlexible(_ s: String) -> Double? {
    let normalized = s.replacingOccurrences(of: ",", with: ".")
    return Double(normalized)
}

struct ActiveExerciseListView: View {
    @EnvironmentObject var store: AppDataStore
    
    // Local Sheet States
    @State private var showingAddExercise = false
    @State private var replacingExercise: Exercise?

    private var active: ActiveWorkout? { store.activeWorkout }
    
    private var template: WorkoutTemplate? {
        guard let aw = active else { return nil }
        return store.workoutTemplates.first(where: { $0.id == aw.templateId })
    }
    
    private var exercises: [Exercise] {
        guard let aw = active else { return [] }
        return aw.exerciseIds.compactMap { id in
            store.exerciseLibrary.first(where: { $0.id == id })
        }
    }
    
    var body: some View {
        List {
            // Persistent Note
            if let note = active?.note, !note.isEmpty {
                Text(note)
                    .font(.body)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            
            // Exercises
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                ExerciseCardView(
                    index: index + 1,
                    exerciseName: exercise.name,
                    targetRir: template?.targets?[exercise.id]?.rir,
                    targetRest: template?.targets?[exercise.id]?.rest ?? 0,
                    overloadStatus: ProgressiveOverloadHelper.checkOverloadStatus(
                        for: exercise.id,
                        in: store.workoutSessions,
                        settings: store.settings
                    ),
                    onMenu: {
                        AnyView(
                            Menu {
                                Button {
                                    replacingExercise = exercise
                                } label: {
                                    Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                                }
                                Button(role: .destructive) {
                                    removeExercise(exercise)
                                } label: {
                                    Label {
                                        Text("Remove")
                                    } icon: {
                                        Image(systemName: "trash")
                                            .tint(.red) // Red Rule
                                    }
                                    .foregroundColor(.red) // Red Rule
                                }
                            } label: {
                                Image(systemName: "ellipsis")
                                    .foregroundColor(Theme.Colors.textSecondary)
                                    .frame(width: 30, height: 30)
                                    .contentShape(Rectangle())
                            }
                        )
                    },
                    content: {
                        VStack(spacing: 6) {
                            let rows = store.activeWorkout?.rowsByExercise[exercise.id] ?? []
                            ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                                rowView(exerciseId: exercise.id, row: row, index: rowIndex)
                            }
                            
                            // Add Set Button
                            Button {
                                addSetRowIfValid(exerciseId: exercise.id)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.accent)
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                        }
                    },
                    note: bindingNote(for: exercise.id),
                    ghostNote: store.ghostExerciseNote(for: exercise.id)
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeExercise(exercise)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
            
            // Add Exercise Button (Footer)
            if !exercises.isEmpty {
                Button {
                    showingAddExercise = true
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Add Exercise")
                    }
                    .font(.headline)
                    .pillButton(backgroundColor: Theme.Colors.cardBackground, foregroundColor: Theme.Colors.accent)
                    .frame(maxWidth: .infinity)
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.vertical, 12)
                .buttonStyle(.plain)
            }
            
            // Spacing
            Color.clear.frame(height: 100)
                 .listRowBackground(Color.clear)
                 .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("Done") {
                    UIApplication.shared.sendAction(
                        #selector(UIResponder.resignFirstResponder),
                        to: nil, from: nil, for: nil
                    )
                }
                .fontWeight(.semibold)
            }
        }
        // Sheet Management
        .sheet(isPresented: $showingAddExercise) {
            NavigationView {
                ExerciseLibraryView(onSelect: { exercise in
                    addExercise(exercise)
                })
            }
        }
        .sheet(item: $replacingExercise) { exerciseToReplace in
             NavigationView {
                 ExerciseLibraryView(onSelect: { newExercise in
                     replaceExercise(old: exerciseToReplace, new: newExercise)
                     replacingExercise = nil
                 })
                 .navigationTitle("Replace \(exerciseToReplace.name)")
                 .toolbar {
                     ToolbarItem(placement: .cancellationAction) {
                         Button("Cancel") { replacingExercise = nil }
                     }
                 }
             }
        }
    }
    
    // MARK: - Row Construction
    
    private func rowView(exerciseId: UUID, row: ActiveSetRow, index: Int) -> some View {
        let ghostData = store.ghostSetData(for: exerciseId, setIndex: index)
        let ghostReps = ghostData.map { "\($0.reps)" }
        let ghostWeight: String? = ghostData.map { w in
            w.weight.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w.weight))" : "\(w.weight)"
        }
        let ghostRir = ghostData.map { "\($0.rir)" }

        // Check total rows for this exercise to enforcing "Min 1 set" rule
        let rowCount = store.activeWorkout?.rowsByExercise[exerciseId]?.count ?? 0
        let canDelete = rowCount > 1
        
        return SwipeToDeleteWrapper(
            onDelete: canDelete ? { deleteSetRow(exerciseId: exerciseId, rowId: row.id) } : nil
        ) {
            SetRowView(
                index: index + 1,
                weight: bindingWeight(exerciseId: exerciseId, rowId: row.id),
                reps: bindingReps(exerciseId: exerciseId, rowId: row.id),
                rir: bindingRir(exerciseId: exerciseId, rowId: row.id),
                isCompleted: bindingIsCompleted(exerciseId: exerciseId, rowId: row.id),
                isPR: checkIsPR(exerciseId: exerciseId, row: row),
                ghostWeight: ghostWeight,
                ghostReps: ghostReps,
                ghostRir: ghostRir
            )
        }
    }
    
    // MARK: - Bindings (ID-Based)
    
    private func bindingIsCompleted(exerciseId: UUID, rowId: UUID) -> Binding<Bool> {
        Binding(
            get: {
                store.activeWorkout?.rowsByExercise[exerciseId]?.first(where: { $0.id == rowId })?.isCompleted ?? false
            },
            set: { newValue in
                guard var aw = store.activeWorkout else { return }
                ensureAtLeastOneRow(&aw, for: exerciseId)
                guard var rows = aw.rowsByExercise[exerciseId], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
                
                rows[index].isCompleted = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.updateActiveWorkout(aw)
                
                if newValue {
                     if self.checkIsPR(exerciseId: exerciseId, row: rows[index]) {
                         HapticManager.shared.heavyImpact()
                     } else {
                         HapticManager.shared.success()
                     }
                     // FIX: Removed startRestTimer(). Timer is now manual only.
                }
            }
        )
    }

    private func bindingReps(exerciseId: UUID, rowId: UUID) -> Binding<String> {
        Binding(
            get: { store.activeWorkout?.rowsByExercise[exerciseId]?.first(where: { $0.id == rowId })?.reps ?? "" },
            set: { newValue in
                guard var aw = store.activeWorkout else { return }
                ensureAtLeastOneRow(&aw, for: exerciseId)
                guard var rows = aw.rowsByExercise[exerciseId], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
                
                let wasCompleted = rows[index].isCompleted
                rows[index].reps = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)
                
                checkAutoComplete(exerciseId: exerciseId, index: index, wasCompleted: wasCompleted)
            }
        )
    }

    private func bindingWeight(exerciseId: UUID, rowId: UUID) -> Binding<String> {
        Binding(
            get: { store.activeWorkout?.rowsByExercise[exerciseId]?.first(where: { $0.id == rowId })?.weight ?? "" },
            set: { newValue in
                guard var aw = store.activeWorkout else { return }
                ensureAtLeastOneRow(&aw, for: exerciseId)
                guard var rows = aw.rowsByExercise[exerciseId], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
                
                let wasCompleted = rows[index].isCompleted
                rows[index].weight = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)
                
                checkAutoComplete(exerciseId: exerciseId, index: index, wasCompleted: wasCompleted)
            }
        )
    }

    private func bindingRir(exerciseId: UUID, rowId: UUID) -> Binding<String> {
        Binding(
            get: { store.activeWorkout?.rowsByExercise[exerciseId]?.first(where: { $0.id == rowId })?.rir ?? "" },
            set: { newValue in
                guard var aw = store.activeWorkout else { return }
                ensureAtLeastOneRow(&aw, for: exerciseId)
                guard var rows = aw.rowsByExercise[exerciseId], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
                
                let wasCompleted = rows[index].isCompleted
                rows[index].rir = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)
                
                // Also check autocomplete on RIR (e.g. if user fills RIR last)
                checkAutoComplete(exerciseId: exerciseId, index: index, wasCompleted: wasCompleted)
            }
        )
    }

    private func bindingNote(for exerciseId: UUID) -> Binding<String> {
        Binding(
            get: { store.activeWorkout?.notesByExercise[exerciseId] ?? "" },
            set: { newValue in
                guard var aw = store.activeWorkout else { return }
                aw.notesByExercise[exerciseId] = newValue
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)
            }
        )
    }
    
    // MARK: - Logic Helpers
    
    private func checkAutoComplete(exerciseId: UUID, index: Int, wasCompleted: Bool) {
        guard var aw = store.activeWorkout,
              let rows = aw.rowsByExercise[exerciseId],
              rows.indices.contains(index) else { return }
        
        // Logic: Weight + Reps required, RIR is optional
        let row = rows[index]
        let weight = parseDoubleFlexible(row.weight) ?? 0
        let reps = parseIntFlexible(row.reps) ?? 0
        
        let shouldBeComplete = weight > 0 && reps > 0
        
        if shouldBeComplete && !wasCompleted {
            // Auto-complete: both fields have valid values
            var updatedRows = rows
            updatedRows[index].isCompleted = true
            aw.rowsByExercise[exerciseId] = updatedRows
            aw.isDirty = true
            
            store.silentUpdateActiveWorkout(aw)
            store.objectWillChange.send()
            
            if self.checkIsPR(exerciseId: exerciseId, row: rows[index]) {
                HapticManager.shared.heavyImpact()
            } else {
                HapticManager.shared.success()
            }
        } else if !shouldBeComplete && wasCompleted {
            // Auto-uncomplete: fields were cleared while set was marked done
            var updatedRows = rows
            updatedRows[index].isCompleted = false
            aw.rowsByExercise[exerciseId] = updatedRows
            aw.isDirty = true
            
            store.silentUpdateActiveWorkout(aw)
            store.objectWillChange.send()
        }
    }
    
    private func checkIsPR(exerciseId: UUID, row: ActiveSetRow) -> Bool {
        guard let weight = parseDoubleFlexible(row.weight), let reps = parseIntFlexible(row.reps), weight > 0, reps > 0 else { return false }
        
        let est1RM = store.workoutManager.calculate1RM(weight: weight, reps: reps)
        
        // 1. Must have previous history to compare against (no PR on first time doing an exercise)
        let previousPRRecord = store.workoutManager.currentPR(sessions: store.workoutSessions, exerciseId: exerciseId)
        guard let previousPR = previousPRRecord?.estimated1RM, previousPR > 0 else {
            // No previous history = first time doing this exercise = not a PR
            return false
        }
        
        // 2. Must beat historical PR
        guard est1RM > previousPR else { return false }
        
        // 3. Must be the BEST set in the CURRENT session so far
        // We find the max 1RM of all *other* completed sets in this session
        // If this set ties the max, it counts as PR.
        guard let rows = store.activeWorkout?.rowsByExercise[exerciseId] else { return true }
        
        let sessionMax1RM = rows.compactMap { r -> Double? in
            guard let w = parseDoubleFlexible(r.weight), let rp = parseIntFlexible(r.reps), w > 0, rp > 0 else { return nil }
            return store.workoutManager.calculate1RM(weight: w, reps: rp)
        }.max() ?? 0
        
        // Return true if we are >= sessionMax (meaning we ARE the session max, or tied for it)
        return est1RM >= sessionMax1RM
    }
    
    private func ensureAtLeastOneRow(_ aw: inout ActiveWorkout, for exerciseId: UUID) {
        if aw.rowsByExercise[exerciseId] == nil || aw.rowsByExercise[exerciseId]?.isEmpty == true {
            aw.rowsByExercise[exerciseId] = [ActiveSetRow()]
        }
    }
    
    private func deleteSetRow(exerciseId: UUID, rowId: UUID) {
        guard var aw = store.activeWorkout else { return }
        guard var rows = aw.rowsByExercise[exerciseId], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        
        // Instant deletion - no animation to prevent zoom/scale effects on other elements
        rows.remove(at: index)
        aw.rowsByExercise[exerciseId] = rows
        aw.isDirty = true
        store.updateActiveWorkout(aw)
    }
    
    private func addSetRowIfValid(exerciseId: UUID) {
        guard var aw = store.activeWorkout else { return }
        ensureAtLeastOneRow(&aw, for: exerciseId)
        
        let rows = aw.rowsByExercise[exerciseId] ?? []
        let newSet = ActiveSetRow()
        
        var updatedRows = rows
        updatedRows.append(newSet)
        
        withAnimation(.easeInOut(duration: 0.2)) {
            aw.rowsByExercise[exerciseId] = updatedRows
            aw.isDirty = true
            store.updateActiveWorkout(aw) // Force update for structural change
        }
        HapticManager.shared.lightImpact()
    }
    
    // MARK: - Exercise Management
    
    private func removeExercise(_ exercise: Exercise) {
        guard var aw = active else { return }
        if let idx = aw.exerciseIds.firstIndex(of: exercise.id) {
            withAnimation {
                aw.exerciseIds.remove(at: idx)
                aw.rowsByExercise.removeValue(forKey: exercise.id)
                store.updateActiveWorkout(aw)
            }
        }
    }
    
    private func addExercise(_ exercise: Exercise) {
        showingAddExercise = false
        guard var aw = active else { return }
        
        if !aw.exerciseIds.contains(exercise.id) {
            withAnimation {
                aw.exerciseIds.append(exercise.id)
                // Initialize with one set
                aw.rowsByExercise[exercise.id] = [ActiveSetRow()]
                store.updateActiveWorkout(aw)
            }
        }
    }
    
    private func replaceExercise(old: Exercise, new: Exercise) {
        guard var aw = active else { return }
        guard let idx = aw.exerciseIds.firstIndex(of: old.id) else { return }
        
        withAnimation {
            // Replace ID in list
            aw.exerciseIds[idx] = new.id
            // Migrate rows? Usually we reset rows for a new exercise
            // But if it's a replacement, maybe we want to keep the structure?
            // "Replace" usually implies "I picked the wrong one".
            // Let's migrate the rows structure but clear values to escape mismatched weight logic
            if let oldRows = aw.rowsByExercise[old.id] {
                // Keep the same number of sets, but clear data
                let newRows = oldRows.map { _ in ActiveSetRow() }
                aw.rowsByExercise[new.id] = newRows
            } else {
                aw.rowsByExercise[new.id] = [ActiveSetRow()]
            }
            aw.rowsByExercise.removeValue(forKey: old.id)
            
            store.updateActiveWorkout(aw)
        }
    }
}
