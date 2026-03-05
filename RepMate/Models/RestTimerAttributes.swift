import Foundation
import ActivityKit

/// Rest timer Live Activity parameters.
struct RestTimerAttributes: ActivityAttributes {
    /// Read-only activity state.
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var isPaused: Bool
    }
    
    /// Timer duration in seconds.
    var totalDuration: Int
    
    /// Theme accent color.
    var accentR: Double
    var accentG: Double
    var accentB: Double
}
