import SwiftUI

struct ReorderExercisesView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    
    // Optional binding for templates. If nil, uses store.activeWorkout
    var templateIds: Binding<[UUID]>? = nil
    
    // Local state for the editable list
    @State private var exerciseIds: [UUID] = []
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                List {
                    ForEach(Array(exerciseIds.enumerated()), id: \.offset) { index, id in
                        if let exercise = store.exerciseLibrary.first(where: { $0.id == id }) {
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(exercise.name)
                                        .font(.headline)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                }
                                Spacer()
                                // The system provides the drag handle automatically, but we ensure content doesn't push it out
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
            if let templateIds = templateIds {
                self.exerciseIds = templateIds.wrappedValue
            } else if let aw = store.activeWorkout {
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
        if let templateIds = templateIds {
            templateIds.wrappedValue = exerciseIds
            HapticManager.shared.success()
            return
        }
        
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
