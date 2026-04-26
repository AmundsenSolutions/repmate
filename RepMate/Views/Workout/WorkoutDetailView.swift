import SwiftUI

struct WorkoutDetailView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    @Environment(\.dismiss) var dismiss

    // We pass the ID so we can fetch the live binding from the store
    var templateId: UUID
    @Binding var navigationPath: NavigationPath

    @State private var showReplaceDialog = false
    
    // MARK: - Editable State
    
    private enum TopLevelFocus {
        case name, note
    }
    @FocusState private var topLevelFocus: TopLevelFocus?
    
    @State private var templateName: String = ""
    @State private var templateCategory: String? = nil // Added category state
    @State private var exerciseIds: [UUID] = []
    @State private var targets: [UUID: TemplateTarget] = [:]
    @State private var note: String = ""
    
    @State private var showingAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showingAddExercise = false
    @State private var showingReorderSheet = false
    @State private var showDeleteConfirmation = false
    
    // Init with just ID, we load in onAppear
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ZStack(alignment: .bottom) { // Changed from VStack to ZStack for solid footer positioning
                
                // Main List Content
                List {
                    // Header Section (Title + Categories + Stats + Note)
                    Group {
                        VStack(spacing: 12) {
                            // ... existing header content ...
                            VStack(spacing: 12) {
                                // Editable Title
                                TextField("Workout Name", text: $templateName)
                                    .focused($topLevelFocus, equals: .name)
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .lineLimit(2)
                                    .onChange(of: templateName) { _, newValue in
                                        if newValue.count > 200 {
                                            templateName = String(newValue.prefix(200))
                                        }
                                    }
                                    .padding(.top, 20)
                                
                                // Category Chips
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: 8) {
                                        // "No Category" Option
                                        Button(action: { templateCategory = nil }) {
                                            Text("None")
                                                .font(.caption)
                                                .fontWeight(.medium)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(templateCategory == nil ? themeManager.palette.accent : Color(uiColor: .tertiarySystemFill))
                                                .foregroundColor(templateCategory == nil ? .black : .white)
                                                .cornerRadius(Theme.Spacing.cornerRadius)
                                        }

                                        ForEach(store.workoutCategories, id: \.self) { cat in
                                            Button(action: { templateCategory = cat }) {
                                                Text(cat)
                                                    .font(.caption)
                                                    .fontWeight(.medium)
                                                    .padding(.vertical, 6)
                                                    .padding(.horizontal, 12)
                                                    .background(templateCategory == cat ? themeManager.palette.accent : Color(uiColor: .tertiarySystemFill))
                                                    .foregroundColor(templateCategory == cat ? .black : .white)
                                                    .cornerRadius(Theme.Spacing.cornerRadius)
                                            }
                                        }
                                        
                                        // Add Category Button
                                        Button {
                                            showingAddCategoryAlert = true
                                        } label: {
                                            Image(systemName: "plus")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(themeManager.palette.accent)
                                                .padding(.vertical, 6)
                                                .padding(.horizontal, 12)
                                                .background(Color(uiColor: .tertiarySystemFill))
                                                .cornerRadius(Theme.Spacing.cornerRadius)
                                        }
                                    }
                                    .padding(.horizontal)
                                }
                                
                                // Stats
                                HStack(spacing: 16) {
                                     statItem(value: "\(exerciseIds.count)", label: "Exercises")
                                     statItem(value: "~" + estimateSets(), label: "Sets")
                                     statItem(value: estimateDuration(), label: "Duration")
                                }
                                .padding(.top, 8)
                                

                                
                                // Workout Note
                                TextField("Notes...", text: $note)
                                    .focused($topLevelFocus, equals: .note)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        }
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    // Exercise List
                    ForEach(Array(exerciseIds.enumerated()), id: \.offset) { index, exerciseId in
                        if let exercise = store.exerciseLibrary.first(where: { $0.id == exerciseId }) {
                            exerciseRow(index: index + 1, exercise: exercise)
                        } else {
                            // Handle Zombie / Missing Exercise
                            HStack {
                                Text("\(index + 1). Unknown/Deleted Exercise")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.05))
                            .cornerRadius(8)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    if let idx = exerciseIds.firstIndex(of: exerciseId) {
                                        exerciseIds.remove(at: idx)
                                    }
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                                .tint(.red)
                            }
                        }
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: removeExercises)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    
                    // Add Button
                    Button {
                        showingAddExercise = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                            Text("Add Exercises")
                        }
                        .font(.headline)
                        .foregroundColor(themeManager.palette.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .cornerRadius(Theme.Spacing.compact)
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .padding(.vertical, 12)
                    .buttonStyle(.plain)
                    
                    // Spacing for footer
                     Color.clear.frame(height: 100) // Increased padding
                         .listRowBackground(Color.clear)
                         .listRowSeparator(.hidden)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        // Special char quick-tap buttons (only focused target cell responds)
                        // If topLevelFocus is set, we are editing Name or Notes, so hide them.
                        if topLevelFocus == nil {
                            Button("–") { NotificationCenter.default.post(name: .insertTargetFieldChar, object: "-") }
                                .frame(minWidth: 36)
                            Button("/") { NotificationCenter.default.post(name: .insertTargetFieldChar, object: "/") }
                                .frame(minWidth: 36)
                            Button("m") { NotificationCenter.default.post(name: .insertTargetFieldChar, object: "m") }
                                .frame(minWidth: 36)
                            Button("s") { NotificationCenter.default.post(name: .insertTargetFieldChar, object: "s") }
                                .frame(minWidth: 36)
                        }
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.semibold)
                    }
                }
                    
                // Footer
                HStack {
                    Spacer()
                    Button {
                        startWorkout()
                    } label: {
                        HStack(spacing: 8) {
                            Text("Start Workout")
                                .font(.system(size: 16, weight: .semibold))
                            Image(systemName: "arrow.right")
                                .font(.system(size: 14, weight: .bold))
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            Capsule()
                                .fill(themeManager.palette.accent)
                        )
                        .foregroundColor(.black)
                    }
                    Spacer()
                }
                .padding(.vertical, 16)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 12) {
                        // Options Menu (...)
                        Menu {
                            // Target Mode (Ghost Data Source)
                            Menu {
                                ForEach(GhostDataSource.allCases, id: \.self) { source in
                                    Button {
                                        store.ghostDataSource = source
                                    } label: {
                                        if store.ghostDataSource == source {
                                            Label(source.rawValue, systemImage: "checkmark")
                                        } else {
                                            Text(source.rawValue)
                                        }
                                    }
                                }
                            } label: {
                                Label("Compare to: \(store.ghostDataSource.rawValue)", systemImage: "arrow.triangle.2.circlepath")
                            }
                            // Reorder Exercises
                            Button {
                                showingReorderSheet = true
                                HapticManager.shared.selection()
                            } label: {
                                Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                            }
                            
                            // Share Workout
                            if let template = store.workoutTemplates.first(where: { $0.id == templateId }),
                               let shareURL = template.shareURL(exercises: store.exerciseLibrary) {
                                ShareLink(item: shareURL) {
                                    Label("Share Workout", systemImage: "square.and.arrow.up")
                                }
                            }
                            
                            Divider()
                            
                            // Delete Workout
                            Button(role: .destructive) {
                                showDeleteConfirmation = true
                            } label: {
                                Label("Delete Workout", systemImage: "trash")
                            }
                            .tint(.red)
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .font(.system(size: 18))
                                .foregroundColor(themeManager.palette.accent)
                                .contentShape(Rectangle())
                        }
                        
                        // Add Exercise
                        Button {
                            showingAddExercise = true
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 18, weight: .bold))
                                .foregroundColor(themeManager.palette.accent)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddExercise) {
                NavigationStack {
                    ExerciseLibraryView(onMultiSelect: { selectedIds in
                        self.exerciseIds.append(contentsOf: selectedIds)
                    })
                }
            }
            .sheet(isPresented: $showingReorderSheet) {
                ReorderExercisesView(templateIds: $exerciseIds)
            }
            .alert("New Category", isPresented: $showingAddCategoryAlert) {
                TextField("Category Name", text: $newCategoryName)
                Button("Add", action: {
                    if !newCategoryName.isEmpty {
                        store.addWorkoutCategory(newCategoryName)
                        templateCategory = newCategoryName
                        newCategoryName = ""
                    }
                })
                Button("Cancel", role: .cancel) {}
            }
            .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    saveData() // commit pending edits first
                    store.deleteWorkoutTemplate(withId: templateId)
                    HapticManager.shared.success()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This workout template will be permanently deleted.")
            }
            // Removed .toolbar(.hidden, for: .tabBar) to prevent pop-in glitch
            .overlay {
                if showReplaceDialog {
                    // Dim background
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture { showReplaceDialog = false }
                    
                    // Bottom-anchored dialog
                    VStack {
                        Spacer()
                        VStack(spacing: 0) {
                            // Message
                            VStack(spacing: 6) {
                                Text("Replace Active Workout?")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(.white)
                                
                                Group {
                                    if let aw = store.activeWorkout,
                                       let activeName = store.workoutTemplates.first(where: { $0.id == aw.templateId })?.name {
                                        Text("\"\(activeName)\" is currently active.\nReplace it with a fresh session?")
                                    } else {
                                        Text("You have an active workout in progress.\nStarting a new one will replace it.")
                                    }
                                }
                                .font(.caption)
                                .foregroundColor(.gray)
                                .multilineTextAlignment(.center)
                            }
                            .padding(.vertical, 16)
                            .padding(.horizontal, 20)
                            
                            Divider().background(Color.gray.opacity(0.3))
                            
                            // Replace button
                            Button {
                                showReplaceDialog = false
                                if let template = store.workoutTemplates.first(where: { $0.id == templateId }) {
                                    doStart(template: template)
                                }
                            } label: {
                                Text("Replace & Start Fresh")
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                            
                            Divider().background(Color.gray.opacity(0.3))
                            
                            // Cancel / Continue button
                            Button {
                                showReplaceDialog = false
                            } label: {
                                Text(store.activeWorkout?.templateId == templateId ? "Continue Current" : "Cancel")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 14)
                                .fill(Color(.systemGray6).opacity(0.95))
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal, 10)
                        .padding(.bottom, 8)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.85), value: showReplaceDialog)
        }
        .onAppear {
            loadData()
            store.isViewingTemplateDetail = true
        }
        .onDisappear {
            saveData()
            store.isViewingTemplateDetail = false
        }
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.caption)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func exerciseRow(index: Int, exercise: Exercise) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("\(index). \(exercise.name)")
                    .font(.headline)
                    .foregroundColor(.white)
                
                Spacer()
            }
            
            // Targets Grid (Sets, Reps, RIR, Rest)
            HStack(spacing: 0) {
                // SETS
                targetCell(
                    label: "SETS",
                    value: Binding(
                        get: { targets[exercise.id]?.sets ?? "" },
                        set: {
                            var t = targets[exercise.id] ?? defaultTarget
                            if $0.isEmpty {
                                targets[exercise.id] = nil
                            } else {
                                t.sets = $0
                                targets[exercise.id] = t
                            }
                        }
                    ),
                    ghostText: "2",
                    keyboardType: .numberPad
                )
                
                // REPS
                targetCell(
                    label: "REPS",
                    value: Binding(
                        get: { targets[exercise.id]?.reps ?? "" },
                        set: {
                            var t = targets[exercise.id] ?? defaultTarget
                            t.reps = $0
                            targets[exercise.id] = t
                        }
                    ),
                    ghostText: "4-9",
                    keyboardType: .numberPad
                )
                
                // RIR
                if store.settings.showRIR {
                    targetCell(
                        label: "RIR",
                        value: Binding(
                            get: { targets[exercise.id]?.rir ?? "" },
                            set: {
                                var t = targets[exercise.id] ?? defaultTarget
                                t.rir = $0
                                targets[exercise.id] = t
                            }
                        ),
                        ghostText: "2",
                        keyboardType: .numberPad
                    )
                }
                
                // REST
                 targetCell(
                    label: "REST",
                    value: Binding(
                        get: { formatRest(targets[exercise.id]?.rest ?? 0) },
                        set: { newValue in
                            if let seconds = parseRestTime(newValue) {
                                var t = targets[exercise.id] ?? defaultTarget
                                t.rest = seconds
                                targets[exercise.id] = t
                            }
                        }
                    ),
                    ghostText: "3m",
                    keyboardType: .numberPad
                )
            }
            .padding(12)
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
        }
        .padding(16)
        .background(Color(uiColor: .tertiarySystemFill))
        .cornerRadius(Theme.Spacing.cornerRadius)
        .padding(.horizontal, 16)
    }
    
    private let defaultTarget = TemplateTarget(sets: "2", reps: "4-9", rir: "2", rest: 180)
    
    private func targetCell(label: String, value: Binding<String>, ghostText: String, keyboardType: UIKeyboardType = .default) -> some View {
        TargetTextFieldCell(label: label, value: value, ghostText: ghostText, keyboardType: keyboardType)
    }
    
    // MARK: - Logic
    
    private func loadData() {
        if let template = store.workoutTemplates.first(where: { $0.id == templateId }) {
            templateName = template.name
            templateCategory = template.category
            exerciseIds = template.exerciseIds
            targets = template.targets ?? [:]
            note = template.note ?? ""
        }
    }
    
    private func saveData() {
        guard !templateName.isEmpty else { return }
        
        let updated = WorkoutTemplate(
            id: templateId,
            name: templateName,
            exerciseIds: exerciseIds,
            targets: targets,
            note: note.isEmpty ? nil : note,
            category: templateCategory
        )
        store.updateWorkoutTemplate(updated)
    }
    
    private func startWorkout() {
        // Dismiss keyboard and wait for animation to clear to prevent constraint errors
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.saveData() // Ensure latest changes are saved
            
            if self.store.activeWorkout != nil {
                // Always show replace dialog when a workout is active
                self.showReplaceDialog = true
                return
            }
            
            if let template = self.store.workoutTemplates.first(where: { $0.id == self.templateId }) {
                self.doStart(template: template)
            }
        }
    }
    
    private func doStart(template: WorkoutTemplate) {
        store.startWorkout(template: template, force: true)
        // Navigation handled globally by AppTabView
    }
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        exerciseIds.move(fromOffsets: source, toOffset: destination)
    }
    
    private func removeExercises(at offsets: IndexSet) {
        exerciseIds.remove(atOffsets: offsets)
    }
    
    // Helpers
    private func estimateSets() -> String {
        let total = exerciseIds.reduce(0) { sum, id in
            let setsStr = targets[id]?.sets ?? "2"
            let maxSets = setsStr.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }.max() ?? 2
            return sum + maxSets
        }
        return "\(total)"
    }
    
    private func estimateDuration() -> String {
        // Build a temporary template with current state
        let tempTemplate = WorkoutTemplate(
            id: templateId,
            name: templateName,
            exerciseIds: exerciseIds,
            targets: targets,
            note: nil,
            category: nil
        )
        let minutes = store.workoutManager.estimateTotalDuration(for: tempTemplate, userRestTime: store.settings.restTime, exerciseLibrary: store.exerciseLibrary)
        return "~\(minutes) min"
    }

    private func formatRest(_ seconds: Int) -> String {
        if seconds % 60 == 0 {
             return "\(seconds/60)m"
        }
        let mins = Double(seconds) / 60.0
        let formatted = String(format: "%g", mins)
        return "\(formatted)m"
    }
    
    private func parseRestTime(_ input: String) -> Int? {
        let lower = input.lowercased().trimmingCharacters(in: .whitespaces)
        if lower.hasSuffix("m") {
            let numStr = lower.dropLast()
            if let mins = Double(numStr) {
                return Int(mins * 60)
            }
        } else if lower.hasSuffix("s") {
            let numStr = lower.dropLast()
            return Int(numStr)
        } else if let val = Double(lower) {
            // Assume minutes if just a number
            return Int(val * 60)
        }
        return nil
    }
}

private struct TargetTextFieldCell: View {
    let label: String
    @Binding var value: String
    let ghostText: String
    var keyboardType: UIKeyboardType = .numberPad
    
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var localText: String = ""
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 2) {
             Text(label)
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(.secondary)
            
            ZStack {
                if localText.isEmpty && !isFocused {
                    Text(ghostText)
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundColor(.secondary.opacity(0.5)) // Ghost color
                }
                TextField("", text: $localText)
                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .keyboardType(keyboardType)
                    .foregroundColor(themeManager.palette.accent) // Active color
                    .focused($isFocused)
                    .onSubmit {
                        commit()
                    }
                    .onChange(of: isFocused) { _, focused in
                        if !focused { commit() }
                    }
                    // Insert special chars broadcast from the parent toolbar
                    .onReceive(NotificationCenter.default.publisher(for: .insertTargetFieldChar)) { note in
                        guard isFocused, let char = note.object as? String else { return }
                        localText += char
                        value = localText
                    }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            localText = value
        }
        .onChange(of: value) { _, newValue in
            if !isFocused {
                localText = newValue
            }
        }
    }
    
    private func commit() {
        if value != localText {
            value = localText
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if !isFocused {
                localText = value
            }
        }
    }
}
