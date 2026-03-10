import Foundation
import UserNotifications

@MainActor final class NotificationManager: ObservableObject {
    static let shared = NotificationManager()
    
    private init() {}
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("Notification auth error: \(error)")
            } else if granted {
                print("Notification permission granted.")
            } else {
                print("Notification permission denied.")
            }
        }
    }
    
    func scheduleWorkoutReminders(on weekdays: [Int], at time: Date) {
        requestAuthorization()
        cancelWorkoutReminders()
        
        let center = UNUserNotificationCenter.current()
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
            
            center.add(request) { error in
                if let error = error {
                    print("Error scheduling workout reminder for day \(weekday): \(error)")
                }
            }
        }
    }
    
    func cancelWorkoutReminders() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { requests in
            let identifiers = requests.map { $0.identifier }.filter { $0.hasPrefix("repmate.workout.reminder.") }
            center.removePendingNotificationRequests(withIdentifiers: identifiers)
        }
    }
    
    func scheduleProteinReminder(at time: Date) {
        requestAuthorization()
        cancelProteinReminder()
        
        let center = UNUserNotificationCenter.current()
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
        
        center.add(request) { error in
            if let error = error {
                print("Error scheduling protein reminder: \(error)")
            }
        }
    }
    
    func cancelProteinReminder() {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: ["repmate.protein.reminder"])
    }
}
