import SwiftUI

// MARK: - Cyber-Glass Color Extensions

extension Theme.Colors {
    /// Primary electric blue accent.
    static let electricBlue = Color(red: 0, green: 0.83, blue: 1.0) // #00D4FF
    
    /// Secondary gold accent for nutrition.
    static let cyberGold = Color(red: 1.0, green: 0.72, blue: 0) // #FFB800
    
    /// Blue shadow glow.
    static let glowBlue = electricBlue.opacity(0.6)
    
    /// Gold shadow glow.
    static let glowGold = cyberGold.opacity(0.6)
    
    // MARK: - Heatmap Colors
    /// Heatmap low.
    static let heatmapLow = Color.red.opacity(0.8)
    /// Heatmap medium.
    static let heatmapMedium = Color.orange
    /// Heatmap high.
    static let heatmapHigh = Color.green
}

// MARK: - Cyber-Glass Style Modifier

/// Applies the core Cyber-Glass material and glowing border aesthetic.
struct CyberGlassStyle: ViewModifier {
    let glowColor: Color
    let cornerRadius: CGFloat
    let borderOpacity: Double
    let glowRadius: CGFloat
    
    init(
        glowColor: Color = Theme.Colors.electricBlue,
        cornerRadius: CGFloat = 20,
        borderOpacity: Double = 0.5,
        glowRadius: CGFloat = 12
    ) {
        self.glowColor = glowColor
        self.cornerRadius = cornerRadius
        self.borderOpacity = borderOpacity
        self.glowRadius = glowRadius
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                ZStack {
                    // Base dark layer
                    Color.black.opacity(0.7)
                    
                    // Ultra-thin material for glass effect
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(.ultraThinMaterial.opacity(0.3))
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                // 1px gradient border
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                glowColor.opacity(borderOpacity),
                                glowColor.opacity(borderOpacity * 0.3),
                                glowColor.opacity(borderOpacity * 0.1)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: glowColor.opacity(0.3), radius: glowRadius, x: 0, y: 4)
            .frame(minHeight: 1) // Prevent "Failed to create image slot" errors
    }
}

// MARK: - Convenience View Extension

extension View {
    /// Applies standard Cyber-Glass styling.
    func cyberGlass(glowColor: Color = Theme.Colors.electricBlue, cornerRadius: CGFloat = 20) -> some View {
        modifier(CyberGlassStyle(glowColor: glowColor, cornerRadius: cornerRadius))
    }
    
    /// Training-specific glass style.
    func cyberGlassBlue() -> some View {
        cyberGlass(glowColor: Theme.Colors.electricBlue)
    }
    
    /// Nutrition-specific glass style.
    func cyberGlassGold() -> some View {
        cyberGlass(glowColor: Theme.Colors.cyberGold)
    }
}

// MARK: - Glowing Text Modifier

struct GlowingText: ViewModifier {
    let color: Color
    let radius: CGFloat
    
    func body(content: Content) -> some View {
        ZStack {
            // Glow layer (multiple shadows for intensity)
            content
                .foregroundColor(color)
                .blur(radius: radius)
            content
                .foregroundColor(color)
                .blur(radius: radius * 0.5)
            // Main text
            content
                .foregroundColor(color)
        }
    }
}

extension View {
    /// Applies neon text glow.
    func glowingText(color: Color = Theme.Colors.electricBlue, radius: CGFloat = 8) -> some View {
        modifier(GlowingText(color: color, radius: radius))
    }
}

// MARK: - Gradient Button Style

struct CyberGradientButton: ViewModifier {
    let primaryColor: Color
    let secondaryColor: Color
    
    init(primaryColor: Color = Theme.Colors.electricBlue, secondaryColor: Color? = nil) {
        self.primaryColor = primaryColor
        self.secondaryColor = secondaryColor ?? primaryColor.opacity(0.7)
    }
    
    func body(content: Content) -> some View {
        content
            .font(.system(size: 16, weight: .bold))
            .foregroundColor(.black)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(
                LinearGradient(
                    colors: [primaryColor, secondaryColor],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
            .shadow(color: primaryColor.opacity(0.5), radius: 12, x: 0, y: 4)
    }
}

extension View {
    /// Applies gradient button style.
    func cyberButton(color: Color = Theme.Colors.electricBlue) -> some View {
        modifier(CyberGradientButton(primaryColor: color))
    }
    
    /// Training-specific button.
    func cyberButtonBlue() -> some View {
        cyberButton(color: Theme.Colors.electricBlue)
    }
    
    /// Nutrition-specific button.
    func cyberButtonGold() -> some View {
        cyberButton(color: Theme.Colors.cyberGold)
    }
}

// MARK: - Pulsing Animation Modifier

struct PulsingAnimation: ViewModifier {
    @State private var isPulsing = false
    let color: Color
    
    func body(content: Content) -> some View {
        content
            .overlay(
                content
                    .foregroundColor(color)
                    .opacity(isPulsing ? 0.3 : 0.8)
            )
            .onAppear {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
            .onDisappear {
                // Reset animation state to prevent CPU drain when offscreen
                isPulsing = false
            }
    }
}

extension View {
    /// Adds a pulsing neon animation.
    func pulsingGlow(color: Color = Theme.Colors.electricBlue) -> some View {
        modifier(PulsingAnimation(color: color))
    }
}
