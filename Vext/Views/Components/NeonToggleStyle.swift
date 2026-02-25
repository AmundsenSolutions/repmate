import SwiftUI

/// A custom glowing toggle style that matches the Cyber Glass aesthetic.
struct NeonToggleStyle: ToggleStyle {
    var onColor: Color
    var offColor: Color = Color.white.opacity(0.1)
    var thumbColor: Color = .white
    
    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
            
            Spacer()
            
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(configuration.isOn ? onColor : offColor)
                .frame(width: 50, height: 30)
                .overlay(
                    Circle()
                        .fill(thumbColor)
                        .padding(2)
                        .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                        .offset(x: configuration.isOn ? 10 : -10)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
                )
                // Add outer glow when ON
                .shadow(color: configuration.isOn ? onColor.opacity(0.6) : .clear, radius: configuration.isOn ? 8 : 0)
                .onTapGesture {
                    HapticManager.shared.lightImpact()
                    configuration.isOn.toggle()
                }
        }
    }
}
