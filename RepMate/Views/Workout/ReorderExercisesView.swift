import SwiftUI

struct ReorderExercisesView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    
    // Local state for the editable list
    @State private var exerciseIds: [UUID] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                List {
                    ForEach(exerciseIds, id: \.self) { id in
                        if let exercise = store.exerciseLibrary.first(where: { $0.id == id }) {
                            Text(exercise.name)
                                .font(.headline)
                                .foregroundColor(.white)
                                .listRowBackground(Theme.Colors.cardBackground)
                        }
                    }
                    .onMove(perform: moveExercises)
                    .onDelete(perform: deleteExercises)
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
                        saveChanges()
                        dismiss()
                    }
                    .font(.headline)
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .onAppear {
            if let aw = store.activeWorkout {
                self.exerciseIds = aw.exerciseIds
            }
        }
    }
    
    private func moveExercises(from source: IndexSet, to destination: Int) {
        exerciseIds.move(fromOffsets: source, toOffset: destination)
    }
    
    private func deleteExercises(at offsets: IndexSet) {
        exerciseIds.remove(atOffsets: offsets)
    }
    
    private func saveChanges() {
        guard var aw = store.activeWorkout else { return }
        aw.exerciseIds = exerciseIds
        
        // Ensure no rows exist for deleted exercises
        var newRowsByExercise = aw.rowsByExercise
        let idSet = Set(exerciseIds)
        for key in newRowsByExercise.keys {
            if !idSet.contains(key) {
                newRowsByExercise.removeValue(forKey: key)
            }
        }
        aw.rowsByExercise = newRowsByExercise
        aw.isDirty = true
        store.updateActiveWorkout(aw)
        HapticManager.shared.success()
    }
}
