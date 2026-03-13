import SwiftUI

struct WorkoutSelectionSheet: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    @EnvironmentObject var storeManager: StoreManager
    @Binding var isPresented: Bool
    var onCreateNewTemplate: ((UUID) -> Void)? = nil // Callback to navigate to template editor
    
    @State private var showPaywall = false
    
    // Grid layout for template capsules
    private let columns = [
        GridItem(.flexible())
    ]
    
    var body: some View {
        VStack(spacing: 0) {
            // grabber
            Capsule()
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 12)
                .padding(.bottom, 20)
            
            // Title
            Text("Select Workout Template")
                .font(.headline)
                .foregroundColor(.white.opacity(0.8))
                .padding(.bottom, 24)
            
            // Templates List
            ScrollView {
                VStack(spacing: 12) {
                    // Quick Start Button
                    Button {
                        startEmptyWorkout()
                    } label: {
                        HStack {
                            ZStack {
                                Circle()
                                    .fill(Theme.active.accent.opacity(0.2))
                                    .frame(width: 32, height: 32)
                                Image(systemName: "bolt.fill")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(Theme.active.accent)
                            }
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Quick Start")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Text("Start empty workout")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(Color.white.opacity(0.3))
                        }
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                        .padding(.vertical, 14)
                        .padding(.horizontal, 20)
                        .background(Color(white: 0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.active.accent.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .padding(.bottom, 8)

                    ForEach(store.workoutTemplates) { template in
                        Button {
                            startWorkout(template: template)
                        } label: {
                            HStack {
                                Text(template.name)
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(.white)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(Color.white.opacity(0.3))
                            }
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                            .padding(.vertical, 18)
                            .padding(.horizontal, 24)
                            .background(Color(white: 0.1))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
            .scrollIndicators(.hidden)
            .frame(maxHeight: 400) 
            
            Spacer().frame(height: 24)
            
            Button {
                startNewWorkout()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.fill")
                    Text("New Workout")
                    Spacer().frame(width: 0)
                    Image(systemName: "plus")
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .glowingPanelButton() // Uses Theme.active.accent internally
            .padding(.bottom, 100) // Clear tab bar completely
        }
        .padding(.horizontal, 20)
        .background(
            Color.black
            .ignoresSafeArea()
        )
        .clipShape(RoundedCorner(radius: 30, corners: [.topLeft, .topRight]))
        .overlay(
            // Top Border Glow
            RoundedCorner(radius: 30, corners: [.topLeft, .topRight])
                .stroke(
                    LinearGradient(
                        colors: [
                            Theme.active.accent.opacity(0.5),
                            Theme.active.accent.opacity(0.1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1
                )
                .ignoresSafeArea(edges: .bottom)
        )
        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: -5)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    // MARK: - Actions
    
    private func startWorkout(template: WorkoutTemplate) {
        store.startWorkout(template: template)
        close()
    }
    
    private func startNewWorkout() {
        if !storeManager.isPro && store.workoutTemplates.count >= 3 {
            showPaywall = true
            HapticManager.shared.lightImpact()
            return
        }
        
        // Create a new template and navigate to the template editor
        let newTemplate = WorkoutTemplate(id: UUID(), name: "New Workout", exerciseIds: [])
        store.addWorkoutTemplate(newTemplate)
        close()
        onCreateNewTemplate?(newTemplate.id)
    }

    private func startEmptyWorkout() {
        store.activeWorkout = ActiveWorkout.startEmpty()
        close()
    }
    
    private func close() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
            isPresented = false
        }
    }
}

// Helper for top corner clipping
struct RoundedCorner: Shape {
    var radius: CGFloat = .infinity
    var corners: UIRectCorner = .allCorners

    func path(in rect: CGRect) -> Path {
        let path = UIBezierPath(roundedRect: rect, byRoundingCorners: corners, cornerRadii: CGSize(width: radius, height: radius))
        return Path(path.cgPath)
    }
}
