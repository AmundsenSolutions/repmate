import SwiftUI
import Combine

struct ActiveExerciseListView: View {
    @EnvironmentObject var store: AppDataStore
    
    // Local Sheet States
    @State private var showingAddExercise = false
    @State private var replacingExercise: Exercise? = nil
    
    @FocusState private var focusedField: WorkoutFieldFocus?
    @State private var scrollTargetID: UUID? = nil
    
    // Safe computed props for toolbar disabled state
    private var isAtFirstField: Bool {
        guard let f = focusedField else { return true }
        return cachedFields.first == f
    }
    private var isAtLastField: Bool {
        guard let f = focusedField else { return true }
        return cachedFields.last == f
    }
    @State private var prCache: [UUID: Bool] = [:]
    @State private var cachedFields: [WorkoutFieldFocus] = []

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
        VStack(spacing: 0) {
            ScrollViewReader { scrollProxy in
                List {
                    // Top Safe Zone
                    Color.clear.frame(height: 10)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        
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
                        targetReps: template?.targets?[exerciseId]?.reps,
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
                                    rowView(exerciseId: exerciseId, exerciseName: exercise?.name ?? "Exercise", row: row, index: rowIndex)
                                        .id(row.id)
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
                
                // Permanent bottom spacer: ensures the "Add Exercise" button is
                // never occluded by the floating "Finish Workout" pill (~66pt).
                // Grows when the keyboard is visible to keep active fields scrollable.
                Color.clear
                    .frame(height: focusedField != nil ? 240 : 90)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden) 
            .background(Color.black) // Tetter hullet mot ZStack
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: focusedField) { _, newFocus in
                guard let focus = newFocus else { return }
                
                let id: UUID
                switch focus {
                case .weight(let setId), .reps(let setId), .rir(let setId): id = setId
                }
                
                // Nå som lista flytter seg selv og skjønner tastaturet,
                // er et enkelt scroll til .center nok!
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    scrollProxy.scrollTo(id, anchor: .center)
                }
            }
        } // End of ScrollViewReader
        .overlay(alignment: .bottom) {
            // TWO FLOATING PILLS KEYBOARD TOOLBAR
            if focusedField != nil {
                HStack(alignment: .bottom) {
                    // LEFT PILL: Navigation & Checkmark
                    HStack(spacing: 20) {
                        Button { focusPrevious() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                        }
                        .disabled(isAtFirstField)
                        .foregroundColor(isAtFirstField ? Color.secondary.opacity(0.3) : Theme.Colors.accent)
                        
                        Button { focusNext() } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                        }
                        .disabled(isAtLastField)
                        .foregroundColor(isAtLastField ? Color.secondary.opacity(0.3) : Theme.Colors.accent)
                        
                        Button { confirmGhostValue() } label: {
                            Image(systemName: "checkmark")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                        }
                        .foregroundColor(Theme.Colors.accent)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(
                        Capsule()
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .opacity(0.4)
                            .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                    )
                    .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                    
                    Spacer()
                    
                    // RIGHT PILL: Done Button
                    Button("Done") { focusedField = nil }
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(Theme.Colors.accent)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            Capsule()
                                .fill(.ultraThinMaterial)
                                .environment(\.colorScheme, .dark)
                                .opacity(0.4)
                                .overlay(Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1))
                        )
                        .shadow(color: Color.black.opacity(0.5), radius: 10, x: 0, y: 5)
                }
                .padding(.horizontal, 16)
                .offset(y: -9) // Pulls the pills down into the safe area gap
                .transition(.move(edge: .bottom).combined(with: .opacity).combined(with: .scale(scale: 0.95)))
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: focusedField)
            }
        }
    } // End of body VStack
        // Sheet Management
        .onAppear {
            updateFieldCache()
            for exercise in exercises {
                recalculatePRStatus(for: exercise.id)
            }
        }
        .onChange(of: store.activeWorkout) { _, _ in
            updateFieldCache()
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
    
    private func rowView(exerciseId: UUID, exerciseName: String, row: ActiveSetRow, index: Int) -> some View {
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
                exerciseName: exerciseName,
                weight: bindingWeight(exerciseId: exerciseId, rowId: row.id),
                reps: bindingReps(exerciseId: exerciseId, rowId: row.id),
                rir: bindingRir(exerciseId: exerciseId, rowId: row.id),
                isCompleted: bindingIsCompleted(exerciseId: exerciseId, rowId: row.id),
                rowId: row.id,
                focusedField: $focusedField,
                isPR: prCache[row.id] ?? false,
                ghostWeight: ghostWeight,
                ghostReps: ghostReps,
                ghostRir: ghostRir
            )
        }
    }
    
    // MARK: - Keyboard Navigation
    
    private func updateFieldCache() {
        guard let aw = store.activeWorkout else { cachedFields = []; return }
        var fields: [WorkoutFieldFocus] = []
        for exId in aw.exerciseIds {
            if let rows = aw.rowsByExercise[exId] {
                for row in rows {
                    fields.append(.weight(setId: row.id))
                    fields.append(.reps(setId: row.id))
                    fields.append(.rir(setId: row.id))
                }
            }
        }
        cachedFields = fields
    }
    
    private func focusNext() {
        guard let current = focusedField, let index = cachedFields.firstIndex(of: current) else { return }
        if index + 1 < cachedFields.count {
            focusedField = cachedFields[index + 1]
        } else {
            focusedField = nil
        }
    }
    
    private func focusPrevious() {
        guard let current = focusedField, let index = cachedFields.firstIndex(of: current) else { return }
        if index - 1 >= 0 {
            focusedField = cachedFields[index - 1]
        } else {
            focusedField = nil
        }
    }
    
    private func confirmGhostValue() {
        guard let current = focusedField else { return }
        
        // Inject data immediately before losing focus
        self.injectGhostData(for: current)
        HapticManager.shared.lightImpact()
        
        // Move to next field natively
        focusNext()
    }
    
    private func injectGhostData(for field: WorkoutFieldFocus) {
        guard var aw = store.activeWorkout else { return }
        
        // Find the exercise and row index for the targeted setId
        let setId: UUID
        switch field {
        case .weight(let id), .reps(let id), .rir(let id): setId = id
        }
        
        var targetMatch: (exerciseId: UUID, rowIndex: Int)? = nil
        for exId in aw.exerciseIds {
            if let rows = aw.rowsByExercise[exId], let idx = rows.firstIndex(where: { $0.id == setId }) {
                targetMatch = (exId, idx)
                break
            }
        }
        
        guard let match = targetMatch,
              let ghost = store.ghostSetData(for: match.exerciseId, setIndex: match.rowIndex) else { return }
        
        switch field {
        case .weight:
            let w = ghost.weight
            aw.rowsByExercise[match.exerciseId]?[match.rowIndex].weight = w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : "\(w)"
        case .reps:
            aw.rowsByExercise[match.exerciseId]?[match.rowIndex].reps = "\(ghost.reps)"
        case .rir:
            aw.rowsByExercise[match.exerciseId]?[match.rowIndex].rir = ghost.rir
        }
        
        aw.isDirty = true
        store.silentUpdateActiveWorkout(aw)
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
                
                let wasCompleted = rows[index].isCompleted
                rows[index].isCompleted = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.updateActiveWorkout(aw)
                
                if newValue && !wasCompleted {
                     if prCache[rowId] == true {
                         HapticManager.shared.heavyImpact()
                     } else {
                         HapticManager.shared.success()
                     }
                     // Auto-jump to next weight field!
                     if let nextField = findNextWeightField(after: rowId) {
                         DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                             focusedField = nextField
                         }
                     } else {
                         focusedField = nil
                     }
                }
            }
        )
    }

    private func findNextWeightField(after rowId: UUID) -> WorkoutFieldFocus? {
        guard let currentIndex = cachedFields.firstIndex(where: { 
            switch $0 {
            case .weight(let id), .reps(let id), .rir(let id): return id == rowId
            }
        }) else { return nil }
        
        for i in (currentIndex + 1)..<cachedFields.count {
            if case .weight = cachedFields[i] {
                return cachedFields[i]
            }
        }
        return nil
    }

    private func bindingReps(exerciseId: UUID, rowId: UUID) -> Binding<String> {
        Binding(
            get: { store.activeWorkout?.rowsByExercise[exerciseId]?.first(where: { $0.id == rowId })?.reps ?? "" },
            set: { newValue in
                guard var aw = store.activeWorkout else { return }
                ensureAtLeastOneRow(&aw, for: exerciseId)
                guard var rows = aw.rowsByExercise[exerciseId], let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
                
                rows[index].reps = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)
                recalculatePRStatus(for: exerciseId)
                checkInstantCompletion(exerciseId: exerciseId, rowId: rowId)
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
                
                rows[index].weight = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)
                recalculatePRStatus(for: exerciseId)
                checkInstantCompletion(exerciseId: exerciseId, rowId: rowId)
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
                
                rows[index].rir = newValue
                aw.rowsByExercise[exerciseId] = rows
                aw.isDirty = true
                store.silentUpdateActiveWorkout(aw)

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
    
    private func checkInstantCompletion(exerciseId: UUID, rowId: UUID) {
        guard var aw = store.activeWorkout,
              var rows = aw.rowsByExercise[exerciseId],
              let index = rows.firstIndex(where: { $0.id == rowId }) else { return }
        
        let row = rows[index]
        let weight = row.weight.parseDoubleFlexible() ?? 0
        let reps = row.reps.parseIntFlexible() ?? 0
        let shouldBeComplete = weight > 0 && reps > 0
        
        if shouldBeComplete && !row.isCompleted {
            rows[index].isCompleted = true
            aw.rowsByExercise[exerciseId] = rows
            aw.isDirty = true
            store.updateActiveWorkout(aw)
        } else if !shouldBeComplete && row.isCompleted {
            rows[index].isCompleted = false
            aw.rowsByExercise[exerciseId] = rows
            aw.isDirty = true
            store.updateActiveWorkout(aw)
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
        updateFieldCache()
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
        updateFieldCache()
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
                updateFieldCache()
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
                updateFieldCache()
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
        updateFieldCache()
    }
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        guard var aw = store.activeWorkout else { return }
        aw.exerciseIds.move(fromOffsets: source, toOffset: destination)
        aw.isDirty = true
        store.updateActiveWorkout(aw)
        updateFieldCache()
        HapticManager.shared.lightImpact()
    }
}
