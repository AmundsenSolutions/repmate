import Foundation

/// A single logged protein intake.
struct ProteinEntry: Identifiable, Codable, Equatable {
    let id: UUID
    var date: Date
    var grams: Int
    var calories: Int?
    var note: String?

    /// Creates a new protein log with current time.
    init(id: UUID = UUID(),
         date: Date = Date(),
         grams: Int,
         calories: Int? = nil,
         note: String? = nil) {
        self.id = id
        self.date = date
        self.grams = grams
        self.calories = calories
        self.note = note
    }
}

/// Custom barcode mapping for unresolved items.
struct CustomBarcodeEntry: Codable, Hashable {
    var name: String
    var proteinGrams: Int
}

/// Saved quick-add protein item.
struct FavoriteProtein: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var grams: Int
    var note: String?
}
