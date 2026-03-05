import SwiftUI

struct CreateExerciseView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    
    // Edit mode: pass an existing exercise to edit it
    var editingExercise: Exercise? = nil
    
    @State private var name = ""
    @State private var category = "Chest"
    @State private var secondaryMuscle: String = ""
    @State private var setupTime: SetupTime = .medium
    
    private var isEditing: Bool { editingExercise != nil }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                Form {
                    Section {
                        TextField("Name", text: $name)
                        
                        Picker("Category", selection: $category) {
                            ForEach(store.categories, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        
                        Picker("Secondary Muscle", selection: $secondaryMuscle) {
                            Text("None").tag("")
                            ForEach(store.categories.filter { $0 != category }, id: \.self) { cat in
                                Text(cat).tag(cat)
                            }
                        }
                        
                        Picker("Setup Time", selection: $setupTime) {
                            ForEach(SetupTime.allCases, id: \.self) { time in
                                Label(time.displayName, systemImage: time.icon).tag(time)
                            }
                        }
                    } footer: {
                        if !secondaryMuscle.isEmpty {
                            Text("Secondary muscle counts at 50% in the muscle heatmap.")
                                .font(.caption2)
                        }
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(isEditing ? "Edit Exercise" : "Create Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
                        saveExercise()
                        HapticManager.shared.impact()
                        dismiss()
                    }
                    .disabled(name.isEmpty)
                }
            }
            .onAppear {
                if let ex = editingExercise {
                    name = ex.name
                    category = ex.category
                    secondaryMuscle = ex.secondaryMuscle ?? ""
                    setupTime = ex.setupTime
                }
            }
            .onChange(of: category) { _, newCategory in
                // Auto-suggest secondary muscle when category changes (only for new exercises)
                if !isEditing {
                    let suggestion = SecondaryMuscleMapping.suggestSecondaryMuscle(
                        exerciseName: name,
                        primaryCategory: newCategory
                    )
                    secondaryMuscle = suggestion ?? ""
                }
            }
            .onChange(of: name) { _, newName in
                // Re-suggest when name changes too
                if !isEditing {
                    let suggestion = SecondaryMuscleMapping.suggestSecondaryMuscle(
                        exerciseName: newName,
                        primaryCategory: category
                    )
                    secondaryMuscle = suggestion ?? ""
                }
            }
        }
    }
    
    private func saveExercise() {
        let secondary = secondaryMuscle.isEmpty ? nil : secondaryMuscle
        
        if var existing = editingExercise {
            existing.name = name
            existing.category = category
            existing.secondaryMuscle = secondary
            existing.setupTime = setupTime
            store.updateExercise(existing)
        } else {
            store.addExercise(
                name: name,
                category: category,
                secondaryMuscle: secondary,
                setupTime: setupTime
            )
        }
    }
}
