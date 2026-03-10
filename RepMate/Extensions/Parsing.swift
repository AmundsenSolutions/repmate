import Foundation

public extension String {
    /// Parses numbers from strings, supporting both . and , decimals.
    func parseIntFlexible() -> Int? {
        if let i = Int(self) { return i }
        let normalized = self.replacingOccurrences(of: ",", with: ".")
        if let d = Double(normalized) { return Int(d) }
        return nil
    }
    
    /// Parses decimals handling both . and , separators.
    func parseDoubleFlexible() -> Double? {
        let normalized = self.replacingOccurrences(of: ",", with: ".")
        return Double(normalized)
    }
}
