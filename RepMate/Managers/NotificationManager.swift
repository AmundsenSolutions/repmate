import SwiftUI
import Combine
@preconcurrency import UserNotifications

@MainActor final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }
    
    func scheduleWorkoutReminders(on weekdays: [Int], at time: Date) {
        Task {
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let identifiers = requests.map { $0.identifier }.filter { $0.hasPrefix("repmate.workout.reminder.") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
            
            let calendar = Calendar.current
            let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
            
            for weekday in weekdays {
                var dateComponents = DateComponents()
                dateComponents.hour = timeComponents.hour
                dateComponents.minute = timeComponents.minute
                dateComponents.weekday = weekday
                
                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                
                let content = UNMutableNotificationContent()
                content.title = "Time to train 🏋️"
                content.body = "Don't skip today's session — your future self will thank you."
                content.sound = .default
                
                let request = UNNotificationRequest(
                    identifier: "repmate.workout.reminder.\(weekday)",
                    content: content,
                    trigger: trigger
                )
                
                try? await UNUserNotificationCenter.current().add(request)
            }
        }
    }
    
    func cancelWorkoutReminders() {
        Task {
            let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
            let identifiers = requests.map { $0.identifier }.filter { $0.hasPrefix("repmate.workout.reminder.") }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    func scheduleProteinReminder(at time: Date) {
        cancelProteinReminder()
        
        let calendar = Calendar.current
        let timeComponents = calendar.dateComponents([.hour, .minute], from: time)
        
        let trigger = UNCalendarNotificationTrigger(dateMatching: timeComponents, repeats: true)
        
        let content = UNMutableNotificationContent()
        content.title = "Log your protein 💪"
        content.body = "Stay on track with your daily target."
        content.sound = .default
        
        let request = UNNotificationRequest(
            identifier: "repmate.protein.reminder",
            content: content,
            trigger: trigger
        )
        
        Task {
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
    
    func cancelProteinReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["repmate.protein.reminder"])
    }
}
