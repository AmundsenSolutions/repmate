import Foundation
import ActivityKit
import SwiftUI
@preconcurrency import UserNotifications

/// Manages the lifecycle of the Rest Timer Live Activity, handling start, update, and termination events.
@MainActor
final class LiveActivityManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = LiveActivityManager()
    
    private var currentActivity: Activity<RestTimerAttributes>?
    
    private override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    /// True if there is a Live Activity currently tracking the timer.
    var hasActiveTimer: Bool { currentActivity != nil }
    
    /// Requests a new Live Activity to track the user's rest period, injecting the upcoming exercise context for the widget UI.
    func startTimer(
        duration: Int,
        accentColor: Color,
        exerciseName: String? = nil,
        setInfo: String? = nil,
        templateName: String? = nil,
        exerciseCategory: String? = nil
    ) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // End any existing activity first
        endTimer()
        
        // Extract RGB components from the accent color
        let (r, g, b) = extractRGB(from: accentColor)
        
        let now = Date()
        let attributes = RestTimerAttributes(
            startTime: now,
            accentR: r,
            accentG: g,
            accentB: b,
            exerciseName: exerciseName,
            setInfo: setInfo,
            templateName: templateName,
            exerciseCategory: exerciseCategory
        )
        
        let endTime = now.addingTimeInterval(TimeInterval(duration))
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
            
            // Schedule local notification for timer end
            scheduleTimerNotification(duration: duration, exerciseName: exerciseName)
            
        } catch {
            print("[LiveActivity] Failed to start: \(error.localizedDescription)")
        }
    }
    
    /// Extends or overwrites the current timer's target end date.
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
        
        let newDuration = Int(newEndTime.timeIntervalSince(Date()))
        if newDuration > 0 {
            cancelTimerNotification()
            scheduleTimerNotification(duration: newDuration, exerciseName: 
            activity.attributes.exerciseName)
        }
    }
    
    /// Instantly terminates any active rest timers globally, ensuring no stale widgets remain on the Lock Screen.
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
        
        // Cancel any pending notifications when timer is ended manually
        cancelTimerNotification()
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
    
    // MARK: - Local Notifications
    
    private func scheduleTimerNotification(duration: Int, exerciseName: String?) {
        guard duration > 0 else { return }
        
        Task {
            let center = UNUserNotificationCenter.current()
            
            do {
                let settings = await center.notificationSettings()
                
                var isAuthorized = settings.authorizationStatus == .authorized
                
                if settings.authorizationStatus == .notDetermined {
                    let granted = try await center.requestAuthorization(options: [.alert, .sound])
                    isAuthorized = granted
                }
                
                guard isAuthorized else { return }
                
                // Configure notification content
                let content = UNMutableNotificationContent()
                content.title = "Rest Complete 💪"
                
                if let name = exerciseName, !name.isEmpty {
                    content.body = "Time to hit your next set — \(name)"
                } else {
                    content.body = "Time to hit your next set"
                }
                
                content.sound = .default
                
                // Trigger after given duration
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(duration), repeats: false)
                let request = UNNotificationRequest(identifier: "RestTimerNotification", content: content, trigger: trigger)
                
                try await center.add(request)
            } catch {
                print("[LiveActivity] Error scheduling notification: \(error.localizedDescription)")
            }
        }
    }
    
    private func cancelTimerNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["RestTimerNotification"])
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        // Suppress notification if app is in foreground
        return []
    }
}
