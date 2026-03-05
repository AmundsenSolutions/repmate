import Foundation
import ActivityKit

/// Shared ActivityAttributes for the rest timer Live Activity.
/// This file must be added to BOTH the main app target AND the widget extension target.
struct RestTimerAttributes: ActivityAttributes {
    /// Static data that doesn't change during the activity
    struct ContentState: Codable, Hashable {
        var endTime: Date
        var isPaused: Bool
    }
    
    /// Total timer duration in seconds (for progress ring calculation)
    var totalDuration: Int
    
    /// Theme accent color components (widgets can't access ThemeManager)
    var accentR: Double
    var accentG: Double
    var accentB: Double
}
