import SwiftUI

struct ExerciseLibraryView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingAddExercise = false
    @State private var showDeleteBlockedAlert = false
    @State private var searchText = ""
    @State private var showingAddCategory = false
    @State private var newCategoryName = ""
    @State private var selectedCategory: String? = nil
    @State private var editingExercise: Exercise? = nil
    
    // For "Select Mode" (Single or Multi)
    var onSelect: ((Exercise) -> Void)? = nil
    var onMultiSelect: ((Set<UUID>) -> Void)? = nil
    var isForStats: Bool = false
    
    @State private var multiSelectedIds: Set<UUID> = []
    
    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                searchBar
                categoryFilters
                exerciseList
            }
            
            // Floating Action Button for Multi-Select
            if onMultiSelect != nil && !multiSelectedIds.isEmpty {
                VStack {
                    Spacer()
                    Button(action: {
                        onMultiSelect?(multiSelectedIds)
                        dismiss()
                    }) {
                        Text("Add to Workout (\(multiSelectedIds.count))")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(themeManager.palette.accent)
                            .cornerRadius(16)
                            .shadow(color: themeManager.palette.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationTitle(selectionTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showingAddExercise) {
            CreateExerciseView()
        }
        .sheet(item: $editingExercise) { exercise in
            CreateExerciseView(editingExercise: exercise)
        }
        .alert("Cannot delete exercise", isPresented: $showDeleteBlockedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This exercise is used in a workout template.")
        }
        .alert("New Category", isPresented: $showingAddCategory) {
            TextField("Name", text: $newCategoryName)
            Button("Add") {
                let trimmed = newCategoryName.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    store.addCategory(trimmed)
                }
                newCategoryName = ""
            }
            Button("Cancel", role: .cancel) { newCategoryName = "" }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search exercises", text: $searchText)
                .foregroundColor(.white)
                .submitLabel(.done)
        }
        .padding(12)
        .background(Color(uiColor: .tertiarySystemFill))
        .cornerRadius(Theme.Spacing.cornerRadius)
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var categoryFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // "All" button
                Button {
                    selectedCategory = nil
                } label: {
                    Text("All")
                        .font(.system(size: 14, weight: .medium))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(selectedCategory == nil ? AnyView(Theme.active.verticalGradient) : AnyView(Color(uiColor: .tertiarySystemFill)))
                        .foregroundColor(selectedCategory == nil ? .black : .white) // Black text when selected
                        .cornerRadius(20)
                }
                
                // Category buttons
                ForEach(store.categories, id: \.self) { category in
                    categoryButton(for: category)
                }
                
                // Add Category Button
                Button {
                    showingAddCategory = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(uiColor: .tertiarySystemFill))
                        .foregroundColor(themeManager.palette.accent)
                        .cornerRadius(20)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    
    private func categoryButton(for category: String) -> some View {
        Button {
            selectedCategory = category
        } label: {
            Text(category)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(selectedCategory == category ? AnyView(Theme.active.verticalGradient) : AnyView(Color(uiColor: .tertiarySystemFill)))
                .foregroundColor(selectedCategory == category ? .black : .white) // Black text when selected
                .cornerRadius(20)
        }
        .contextMenu {
            Button(role: .destructive) {
                if let index = store.categories.firstIndex(of: category) {
                    store.deleteCategory(at: IndexSet(integer: index))
                }
            } label: {
                Label("Delete Category", systemImage: "trash")
            }
            .tint(.red)
        }
    }
    
    private var exerciseList: some View {
        List {
            if filteredExercises.isEmpty {
                emptyState
            } else {
                ForEach(filteredExercises) { exercise in
                    exerciseRow(for: exercise)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .scrollDismissesKeyboard(.interactively)
    }
    
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "dumbbell.fill")
                .font(.system(size: 40))
                .foregroundColor(Theme.Colors.textDim)
            Text("No Exercises Found")
                .font(.headline)
                .foregroundColor(Theme.Colors.textPrimary)
            Text("Create a new exercise to add it to your library.")
                .font(.subheadline)
                .foregroundColor(Theme.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 32)
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Spacing.cornerRadius)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }
    
    private func exerciseRow(for exercise: Exercise) -> some View {
        ExerciseCard(
            exercise: exercise,
            isSelected: multiSelectedIds.contains(exercise.id),
            selectionMode: selectionMode,
            onTap: {
                handleSelection(exercise)
            }
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button(role: .destructive) {
                let isUsed = store.workoutTemplates.contains { $0.exerciseIds.contains(exercise.id) }
                if isUsed {
                    showDeleteBlockedAlert = true
                } else {
                    if let index = store.exerciseLibrary.firstIndex(where: { $0.id == exercise.id }) {
                        _ = store.deleteExercise(at: IndexSet(integer: index))
                        HapticManager.shared.success()
                    }
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
        .swipeActions(edge: .leading) {
            Button {
                editingExercise = exercise
            } label: {
                Label("Edit", systemImage: "pencil")
            }
            .tint(Theme.Colors.accent)
        }
    }
    
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        if !isForStats {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddExercise = true
                } label: {
                    Text("Create New")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(Theme.Colors.accent)
                }
            }
        }
    }
    
    // MARK: - Logic
    
    private var selectionMode: Bool {
        onSelect != nil || onMultiSelect != nil
    }
    
    private var selectionTitle: String {
        if onMultiSelect != nil { return "Add Exercises" }
        if onSelect != nil { return "Select Exercise" }
        return "Exercise Library"
    }

    private func handleSelection(_ exercise: Exercise) {
        if let onSelect = onSelect {
            onSelect(exercise)
            dismiss()
        } else if onMultiSelect != nil {
            if multiSelectedIds.contains(exercise.id) {
                multiSelectedIds.remove(exercise.id)
            } else {
                multiSelectedIds.insert(exercise.id)
            }
        } else {
            // View Mode: Edit Exercise
            editingExercise = exercise
        }
    }
    
    private var sortedExercises: [Exercise] {
        store.exerciseLibrary.sorted { ex1, ex2 in
            if isForStats {
                let d1 = store.lastTrainedDate(for: ex1.id) ?? Date.distantPast
                let d2 = store.lastTrainedDate(for: ex2.id) ?? Date.distantPast
                if d1 != d2 {
                    return d1 > d2 // Newest first
                }
            }
            return ex1.name < ex2.name
        }
    }
    
    private var filteredExercises: [Exercise] {
        var exercises = sortedExercises
        
        if let category = selectedCategory {
            exercises = exercises.filter { $0.category == category }
        }
        
        if !searchText.isEmpty {
            exercises = exercises.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return exercises
    }
}

struct ExerciseCard: View {
    let exercise: Exercise
    var isSelected: Bool = false
    var selectionMode: Bool = false
    var onTap: (() -> Void)?
    
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(exercise.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    
                    HStack(spacing: 6) {
                        Text(exercise.category)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.Colors.accent.opacity(0.15))
                            .cornerRadius(Theme.Spacing.tight)
                        
                        if let secondary = exercise.secondaryMuscle {
                            Text(secondary)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.gray)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.gray.opacity(0.15))
                                .cornerRadius(Theme.Spacing.tight)
                        }
                    }
                }
                
                Spacer()
                
                if selectionMode {
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(themeManager.palette.accent)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 22))
                            .foregroundColor(.gray)
                    }
                }
            }
            .padding(16)
            .background(Color(uiColor: .tertiarySystemFill))
            .cornerRadius(Theme.Spacing.cornerRadius)
        }
        .buttonStyle(.plain)
    }
}
