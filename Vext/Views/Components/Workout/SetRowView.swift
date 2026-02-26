import SwiftUI

struct SetRowView: View {
    let index: Int
    @Binding var weight: String
    @Binding var reps: String
    @Binding var rir: String
    
    // Configuration
    @Binding var isCompleted: Bool
    
    // PR Detection
    var isPR: Bool = false
    @State private var showPRGlow = false
    
    // Ghost Data (for Active Workout)
    var ghostWeight: String? = nil
    var ghostReps: String? = nil
    var ghostRir: String? = nil
    
    // Focus management for keyboard toolbar
    @FocusState private var weightFocused: Bool
    @FocusState private var repsFocused: Bool
    @FocusState private var rirFocused: Bool
    
    private enum Field: Int, CaseIterable {
        case weight, reps, rir
        
        var label: String {
            switch self {
            case .weight: return "KG"
            case .reps: return "REPS"
            case .rir: return "RIR"
            }
        }
    }
    
    private var activeField: Field? {
        if weightFocused { return .weight }
        if repsFocused { return .reps }
        if rirFocused { return .rir }
        return nil
    }
    
    // Computed: row is complete when weight AND reps have values
    private var hasValidInput: Bool {
        let w = Double(weight.replacingOccurrences(of: ",", with: ".")) ?? 0
        let r = Int(reps) ?? Int(Double(reps.replacingOccurrences(of: ",", with: ".")) ?? 0)
        return w > 0 && r > 0
    }
    
    var body: some View {
        HStack(spacing: 6) { // Compact 6px spacing between columns
            // Index + PR/Completed Indicator
            HStack(spacing: 2) {
                if isCompleted {
                    // Completed checkmark
                    Image(systemName: isPR ? "star.fill" : "checkmark.circle.fill")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(isPR ? Theme.Colors.prGold : .green)
                } else {
                    Text("\(index)")
                        .font(.caption)
                        .bold()
                        .foregroundColor(.secondary)
                }
                
                if isPR && isCompleted {
                    Text("PR")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundColor(Theme.Colors.background)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Theme.Colors.prGold)
                        .cornerRadius(4)
                }
            }
            .frame(width: 42, alignment: .leading)
            
            // Weight
            BufferedInputView(
                value: $weight,
                placeholder: ghostWeight ?? "-",
                keyboardType: .decimalPad,
                color: isPR && isCompleted ? Theme.Colors.prGold : (isCompleted ? .green : Theme.Colors.accent),
                alignment: .center,
                font: .system(size: 15, weight: .semibold, design: .monospaced),
                backgroundColor: isCompleted ? Theme.Colors.inputBackground.opacity(0.6) : Theme.Colors.inputBackground,
                cornerRadius: 6
            )
            .focused($weightFocused)
            .frame(maxWidth: .infinity)
            
            // Reps
            BufferedInputView(
                value: $reps,
                placeholder: ghostReps ?? "-",
                keyboardType: .decimalPad,
                color: isPR && isCompleted ? Theme.Colors.prGold : (isCompleted ? .green : Theme.Colors.accent),
                alignment: .center,
                font: .system(size: 15, weight: .semibold, design: .monospaced),
                backgroundColor: isCompleted ? Theme.Colors.inputBackground.opacity(0.6) : Theme.Colors.inputBackground,
                cornerRadius: 6
            )
            .focused($repsFocused)
            .frame(maxWidth: .infinity)
            
            // RIR
            BufferedInputView(
                value: $rir,
                placeholder: ghostRir ?? "-",
                keyboardType: .decimalPad,
                color: isPR && isCompleted ? Theme.Colors.prGold : (isCompleted ? .green : Theme.Colors.accent),
                alignment: .center,
                font: .system(size: 15, weight: .semibold, design: .monospaced),
                backgroundColor: isCompleted ? Theme.Colors.inputBackground.opacity(0.6) : Theme.Colors.inputBackground,
                cornerRadius: 6
            )
            .focused($rirFocused)
            .frame(maxWidth: .infinity)
        }
        .background(
            // Subtle PR glow effect
            showPRGlow
                ? RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.Colors.prGold.opacity(0.15))
                    .blur(radius: 8)
                : nil
        )
        .onChange(of: isCompleted) { _, newValue in
            if newValue && isPR {
                // Show glow briefly
                withAnimation(.easeInOut(duration: 0.3)) {
                    showPRGlow = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    withAnimation(.easeOut(duration: 0.5)) {
                        showPRGlow = false
                    }
                }
            }
        }
        .contentShape(Rectangle()) // Ensure entire row is hittable even if empty
    }
    
    // MARK: - Focus Navigation
    
    private enum FocusDirection {
        case previous, next
    }
    
    private func moveFocus(direction: FocusDirection) {
        guard let current = activeField else { return }
        let allFields = Field.allCases
        let currentIndex = allFields.firstIndex(of: current)!
        
        let targetIndex: Int
        switch direction {
        case .previous:
            targetIndex = currentIndex - 1
        case .next:
            targetIndex = currentIndex + 1
        }
        
        guard allFields.indices.contains(targetIndex) else { return }
        
        setFocus(to: allFields[targetIndex])
    }
    
    private func setFocus(to field: Field) {
        // Clear all first
        weightFocused = false
        repsFocused = false
        rirFocused = false
        
        // Set target after a tiny delay to ensure the clear takes effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            switch field {
            case .weight: weightFocused = true
            case .reps: repsFocused = true
            case .rir: rirFocused = true
            }
        }
    }
    
    private func dismissAllFocus() {
        weightFocused = false
        repsFocused = false
        rirFocused = false
    }
}
