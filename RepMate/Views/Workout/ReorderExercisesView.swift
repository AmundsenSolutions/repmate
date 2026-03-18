import SwiftUI

struct ReorderExercisesView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    
    // Optional binding for templates. If nil, uses store.activeWorkout
    var templateIds: Binding<[UUID]>? = nil
    
    // Local, visual-only list for smooth drag animation.
    // Important: this list is the sole source for List/ForEach rendering.
    @State private var exercises: [Exercise] = []
    
    // Debounced persistence task to avoid saving during the move animation.
    @State private var pendingSaveTask: Task<Void, Never>?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                List {
                    ForEach(exercises, id: \.id) { exercise in
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(exercise.name)
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            Spacer()
                            // The system provides the drag handle automatically.
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 4)
                        .listRowBackground(
                            Theme.Colors.cardBackground
                                .cornerRadius(Theme.Spacing.cornerRadius)
                                .padding(.vertical, 4)
                        )
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                    }
                    .onMove(perform: moveExercises)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active)) // Always in edit mode
            }
            .navigationTitle("Reorder Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundColor(Theme.Colors.textSecondary)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        persistNow()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .onAppear {
            loadExercisesForEditing()
        }
    }
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        withAnimation(.easeInOut(duration: 0.2)) {
            exercises.move(fromOffsets: source, toOffset: destination)
        }
        scheduleDebouncedPersist()
    }
    
    private func loadExercisesForEditing() {
        let ids: [UUID]
        if let templateIds = templateIds {
            ids = templateIds.wrappedValue
        } else if let aw = store.activeWorkout {
            ids = aw.exerciseIds
        } else {
            ids = []
        }
        
        let byId = Dictionary(uniqueKeysWithValues: store.exerciseLibrary.map { ($0.id, $0) })
        self.exercises = ids.compactMap { byId[$0] }
    }
    
    private func scheduleDebouncedPersist() {
        pendingSaveTask?.cancel()
        
        // Wait for List's reorder animation to settle before persisting.
        pendingSaveTask = Task { [templateIds] in
            try? await Task.sleep(nanoseconds: 450_000_000) // ~0.45s is enough for the move animation
            guard !Task.isCancelled else { return }
            await MainActor.run {
                persist(templateIds: templateIds, debouncedForActiveWorkout: true)
            }
        }
    }
    
    private func persistNow() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        persist(templateIds: templateIds, debouncedForActiveWorkout: false)
        HapticManager.shared.success()
    }
    
    private func persist(templateIds: Binding<[UUID]>?, debouncedForActiveWorkout: Bool) {
        let exerciseIds = exercises.map(\.id)
        
        if let templateIds {
            templateIds.wrappedValue = exerciseIds
            return
        }
        
        guard var aw = store.activeWorkout else { return }
        aw.exerciseIds = exerciseIds
        
        // Ensure no rows exist for deleted exercises
        var newRowsByExercise = aw.rowsByExercise
        let idSet = Set(exerciseIds)
        for key in newRowsByExercise.keys where !idSet.contains(key) {
            newRowsByExercise.removeValue(forKey: key)
        }
        aw.rowsByExercise = newRowsByExercise
        aw.isDirty = true
        
        if debouncedForActiveWorkout {
            // Avoid stutter: update instantly, debounce disk write.
            store.silentUpdateActiveWorkout(aw)
        } else {
            store.updateActiveWorkout(aw)
        }
    }
}
