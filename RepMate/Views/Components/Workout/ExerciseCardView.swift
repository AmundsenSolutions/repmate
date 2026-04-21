import SwiftUI

struct ExerciseCardView<Content: View, MenuContent: View>: View {
    let index: Int
    let exerciseName: String
    
    // Header Info
    var targetReps: String? = nil
    var targetRir: String? = nil
    var targetRest: Int = 0
    
    // Progressive Overload Indicator
    var overloadStatus: OverloadDirection = .none
    var showRIR: Bool = true
    
    // Actions
    var menuContent: MenuContent
    
    // Injected Content (The rows)
    var content: Content
    
    // Note State
    @Binding var note: String
    var ghostNote: String? = nil
    
    init(
        index: Int,
        exerciseName: String,
        targetReps: String? = nil,
        targetRir: String? = nil,
        targetRest: Int = 0,
        overloadStatus: OverloadDirection = .none,
        showRIR: Bool = true,
        note: Binding<String>,
        ghostNote: String? = nil,
        @ViewBuilder menuContent: () -> MenuContent,
        @ViewBuilder content: () -> Content
    ) {
        self.index = index
        self.exerciseName = exerciseName
        self.targetReps = targetReps
        self.targetRir = targetRir
        self.targetRest = targetRest
        self.overloadStatus = overloadStatus
        self.showRIR = showRIR
        self._note = note
        self.ghostNote = ghostNote
        self.menuContent = menuContent()
        self.content = content()
    }
    
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
                    
                    // Targets (Reps / RIR / Rest)
                    if (targetReps != nil || targetRir != nil || targetRest > 0) {
                        HStack(spacing: 8) {
                            if let reps = targetReps, !reps.isEmpty {
                                HStack(spacing: 2) {
                                    Image(systemName: "repeat")
                                    Text("\(reps)")
                                }
                            }
                            if showRIR, let rir = targetRir, !rir.isEmpty {
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
                menuContent
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
                if showRIR {
                    Text("RIR")
                        .frame(maxWidth: .infinity)
                }
                
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

extension ExerciseCardView where MenuContent == EmptyView {
    init(
        index: Int,
        exerciseName: String,
        targetReps: String? = nil,
        targetRir: String? = nil,
        targetRest: Int = 0,
        overloadStatus: OverloadDirection = .none,
        showRIR: Bool = true,
        note: Binding<String>,
        ghostNote: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.index = index
        self.exerciseName = exerciseName
        self.targetReps = targetReps
        self.targetRir = targetRir
        self.targetRest = targetRest
        self.overloadStatus = overloadStatus
        self.showRIR = showRIR
        self._note = note
        self.ghostNote = ghostNote
        self.menuContent = EmptyView()
        self.content = content()
    }
}
