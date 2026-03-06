
import SwiftUI
import Combine
import Foundation

/// App color palette manager.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var activeTheme: ThemeVariant = .electricBlue {
        didSet {
            UserDefaults.standard.set(activeTheme.rawValue, forKey: "activeTheme")
        }
    }
    
    // Custom Color Persistence
    @Published var customColor: Color = Color.blue {
        didSet {
            if let hex = customColor.toHex() {
                UserDefaults.standard.set(hex, forKey: "customThemeColor")
            }
        }
    }
    
    private init() {
        // Load Active Theme
        if let data = UserDefaults.standard.string(forKey: "activeTheme"),
           let theme = ThemeVariant(rawValue: data) {
            self.activeTheme = theme
        }
        
        // Load Custom Color
        if let hex = UserDefaults.standard.string(forKey: "customThemeColor") {
            self.customColor = Color(hex: hex) ?? .blue
        }
    }
    
    var palette: ThemePalette {
        if activeTheme == .custom {
            return ThemePalette(
                accent: customColor,
                glow: customColor,
                tint: customColor.opacity(0.1)
            )
        }
        return activeTheme.palette
    }
    
    // Filtered List for Menu
    static let availableThemes: [ThemeVariant] = [
        .electricBlue,
        .crimsonRed,
        .cosmicPurple
    ]
}

/// Supported theme variants.
enum ThemeVariant: String, CaseIterable, Identifiable {
    case electricBlue
    case crimsonRed
    case cosmicPurple
    case custom
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .electricBlue: return "Electric Blue 💧"
        case .crimsonRed: return "Crimson Red 🔥"
        case .cosmicPurple: return "Cosmic Purple 💜"
        case .custom: return "Custom 🎨"
        }
    }
    
    var palette: ThemePalette {
        switch self {
        case .electricBlue:
            return ThemePalette(
                accent: Color(red: 0, green: 0.6, blue: 1.0),
                glow: Color(red: 0, green: 0.4, blue: 0.8),
                tint: Color.blue.opacity(0.1)
            )
        case .crimsonRed:
            return ThemePalette(
                accent: Color(red: 0.85, green: 0.1, blue: 0.2), // Deep Crimson
                glow: Color(red: 0.6, green: 0.0, blue: 0.1),
                tint: Color.red.opacity(0.1)
            )
        case .cosmicPurple:
            return ThemePalette(
                accent: Color(red: 0.6, green: 0.15, blue: 0.9),
                glow: Color(red: 0.4, green: 0.05, blue: 0.7),
                tint: Color.purple.opacity(0.1)
            )
        case .custom:
            // Fallback if accessed directly without Manager context
            return ThemePalette(accent: .blue, glow: .blue, tint: .blue.opacity(0.1))
        }
    }
}

/// Theme palette blueprint.
struct ThemePalette {
    /// Primary UI accent.
    let accent: Color
    
    /// Secondary gradient glow.
    let glow: Color
    
    /// Material background tint.
    let tint: Color
    
    /// Diagonal accent gradient.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.8), glow.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Vertical background gradient.
    var verticalGradient: LinearGradient {
        LinearGradient(
            colors: [accent, glow],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Color Hex Helpers
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        var r: CGFloat = 0.0
        var g: CGFloat = 0.0
        var b: CGFloat = 0.0
        
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }
        
        let length = hexSanitized.count
        
        if length == 6 {
            r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
            g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
            b = CGFloat(rgb & 0x0000FF) / 255.0
        } else {
            return nil
        }
        
        self.init(red: r, green: g, blue: b)
    }
    
    func toHex() -> String? {
        // Simple conversion for sRGB. 
        // Note: This needs UIColor/CGColor underlying support.
        guard let components = self.cgColor?.components, components.count >= 3 else {
            return nil
        }
        
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        
        let hex = String(format: "#%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        return hex
    }
}
