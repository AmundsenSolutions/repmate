
import SwiftUI
import Combine
import Foundation

/// Manages the application's theme/color palette.
/// Features a "Glass Clean" base aesthetic with dynamic accent colors.
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    
    @Published var activeTheme: ThemeVariant = .cleanBlue {
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
        .cleanBlue,
        .neonPurple,
        .lavaRed
    ]
}

/// Defines the available theme variants for the Multi-Theme Engine.
enum ThemeVariant: String, CaseIterable, Identifiable {
    case cleanBlue
    case neonPurple
    case lavaRed
    case arcticWhite // Keep only requested core cases in the main logic if desired, but for enum stability we keep cases.
    // We will use ThemeManager.availableThemes to filter the UI.
    
    // Kept for backward compatibility if user had these selected, 
    // but they won't appear in the new menu.
    case forestGreen
    case oceanTeal
    case cyberGold
    case deepIndigo
    case sunsetOrange
    case royalMagenta
    
    case custom // New case
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .cleanBlue: return "Clean Blue 💧"
        case .neonPurple: return "Neon Purple 💜"
        case .lavaRed: return "Lava Red 🔥"
        case .arcticWhite: return "Arctic White ❄️"
        case .custom: return "Custom 🎨"
            
        // Legacy/Hidden
        case .forestGreen: return "Forest Green 🌲"
        case .oceanTeal: return "Ocean Teal 🌊"
        case .cyberGold: return "Cyber Gold ⚡️"
        case .deepIndigo: return "Deep Indigo 🌌"
        case .sunsetOrange: return "Sunset Orange 🌅"
        case .royalMagenta: return "Royal Magenta 👑"
        }
    }
    
    var palette: ThemePalette {
        switch self {
        case .cleanBlue:
            return ThemePalette(
                accent: Color(red: 0, green: 0.83, blue: 1.0), // #00D4FF
                glow: Color(red: 0, green: 0.6, blue: 1.0),
                tint: Color.blue.opacity(0.1)
            )
        case .neonPurple:
            return ThemePalette(
                accent: Color(red: 0.8, green: 0.0, blue: 1.0),
                glow: Color(red: 0.6, green: 0.0, blue: 1.0),
                tint: Color.purple.opacity(0.1)
            )
        case .lavaRed:
            return ThemePalette(
                accent: Color(red: 1.0, green: 0.2, blue: 0.2),
                glow: Color.red,
                tint: Color.red.opacity(0.1)
            )
        case .forestGreen:
            return ThemePalette(
                accent: Color(red: 0.2, green: 0.9, blue: 0.4),
                glow: Color.green,
                tint: Color.green.opacity(0.1)
            )
        case .oceanTeal:
            return ThemePalette(
                accent: Color(red: 0.0, green: 0.9, blue: 0.9),
                glow: Color(red: 0.0, green: 0.6, blue: 0.8),
                tint: Color.cyan.opacity(0.1)
            )
        case .cyberGold:
            return ThemePalette(
                accent: Color(red: 1.0, green: 0.8, blue: 0.0),
                glow: Color(red: 1.0, green: 0.6, blue: 0.0),
                tint: Color.yellow.opacity(0.1)
            )
        case .deepIndigo:
            return ThemePalette(
                accent: Color(red: 0.3, green: 0.3, blue: 1.0),
                glow: Color(red: 0.0, green: 0.0, blue: 0.8),
                tint: Color.indigo.opacity(0.1)
            )
        case .sunsetOrange:
            return ThemePalette(
                accent: Color(red: 1.0, green: 0.5, blue: 0.0),
                glow: Color(red: 1.0, green: 0.3, blue: 0.0),
                tint: Color.orange.opacity(0.1)
            )
        case .royalMagenta:
            return ThemePalette(
                accent: Color(red: 1.0, green: 0.0, blue: 0.5),
                glow: Color(red: 0.8, green: 0.0, blue: 0.4),
                tint: Color.pink.opacity(0.1)
            )
        case .arcticWhite:
            return ThemePalette(
                accent: Color.white,
                glow: Color(white: 0.8),
                tint: Color.white.opacity(0.1)
            )
        case .custom:
            // Fallback if accessed directly without Manager context
            return ThemePalette(accent: .blue, glow: .blue, tint: .blue.opacity(0.1))
        }
    }
}

/// Defines the color set for a theme.
struct ThemePalette {
    /// The primary accent color (buttons, highlights).
    let accent: Color
    
    /// The secondary glow color (gradients, shadows).
    let glow: Color
    
    /// A subtle tint color for card backgrounds.
    let tint: Color
    
    /// Returns a linear gradient using the accent and glow colors.
    var gradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.8), glow.opacity(0.8)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    /// Returns a vertical gradient for backgrounds.
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
