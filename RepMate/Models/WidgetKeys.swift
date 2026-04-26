import Foundation

/// M12 Fix: Centralized keys for UserDefaults shared with widgets.
enum WidgetKeys {
    static let suiteName = "group.com.repmate"
    
    // Protein keys
    static let todayProtein = "todayProtein"
    static let proteinGoal = "proteinGoal"
    
    // Workout keys
    static let isWorkoutActive = "isWorkoutActive"
    static let exercisesCompleted = "exercisesCompleted"
    static let activeWorkoutName = "activeWorkoutName"
}
