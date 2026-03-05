import SwiftUI

struct EditNeglectedMusclesView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedMuscles: Set<String> = []
    
    private let maxSelections = 9
    
    // Combine all unique categories from library
    private var allMuscles: [String] {
        var set = Set<String>()
        for ex in store.exerciseLibrary {
            set.insert(ex.category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized)
            if let sec = ex.secondaryMuscle {
                set.insert(sec.trimmingCharacters(in: .whitespacesAndNewlines).capitalized)
            }
        }
        return Array(set).sorted()
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Instruction Text
                    Text("Select up to \(maxSelections) muscle groups to track on your dashboard.")
                        .font(Theme.Fonts.body)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                        .padding(.top, 20)
                        .padding(.bottom, 10)
                    
                    Text("\(selectedMuscles.count) / \(maxSelections) selected")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(selectedMuscles.count == maxSelections ? themeManager.palette.accent : Theme.Colors.textDim)
                        .padding(.bottom, 20)
                    
                    List {
                        ForEach(allMuscles, id: \.self) { muscle in
                            Button {
                                toggleSelection(for: muscle)
                            } label: {
                                HStack {
                                    Text(muscle)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white)
                                    
                                    Spacer()
                                    
                                    if selectedMuscles.contains(muscle) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundColor(themeManager.palette.accent)
                                    } else {
                                        Image(systemName: "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(.gray)
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Tracked Muscles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(role: .cancel) {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .foregroundColor(Theme.Colors.textSecondary)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        store.updateTrackedMuscles(Array(selectedMuscles).sorted())
                        HapticManager.shared.success()
                        dismiss()
                    } label: {
                        Text("Save")
                            .font(.headline)
                            .foregroundColor(themeManager.palette.accent)
                    }
                }
            }
            .onAppear {
                selectedMuscles = Set(store.settings.trackedMuscles)
            }
        }
    }
    
    private func toggleSelection(for muscle: String) {
        if selectedMuscles.contains(muscle) {
            selectedMuscles.remove(muscle)
        } else {
            if selectedMuscles.count < maxSelections {
                selectedMuscles.insert(muscle)
            } else {
                HapticManager.shared.error()
            }
        }
    }
}
