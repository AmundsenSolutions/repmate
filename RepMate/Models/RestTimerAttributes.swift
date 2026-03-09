import Foundation
import ActivityKit

/// Defines the core data payload and dynamic state for the Rest Timer Live Activity widget.
struct RestTimerAttributes: ActivityAttributes {
    /// Read-only activity state.
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var isPaused: Bool
    }
    
    /// When the timer was started, used to calculate correct progress ring fill.
    var startTime: Date
    
    /// Theme accent color.
    var accentR: Double
    var accentG: Double
    var accentB: Double
    
    // Dynamic exercise context passed from ActiveWorkoutView
    var exerciseName: String?
    var setInfo: String?
    var templateName: String?
    var exerciseCategory: String?
}
