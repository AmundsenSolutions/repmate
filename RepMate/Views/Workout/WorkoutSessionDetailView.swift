import SwiftUI

struct WorkoutSessionDetailView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    @Environment(\.dismiss) private var dismiss
    
    // Original session for reference
    let originalSession: WorkoutSession
    
    // Local editable copy
    @State private var editedSets: [SetLog]
    @State private var editedNotes: String
    @State private var editedExerciseNotes: [UUID: String] // New: Per exercise notes
    @State private var isDirty = false
    @State private var showingAddExercise = false // For history editing
    @State private var editedStartDate: Date = Date()
    @State private var editedEndDate: Date = Date()
    
    @FocusState private var focusedField: WorkoutFieldFocus?
    @State private var scrollTargetID: UUID? = nil
    
    init(session: WorkoutSession) {
        self.originalSession = session
        _editedSets = State(initialValue: session.sets)
        _editedNotes = State(initialValue: session.notes ?? "")
        _editedExerciseNotes = State(initialValue: session.exerciseNotes ?? [:])
        
        // Ensure we fall back to session.date and respect any existing started/ended timestamps
        let start = session.startedAt ?? session.date
        let end = session.endedAt ?? session.date.addingTimeInterval(3600) // Default to 1 hour if no end time
        
        _editedStartDate = State(initialValue: start)
        _editedEndDate = State(initialValue: end)
    }
    
    private var template: WorkoutTemplate? {
        store.workoutTemplates.first(where: { $0.id == originalSession.templateId })
    }
    
    // Group sets by exercise, maintaining order
    private var exercisesWithSets: [(Exercise, [SetLog])] {
        var setsByExercise: [UUID: [SetLog]] = [:]
        for set in editedSets {
            setsByExercise[set.exerciseId, default: []].append(set)
        }
        
        var result: [(Exercise, [SetLog])] = []
        var seenExerciseIds = Set<UUID>()
        
        // Preserve order from editedSets
        for set in editedSets {
            if !seenExerciseIds.contains(set.exerciseId) {
                seenExerciseIds.insert(set.exerciseId)
                if let ex = store.exerciseLibrary.first(where: { $0.id == set.exerciseId }) {
                    result.append((ex, setsByExercise[set.exerciseId]?.sorted { $0.setIndex < $1.setIndex } ?? []))
                } else {
                    let unknownEx = Exercise(id: set.exerciseId, name: "Unknown Exercise", category: "Other")
                    result.append((unknownEx, setsByExercise[set.exerciseId]?.sorted { $0.setIndex < $1.setIndex } ?? []))
                }
            }
        }
        
        return result
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header Stats (matching ActiveWorkoutView)
                HStack {
                    StatItem(value: "\(exercisesWithSets.count)", label: "Exercises")
                    Spacer()
                    StatItem(value: "\(editedSets.count)", label: "Sets")
                    Spacer()
                    StatItem(value: computedDuration, label: "Duration")
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                ScrollViewReader { scrollProxy in
                    List {
                        // Time Editing Section
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Start")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                DatePicker("", selection: $editedStartDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .environment(\.colorScheme, .dark)
                                    .onChange(of: editedStartDate) { _, _ in isDirty = true }
                            }
                            
                            HStack {
                                Text("End")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                DatePicker("", selection: $editedEndDate, displayedComponents: [.date, .hourAndMinute])
                                    .labelsHidden()
                                    .environment(\.colorScheme, .dark)
                                    .onChange(of: editedEndDate) { _, _ in isDirty = true }
                            }
                            
                            TextField("Workout notes...", text: $editedNotes)
                                .font(.body)
                                .foregroundColor(themeManager.palette.accent)
                                .onChange(of: editedNotes) { _, _ in isDirty = true }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.bottom, 8)
                        
                        // Exercise Cards
                        ForEach(Array(exercisesWithSets.enumerated()), id: \.element.0.id) { index, item in
                            let (exercise, sets) = item
                            
                            ExerciseCardView(
                                index: index + 1,
                                exerciseName: exercise.name,
                                targetReps: template?.targets?[exercise.id]?.reps,
                                targetRir: template?.targets?[exercise.id]?.rir, // Show valid targets if we have them
                                targetRest: template?.targets?[exercise.id]?.rest ?? 0,
                                showRIR: store.settings.showRIR,
                                note: bindingExerciseNote(for: exercise.id),
                                ghostNote: nil
                            ) {
                                VStack(spacing: 6) {
                                    ForEach(sets) { set in
                                        editableSetRow(set: set, exerciseId: exercise.id, exerciseName: exercise.name)
                                            .id(set.id)
                                    }
                                    
                                    // Add Set Button
                                    Button {
                                        addSet(for: exercise.id, afterIndex: sets.last?.setIndex ?? 0)
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title2)
                                            .foregroundColor(themeManager.palette.accent)
                                            .padding(.top, 4)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .buttonStyle(.plain)
                                }
                            }
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        }
                        
    
                        
                        // Add Exercise Button
                        Button {
                            showingAddExercise = true
                        } label: {
                            HStack {
                                Image(systemName: "plus.circle.fill")
                                Text("Add Exercise")
                            }
                            .font(.headline)
                            .pillButton(backgroundColor: Theme.Colors.cardBackground, foregroundColor: themeManager.palette.accent)
                            .frame(maxWidth: .infinity)
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .padding(.vertical, 12)
                        .buttonStyle(.plain)
                        
                        // Spacing
                        Color.clear.frame(height: 100)
                             .listRowBackground(Color.clear)
                             .listRowSeparator(.hidden)
                    }
                    .listStyle(.plain)
                    .scrollDismissesKeyboard(.interactively)
                    .onChange(of: scrollTargetID) { _, newID in
                        if let id = newID {
                            withAnimation(.easeOut(duration: 0.2)) {
                                scrollProxy.scrollTo(id, anchor: .center)
                            }
                            scrollTargetID = nil
                        }
                    }
                } // End of ScrollViewReader
            }
            // FLOATING SAVE BUTTON
            if focusedField == nil {
                Button {
                    saveWorkout()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text("Save Workout")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        Capsule()
                            .fill(isDirty ? Theme.Colors.accent : Color.gray.opacity(0.3))
                    )
                    .foregroundColor(isDirty ? .black : .gray)
                }
                .buttonStyle(PlainButtonStyle())
                .disabled(!isDirty)
                .padding(.bottom, 24)
            }
            
            // TWO FLOATING PILLS KEYBOARD TOOLBAR
            if focusedField != nil {
                HStack(alignment: .bottom) {
                    // LEFT PILL: Navigation
                    HStack(spacing: 20) {
                        Button { focusPrevious() } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                        }
                        .disabled(isAtFirstField)
                        .foregroundColor(isAtFirstField ? Color.secondary.opacity(0.3) : themeManager.palette.accent)
                        
                        Button { focusNext() } label: {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 18, weight: .bold))
                                .frame(width: 30, height: 30)
                        }
                        .disabled(isAtLastField)
                        .foregroundColor(isAtLastField ? Color.secondary.opacity(0.3) : themeManager.palette.accent)
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
                        .foregroundColor(themeManager.palette.accent)
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
        } // End of ZStack

        .navigationTitle(template?.name ?? "Workout")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingAddExercise) {
            NavigationView {
                ExerciseLibraryView(onSelect: { exercise in
                    addExerciseToSession(exercise)
                })
            }
        }
        .toolbar(.hidden, for: .tabBar)
    }
    
    // MARK: - Subviews
    
    private func editableSetRow(set: SetLog, exerciseId: UUID, exerciseName: String) -> some View {
        SwipeToDeleteWrapper(
            onDelete: { deleteSet(id: set.id) }
        ) {
            SetRowView(
                index: set.setIndex,
                exerciseName: exerciseName,
                weight: bindingWeight(for: set.id),
                reps: bindingReps(for: set.id),
                rir: bindingRir(for: set.id),
                isCompleted: .constant(true),
                showRIR: store.settings.showRIR,
                rowId: set.id,
                focusedField: $focusedField
            )
        }
    }
    
    // MARK: - Bindings
    
    // MARK: - Keyboard Navigation
    
    private var allFields: [WorkoutFieldFocus] {
        var fields: [WorkoutFieldFocus] = []
        for (_, sets) in exercisesWithSets {
            for set in sets {
                fields.append(.weight(setId: set.id))
                fields.append(.reps(setId: set.id))
                fields.append(.rir(setId: set.id))
            }
        }
        return fields
    }
    
    private var isAtFirstField: Bool {
        guard let f = focusedField, let index = allFields.firstIndex(of: f) else { return true }
        return index == 0
    }
    
    private var isAtLastField: Bool {
        guard let f = focusedField, let index = allFields.firstIndex(of: f) else { return true }
        return index == allFields.count - 1
    }
    
    private func focusNext() {
        guard let current = focusedField, let index = allFields.firstIndex(of: current) else { return }
        if index + 1 < allFields.count {
            let nextField = allFields[index + 1]
            let id: UUID
            switch nextField {
            case .weight(let setId), .reps(let setId), .rir(let setId): id = setId
            }
            scrollTargetID = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedField = nextField
            }
        } else {
            focusedField = nil
        }
    }
    
    private func focusPrevious() {
        guard let current = focusedField, let index = allFields.firstIndex(of: current) else { return }
        if index - 1 >= 0 {
            let prevField = allFields[index - 1]
            let id: UUID
            switch prevField {
            case .weight(let setId), .reps(let setId), .rir(let setId): id = setId
            }
            scrollTargetID = id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                focusedField = prevField
            }
        } else {
            focusedField = nil
        }
    }
    
    private func bindingWeight(for setId: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let set = editedSets.first(where: { $0.id == setId }) else { return "" }
                if let w = set.weight, w > 0 {
                    return w.truncatingRemainder(dividingBy: 1) == 0 ? "\(Int(w))" : "\(w)"
                }
                return ""
            },
            set: { newValue in
                if let idx = editedSets.firstIndex(where: { $0.id == setId }) {
                    editedSets[idx].weight = Double(newValue.replacingOccurrences(of: ",", with: "."))
                    isDirty = true
                }
            }
        )
    }
    
    private func bindingReps(for setId: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let set = editedSets.first(where: { $0.id == setId }) else { return "" }
                return set.reps > 0 ? "\(set.reps)" : ""
            },
            set: { newValue in
                if let idx = editedSets.firstIndex(where: { $0.id == setId }) {
                    editedSets[idx].reps = Int(newValue) ?? 0
                    isDirty = true
                }
            }
        )
    }
    
    private func bindingRir(for setId: UUID) -> Binding<String> {
        Binding(
            get: {
                guard let set = editedSets.first(where: { $0.id == setId }) else { return "" }
                return set.rir ?? ""
            },
            set: { newValue in
                if let idx = editedSets.firstIndex(where: { $0.id == setId }) {
                    editedSets[idx].rir = newValue.isEmpty ? nil : newValue
                    isDirty = true
                }
            }
        )
    }
    
    // New: Binding for exercise note
    private func bindingExerciseNote(for exerciseId: UUID) -> Binding<String> {
        Binding(
            get: {
                editedExerciseNotes[exerciseId] ?? ""
            },
            set: { newValue in
                editedExerciseNotes[exerciseId] = newValue
                isDirty = true
            }
        )
    }
    
    // MARK: - Actions
    
    private func addSet(for exerciseId: UUID, afterIndex: Int) {
        let newSet = SetLog(
            id: UUID(),
            exerciseId: exerciseId,
            setIndex: afterIndex + 1,
            reps: 0,
            weight: nil,
            rir: nil
        )
        // Find insert position
        // We append to the raw array, but we need to ensure sort order if we want it to appear correctly?
        // Actually, the exercisesWithSets groups by exerciseId.
        // We should just append to editedSets.
        editedSets.append(newSet)
        isDirty = true
        HapticManager.shared.lightImpact()
    }
    
    private func addExerciseToSession(_ exercise: Exercise) {
        // Create 1 empty set for this new exercise
        let newSet = SetLog(
            id: UUID(),
            exerciseId: exercise.id,
            setIndex: 1, // Start at 1
            reps: 0,
            weight: nil,
            rir: nil
        )
        editedSets.append(newSet)
        isDirty = true
        HapticManager.shared.lightImpact()
    }
    
    private func deleteSet(id: UUID) {
        editedSets.removeAll { $0.id == id }
        isDirty = true
        HapticManager.shared.success()
    }
    
    private func saveWorkout() {
        // Validate: Ensure endDate is after startDate
        if editedEndDate <= editedStartDate {
            HapticManager.shared.error()
            // Optional: You could show an alert here, but Haptic + keeping isDirty true is a start
            return
        }
        
        var updatedSession = originalSession
        updatedSession.sets = editedSets
        updatedSession.notes = editedNotes.isEmpty ? nil : editedNotes
        updatedSession.exerciseNotes = editedExerciseNotes
        updatedSession.startedAt = editedStartDate
        updatedSession.endedAt = editedEndDate
        updatedSession.date = editedStartDate // Update the main date too
        
        store.updateWorkoutSession(updatedSession)
        isDirty = false
        HapticManager.shared.success()
        dismiss()
    }
    
    // MARK: - Formatting
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()
    
    private func formatDate(_ date: Date) -> String {
        return Self.dateFormatter.string(from: date)
    }
    
    private var computedDuration: String {
        let durationInSeconds = editedEndDate.timeIntervalSince(editedStartDate)
        let durationInMinutes = max(0, Int(durationInSeconds / 60))
        if durationInMinutes < 1 {
            return "< 1 min"
        }
        return "\(durationInMinutes) min"
    }
}
