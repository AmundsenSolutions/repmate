import SwiftUI

struct TargetRepRangeSheet: View {
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var themeManager: ThemeManager
    
    @State var minReps: Int
    @State var maxReps: Int
    
    var onSave: (Int, Int) -> Void
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Target Rep Range")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 24)
                    
                    Text("Select your default rep range for new exercises.")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    HStack(spacing: 0) {
                        Picker("Min", selection: $minReps) {
                            ForEach(1..<20, id: \.self) { val in
                                Text("\(val)").tag(val)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .onChange(of: minReps) { _, newValue in
                            if newValue > maxReps {
                                maxReps = newValue
                            }
                        }
                        
                        Text("to")
                            .font(.headline)
                            .foregroundColor(.gray)
                        
                        Picker("Max", selection: $maxReps) {
                            ForEach(1..<31, id: \.self) { val in
                                Text("\(val)").tag(val)
                            }
                        }
                        .pickerStyle(.wheel)
                        .frame(maxWidth: .infinity)
                        .clipped()
                        .onChange(of: maxReps) { _, newValue in
                            if newValue < minReps {
                                minReps = newValue
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .background(Theme.Colors.cardBackground)
                    .cornerRadius(Theme.Spacing.cornerRadius)
                    .padding(.horizontal, 20)
                    
                    Spacer()
                    
                    Button {
                        onSave(minReps, maxReps)
                        HapticManager.shared.success()
                        dismiss()
                    } label: {
                        Text("Save")
                    }
                    .primaryActionButton() // Uses Theme.swift extension for the dynamic gradient
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
            }
        }
        .presentationDetents([.height(450)])
        .presentationDragIndicator(.visible)
    }
}
