import Foundation

/// H1, M9 Fix: Encapsulates all data migrations to avoid bloating AppDataStore.
/// Uses a version flag to avoid running heavy O(N) migrations on every launch.
final class MigrationManager {
    static let currentMigrationVersion = 1

    /// Runs all pending migrations. Returns true if any changes were made.
    @MainActor
    static func runMigrationsIfNeeded(store: AppDataStore) -> Bool {
        let savedVersion = store.settings.migrationVersion ?? 0
        guard savedVersion < currentMigrationVersion else { return false }
        
        var hasChanges = false
        
        // Version 1 migrations
        if savedVersion < 1 {
            hasChanges = migrateSecondaryMuscles(store: store) || hasChanges
            hasChanges = migrateSetupTimes(store: store) || hasChanges
            hasChanges = migrateArmsToBicepsTriceps(store: store) || hasChanges
            hasChanges = migrateLegsToGranularCategories(store: store) || hasChanges
        }
        
        // Mark migration as complete
        if hasChanges || savedVersion < currentMigrationVersion {
            store.settings.migrationVersion = currentMigrationVersion
            hasChanges = true
        }
        
        return hasChanges
    }
    
    @MainActor
    private static func migrateSecondaryMuscles(store: AppDataStore) -> Bool {
        var hasChanges = false
        for index in store.exerciseLibrary.indices {
            if store.exerciseLibrary[index].secondaryMuscle == nil {
                if let suggested = SecondaryMuscleMapping.suggestSecondaryMuscle(
                    exerciseName: store.exerciseLibrary[index].name,
                    primaryCategory: store.exerciseLibrary[index].category
                ) {
                    store.exerciseLibrary[index].secondaryMuscle = suggested
                    hasChanges = true
                }
            }
        }
        return hasChanges
    }
    
    @MainActor
    private static func migrateSetupTimes(store: AppDataStore) -> Bool {
        var hasChanges = false
        for index in store.exerciseLibrary.indices {
            let suggested = SetupTimeMapping.suggestSetupTime(exerciseName: store.exerciseLibrary[index].name)
            if store.exerciseLibrary[index].setupTime != suggested {
                store.exerciseLibrary[index].setupTime = suggested
                hasChanges = true
            }
        }
        return hasChanges
    }
    
    @MainActor
    private static func migrateArmsToBicepsTriceps(store: AppDataStore) -> Bool {
        var hasChanges = false
        for index in store.exerciseLibrary.indices {
            if store.exerciseLibrary[index].category == "Arms" {
                let name = store.exerciseLibrary[index].name.lowercased()
                let newCategory: String
                
                if name.contains("curl") || name.contains("bicep") {
                    newCategory = "Biceps"
                } else if name.contains("extension") || name.contains("tricep") || name.contains("skull") || name.contains("dip") || name.contains("pushdown") || name.contains("press") {
                    newCategory = "Triceps"
                } else {
                    newCategory = "Triceps"
                }
                
                store.exerciseLibrary[index].category = newCategory
                hasChanges = true
            }
        }
        return hasChanges
    }
    
    @MainActor
    private static func migrateLegsToGranularCategories(store: AppDataStore) -> Bool {
        var hasChanges = false
        for index in store.exerciseLibrary.indices {
            if store.exerciseLibrary[index].category == "Legs" {
                let name = store.exerciseLibrary[index].name.lowercased()
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
                
                store.exerciseLibrary[index].category = newCategory
                hasChanges = true
            }
        }
        return hasChanges
    }
}
