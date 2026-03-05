import Foundation
import ActivityKit
import SwiftUI

/// Rest timer Live Activity manager.
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<RestTimerAttributes>?
    
    private init() {}
    
    /// Starts a rest timer Live Activity.
    func startTimer(duration: Int, accentColor: Color) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // End any existing activity first
        endTimer()
        
        // Extract RGB components from the accent color
        let (r, g, b) = extractRGB(from: accentColor)
        
        let attributes = RestTimerAttributes(
            totalDuration: duration,
            accentR: r,
            accentG: g,
            accentB: b
        )
        
        let endTime = Date().addingTimeInterval(TimeInterval(duration))
        let state = RestTimerAttributes.ContentState(
            endTime: endTime,
            isPaused: false
        )
        
        let content = ActivityContent(state: state, staleDate: endTime.addingTimeInterval(30))
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil // No push updates needed, timer is local
            )
            // Activity started successfully
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }
    
    /// Updates Live Activity end time.
    func updateTimer(newEndTime: Date) {
        guard let activity = currentActivity else { return }
        
        let state = RestTimerAttributes.ContentState(
            endTime: newEndTime,
            isPaused: false
        )
        
        let content = ActivityContent(state: state, staleDate: newEndTime.addingTimeInterval(30))
        
        Task {
            await activity.update(content)
        }
    }
    
    /// Ends all active Live Activities.
    func endTimer() {
        // End the tracked current activity
        if let activity = currentActivity {
            let finalState = RestTimerAttributes.ContentState(
                endTime: Date(),
                isPaused: false
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            
            Task {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
        
        // Safety net: End ANY other RestTimerAttributes activities (orphans from app kill)
        for activity in Activity<RestTimerAttributes>.activities {
            let finalState = RestTimerAttributes.ContentState(
                endTime: Date(),
                isPaused: false
            )
            let content = ActivityContent(state: finalState, staleDate: nil)
            
            Task {
                await activity.end(content, dismissalPolicy: .immediate)
            }
        }
        
        currentActivity = nil
    }
    
    // MARK: - Helpers
    
    private func extractRGB(from color: Color) -> (Double, Double, Double) {
        // Convert SwiftUI Color to CGColor components
        if let cgColor = color.cgColor,
           let components = cgColor.components,
           components.count >= 3 {
            return (Double(components[0]), Double(components[1]), Double(components[2]))
        }
        return (0, 0.83, 1.0) // Default: Clean Blue
    }
}
