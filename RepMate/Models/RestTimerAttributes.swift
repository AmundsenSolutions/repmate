import Foundation
import ActivityKit

/// Defines the core data payload and dynamic state for the Rest Timer Live Activity widget.
struct RestTimerAttributes: ActivityAttributes {
    /// Read-only activity state.
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var isPaused: Bool
    }
    
    /// The total duration of the rest timer in seconds, used to calculate the progress ring.
    var totalDuration: Int
    
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
