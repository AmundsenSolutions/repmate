import Foundation

extension Array {
    /// Safely access an element at the given index.
    /// Returns nil if the index is out of bounds.
    subscript(safe index: Int) -> Element? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

extension Int {
    /// Formats seconds as a duration string.
    /// Returns "Xm" for whole minutes, "X.Xm" for half-minutes, or "M:SS" for others.
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

/// A wrapper to make Date identifiable for use in SwiftUI sheets/navigation.
struct DateWrapper: Identifiable, Hashable {
    let id: UUID
    let date: Date
    
    init(_ date: Date) {
        self.id = UUID()
        self.date = date
    }
}
