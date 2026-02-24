import SwiftUI

/// A TextField wrapper that buffers input in local State to preventing focus loss
/// when parent views re-render (e.g. from global store updates).
struct BufferedInputView: View {
    @Binding var value: String
    var placeholder: String
    var keyboardType: UIKeyboardType = .default
    var color: Color = Theme.Colors.textPrimary
    var alignment: TextAlignment = .center
    var font: Font = .system(size: 15, weight: .semibold, design: .monospaced)
    var backgroundColor: Color = Theme.Colors.inputBackground
    var cornerRadius: CGFloat = Theme.Spacing.compact
    
    // External focus control (optional)
    var externalFocus: FocusState<Bool>.Binding?
    
    @State private var localText: String
    @FocusState private var isFocused: Bool
    
    init(value: Binding<String>, placeholder: String, keyboardType: UIKeyboardType = .default, color: Color = Theme.Colors.textPrimary, alignment: TextAlignment = .center, font: Font = .body, backgroundColor: Color = Theme.Colors.inputBackground, cornerRadius: CGFloat = Theme.Spacing.compact, externalFocus: FocusState<Bool>.Binding? = nil) {
        self._value = value
        self.placeholder = placeholder
        self.keyboardType = keyboardType
        self.color = color
        self.alignment = alignment
        self.font = font
        self.backgroundColor = backgroundColor
        self.cornerRadius = cornerRadius
        self.externalFocus = externalFocus
        self._localText = State(initialValue: value.wrappedValue)
    }
    
    var body: some View {
        ZStack(alignment: alignment == .leading ? .leading : (alignment == .trailing ? .trailing : .center)) {
            if localText.isEmpty && !isFocused {
                Text(placeholder)
                    .font(font)
                    .foregroundColor(.secondary.opacity(0.3))
                    .allowsHitTesting(false)
            }
            TextField("", text: $localText)
                .font(font)
                .multilineTextAlignment(alignment)
                .keyboardType(keyboardType)
                .foregroundColor(color)
                .minimumScaleFactor(0.5)
                .focused($isFocused)
                // Sync Logic
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        value = localText // Sync on focus loss
                    } else {
                        localText = value // Refresh locally on focus gain
                    }
                }
                .onSubmit {
                    value = localText
                }
                // SYNC: Local -> Binding (Continuous for Save Buttons)
                .onChange(of: localText) { _, newLocal in
                    if isFocused && value != newLocal {
                        value = newLocal
                    }
                }
                // SYNC: Binding -> Local (Only if not focused, to avoid cursor jumps)
                .onChange(of: value) { _, newBinding in
                    if !isFocused && localText != newBinding {
                        localText = newBinding
                    }
                }
                // External focus sync (if provided)
                .onChange(of: externalFocus?.wrappedValue) { _, newValue in
                    if let newValue = newValue, !newValue {
                        isFocused = false
                        value = localText
                    }
                }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(backgroundColor)
        .cornerRadius(cornerRadius)
    }
}

