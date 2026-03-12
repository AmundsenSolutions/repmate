//
//  ActiveExerciseListView.swift
//  RepMate
//
//  Created by Auto-Agent on 02/02/2026.
//

import SwiftUI
import Combine

struct ActiveExerciseListView: View {
    @EnvironmentObject var store: AppDataStore
    
    // Local Sheet States
    @State private var showingAddExercise = false
    @State private var replacingExercise: Exercise?
    @State private var prCache: [UUID: Bool] = [:]

    private var active: ActiveWorkout? { store.activeWorkout }
    
    private var template: WorkoutTemplate? {
        guard let aw = active else { return nil }
        return store.workoutTemplates.first(where: { $0.id == aw.templateId })
    }
    
    private var exercises: [(id: UUID, exercise: Exercise?)] {
        guard let aw = active else { return [] }
        return aw.exerciseIds.map { id in
            (id: id, exercise: store.exerciseLibrary.first(where: { $0.id == id }))
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
            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, item in
                let exerciseId = item.id
                let exercise = item.exercise
                
                ExerciseCardView(
                    index: index + 1,
                    exerciseName: exercise?.name ?? "Deleted Exercise",
                    targetRir: template?.targets?[exerciseId]?.rir,
                    targetRest: template?.targets?[exerciseId]?.rest ?? 0,
                    overloadStatus: ProgressiveOverloadHelper.checkOverloadStatus(
                        for: exerciseId,
                        in: store.workoutSessions,
                        settings: store.settings
                    ),
                    note: bindingNote(for: exerciseId),
                    ghostNote: store.ghostExerciseNote(for: exerciseId),
                    menuContent: {
                        Menu {
                            Button {
                                if let ex = exercise {
                                    replacingExercise = ex
                                }
                            } label: {
                                Label("Replace", systemImage: "arrow.triangle.2.circlepath")
                            }
                            .disabled(exercise == nil)
                            
                            Button(role: .destructive) {
                                removeExercise(id: exerciseId)
                            } label: {
                                Label {
                                    Text("Remove")
                                } icon: {
                                    Image(systemName: "trash")
                                        .tint(.red)
                                }
                                .foregroundColor(.red)
                            }
                        } label: {
                            Image(systemName: "ellipsis")
                                .foregroundColor(Theme.Colors.textSecondary)
                                .frame(width: 30, height: 30)
                                .contentShape(Rectangle())
                        }
                    },
                    content: {
                        VStack(spacing: 6) {
                            let rows = store.activeWorkout?.rowsByExercise[exerciseId] ?? []
                            ForEach(Array(rows.enumerated()), id: \.element.id) { rowIndex, row in
                                rowView(exerciseId: exerciseId, row: row, index: rowIndex)
                            }
                            
                            // Add Set Button
                            Button {
                                addSetRowIfValid(exerciseId: exerciseId)
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(Theme.Colors.accent)
                                    .padding(.top, 4)
                            }
                            .frame(maxWidth: .infinity)
                            .buttonStyle(.plain)
                        }
                    }
                )
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 10, bottom: 6, trailing: 10))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button(role: .destructive) {
                        removeExercise(id: exerciseId)
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
            .onMove(perform: moveExercises)
            
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
        .onAppear {
            for exercise in exercises {
                recalculatePRStatus(for: exercise.id)
            }
        }
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
                isPR: prCache[row.id] ?? false,
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
                     if prCache[rowId] == true {
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
                recalculatePRStatus(for: exerciseId)
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
                recalculatePRStatus(for: exerciseId)
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
        let weight = row.weight.parseDoubleFlexible() ?? 0
        let reps = row.reps.parseIntFlexible() ?? 0
        
        let shouldBeComplete = weight > 0 && reps > 0
        
        if shouldBeComplete && !wasCompleted {
            // Auto-complete: both fields have valid values
            var updatedRows = rows
            updatedRows[index].isCompleted = true
            aw.rowsByExercise[exerciseId] = updatedRows
            aw.isDirty = true
            
            store.silentUpdateActiveWorkout(aw)
            store.objectWillChange.send()
            
            if prCache[rows[index].id] == true {
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
    
    private func recalculatePRStatus(for exerciseId: UUID) {
        guard let rows = store.activeWorkout?.rowsByExercise[exerciseId] else { return }
        
        let previousPRRecord = store.workoutManager.currentPR(sessions: store.workoutSessions, exerciseId: exerciseId)
        let previousPR = previousPRRecord?.estimated1RM ?? 0
        
        if previousPR <= 0 {
            // No previous history = first time doing this exercise = not a PR
            for row in rows {
                prCache[row.id] = false
            }
            return
        }
        
        var maxSession1RM: Double = 0
        for row in rows {
            if let w = row.weight.parseDoubleFlexible(), let rp = row.reps.parseIntFlexible(), w > 0, rp > 0 {
                let est1RM = store.workoutManager.calculate1RM(weight: w, reps: rp)
                maxSession1RM = max(maxSession1RM, est1RM)
            }
        }
        
        for row in rows {
            if let w = row.weight.parseDoubleFlexible(), let rp = row.reps.parseIntFlexible(), w > 0, rp > 0 {
                let est1RM = store.workoutManager.calculate1RM(weight: w, reps: rp)
                prCache[row.id] = (est1RM > previousPR) && (est1RM >= maxSession1RM)
            } else {
                prCache[row.id] = false
            }
        }
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
    
    private func removeExercise(id: UUID) {
        guard var aw = active else { return }
        if let idx = aw.exerciseIds.firstIndex(of: id) {
            withAnimation {
                aw.exerciseIds.remove(at: idx)
                aw.rowsByExercise.removeValue(forKey: id)
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
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        guard var aw = store.activeWorkout else { return }
        aw.exerciseIds.move(fromOffsets: source, toOffset: destination)
        aw.isDirty = true
        store.updateActiveWorkout(aw)
        HapticManager.shared.lightImpact()
    }
}
