import Foundation

/// A model representing a saved progress photo.
struct ProgressPhoto: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var date: Date
    var filename: String // The name of the file saved in the Documents directory
}
