//
//  AppDataStore.swift
//  Vext
//
//  Created by Aleksander Amundsen on 11/12/2025.
//

import Foundation
import Combine
import SwiftUI

/// Central observable store handling protein entries, settings, and persistence.
@MainActor
final class AppDataStore: ObservableObject {
    // Published = SwiftUI updates UI automatically when these change
    @Published var proteinEntries: [ProteinEntry] = []
    @Published var settings: AppSettings = .default
    @Published var workoutTemplates: [WorkoutTemplate] = []
    @Published var workoutSessions: [WorkoutSession] = []
    @Published var exerciseLibrary: [Exercise] = []
    @Published var customBarcodes: [String: CustomBarcodeEntry] = [:]
    @Published var lastErrorMessage: String? = nil
    
    // ActiveWorkout uses custom getter/setter to allow silent updates
    private var _activeWorkoutStorage: ActiveWorkout? = nil
    var activeWorkout: ActiveWorkout? {
        get { _activeWorkoutStorage }
        set {
            objectWillChange.send()
            _activeWorkoutStorage = newValue
        }
    }
    @Published var categories: [String] = []
    @Published var favoriteProteinItems: [FavoriteProtein] = []
    @Published var workoutCategories: [String] = []
    @Published var ghostDataSource: GhostDataSource = .latest
    @Published var isViewingActiveWorkout: Bool = false // Track when ActiveWorkoutView is visible
    @Published var isViewingTemplateDetail: Bool = false // Track when WorkoutDetailView is visible
    
    // Services
    let proteinManager = ProteinManager()
    let historyManager = HistoryManager()
    let workoutManager = WorkoutManager()

    private let fileName = "vext_data.json"

    init() {
        load()
        // Backup initially loaded data (safety on launch)
        if let url = PersistenceManager.shared.fileURL(for: fileName) {
            BackupManager.shared.backup(sourceURL: url)
        }
    }
    
    /// Resets all data to default state - useful for testing or fresh start
    func resetAllData() {
        proteinEntries = []
        settings = .default
        workoutTemplates = []
        workoutSessions = []
        exerciseLibrary = defaultExercises
        activeWorkout = nil
        categories = defaultCategories()
        favoriteProteinItems = []
        workoutCategories = defaultWorkoutCategories()
        customBarcodes = [:]
        
        // Re-seed default workouts
        seedDefaultWorkouts()
        
        save()
    }

    // MARK: - Protein helpers

    /// Adds a protein entry with optional note, then persists the updated list.
    func addProteinEntry(grams: Int, note: String?) {
        let entry = ProteinEntry(grams: grams, note: note)
        proteinEntries.append(entry)
        save()
    }

    /// Deletes protein entries for the current day at the provided list offsets,
    /// then saves the updated list.
    func deleteProteinEntriesForToday(at offsets: IndexSet) {
        let today = Date()
        let todayEntries = proteinEntriesFor(date: today)
        let idsToDelete = proteinManager.resolveIdsToDelete(at: offsets, in: todayEntries)

        proteinEntries.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    /// Deletes protein entries for a specific date at the provided list offsets,
    /// then saves the updated list.
    func deleteProteinEntriesFor(date: Date, at offsets: IndexSet) {
        let dateEntries = proteinEntriesFor(date: date)
        let idsToDelete = proteinManager.resolveIdsToDelete(at: offsets, in: dateEntries)

        proteinEntries.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    /// Deletes a specific protein entry by ID.
    func deleteProteinEntry(withID id: UUID) {
        proteinEntries.removeAll { $0.id == id }
        save()
    }

    /// Calculates the current hit target streak (consecutive days ending today
    /// where totalProteinFor(day) >= dailyProteinTarget).
    /// Days with no entries count as 0g and break the streak.
    func proteinStreak() -> Int {
        proteinManager.proteinStreak(entries: proteinEntries, target: settings.dailyProteinTarget)
    }

    /// Returns all protein entries occurring on the given date.
    func proteinEntriesFor(date: Date) -> [ProteinEntry] {
        proteinManager.entriesFor(date: date, in: proteinEntries)
    }

    /// Sums grams for all protein entries on the given date.
    func totalProteinFor(date: Date) -> Int {
        proteinManager.totalProtein(for: date, in: proteinEntries)
    }

    // MARK: - Protein Favorites & Quick Add
    
    /// Returns the 5 most recent unique protein entries (based on grams + note combination).
    func getRecentUniqueEntries() -> [ProteinEntry] {
        proteinManager.getRecentUniqueEntries(from: proteinEntries)
    }
    
    /// Toggles a protein entry as a favorite.
    /// If an identical favorite exists (same grams/note), it removes it. Otherwise, adds it.
    func toggleFavorite(entry: ProteinEntry) {
        if let index = favoriteProteinItems.firstIndex(where: { $0.grams == entry.grams && $0.note == entry.note }) {
            favoriteProteinItems.remove(at: index)
        } else {
            let fav = FavoriteProtein(grams: entry.grams, note: entry.note)
            favoriteProteinItems.append(fav)
        }
        save()
    }
    
    func isFavorite(entry: ProteinEntry) -> Bool {
        favoriteProteinItems.contains(where: { $0.grams == entry.grams && $0.note == entry.note })
    }
    
    func deleteFavorite(at offsets: IndexSet) {
        favoriteProteinItems.remove(atOffsets: offsets)
        save()
    }

    // MARK: - Settings

    /// Updates the daily protein target and persists settings.
    func updateDailyProteinTarget(_ grams: Int) {
        settings.dailyProteinTarget = grams
        save()
    }
    
    /// Updates the default rest time and persists settings.
    func updateRestTime(_ seconds: Int) {
        settings.restTime = seconds
        save()
    }
    
    func updateTargetRepRange(min: Int, max: Int) {
        settings.minReps = min
        settings.maxReps = max
        save()
    }
    
    /// Updates the specific muscle groups tracked in the Neglected Stats view.
    func updateTrackedMuscles(_ muscles: [String]) {
        settings.trackedMuscles = muscles
        save()
    }

    // MARK: - Workout Templates

    /// Adds a workout template and persists the updated list.
    func addWorkoutTemplate(_ template: WorkoutTemplate) {
        workoutTemplates.append(template)
        save()
    }

    /// Deletes workout templates at the provided offsets and persists the updated list.
    /// Blocks deletion if the template is currently active OR is used by historical sessions.
    func deleteWorkoutTemplate(at offsets: IndexSet) {
        let indicesToRemove = offsets.sorted(by: >)
        var blockedCount = 0
        var blockedReason: String?
        
        // Collect all template IDs used in saved sessions
        let sessionUsedTemplateIds = Set(workoutSessions.map { $0.templateId })
        
        for index in indicesToRemove {
            guard index < workoutTemplates.count else { continue }
            let template = workoutTemplates[index]
            
            // Safety Check 1: Is this template currently active?
            if let aw = activeWorkout, aw.templateId == template.id {
                print("Blocked deletion of active template: \(template.name)")
                blockedCount += 1
                blockedReason = "Cannot delete a workout template while it is active."
                continue
            }
            
            // Safety Check 2: Is this template used in any saved workout session?
            if sessionUsedTemplateIds.contains(template.id) {
                print("Blocked deletion of template used in history: \(template.name)")
                blockedCount += 1
                blockedReason = "Cannot delete a workout template that has saved sessions in history."
                continue
            }
            
            workoutTemplates.remove(at: index)
        }
        
        if blockedCount > 0 {
            lastErrorMessage = blockedReason
            HapticManager.shared.error()
        }
        save()
    }

    /// Updates an existing workout template.
    func updateWorkoutTemplate(_ template: WorkoutTemplate) {
        if let index = workoutTemplates.firstIndex(where: { $0.id == template.id }) {
            workoutTemplates[index] = template
            save()
        }
    }

    func moveWorkoutTemplate(from source: IndexSet, to destination: Int) {
        workoutTemplates.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Duplicates an existing workout template with "Copy of" prefix.
    func duplicateWorkoutTemplate(id: UUID) {
        guard let template = workoutTemplates.first(where: { $0.id == id }) else { return }
        let newTemplate = WorkoutTemplate(
            id: UUID(),
            name: "Copy of \(template.name)",
            exerciseIds: template.exerciseIds
        )
        workoutTemplates.append(newTemplate)
        save()
    }

    // MARK: - Persistence

    /// Container for encoding/decoding the persisted state.
    private struct PersistedData: Codable {
        var proteinEntries: [ProteinEntry]
        var settings: AppSettings
        var workoutTemplates: [WorkoutTemplate]
        var workoutSessions: [WorkoutSession]
        var exerciseLibrary: [Exercise]
        var activeWorkout: ActiveWorkout?
        var categories: [String]?
        var favoriteProteinItems: [FavoriteProtein]?
        var workoutCategories: [String]?
        var ghostDataSource: GhostDataSource?
        var customBarcodes: [String: CustomBarcodeEntry]?
    }

    /// Loads persisted data from disk, falling back to defaults on first launch
    /// or when decoding fails.
    private func load() {
        do {
            let decoded = try PersistenceManager.shared.load(PersistedData.self, from: fileName)
            self.proteinEntries = decoded.proteinEntries
            self.settings = decoded.settings
            self.workoutTemplates = decoded.workoutTemplates
            // Sort sessions by date descending (newest first) to establish the invariant
            self.workoutSessions = decoded.workoutSessions.sorted { $0.date > $1.date }
            self.exerciseLibrary = decoded.exerciseLibrary
            self.activeWorkout = decoded.activeWorkout
            self.categories = decoded.categories ?? defaultCategories()
            self.favoriteProteinItems = decoded.favoriteProteinItems ?? []
            self.workoutCategories = decoded.workoutCategories ?? defaultWorkoutCategories()
            self.ghostDataSource = decoded.ghostDataSource ?? .latest
            self.customBarcodes = decoded.customBarcodes ?? [:]
            
            // Seed defaults if missing
            seedDefaultWorkouts()
            
            // One-time migration: Auto-populate secondary muscles for existing exercises
            migrateSecondaryMuscles()
            
            // One-time migration: Auto-populate setupTime for existing exercises
            migrateSetupTimes()
            
            // One-time migration: Convert Arms to Biceps/Triceps
            migrateArmsToBicepsTriceps()
            
            // One-time migration: Convert Legs to Quads/Hamstrings/Glutes/Calves
            migrateLegsToGranularCategories()
        } catch PersistenceError.fileNotFound {
            print("First launch: Seeding defaults.")
            // Defaults
            activeWorkout = nil
            proteinEntries = []
            settings = .default
            workoutTemplates = []
            workoutSessions = []
            exerciseLibrary = defaultExercises
            categories = defaultCategories()
            favoriteProteinItems = []
            workoutCategories = defaultWorkoutCategories()
            customBarcodes = [:]
            
            seedDefaultWorkouts()
        } catch {
            print("CRITICAL: Error loading data: \(error)")
            lastErrorMessage = "Failed to load data. Resetting to defaults."
            
            // Reset to defaults on corruption
            proteinEntries = []
            settings = .default
            workoutTemplates = []
            workoutSessions = []
            exerciseLibrary = defaultExercises
            activeWorkout = nil
            categories = defaultCategories()
            favoriteProteinItems = []
            workoutCategories = defaultWorkoutCategories()
            customBarcodes = [:]
            
            seedDefaultWorkouts()
        }
    }

    private func defaultCategories() -> [String] {
        DefaultData.categories
    }
    
    private func defaultWorkoutCategories() -> [String] {
        DefaultData.workoutCategories
    }
    
    // MARK: - Workout Category Management
    
    func addWorkoutCategory(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty && !workoutCategories.contains(trimmed) {
            workoutCategories.append(trimmed)
            save()
        }
    }
    
    func deleteWorkoutCategory(at offsets: IndexSet) {
        let indicesToRemove = offsets.sorted(by: >)
        var blockedCount = 0
        var blockedReason: String?
        
        for index in indicesToRemove {
            guard index < workoutCategories.count else { continue }
            let name = workoutCategories[index]
            
            // Check usage
            let usedCount = workoutTemplates.filter { $0.category == name }.count
            if usedCount > 0 {
                blockedCount += 1
                blockedReason = "Cannot delete category '\(name)' because it is used by \(usedCount) workout templates."
                continue
            }
            workoutCategories.remove(at: index)
        }
        
        if blockedCount > 0 {
            lastErrorMessage = blockedReason
            HapticManager.shared.error()
        }
        save()
    }
    
    func deleteWorkoutCategory(_ category: String) {
        // Safe check
        let usedCount = workoutTemplates.filter { $0.category == category }.count
        if usedCount > 0 {
            HapticManager.shared.error()
            lastErrorMessage = "Cannot delete category '\(category)' because it is used by \(usedCount) workout templates."
            return
        }
        
        workoutCategories.removeAll { $0 == category }
        save()
    }

    /// Encodes current state to disk.
    private func save() {
        // Trigger Backup before overwrite
        if let url = PersistenceManager.shared.fileURL(for: fileName) {
            BackupManager.shared.backup(sourceURL: url)
        }
        
        let payload = PersistedData(
            proteinEntries: proteinEntries,
            settings: settings,
            workoutTemplates: workoutTemplates,
            workoutSessions: workoutSessions,
            exerciseLibrary: exerciseLibrary,
            activeWorkout: activeWorkout,
            categories: categories,
            favoriteProteinItems: favoriteProteinItems,
            workoutCategories: workoutCategories,
            ghostDataSource: ghostDataSource,
            customBarcodes: customBarcodes
        )

        PersistenceManager.shared.save(payload, to: fileName) { [weak self] result in
            if case .failure(let error) = result {
                print("Error saving data: \(error)")
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "Failed to save data."
                }
            }
        }
    }

    // MARK: - Workout Sessions

    /// Adds a workout session and persists the updated list.
    /// INVARIANT: Sessions are maintained in date-descending order (newest first).
    /// This method inserts at index 0 because new sessions are always the newest.
    func addWorkoutSession(_ session: WorkoutSession) {
        // Insert at the beginning to maintain date descending order
        workoutSessions.insert(session, at: 0)
        save()
    }

    /// Deletes workout sessions at the provided offsets and persists the updated list.
    func deleteWorkoutSession(at offsets: IndexSet) {
        let indicesToRemove = offsets.sorted(by: >)
        for index in indicesToRemove {
            guard index >= 0 && index < workoutSessions.count else { continue }
            workoutSessions.remove(at: index)
        }
        save()
    }
    
    func updateWorkoutSession(_ session: WorkoutSession) {
        if let index = workoutSessions.firstIndex(where: { $0.id == session.id }) {
            workoutSessions[index] = session
            save()
        }
    }

    // MARK: - Exercise Library

    /// Returns a default list of common exercises across all categories.
    private var defaultExercises: [Exercise] {
        DefaultData.exercises
    }

    /// Adds an exercise to the library and persists the updated list.
    @discardableResult
    func addExercise(name: String, category: String, secondaryMuscle: String? = nil, setupTime: SetupTime = .medium) -> Exercise {
        let exercise = Exercise(id: UUID(), name: name, category: category, secondaryMuscle: secondaryMuscle, setupTime: setupTime)
        exerciseLibrary.append(exercise)
        save()
        return exercise
    }
    
    /// Updates an existing exercise in the library by matching its ID.
    func updateExercise(_ exercise: Exercise) {
        if let index = exerciseLibrary.firstIndex(where: { $0.id == exercise.id }) {
            exerciseLibrary[index] = exercise
            save()
        }
    }

    /// Deletes exercises at the provided offsets and persists the updated list.
    /// If an exercise is referenced by any workout template, deletion is blocked and an error message is set.
    /// - Returns: `true` if deletion succeeded, `false` if blocked
    @discardableResult
    func deleteExercise(at offsets: IndexSet) -> Bool {
        // Map offsets to stable exercise IDs
        let idsToDelete: [UUID] = offsets.compactMap { index in
            guard index >= 0 && index < exerciseLibrary.count else { return nil }
            return exerciseLibrary[index].id
        }

        // Collect all exercise IDs used by templates
        let templateUsedIds = Set(workoutTemplates.flatMap { $0.exerciseIds })
        
        // Also check saved workout sessions for exercise usage
        let sessionUsedIds = Set(workoutSessions.flatMap { $0.sets.map { $0.exerciseId } })
        let allUsedIds = templateUsedIds.union(sessionUsedIds)

        // Block deletion if any selected exercise is used
        if idsToDelete.contains(where: { allUsedIds.contains($0) }) {
            if idsToDelete.contains(where: { sessionUsedIds.contains($0) }) {
                lastErrorMessage = "Exercise is used in a saved workout session."
            } else {
                lastErrorMessage = "Exercise is used in a workout template."
            }
            return false
        }

        // Otherwise delete the rows and persist
        let indicesToRemove = offsets.sorted(by: >)
        for index in indicesToRemove {
            guard index >= 0 && index < exerciseLibrary.count else { continue }
            exerciseLibrary.remove(at: index)
        }

        lastErrorMessage = nil
        save()
        return true
    }

    // MARK: - Category Management
    
    func addCategory(_ name: String) {
        if !categories.contains(name) {
            categories.append(name)
            save()
        }
    }
    
    func deleteCategory(at offsets: IndexSet) {
        let indicesToRemove = offsets.sorted(by: >)
        var blockedCount = 0
        var blockedReason: String?
        
        for index in indicesToRemove {
            guard index < categories.count else { continue }
            let categoryName = categories[index]
            
            // Check if any exercise uses this category
            let usedCount = exerciseLibrary.filter { $0.category == categoryName }.count
            if usedCount > 0 {
                print("Blocked deletion of category used by exercises: \(categoryName)")
                blockedCount += 1
                blockedReason = "Cannot delete category '\(categoryName)' because it contains \(usedCount) exercises."
                continue
            }
            
            categories.remove(at: index)
        }
        
        if blockedCount > 0 {
            lastErrorMessage = blockedReason
            HapticManager.shared.error()
        }
        save()
    }
    
    func moveCategory(from source: IndexSet, to destination: Int) {
        categories.move(fromOffsets: source, toOffset: destination)
        save()
    }

    // MARK: - Active Workout

    func startWorkout(template: WorkoutTemplate, force: Bool = false) {
        // If same template is already active and not forcing restart, keep it
        if !force, let aw = activeWorkout, aw.templateId == template.id {
            return
        }
        activeWorkout = ActiveWorkout.start(from: template)
        save()
    }

    func discardActiveWorkout() {
        activeWorkout = nil
        save()
    }

    func updateActiveWorkout(_ workout: ActiveWorkout) {
        activeWorkout = workout
        save()
    }
    
    /// Updates the active workout WITHOUT triggering objectWillChange.
    /// Use this for minor updates (adding sets, updating row values) to prevent full re-renders.
    func silentUpdateActiveWorkout(_ workout: ActiveWorkout) {
        // Directly update backing storage, bypassing the setter that calls objectWillChange
        _activeWorkoutStorage = workout
        save()
    }

    /// Finishes the current active workout by converting rows into SetLog entries,
    /// creating a WorkoutSession, saving it, and clearing the active workout.
    func finishActiveWorkout() {
        guard let aw = activeWorkout else { return }
        
        let availableExerciseIds = Set(exerciseLibrary.map { $0.id })
        let result = workoutManager.generateSession(from: aw, templates: workoutTemplates, availableExerciseIds: availableExerciseIds)
        
        if let session = result.session {
            addWorkoutSession(session)
            activeWorkout = nil
            
            // Warn user if zombie exercises were found
            if !result.zombieIds.isEmpty {
                lastErrorMessage = "Warning: \(result.zombieIds.count) deleted exercise(s) were skipped from this session."
            }
            
            save()
        }
    }
    
    // MARK: - History Helpers
    
    func previousSetData(for exerciseId: UUID, setIndex: Int) -> (weight: Double, reps: Int, rir: String)? {
        historyManager.previousSetData(for: exerciseId, setIndex: setIndex, in: workoutSessions)
    }

    /// Retrieve the most recent note for a specific exercise.
    func previousExerciseNote(for exerciseId: UUID) -> String? {
        historyManager.previousExerciseNote(for: exerciseId, in: workoutSessions)
    }
    
    /// Ghost data respecting the Routine vs Latest toggle.
    func ghostSetData(for exerciseId: UUID, setIndex: Int) -> (weight: Double, reps: Int, rir: String)? {
        switch ghostDataSource {
        case .latest:
            return historyManager.previousSetData(for: exerciseId, setIndex: setIndex, in: workoutSessions)
        case .routine:
            guard let templateId = activeWorkout?.templateId else {
                return historyManager.previousSetData(for: exerciseId, setIndex: setIndex, in: workoutSessions)
            }
            let filtered = workoutSessions.filter { $0.templateId == templateId }
            return historyManager.previousSetData(for: exerciseId, setIndex: setIndex, in: filtered)
        }
    }
    
    func ghostExerciseNote(for exerciseId: UUID) -> String? {
        switch ghostDataSource {
        case .latest:
            return historyManager.previousExerciseNote(for: exerciseId, in: workoutSessions)
        case .routine:
            guard let templateId = activeWorkout?.templateId else {
                return historyManager.previousExerciseNote(for: exerciseId, in: workoutSessions)
            }
            let filtered = workoutSessions.filter { $0.templateId == templateId }
            return historyManager.previousExerciseNote(for: exerciseId, in: filtered)
        }
    }
    
    // MARK: - Stats Helpers
    
    // Optimized: We now guarantee workoutSessions is sorted by date descending on load/add.
    var sortedWorkoutSessions: [WorkoutSession] {
        workoutSessions
    }
    
    func chartData(for exerciseId: UUID, months: Int) -> [(date: Date, weight: Double)] {
        historyManager.chartData(for: exerciseId, months: months, in: workoutSessions)
    }

    var hasValidActiveSets: Bool {
        guard let aw = activeWorkout else { return false }
        for (_, rows) in aw.rowsByExercise {
            for row in rows {
                let reps = Int(row.reps) ?? Int(Double(row.reps.replacingOccurrences(of: ",", with: ".")) ?? 0)
                if reps > 0 { return true }
            }
        }
        return false
    }

    // MARK: - Seeding
    
    private func seedDefaultWorkouts() {
        // CHANGED: Always ensure default templates exist, even if user deleted them
        // We check if each default exists by name, and recreate if missing
        
        let defaults = DefaultData.workouts
        
        var hasChanges = false
        
        for def in defaults {
            // Finding existing templates: match by name
            if let index = workoutTemplates.firstIndex(where: { $0.name == def.name }) {
                // Self-Healing: If existing template has 0 exercises, it's considered broken/empty.
                // We overwrite it with the default definition.
                if workoutTemplates[index].exerciseIds.isEmpty {
                    print("Seeding: Repairing empty template '\(def.name)'")
                    
                    var exerciseIds: [UUID] = []
                    var targets: [UUID: TemplateTarget] = [:]
                    
                    for exDef in def.exercises {
                        let exerciseId: UUID
                        if let existing = exerciseLibrary.first(where: { $0.name.lowercased() == exDef.name.lowercased() }) {
                            exerciseId = existing.id
                        } else {
                            let newEx = Exercise(id: UUID(), name: exDef.name, category: exDef.cat)
                            exerciseLibrary.append(newEx)
                            exerciseId = newEx.id
                        }
                        exerciseIds.append(exerciseId)
                        targets[exerciseId] = TemplateTarget(sets: exDef.sets, reps: exDef.reps, rir: exDef.rir, rest: 180)
                    }
                    
                    // Replace the empty template with the fixed one (keeping ID if desired, but replacing is safer for fresh start)
                    let repairedTemplate = WorkoutTemplate(
                        id: workoutTemplates[index].id, // Keep ID to preserve sessions? Or new ID? usage in sessions is by ID.
                        // If we keep ID, we fix sessions.
                        name: def.name,
                        exerciseIds: exerciseIds,
                        targets: targets,
                        note: def.note,
                        category: def.category
                    )
                    workoutTemplates[index] = repairedTemplate
                    hasChanges = true
                }
            } else {
                // Template doesn't exist, create it (Original Logic)
                var exerciseIds: [UUID] = []
                var targets: [UUID: TemplateTarget] = [:]
                
                for exDef in def.exercises {
                    // Find or create exercise
                    let exerciseId: UUID
                    if let existing = exerciseLibrary.first(where: { $0.name.lowercased() == exDef.name.lowercased() }) {
                        exerciseId = existing.id
                    } else {
                        let newEx = Exercise(id: UUID(), name: exDef.name, category: exDef.cat)
                        exerciseLibrary.append(newEx)
                        exerciseId = newEx.id
                    }
                    
                    exerciseIds.append(exerciseId)
                    targets[exerciseId] = TemplateTarget(sets: exDef.sets, reps: exDef.reps, rir: exDef.rir, rest: 180)
                }
                
                let template = WorkoutTemplate(
                    id: UUID(),
                    name: def.name,
                    exerciseIds: exerciseIds,
                    targets: targets,
                    note: def.note,
                    category: def.category
                )
                workoutTemplates.append(template)
                hasChanges = true
            }
        }
        
        // Always save if we made changes to templates
        if hasChanges {
            save()
        }
        
        // Seed categories if empty or missing defaults
        let defaultCats = defaultCategories()
        var catChanged = false
        for cat in defaultCats {
            if !categories.contains(cat) {
                categories.append(cat)
                catChanged = true
            }
        }
        if catChanged {
            save()
        }
        
        // Seed workout categories if empty or missing defaults
        let defaultWorkoutCats = defaultWorkoutCategories()
        var workoutCatChanged = false
        for cat in defaultWorkoutCats {
            if !workoutCategories.contains(cat) {
                workoutCategories.append(cat)
                workoutCatChanged = true
            }
        }
        if workoutCatChanged {
            save()
        }
    }
    
    // MARK: - Migrations
    
    /// One-time migration to auto-populate secondary muscles for existing exercises.
    private func migrateSecondaryMuscles() {
        var hasChanges = false
        
        for index in exerciseLibrary.indices {
            if exerciseLibrary[index].secondaryMuscle == nil {
                if let suggested = SecondaryMuscleMapping.suggestSecondaryMuscle(
                    exerciseName: exerciseLibrary[index].name,
                    primaryCategory: exerciseLibrary[index].category
                ) {
                    exerciseLibrary[index].secondaryMuscle = suggested
                    hasChanges = true
                }
            }
        }
        
        if hasChanges {
            print("Migration: Auto-populated secondary muscles for \(exerciseLibrary.filter { $0.secondaryMuscle != nil }.count) exercises")
            save()
        }
    }
    
    /// One-time migration to auto-populate setupTime for existing exercises.
    private func migrateSetupTimes() {
        var hasChanges = false
        var counts: [SetupTime: Int] = [.fast: 0, .medium: 0, .slow: 0]
        
        for index in exerciseLibrary.indices {
            // Only migrate exercises that still have the default .medium
            // We detect "not yet migrated" by checking if the suggested differs
            let suggested = SetupTimeMapping.suggestSetupTime(exerciseName: exerciseLibrary[index].name)
            if exerciseLibrary[index].setupTime != suggested {
                exerciseLibrary[index].setupTime = suggested
                counts[suggested, default: 0] += 1
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("Migration: Updated setupTimes - Fast: \(counts[.fast]!), Medium: \(counts[.medium]!), Slow: \(counts[.slow]!)")
            save()
        }
    }
    
    /// One-time migration: Convert 'Arms' exercises to 'Biceps' or 'Triceps'.
    private func migrateArmsToBicepsTriceps() {
        var hasChanges = false
        var counts: [String: Int] = ["Biceps": 0, "Triceps": 0]
        
        for index in exerciseLibrary.indices {
            if exerciseLibrary[index].category == "Arms" {
                let name = exerciseLibrary[index].name.lowercased()
                let newCategory: String
                
                if name.contains("curl") || name.contains("bicep") {
                    newCategory = "Biceps"
                } else if name.contains("extension") || name.contains("tricep") || name.contains("skull") || name.contains("dip") || name.contains("pushdown") || name.contains("press") {
                    newCategory = "Triceps"
                } else {
                    // Use Triceps as fallback
                    newCategory = "Triceps"
                }
                
                exerciseLibrary[index].category = newCategory
                counts[newCategory, default: 0] += 1
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("Migration: Converted Arms -> Biceps: \(counts["Biceps"]!), Triceps: \(counts["Triceps"]!)")
            save()
        }
    }
    
    /// One-time migration: Convert 'Legs' exercises to 'Quads', 'Hamstrings', 'Glutes', or 'Calves'.
    private func migrateLegsToGranularCategories() {
        var hasChanges = false
        var counts: [String: Int] = ["Quads": 0, "Hamstrings": 0, "Glutes": 0, "Calves": 0]
        
        for index in exerciseLibrary.indices {
            if exerciseLibrary[index].category == "Legs" {
                let name = exerciseLibrary[index].name.lowercased()
                let newCategory: String
                
                if name.contains("calf") || name.contains("calves") {
                    newCategory = "Calves"
                } else if name.contains("curl") || name.contains("romanian") || name.contains("stiff") || name.contains("rdl") {
                    newCategory = "Hamstrings"
                } else if name.contains("glute") || name.contains("hip thrust") || name.contains("bridge") {
                    newCategory = "Glutes"
                } else {
                    // Default to Quads for Squats, Leg Press, Extensions, lunges, etc.
                    newCategory = "Quads"
                }
                
                exerciseLibrary[index].category = newCategory
                counts[newCategory, default: 0] += 1
                hasChanges = true
            }
        }
        
        if hasChanges {
            print("Migration: Converted Legs -> Quads: \(counts["Quads"]!), Hamstrings: \(counts["Hamstrings"]!), Glutes: \(counts["Glutes"]!), Calves: \(counts["Calves"]!)")
            save()
        }
    }
}
