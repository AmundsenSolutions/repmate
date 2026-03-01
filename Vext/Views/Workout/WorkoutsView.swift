import SwiftUI

struct WorkoutsView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Use environment for reactivity
    
    @State private var searchText = ""
    @State private var selectedFilter: String? = nil
    @State private var navigationPath = NavigationPath()
    @State private var templateToDelete: WorkoutTemplate?
    @State private var showDeleteAlert = false
    @State private var showAddCategoryAlert = false
    @State private var newCategoryName = ""
    @State private var showPaywall = false
    @EnvironmentObject var storeManager: StoreManager
    
    // Derived filters based on template names or hardcoded common ones
    private var filters: [String] {
        ["All"] + store.workoutCategories
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    searchBar
                    filterChips
                    contentList
                }
            }
            .navigationTitle("Workouts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    addTemplateButton
                }
            }
            .navigationDestination(for: WorkoutNavigation.self) { destination in
                 switch destination {
                 case .exerciseLibrary:
                     ExerciseLibraryView()
                 case .templateDetail(let id):
                     WorkoutDetailView(templateId: id, navigationPath: $navigationPath)
                 }
             }
            .alert("Delete Template?", isPresented: $showDeleteAlert, presenting: templateToDelete) { template in
                Button("Delete", role: .destructive) {
                    if let index = store.workoutTemplates.firstIndex(where: { $0.id == template.id }) {
                        store.deleteWorkoutTemplate(at: IndexSet(integer: index))
                    }
                }
                Button("Cancel", role: .cancel) {}
            } message: { template in
                Text("Are you sure you want to delete '\(template.name)'? This cannot be undone.")
            }
            .alert("Add Category", isPresented: $showAddCategoryAlert) {
                TextField("Category name", text: $newCategoryName)
                Button("Add") {
                    store.addWorkoutCategory(newCategoryName)
                    newCategoryName = ""
                    HapticManager.shared.success()
                }
                Button("Cancel", role: .cancel) {
                    newCategoryName = ""
                }
            } message: {
                Text("Enter a name for the new workout category")
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.gray)
            TextField("Search workouts", text: $searchText)
                .foregroundColor(Theme.Colors.textPrimary)
        }
        .padding(12)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Spacing.cornerRadius)
        .padding(.horizontal)
        .padding(.top, 10)
    }
    
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(filters, id: \.self) { filter in
                    Button {
                        if filter == "All" {
                            selectedFilter = nil
                        } else {
                            selectedFilter = filter
                        }
                    } label: {
                        Text(filter)
                            .font(.system(size: 14, weight: .medium))
                            .pillButton(
                                backgroundColor: (selectedFilter == filter || (selectedFilter == nil && filter == "All")) ? themeManager.palette.accent : Theme.Colors.cardBackground,
                                foregroundColor: (selectedFilter == filter || (selectedFilter == nil && filter == "All")) ? .black : .white
                            )
                    }
                    .contextMenu {
                        if filter != "All" {
                            Button(role: .destructive) {
                                store.deleteWorkoutCategory(filter)
                                if selectedFilter == filter {
                                    selectedFilter = nil
                                }
                                HapticManager.shared.success()
                            } label: {
                                Label("Delete Category", systemImage: "trash")
                            }
                        }
                    }
                }
                
                // Add Category Button
                Button {
                    showAddCategoryAlert = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .medium))
                        .pillButton(
                            backgroundColor: Theme.Colors.cardBackground,
                            foregroundColor: themeManager.palette.accent
                        )
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
    }
    

    
    private var contentList: some View {
        Group {
            if filteredTemplates.isEmpty {
                 VStack {
                    Text("No workouts found.")
                        .foregroundColor(.gray)
                        .padding(.top, 40)
                    Spacer()
                }
            } else {
                List {
                    ForEach(filteredTemplates) { template in
                        WorkoutCard(template: template,
                                    exerciseNames: exerciseNames(for: template),
                                    exerciseCount: template.exerciseIds.count,
                                    accentColor: themeManager.palette.accent,
                                    onTap: {
                                        navigationPath.append(WorkoutNavigation.templateDetail(template.id))
                                    },
                                    onEdit: {
                                        navigationPath.append(WorkoutNavigation.templateDetail(template.id))
                                    },
                                    onDuplicate: {
                                        if !storeManager.isPro && store.workoutTemplates.count >= 3 {
                                            showPaywall = true
                                            HapticManager.shared.lightImpact()
                                        } else {
                                            store.duplicateWorkoutTemplate(id: template.id, isPro: storeManager.isPro)
                                        }
                                    },
                                    onDelete: {
                                        templateToDelete = template
                                        showDeleteAlert = true
                                    })
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                templateToDelete = template
                                showDeleteAlert = true
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red) // Force RED color
                            
                            Button {
                                if !storeManager.isPro && store.workoutTemplates.count >= 3 {
                                    showPaywall = true
                                    HapticManager.shared.lightImpact()
                                } else {
                                    store.duplicateWorkoutTemplate(id: template.id, isPro: storeManager.isPro)
                                }
                            } label: {
                                Label("Duplicate", systemImage: "doc.on.doc")
                            }
                            .tint(.blue) // Always blue for duplicate
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .scrollDismissesKeyboard(.interactively)
                .padding(.bottom, 100)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
    
    private var addTemplateButton: some View {
        Button {
             if !storeManager.isPro && store.workoutTemplates.count >= 3 {
                 showPaywall = true
                 HapticManager.shared.lightImpact()
             } else {
                 let newTemplate = WorkoutTemplate(id: UUID(), name: "New Workout", exerciseIds: [])
                 store.addWorkoutTemplate(newTemplate)
                 navigationPath.append(WorkoutNavigation.templateDetail(newTemplate.id))
             }
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 22, weight: .semibold))
                .foregroundColor(themeManager.palette.accent)
        }
    }
    
    private var filteredTemplates: [WorkoutTemplate] {
        var templates = store.workoutTemplates
        
        if let filter = selectedFilter {
            // Filter by explicit category first
            templates = templates.filter { 
                if let cat = $0.category {
                    return cat == filter 
                }
                // Fallback: Check if name contains filter (for backward compatibility)
                return $0.name.localizedCaseInsensitiveContains(filter)
            }
        }
        
        if !searchText.isEmpty {
            templates = templates.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        
        return templates
    }

    private func deleteTemplates(at offsets: IndexSet) {
        store.deleteWorkoutTemplate(at: offsets)
    }

    private func moveTemplates(from source: IndexSet, to destination: Int) {
        store.moveWorkoutTemplate(from: source, to: destination)
    }

    private func exerciseNames(for template: WorkoutTemplate) -> String {
        let names = template.exerciseIds.map { exerciseId in
            store.exerciseLibrary.first(where: { $0.id == exerciseId })?.name ?? "Unknown"
        }
        if names.isEmpty { return "No exercises" }
        return names.joined(separator: ", ")
    }
}

// MARK: - Workout Card Component
struct WorkoutCard: View {
    let template: WorkoutTemplate
    let exerciseNames: String
    let exerciseCount: Int
    let accentColor: Color // Passed from parent for reactivity
    let onTap: () -> Void
    let onEdit: () -> Void
    let onDuplicate: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text(template.name)
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    
                    if let category = template.category {
                        Text(category)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(accentColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(accentColor.opacity(0.2))
                            .cornerRadius(Theme.Spacing.tight) // 8px for tags
                    }
                    
                    Text("\(exerciseCount) exercises")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    
                    Text(exerciseNames)
                        .font(.system(size: 12))
                        .foregroundColor(.gray.opacity(0.7))
                        .lineLimit(1)
                }
                
                Spacer()
                
                Menu {
                    Button(action: onEdit) {
                        Label("Edit", systemImage: "pencil")
                    }
                    Button(action: onDuplicate) {
                        Label("Duplicate", systemImage: "doc.on.doc")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundColor(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
            }
            .oledCard()
        }
        .buttonStyle(.plain) // Important for ScrollView
    }
}
