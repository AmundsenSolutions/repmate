import Foundation
import Combine
import SwiftUI
import WidgetKit

/// Core data store managing app state, user data, and persistence.
@MainActor
final class AppDataStore: ObservableObject {
    private let appGroup = "group.no.amundsen.repmate"
    // Published = SwiftUI updates UI automatically when these change
    @Published var proteinEntries: [ProteinEntry] = []
    // Manually notify changes for settings to resolve compiler errors with @Published
    var settings: AppSettings = .default {
        willSet {
            objectWillChange.send()
        }
    }
    @Published var workoutTemplates: [WorkoutTemplate] = []
    @Published var workoutSessions: [WorkoutSession] = []
    @Published var exerciseLibrary: [Exercise] = []
    @Published var customBarcodes: [String: CustomBarcodeEntry] = [:]
    
    /// Drives automatic midnight UI refreshes.
    @Published var currentDate: Date = Date()
    
    @Published var lastErrorMessage: String? = nil
    
    // ActiveWorkout uses custom getter/setter to allow silent updates
    private var _activeWorkoutStorage: ActiveWorkout? = nil
    var activeWorkout: ActiveWorkout? {
        get { _activeWorkoutStorage }
        set {
            objectWillChange.send()
            _activeWorkoutStorage = newValue
            // If we set activeWorkout explicitly, cancel any pending silent saves
            // to prevent an old state from overwriting this fresh one.
            silentSaveTask?.cancel()
            silentSaveTask = nil
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

    private let fileName = "repmate_data.json"
    /// Debounce task for silentUpdateActiveWorkout — prevents per-keystroke disk writes.
    private var silentSaveTask: Task<Void, Never>?
    
    // Domain stores (composition): allows gradual migration away from a mega-store.
    lazy var proteinStore: ProteinStore = ProteinStore(store: self)
    lazy var workoutStore: WorkoutStore = WorkoutStore(store: self)
    lazy var settingsStore: SettingsStore = SettingsStore(store: self)

    init() {
        // Migrate old vext_data.json to repmate_data.json to prevent data loss on update
        if PersistenceManager.shared.fileExists("vext_data.json") {
            if let oldURL = PersistenceManager.shared.fileURL(for: "vext_data.json"),
               let newURL = PersistenceManager.shared.fileURL(for: "repmate_data.json") {
                try? FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        }
        
        // Load data synchronously so it's ready before views render
        load()
        // Backup initially loaded data (safety on launch)
        if let url = PersistenceManager.shared.fileURL(for: fileName) {
            BackupManager.shared.backup(sourceURL: url)
        }
        
        // Setup observers for day changes (Midnight Edge Case)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)
        
        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: UIApplication.significantTimeChangeNotification, object: nil)
        #endif
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func dayChanged() {
        Task { @MainActor in
            self.currentDate = Date()
            self.objectWillChange.send()
        }
    }
    
    /// Wipes and resets all user data.
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
        _ = seedDefaultWorkouts()
        
        save()
    }

    // MARK: - Protein helpers

    /// Logs a new protein intake.
    func addProteinEntry(grams: Int, note: String?) {
        let entry = ProteinEntry(grams: grams, note: note)
        proteinEntries.append(entry)
        save()
    }

    /// Removes specific protein logs for today.
    func deleteProteinEntriesForToday(at offsets: IndexSet) {
        let today = Date()
        let todayEntries = proteinEntriesFor(date: today)
        let idsToDelete = proteinManager.resolveIdsToDelete(at: offsets, in: todayEntries)

        proteinEntries.removeAll { idsToDelete.contains($0.id) }
        save()
    }

    /// Removes specific protein logs for a given date.
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

    /// Calculates consecutive days the protein target was met.
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
    
    /// Gets recent unique protein logs for Quick Add.
    func getRecentUniqueEntries() -> [ProteinEntry] {
        proteinManager.getRecentUniqueEntries(from: proteinEntries)
    }
    
    /// Toggles a protein log in Favorites.
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

    func saveSettings() {
        save()
    }

    /// Updates the daily protein target and persists settings.
    func updateDailyProteinTarget(_ grams: Int) {
        let capped = min(max(grams, 0), 1000)
        self.settings.dailyProteinTarget = capped
        save()
    }
    
    /// Updates the default rest time and persists settings.
    func updateRestTime(_ seconds: Int) {
        let capped = min(max(seconds, 0), 600)
        self.settings.restTime = capped
        save()
    }
    
    func updateTargetRepRange(min: Int, max: Int) {
        self.settings.minReps = min
        self.settings.maxReps = max
        save()
    }
    
    /// Updates the specific muscle groups tracked in the Neglected Stats view.
    func updateTrackedMuscles(_ muscles: [String]) {
        self.settings.trackedMuscles = muscles
        save()
    }

    // MARK: - Workout Templates

    /// Adds a workout template and persists the updated list.
    func addWorkoutTemplate(_ template: WorkoutTemplate) {
        workoutTemplates.append(template)
        save()
    }

    /// Deletes templates (blocked if active or in history).
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
                blockedCount += 1
                blockedReason = "Cannot delete a workout template while it is active."
                continue
            }
            
            // Safety Check 2: Is this template used in any saved workout session?
            if sessionUsedTemplateIds.contains(template.id) {
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

    /// Deletes a workout template by ID.
    func deleteWorkoutTemplate(withId id: UUID) {
        guard let index = workoutTemplates.firstIndex(where: { $0.id == id }) else { return }
        deleteWorkoutTemplate(at: IndexSet(integer: index))
    }

    /// Updates an existing workout template.
    func updateWorkoutTemplate(_ template: WorkoutTemplate) {
        if let index = workoutTemplates.firstIndex(where: { $0.id == template.id }) {
            workoutTemplates[index] = template
            save()
        }
    }

    /// Stops any active rest timers. Called via deep link or UI.
    func stopRestTimer() {
        if var aw = activeWorkout {
            aw.timerTargetDate = nil
            updateActiveWorkout(aw)
        }
        LiveActivityManager.shared.endTimer()
    }

    func moveWorkoutTemplate(from source: IndexSet, to destination: Int) {
        workoutTemplates.move(fromOffsets: source, toOffset: destination)
        save()
    }

    /// Duplicates a template (enforces free tier limit).
    func duplicateWorkoutTemplate(id: UUID, isPro: Bool) {
        if !isPro && workoutTemplates.count >= 3 {
             lastErrorMessage = "Free limit reached"
             return
        }
        
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
        var storedSettings: AppSettings
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

    /// Loads saved data from disk or seeds defaults on first launch.
    private func load() {
        let url = PersistenceManager.shared.fileURL(for: fileName)
        guard let url = url, FileManager.default.fileExists(atPath: url.path) else {
            loadDefaults()
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            
            // 1. Attempt full decode
            do {
                let decoded = try decoder.decode(PersistedData.self, from: data)
                applyDecodedData(decoded)
            } catch {
                print("Decoding error (Initial): \(error)")
                
                // 2. Fallback: Robust Granular Decoding
                // If the full struct fails, we try to recover as much as possible.
                // We use a dictionary-based approach to pull out pieces individually.
                let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] ?? [:]
                
                // Decode components individually
                func decodePiece<T: Decodable>(_ type: T.Type, key: String) -> T? {
                    guard let pieceData = try? JSONSerialization.data(withJSONObject: json[key] ?? [:]) else { return nil }
                    do {
                        return try decoder.decode(T.self, from: pieceData)
                    } catch {
                        print("Decoding error (Piece '\(key)'): \(error)")
                        return nil
                    }
                }
                
                func decodeArrayPiece<T: Decodable>(_ type: [T].Type, key: String) -> [T]? {
                    guard let pieceData = try? JSONSerialization.data(withJSONObject: json[key] ?? []) else { return nil }
                    do {
                        return try decoder.decode([T].self, from: pieceData)
                    } catch {
                        print("Decoding error (Array Piece '\(key)'): \(error)")
                        return nil
                    }
                }

                self.proteinEntries = decodeArrayPiece([ProteinEntry].self, key: "proteinEntries") ?? []
                self.settings = decodePiece(AppSettings.self, key: "storedSettings") ?? .default
                self.workoutTemplates = decodeArrayPiece([WorkoutTemplate].self, key: "workoutTemplates") ?? []
                self.workoutSessions = (decodeArrayPiece([WorkoutSession].self, key: "workoutSessions") ?? []).sorted { $0.date > $1.date }
                self.exerciseLibrary = decodeArrayPiece([Exercise].self, key: "exerciseLibrary") ?? defaultExercises
                self.activeWorkout = decodePiece(ActiveWorkout.self, key: "activeWorkout")
                self.categories = decodeArrayPiece([String].self, key: "categories") ?? defaultCategories()
                self.favoriteProteinItems = decodeArrayPiece([FavoriteProtein].self, key: "favoriteProteinItems") ?? []
                self.workoutCategories = decodeArrayPiece([String].self, key: "workoutCategories") ?? defaultWorkoutCategories()
                self.ghostDataSource = decodePiece(GhostDataSource.self, key: "ghostDataSource") ?? .latest
                self.customBarcodes = decodePiece([String: CustomBarcodeEntry].self, key: "customBarcodes") ?? [:]
                
                lastErrorMessage = "Some settings were reset due to an update, but your workouts were preserved."
            }
            
            // Post-load migrations
            finalizeLoad()
            
        } catch {
            print("Critical Load Error: \(error)")
            loadDefaults()
        }
    }

    private func applyDecodedData(_ decoded: PersistedData) {
        self.proteinEntries = decoded.proteinEntries
        self.settings = decoded.storedSettings
        self.workoutTemplates = decoded.workoutTemplates
        self.workoutSessions = decoded.workoutSessions.sorted { $0.date > $1.date }
        self.exerciseLibrary = decoded.exerciseLibrary
        self.activeWorkout = decoded.activeWorkout
        self.categories = decoded.categories ?? defaultCategories()
        self.favoriteProteinItems = decoded.favoriteProteinItems ?? []
        self.workoutCategories = decoded.workoutCategories ?? defaultWorkoutCategories()
        self.ghostDataSource = decoded.ghostDataSource ?? .latest
        self.customBarcodes = decoded.customBarcodes ?? [:]
    }

    private func finalizeLoad() {
        var needsSave = false
        needsSave = seedDefaultWorkouts() || needsSave
        needsSave = migrateSecondaryMuscles() || needsSave
        needsSave = migrateSetupTimes() || needsSave
        needsSave = migrateArmsToBicepsTriceps() || needsSave
        needsSave = migrateLegsToGranularCategories() || needsSave
        
        // Backward compatibility for RIR setting
        if self.settings.optShowRIR == nil {
            self.settings.optShowRIR = !self.workoutSessions.isEmpty
            needsSave = true
        }
        
        if needsSave { save() }
    }

    private func loadDefaults() {
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
        
        _ = seedDefaultWorkouts()
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
            storedSettings: settings,
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
            if case .failure = result {
                DispatchQueue.main.async {
                    self?.lastErrorMessage = "Failed to save data."
                }
            } else {
                DispatchQueue.main.async {
                    self?.syncToWidgets()
                }
            }
        }
    }

    private func syncToWidgets() {
        let defaults = UserDefaults(suiteName: appGroup)
        
        // Protein Sync
        let todayProtein = totalProteinFor(date: Date())
        defaults?.set(todayProtein, forKey: "todayProtein")
        defaults?.set(settings.dailyProteinTarget, forKey: "proteinGoal")
        
        // Workout Sync
        defaults?.set(activeWorkout != nil, forKey: "isWorkoutActive")
        if let aw = activeWorkout {
            defaults?.set(aw.exerciseIds.count, forKey: "exercisesCompleted")
            // Find template name
            let templateName = workoutTemplates.first(where: { $0.id == aw.templateId })?.name ?? "Workout"
            defaults?.set(templateName, forKey: "activeWorkoutName")
        }
        
        WidgetCenter.shared.reloadAllTimelines()
    }

    // MARK: - Workout Sessions

    /// Saves a completed session (newest first).
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

    /// Adds a new exercise to the library.
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

    /// Deletes exercises if unused in history or templates.
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
        
        // Check if currently active in a workout
        let activeUsedIds = Set(activeWorkout?.exerciseIds ?? [])
        
        let allUsedIds = templateUsedIds.union(sessionUsedIds).union(activeUsedIds)

        // Block deletion if any selected exercise is used
        if idsToDelete.contains(where: { allUsedIds.contains($0) }) {
            if idsToDelete.contains(where: { activeUsedIds.contains($0) }) {
                lastErrorMessage = "Exercise is in your current active workout."
            } else if idsToDelete.contains(where: { sessionUsedIds.contains($0) }) {
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
        silentSaveTask?.cancel()
        silentSaveTask = nil
        activeWorkout = nil
        save()
    }

    func updateActiveWorkout(_ workout: ActiveWorkout) {
        activeWorkout = workout
        save()
    }
    
    /// Updates active workout without triggering UI stutters.
    /// Disk write is debounced: in-memory update is immediate, save fires 1.5s after the last call.
    func silentUpdateActiveWorkout(_ workout: ActiveWorkout) {
        _activeWorkoutStorage = workout   // instant, no objectWillChange
        
        // Cancel existing task to extend the debounce timer
        silentSaveTask?.cancel()
        
        silentSaveTask = Task { [weak self] in
            guard let self else { return }
            try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 s debounce
            guard !Task.isCancelled else { return }
            
            // Perform the save on the MainActor (AppDataStore is @MainActor, but good to be explicit)
            await MainActor.run {
                if !Task.isCancelled {
                    self.save()
                    self.silentSaveTask = nil // Clear task once done
                }
            }
        }
    }

    /// Finalizes active workout and saves to history.
    func finishActiveWorkout() -> Bool {
        silentSaveTask?.cancel()
        silentSaveTask = nil
        guard var aw = activeWorkout else { return false }
        
        // 1. Validate and sanitize sets
        var validExerciseIds: [UUID] = []
        for exId in aw.exerciseIds {
            if let rows = aw.rowsByExercise[exId] {
                let validRows = rows.filter { row in
                    let reps = Int(row.reps) ?? Int(Double(row.reps.replacingOccurrences(of: ",", with: ".")) ?? 0)
                    return reps > 0
                }
                aw.rowsByExercise[exId] = validRows
                if !validRows.isEmpty {
                    validExerciseIds.append(exId)
                }
            }
        }
        
        aw.exerciseIds = validExerciseIds
        
        // 2. Abort if no valid sets remain
        if validExerciseIds.isEmpty {
            HapticManager.shared.error()
            return false
        }
        
        // Update aw to the sanitized version
        activeWorkout = aw
        
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
            return true
        }
        return false
    }
    
    // MARK: - History Helpers
    
    func previousSetData(for exerciseId: UUID, setIndex: Int) -> (weight: Double, reps: Int, rir: String)? {
        historyManager.previousSetData(for: exerciseId, setIndex: setIndex, in: workoutSessions)
    }

    /// Gets latest exercise note.
    func previousExerciseNote(for exerciseId: UUID) -> String? {
        historyManager.previousExerciseNote(for: exerciseId, in: workoutSessions)
    }
    
    /// Gets ghost data for previous performance.
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
    
    /// Find last date exercise was performed.
    func lastTrainedDate(for exerciseId: UUID) -> Date? {
        // workoutSessions are already sorted newest first
        for session in workoutSessions {
            if session.sets.contains(where: { $0.exerciseId == exerciseId }) {
                return session.date
            }
        }
        return nil
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
    
    /// Call this after AI onboarding resolves (save or skip) so default templates
    /// only appear when the user didn't receive an AI-generated plan.
    func seedDefaultWorkoutsIfNeeded() {
        if seedDefaultWorkouts() { save() }
    }

    private func seedDefaultWorkouts() -> Bool {
        let defaults = DefaultData.workouts
        let hasSeeded = UserDefaults.standard.bool(forKey: "hasSeededDefaultWorkouts")

        // For brand-new installs: defer seeding until AI onboarding completes or is skipped.
        // This prevents default Upper/Lower templates from appearing if the user gets an AI plan.
        // Existing users (hasSeeded = true) skip this guard entirely — no data impact.
        let hasSeenAIOnboarding = UserDefaults.standard.bool(forKey: "hasSeenAIOnboarding")
        if !hasSeeded && !hasSeenAIOnboarding {
            return false
        }

        var hasChanges = false
        
        for def in defaults {
            // Finding existing templates: match by name
            if let index = workoutTemplates.firstIndex(where: { $0.name == def.name }) {
                // Self-Healing: If existing template has 0 exercises, it's considered broken/empty.
                // We overwrite it with the default definition. This ALWAYS runs if the template exists but is empty.
                if workoutTemplates[index].exerciseIds.isEmpty {
                    
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
                        targets[exerciseId] = TemplateTarget(sets: String(exDef.sets), reps: exDef.reps, rir: exDef.rir, rest: 180)
                    }
                    
                    let repairedTemplate = WorkoutTemplate(
                        id: workoutTemplates[index].id,
                        name: def.name,
                        exerciseIds: exerciseIds,
                        targets: targets,
                        note: def.note,
                        category: def.category
                    )
                    workoutTemplates[index] = repairedTemplate
                    hasChanges = true
                }
            } else if !hasSeeded {
                // Template doesn't exist AND we haven't seeded yet: Initial creation.
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
                    targets[exerciseId] = TemplateTarget(sets: String(exDef.sets), reps: exDef.reps, rir: exDef.rir, rest: 180)
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
        
        // Seed categories if empty or missing defaults (Always runs)
        let defaultCats = defaultCategories()
        for cat in defaultCats {
            if !categories.contains(cat) {
                categories.append(cat)
                hasChanges = true
            }
        }
        
        // Seed workout categories if empty or missing defaults (Always runs)
        let defaultWorkoutCats = defaultWorkoutCategories()
        for cat in defaultWorkoutCats {
            if !workoutCategories.contains(cat) {
                workoutCategories.append(cat)
                hasChanges = true
            }
        }
        
        // Mark as seeded so deleted templates stay deleted on future launches
        if !hasSeeded {
            UserDefaults.standard.set(true, forKey: "hasSeededDefaultWorkouts")
        }
        
        return hasChanges
    }
    
    // MARK: - Migrations
    
    /// Auto-fills secondary muscles for older exercises.
    @discardableResult
    private func migrateSecondaryMuscles() -> Bool {
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
        
        return hasChanges
    }
    
    /// Auto-fills setup times for older exercises.
    @discardableResult
    private func migrateSetupTimes() -> Bool {
        var hasChanges = false
        var counts: [SetupTime: Int] = [.fast: 0, .medium: 0, .slow: 0]
        
        for index in exerciseLibrary.indices {
            let suggested = SetupTimeMapping.suggestSetupTime(exerciseName: exerciseLibrary[index].name)
            if exerciseLibrary[index].setupTime != suggested {
                exerciseLibrary[index].setupTime = suggested
                counts[suggested, default: 0] += 1
                hasChanges = true
            }
        }
        
        return hasChanges
    }
    
    /// Converts 'Arms' category to Biceps/Triceps.
    @discardableResult
    private func migrateArmsToBicepsTriceps() -> Bool {
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
                    newCategory = "Triceps"
                }
                
                exerciseLibrary[index].category = newCategory
                counts[newCategory, default: 0] += 1
                hasChanges = true
            }
        }
        
        return hasChanges
    }
    
    /// Converts 'Legs' category to specific leg muscles.
    @discardableResult
    private func migrateLegsToGranularCategories() -> Bool {
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
                    newCategory = "Quads"
                }
                
                exerciseLibrary[index].category = newCategory
                counts[newCategory, default: 0] += 1
                hasChanges = true
            }
        }
        
        return hasChanges
    }
}
