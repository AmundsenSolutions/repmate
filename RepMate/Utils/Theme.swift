import SwiftUI

/// Centralized Design System for RepMate
/// Follows the "Cyber Glass" aesthetic: Flat OLED blacks, tactile buttons, glowing accents. spacing.
struct Theme {
    
    // MARK: - Colors
    struct Colors {
        static let background = Color.black
        static let cardBackground = Color(uiColor: .tertiarySystemFill)
        static let inputBackground = Color(white: 0.1)
        
        // Dynamic Proxy: Route static access to active theme
        static var accent: Color { Theme.active.accent }
        static let prGold = Color.yellow // Keep static Gold for PRs
        static let error = Color.red
        static let cyberRed = Color.red
        
        static let textPrimary = Color.white
        static let textSecondary = Color.secondary
        static let textDim = Color.gray
    }
    
    // MARK: - Fonts
    struct Fonts {
        static let body = Font.system(size: 16, weight: .regular)
        static let value = Font.system(size: 16, weight: .medium)
        static let sectionHeader = Font.caption.weight(.bold)
    }
    
    // MARK: - Dynamic Theme Access
    static var active: ThemePalette {
        ThemeManager.shared.palette
    }
    
    // MARK: - Spacing & Dimensions
    struct Spacing {
        static let standard: CGFloat = 16
        static let compact: CGFloat = 12
        static let tight: CGFloat = 8
        
        static let cornerRadius: CGFloat = 20 // Primary cards and buttons
        static let cornerRadiusSmall: CGFloat = 12 // Stat cards, charts, smaller components
    }
    
    enum GlassStyle {
        case primary
        case secondary
    }
}


// MARK: - View Extensions for Consistency

extension View {
    /// Applies the standard OLED card style
    func oledCard() -> some View {
        self
            .padding(Theme.Spacing.standard)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.cornerRadius)
    }
    
    /// Applies a slimmer OLED row style (less vertical padding)
    func slimOledRow() -> some View {
        self
            .padding(.horizontal, Theme.Spacing.standard)
            .padding(.vertical, Theme.Spacing.compact) // 12px
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.cornerRadius)
    }
    
    /// Applies the standard Primary Action Button style (Dynamic Theme)
    func primaryActionButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.active.verticalGradient)
            .cornerRadius(Theme.Spacing.cornerRadius)
            .shadow(color: Theme.active.accent.opacity(0.3), radius: 8, x: 0, y: 4)
    }
    
    /// Applies the standard Secondary Action Button style
    func secondaryActionButton() -> some View {
        self
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(Theme.Colors.textPrimary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.cornerRadius)
    }
    
    /// Standard section header style
    func sectionHeader() -> some View {
        self
            .font(.caption)
            .fontWeight(.bold)
            .foregroundColor(Theme.Colors.textSecondary)
            .textCase(.uppercase)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    /// Pill button style for chips
    func pillButton(backgroundColor: Color = Theme.Colors.cardBackground, foregroundColor: Color = .white) -> some View {
        self
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(20) // Full pill
    }
    
    // MARK: - Heavy Glass Modifiers
    
    /// Applies the "Heavy Glass" card style (Apple Glass Aesthetic)
    /// - Parameter style: .primary (Active Theme Accent) or .secondary (Neutral/Gray)
    func glassCard(style: Theme.GlassStyle = .primary) -> some View {
        self
            .background(
                ZStack {
                    // 1. Deep Blur Base
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .opacity(0.9) // Heavy blur
                    
                    // 2. Translucent Tint
                    Color.white.opacity(0.03)
                    
                    // 3. Inner Glow (Top Gradient)
                    LinearGradient(
                        colors: [
                            (style == .primary ? Theme.active.accent : .white).opacity(0.15),
                            .clear
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .mask(
                        RoundedRectangle(cornerRadius: Theme.Spacing.cornerRadius)
                            .padding(1) // Inset slightly to create inner glow feel
                    )
                }
            )
            .cornerRadius(Theme.Spacing.cornerRadius)
            .overlay(
                // 4. Glowing Border (Light Source Effect)
                RoundedRectangle(cornerRadius: Theme.Spacing.cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [
                                (style == .primary ? Theme.active.accent : .white).opacity(0.6), // Bright top-left
                                (style == .primary ? Theme.active.accent : .white).opacity(0.1)  // Faded bottom-right
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(
                color: (style == .primary ? Theme.active.accent : .black).opacity(0.2),
                radius: 15, x: 0, y: 8
            )
    }
    
    /// A large, pill-shaped glass button with directional arrow (for "Start Workout")
    func glassCapsuleButton() -> some View {
        self
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 14)
            .background(
                ZStack {
                    Capsule()
                        .fill(.ultraThinMaterial)
                    
                    // Subtle gradient fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [Theme.active.accent.opacity(0.3), Theme.active.accent.opacity(0.1)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }
            )
            .overlay(
                Capsule()
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.6), .white.opacity(0.1)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: Theme.active.accent.opacity(0.25), radius: 8, x: 0, y: 4)
    }
    
    /// A full-width, heavy glowing button for primary bottom actions
    func glowingPanelButton() -> some View {
        self
            .font(.system(size: 20, weight: .bold, design: .rounded))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(
                ZStack {
                    // Deep Glass
                    Rectangle()
                        .fill(.ultraThinMaterial)
                    
                    // Heavy Tint
                    Theme.active.verticalGradient.opacity(0.6)
                }
            )
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.8), .white.opacity(0.2)],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1.5 // Thicker border
                    )
            )
            .shadow(color: Theme.active.accent.opacity(0.4), radius: 12, x: 0, y: 0) // External glow
    }
    
    /// Applies a glass effect to the bottom tab bar area (Refined)
    func glassTabBar() -> some View {
        self
            .background(
                ZStack {
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .ignoresSafeArea()
                    
                    // Subtle top border line
                    VStack {
                        Divider()
                            .background(.white.opacity(0.15))
                        Spacer()
                    }
                }
            )
    }
}
