import SwiftUI

enum HomeNavigation: Hashable {
    case activeWorkout
    case workoutSession(WorkoutSession)
    case heatmap
    case templateDetail(UUID) // For "New Workout" → template editor
}

struct HomeView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity

    @State private var showingAddProtein = false
    @State private var showingWorkoutSelection = false
    @State private var showingReplaceAlert = false
    @State private var pendingTemplate: WorkoutTemplate?
    @State private var navigationPath = NavigationPath()
    


    var body: some View {
        ZStack {
            // Main Content Layer
            NavigationStack(path: $navigationPath) {
                ZStack {
                    // Background & Gradients
                    Theme.Colors.background.ignoresSafeArea()
                    
                    // Ambient Background Glow (Dynamic)
                    if !showingWorkoutSelection {
                        Circle()
                            .fill(Theme.active.accent.opacity(0.15))
                            .frame(width: 300, height: 300)
                            .blur(radius: 100)
                            .drawingGroup()   // Rasterise: prevents per-frame blur recalc on scroll
                            .offset(x: -100, y: -200)
                    }
                    
                    ScrollView {
                        VStack(spacing: 12) {
                            // MARK: - Protein Summary Card (Hero)
                            Button {
                                navigationPath.append(HomeNavigation.heatmap)
                            } label: {
                                ProteinSummaryCard()
                            }
                            .buttonStyle(.plain)
                            
                            // MARK: - Twin Hero Cards Section
                            twinHeroCards
                            
                            // MARK: - Quick Add Section (if favorites exist)
                            if !store.favoriteProteinItems.isEmpty {
                                quickAddSection
                            }
                            
                            // MARK: - Latest Entries Section
                            if !todayEntries.isEmpty {
                                latestEntriesSection
                            }
                            
                            // MARK: - Weekly Muscle Group Overview
                            weeklyMuscleOverviewSection

                            // MARK: - Workout History
                            workoutHistorySection
                            
                            // Bottom spacer for safe area + large button
                            Color.clear.frame(height: 100)
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 24)
                        .frame(maxWidth: 600)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                    
                    // Floating Bottom Button (Log Protein)
                    VStack {
                        Spacer()
                        if !showingWorkoutSelection {
                            Button {
                                showingAddProtein = true
                                HapticManager.shared.lightImpact()
                            } label: {
                                HStack {
                                    Image(systemName: "bolt.fill")
                                    Text("Log Protein")
                                }
                                .frame(maxWidth: .infinity)
                                .contentShape(Rectangle())
                            }
                            .glowingPanelButton()
                            .frame(maxWidth: 600)
                            .padding(.horizontal, 16)
                            .padding(.bottom, store.activeWorkout != nil ? 80 : 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                        }
                    }
                }
                .navigationBarTitleDisplayMode(.inline)
                .onChange(of: store.activeWorkout) { _, newValue in
                    if newValue != nil {
                        showingWorkoutSelection = false
                        // Navigation handled by AppTabView (FullScreenCover)
                    }
                }
                .navigationDestination(for: HomeNavigation.self) { destination in
                    switch destination {
                    case .activeWorkout:
                        ActiveWorkoutView()
                    case .workoutSession(let session):
                        WorkoutSessionDetailView(session: session)
                    case .heatmap:
                        ProteinHeatmapView()
                    case .templateDetail(let id):
                        WorkoutDetailView(templateId: id, navigationPath: $navigationPath)
                    }
                }
            }
            .ignoresSafeArea(edges: .bottom)
            
            // Dimming Overlay
            if showingWorkoutSelection {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showingWorkoutSelection = false
                        }
                    }
                    .transition(.opacity)
                    .zIndex(10)
            }
            
            // Workout Selection Glass Sheet
            if showingWorkoutSelection {
                VStack {
                    Spacer()
                    WorkoutSelectionSheet(
                        isPresented: $showingWorkoutSelection,
                        onCreateNewTemplate: { templateId in
                            navigationPath.append(HomeNavigation.templateDetail(templateId))
                        }
                    )
                        .transition(.move(edge: .bottom))
                }
                .zIndex(11)
                .ignoresSafeArea(edges: .bottom)
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: showingWorkoutSelection)
        .sheet(isPresented: $showingAddProtein) {
            AddProteinEntryView()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .alert("Replace Active Workout?", isPresented: $showingReplaceAlert) {
            Button("Start Fresh", role: .destructive) {
                if let template = pendingTemplate {
                    store.startWorkout(template: template, force: true)
                    HapticManager.shared.success()
                }
                pendingTemplate = nil
            }
            Button("Cancel", role: .cancel) {
                pendingTemplate = nil
            }
        } message: {
            if let template = pendingTemplate {
                Text("You already have an active session for \"\(template.name)\". Do you want to restart it?")
            } else {
                Text("This will discard your current active workout.")
            }
        }
    }
    
    // MARK: - Twin Hero Cards
    
    private var twinHeroCards: some View {
        VStack(spacing: 16) {
            // Training Card
            if store.workoutSessions.isEmpty && store.activeWorkout == nil {
                trainingHeroCard
            }
            
            // Nutrition Card
            if todayEntries.isEmpty {
                nutritionHeroCard
            }
        }
    }
    
    private var trainingHeroCard: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                showingWorkoutSelection = true
                HapticManager.shared.lightImpact()
            }
        } label: {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.active.accent.opacity(0.5), lineWidth: 1)
                        .frame(width: 50, height: 50)
                        .background(Theme.active.accent.opacity(0.1))
                        .cornerRadius(12)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.active.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready for your first lift?")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Start a workout")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Theme.active.accent.opacity(0.4), radius: 5)
                    
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
            .glassCard(style: .primary)
        }
        .buttonStyle(.plain)
    }
    
    private var nutritionHeroCard: some View {
        Button {
            showingAddProtein = true
            HapticManager.shared.lightImpact()
        } label: {
            HStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Theme.active.accent.opacity(0.5), lineWidth: 1)
                        .frame(width: 50, height: 50)
                        .background(Theme.active.accent.opacity(0.1))
                        .cornerRadius(12)
                    
                    Image(systemName: "fork.knife")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.active.accent)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Log your first meal")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.white)
                    
                    Text("Track your protein")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.ultraThinMaterial)
                        .frame(width: 40, height: 40)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.3), lineWidth: 1)
                        )
                        .shadow(color: Theme.active.accent.opacity(0.4), radius: 5)
                    
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
            .contentShape(Rectangle())
            .glassCard(style: .secondary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Quick Add Favorites Section
    
    private var quickAddSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Add")
                .sectionHeader()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(store.favoriteProteinItems) { entry in
                        Button {
                            store.addProteinEntry(grams: entry.grams, note: entry.note)
                            HapticManager.shared.lightImpact()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.active.accent)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.note ?? "Protein")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.white)
                                        .lineLimit(1)
                                    
                                    Text("\(entry.grams)g")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .fill(Color.black.opacity(0.5))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 20, style: .continuous)
                                    .stroke(Theme.active.accent.opacity(0.3), lineWidth: 1)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
            }
        }
    }
    
    // MARK: - Latest Entries Section
    
    private var latestEntriesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Latest Entries")
                .sectionHeader()
            
            List {
                ForEach(todayEntries.prefix(3)) { entry in
                    entryRow(for: entry)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets())
                        .swipeActions(edge: .leading) {
                            Button {
                                store.toggleFavorite(entry: entry)
                                HapticManager.shared.success()
                            } label: {
                                Label("Favorite", systemImage: store.isFavorite(entry: entry) ? "star.slash" : "star")
                            }
                            .tint(Theme.active.accent)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                store.deleteProteinEntry(withID: entry.id)
                                HapticManager.shared.success()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .scrollDisabled(true)
            .frame(height: CGFloat(todayEntries.prefix(3).count * 76))
        }
    }
    
    private func entryRow(for entry: ProteinEntry) -> some View {
        HStack {
            Text(entry.date, style: .time)
                .font(.system(size: 13, weight: .regular, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 55, alignment: .leading)
            
            Text(entry.note ?? "Protein")
                .font(.system(size: 15, weight: .regular))
                .foregroundColor(.white)
                .lineLimit(1)
            
            Spacer()
            
            Text("\(entry.grams)g")
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.active.accent)
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: Theme.Spacing.cornerRadius, style: .continuous)
                .fill(Color.black.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Spacing.cornerRadius, style: .continuous)
                .stroke(Theme.active.accent.opacity(0.15), lineWidth: 1)
        )
        .contextMenu {
            Button {
                store.toggleFavorite(entry: entry)
                HapticManager.shared.success()
            } label: {
                Label(store.isFavorite(entry: entry) ? "Unfavorite" : "Favorite",
                      systemImage: store.isFavorite(entry: entry) ? "star.slash" : "star")
            }
            Button(role: .destructive) {
                withAnimation {
                    store.deleteProteinEntry(withID: entry.id)
                }
                HapticManager.shared.success()
            } label: {
                Label("Delete", systemImage: "trash")
            }
            .tint(.red)
        }
    }
    
    // MARK: - Workout History Section
    
    private var workoutHistorySection: some View {
        WorkoutHistoryCard(
            onSelectSession: { session in
                navigationPath.append(HomeNavigation.workoutSession(session))
            },
            onDeleteSession: { offsets in
                deleteWorkoutSessions(at: offsets)
            }
        )
        .frame(minHeight: 1)
    }
    
    // MARK: - Helpers
    
    private var todayEntries: [ProteinEntry] {
        store.proteinEntriesFor(date: store.currentDate).sorted { $0.date > $1.date }
    }
    
    private func deleteWorkoutSessions(at offsets: IndexSet) {
        let sessions = store.workoutSessions
        let indicesToDelete = offsets.compactMap { categoryIndex -> Int? in
            guard categoryIndex >= 0 && categoryIndex < sessions.count else { return nil }
            let session = sessions[categoryIndex]
            return store.workoutSessions.firstIndex(where: { $0.id == session.id })
        }
        store.deleteWorkoutSession(at: IndexSet(indicesToDelete))
    }
    
    // MARK: - Weekly Muscle Group Overview
    
    private var weeklyMuscleOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("This Week")
                .sectionHeader()
            
            let volume = store.workoutManager.getCategoryVolume(
                sessions: store.workoutSessions,
                exerciseLibrary: store.exerciseLibrary,
                days: 7
            )
            
            if volume.isEmpty {
                Text("No activity yet this week.")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(volume.sorted(by: { $0.value > $1.value }).prefix(5), id: \.key) { category, sets in
                        HStack {
                            Text(category)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            Spacer()
                            Text("\(Int(sets)) sets")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(Theme.active.accent)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color.black.opacity(0.4))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }

    private func startWorkout(template: WorkoutTemplate) {
        if let current = store.activeWorkout, current.templateId == template.id {
            pendingTemplate = template
            showingReplaceAlert = true
            return
        }
        
        store.startWorkout(template: template, force: true)
        HapticManager.shared.success()
    }
    
    private func startNewWorkout() {
        startWorkout(template: .empty)
    }
}

#Preview {
    HomeView()
        .environmentObject(AppDataStore())
}
