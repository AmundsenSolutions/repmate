import SwiftUI
import Combine

struct PersistentWorkoutBanner: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Theme reactivity
    @Environment(\.scenePhase) private var scenePhase
    
    // Timer state
    @State private var timeString: String = "00:00"
    @State private var timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    var onTap: () -> Void
    
    var body: some View {
        if store.activeWorkout != nil && !store.isViewingActiveWorkout && !store.isViewingTemplateDetail {
            Button(action: {
                HapticManager.shared.lightImpact()
                onTap()
            }) {
                HStack(spacing: 12) {
                    // Icon
                    Image(systemName: "chevron.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(themeManager.palette.accent)
                    
                    // Text
                    Text("RESUME SESSION")
                        .font(Theme.Fonts.sectionHeader)
                        .foregroundColor(themeManager.palette.accent)
                    
                    Spacer()
                    
                    // Timer
                    Text(timeString)
                        .font(.system(size: 16, weight: .regular, design: .monospaced))
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)
            .cyberGlass(glowColor: themeManager.palette.accent)
            .padding(.horizontal, 16)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: store.activeWorkout == nil)
            .onAppear {
                updateTimer()
            }
            .onReceive(timer) { _ in
                updateTimer()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .active {
                    // Immediately update timer when returning from background
                    updateTimer()
                }
            }
        }
    }
    
    private func updateTimer() {
        guard let start = store.activeWorkout?.startedAt else { return }
        let diff = Int(Date().timeIntervalSince(start))
        let h = diff / 3600
        let m = (diff % 3600) / 60
        let s = diff % 60
        if h > 0 {
            timeString = String(format: "%d:%02d:%02d", h, m, s)
        } else {
            timeString = String(format: "%02d:%02d", m, s)
        }
    }
}
