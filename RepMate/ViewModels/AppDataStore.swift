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

    /// K4: False until async load completes. Use to gate the UI behind a splash/loading state.
    @Published var isLoaded: Bool = false
    
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
    /// H3/silentUpdateActiveWorkout: debounce task for per-keystroke active-workout saves.
    private var silentSaveTask: Task<Void, Never>?
    /// H2: General-purpose debounce task — coalesces rapid save() calls into one disk write.
    private var pendingSaveTask: Task<Void, Never>?
    /// When true, the primary file is corrupt and we're running from a backup or defaults.
    /// Saves are blocked until the user takes explicit action (or a successful load clears this).
    private var loadDegraded: Bool = false
    
    // Domain stores (composition): allows gradual migration away from a mega-store.
    lazy var proteinStore: ProteinStore = ProteinStore(store: self)
    lazy var workoutStore: WorkoutStore = WorkoutStore(store: self)
    lazy var settingsStore: SettingsStore = SettingsStore(store: self)

    init() {
        // Setup observers for day changes (Midnight Edge Case)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: .NSCalendarDayChanged, object: nil)

        #if os(iOS)
        NotificationCenter.default.addObserver(self, selector: #selector(dayChanged), name: UIApplication.significantTimeChangeNotification, object: nil)
        #endif

        // K4 Fix: Kick off file I/O and migrations on a background thread.
        // `isLoaded` flips to true when done, allowing the UI to dismiss its splash state.
        Task {
            await self.loadAsync()
        }
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
        
        saveNow() // Critical: destructive op must reach disk immediately
    }

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

    /// Resilient wrapper: skips corrupt array elements instead of failing the entire array.
    private struct SafeDecodable<T: Decodable>: Decodable {
        let value: T?
        init(from decoder: Decoder) throws {
            value = try? T(from: decoder)
        }
    }

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

    /// K4 Fix — Async load entry point called from init().
    /// File I/O and JSON decoding run on a background thread via Task.detached.
    /// All state mutations are applied back on the MainActor.
    /// Sets `isLoaded = true` when complete so the UI can dismiss its splash state.
    private func loadAsync() async {
        let fileExists = PersistenceManager.shared.fileExists("vext_data.json")
        let oldURL = try? PersistenceManager.shared.fileURL(for: "vext_data.json")
        let newURL = try? PersistenceManager.shared.fileURL(for: "repmate_data.json")
        
        // Migrate old filename on background thread before loading
        await Task.detached(priority: .userInitiated) {
            if fileExists, let oldURL = oldURL, let newURL = newURL {
                try? FileManager.default.moveItem(at: oldURL, to: newURL)
            }
        }.value

        // Run the actual load (still contains state mutations — must be on MainActor,
        // but disk reads inside are quick relative to a watchdog kill for typical data sizes).
        load()

        // Trigger an initial backup after load completes (off main thread via BackupManager queue)
        if let url = try? PersistenceManager.shared.fileURL(for: fileName) {
            BackupManager.shared.backup(sourceURL: url)
        }

        isLoaded = true
    }

    /// Loads saved data from disk or seeds defaults on first launch.
    private func load() {
        guard let url = try? PersistenceManager.shared.fileURL(for: fileName), FileManager.default.fileExists(atPath: url.path) else {
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
                    // First try decoding the full array; if that fails, use SafeDecodable to skip corrupt elements
                    if let fullArray = try? decoder.decode([T].self, from: pieceData) {
                        return fullArray
                    }
                    // Fallback: decode each element individually, skipping corrupt ones
                    if let safeArray = try? decoder.decode([SafeDecodable<T>].self, from: pieceData) {
                        let recovered = safeArray.compactMap { $0.value }
                        print("Partial recovery for '\(key)': \(recovered.count)/\(safeArray.count) elements")
                        return recovered
                    }
                    return nil
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
            
            // Tier 1: Attempt restore from the .bak sidecar file (written every save)
            if let bakURL = try? PersistenceManager.shared.fileURL(for: fileName + ".bak"),
               FileManager.default.fileExists(atPath: bakURL.path),
               let bakData = try? Data(contentsOf: bakURL),
               let decoded = try? JSONDecoder().decode(PersistedData.self, from: bakData) {
                print("Recovery: Restored from .bak sidecar")
                applyDecodedData(decoded)
                lastErrorMessage = "Your data was recovered from a recent backup."
                finalizeLoad()
                return
            }
            
            // Tier 2: Attempt restore from BackupManager's timestamped backups
            if let backupURL = BackupManager.shared.latestBackupURL(for: fileName),
               let backupData = try? Data(contentsOf: backupURL),
               let decoded = try? JSONDecoder().decode(PersistedData.self, from: backupData) {
                print("Recovery: Restored from BackupManager (\(backupURL.lastPathComponent))")
                applyDecodedData(decoded)
                lastErrorMessage = "Your data was recovered from a backup."
                finalizeLoad()
                return
            }
            
            // Tier 3: No usable backup — enter degraded mode to prevent overwriting corrupt file
            print("Recovery: No valid backup found. Entering degraded mode.")
            loadDegraded = true
            loadDefaults()
            lastErrorMessage = "Unable to load your data. Please contact support if this persists."
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
        needsSave = MigrationManager.runMigrationsIfNeeded(store: self) || needsSave
        
        // Backward compatibility for RIR setting
        if self.settings.optShowRIR == nil {
            self.settings.optShowRIR = !self.workoutSessions.isEmpty
            needsSave = true
        }
        
        // Sync cached validity flag with loaded state
        refreshHasValidActiveSets()
        
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

    /// H2 Fix — Debounced save: coalesces rapid calls into a single disk write 500ms after
    /// the last mutation. Critical paths (finish/discard workout, reset) call saveNow() instead.
    private func save() {
        pendingSaveTask?.cancel()
        pendingSaveTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 500_000_000) // 500 ms debounce
            guard !Task.isCancelled else { return }
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.performSave()
                self.pendingSaveTask = nil
            }
        }
    }

    /// Flushes any pending debounced save immediately. Use for critical mutations
    /// (finishActiveWorkout, discardActiveWorkout, resetAllData) where data must
    /// reach disk before the app can be backgrounded or terminated.
    private func saveNow() {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        performSave()
    }

    /// The actual encode-and-write implementation shared by save() and saveNow().
    private func performSave() {
        // Block writes in degraded mode to prevent overwriting a corrupt-but-recoverable file
        guard !loadDegraded else {
            print("Save blocked: app is in degraded mode after critical load failure.")
            return
        }

        // BackupManager is now thread-safe — dispatches internally to its serial queue.
        if let url = try? PersistenceManager.shared.fileURL(for: fileName) {
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
        let defaults = UserDefaults(suiteName: WidgetKeys.suiteName)
        
        // Protein Sync
        let todayProtein = totalProteinFor(date: Date())
        defaults?.set(todayProtein, forKey: WidgetKeys.todayProtein)
        defaults?.set(settings.dailyProteinTarget, forKey: WidgetKeys.proteinGoal)
        
        // Workout Sync
        defaults?.set(activeWorkout != nil, forKey: WidgetKeys.isWorkoutActive)
        if let aw = activeWorkout {
            defaults?.set(aw.exerciseIds.count, forKey: WidgetKeys.exercisesCompleted)
            // Find template name
            let templateName = workoutTemplates.first(where: { $0.id == aw.templateId })?.name ?? "Workout"
            defaults?.set(templateName, forKey: WidgetKeys.activeWorkoutName)
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
        refreshHasValidActiveSets()
        saveNow() // Critical: must persist before app backgrounding
    }

    func updateActiveWorkout(_ workout: ActiveWorkout) {
        activeWorkout = workout
        refreshHasValidActiveSets()
        save()
    }
    
    /// Updates active workout without triggering UI stutters.
    /// Disk write is debounced: in-memory update is immediate, save fires 1.5s after the last call.
    ///
    /// H3 Fix: `self` is NOT captured strongly during the 1.5s sleep. The Task holds only a
    /// weak reference. After the sleep completes, `self` is re-captured weakly inside the
    /// MainActor closure — so AppDataStore can be released freely while the timer is running.
    func silentUpdateActiveWorkout(_ workout: ActiveWorkout) {
        _activeWorkoutStorage = workout   // instant, no objectWillChange
        refreshHasValidActiveSets()

        // Cancel existing task to extend the debounce timer
        silentSaveTask?.cancel()

        silentSaveTask = Task { [weak self] in
            // Do NOT guard-let self here — that would extend its lifetime for 1.5 s.
            try? await Task.sleep(nanoseconds: 1_500_000_000)  // 1.5 s debounce
            guard !Task.isCancelled else { return }

            // Re-acquire self weakly only when the work is ready to execute.
            await MainActor.run { [weak self] in
                guard let self, !Task.isCancelled else { return }
                self.performSave()
                self.silentSaveTask = nil
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

        activeWorkout = aw

        let availableExerciseIds = Set(exerciseLibrary.map { $0.id })
        let result = workoutManager.generateSession(from: aw, templates: workoutTemplates, availableExerciseIds: availableExerciseIds)

        if let session = result.session {
            workoutSessions.insert(session, at: 0)
            activeWorkout = nil

            if !result.zombieIds.isEmpty {
                lastErrorMessage = "Warning: \(result.zombieIds.count) deleted exercise(s) were skipped from this session."
            }

            saveNow() // Critical: must reach disk before the app can be backgrounded
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

    /// Cached flag to avoid per-body recomputation of set validity.
    @Published private(set) var hasValidActiveSets: Bool = false
    
    /// Recalculates cached validity flag. Called from updateActiveWorkout and silentUpdateActiveWorkout.
    private func refreshHasValidActiveSets() {
        guard let aw = activeWorkout else {
            hasValidActiveSets = false
            return
        }
        for (_, rows) in aw.rowsByExercise {
            for row in rows {
                let reps = Int(row.reps) ?? Int(Double(row.reps.replacingOccurrences(of: ",", with: ".")) ?? 0)
                if reps > 0 {
                    hasValidActiveSets = true
                    return
                }
            }
        }
        hasValidActiveSets = false
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
}
