import Foundation

extension Notification.Name {
    static let insertTargetFieldChar = Notification.Name("insertTargetFieldChar")
    static let confirmGhostValue = Notification.Name("confirmGhostValue")
}

extension Array {
    /// Safely gets item at index.
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

extension Int {
    /// Formats seconds as readable duration.
    var formattedDuration: String {
        if self % 60 == 0 {
            return "\(self / 60)m"
        }
        if self % 30 == 0 {
            let mins = Double(self) / 60.0
            return String(format: "%.1fm", mins)
        }
        let mins = self / 60
        let secs = self % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Date Wrapper

/// Wraps Date to make it Identifiable for SwiftUI.
struct DateWrapper: Identifiable, Hashable {
    let id: UUID
    let date: Date
    
    init(_ date: Date) {
        self.id = UUID()
        self.date = date
    }
}
