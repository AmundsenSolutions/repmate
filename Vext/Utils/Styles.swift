import SwiftUI

// Custom Toggle Style for Checkbox behavior
struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        Button {
            configuration.isOn.toggle()
        } label: {
            Image(systemName: configuration.isOn ? "checkmark.circle.fill" : "circle")
                .foregroundColor(configuration.isOn ? Theme.Colors.accent : .secondary)
                .font(.title2)
        }
        .buttonStyle(.plain)
    }
}
