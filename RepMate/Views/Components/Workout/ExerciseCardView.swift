import SwiftUI

struct ExerciseCardView<Content: View>: View {
    let index: Int
    let exerciseName: String
    
    // Header Info
    var targetRir: String? = nil
    var targetRest: Int = 0
    
    // Progressive Overload Indicator
    var overloadStatus: OverloadDirection = .none
    
    // Actions
    var onMenu: (() -> AnyView)? = nil
    
    // Injected Content (The rows)
    @ViewBuilder let content: Content
    
    // Note State
    @Binding var note: String
    var ghostNote: String? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) { // Compact spacing
            
            // --- Header ---
            HStack {
                // Index Badge
                Text("\(index)")
                    .font(.caption)
                    .bold()
                    .foregroundColor(.white)
                    .frame(width: 22, height: 22)
                    .background(Color.secondary.opacity(0.3))
                    .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(exerciseName)
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        // Progressive Overload Indicator
                        if overloadStatus == .up {
                            Image(systemName: "arrow.up.circle.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        } else if overloadStatus == .down {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.caption)
                                .foregroundColor(.red)
                        }
                    }
                    
                    // Targets (RIR / Rest)
                    if (targetRir != nil || targetRest > 0) {
                        HStack(spacing: 8) {
                            if let rir = targetRir, !rir.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "chart.bar.fill")
                                    Text("RIR \(rir)")
                                }
                            }
                            if targetRest > 0 {
                                HStack(spacing: 2) {
                                    Image(systemName: "clock")
                                    Text(targetRest.formattedDuration)
                                }
                            }
                        }
                        .font(.caption2)
                        .foregroundColor(Theme.Colors.accent.opacity(0.8))
                    }
                }
                
                Spacer()
                
                // Menu (Optional)
                if let onMenu = onMenu {
                    onMenu()
                }
            }
            
            // --- Note ---
            TextField(ghostNote ?? "Add note...", text: $note)
                .font(.caption)
                .foregroundColor(Theme.Colors.accent.opacity(0.9))
                .padding(.leading, 2)
            
            // --- Column Headers ---
            HStack(spacing: 6) {
                Text("SET")
                    .frame(width: 42, alignment: .leading)
                Text("KG")
                    .frame(maxWidth: .infinity)
                Text("REPS")
                    .frame(maxWidth: .infinity)
                Text("RIR")
                    .frame(maxWidth: .infinity)
                
                // Placeholder for Action Column
                Text("")
                    .frame(width: 36)
            }
            .font(.caption2)
            .bold()
            .foregroundColor(.secondary)
            
            // --- Rows Content ---
            content
            
        }

        .padding(12)
        .background(Theme.Colors.cardBackground) // Dark gray card background on black
        .cornerRadius(Theme.Spacing.cornerRadius)
}
}
