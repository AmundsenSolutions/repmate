import SwiftUI

/// Main application entry point and global state host.
@main
struct RepMateApp: App {
    @StateObject private var store = AppDataStore()
    @StateObject private var weightStore = WeightStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @AppStorage("hasSeenAIOnboarding") private var hasSeenAIOnboarding = false
    
    // Deep-link import state
    @State private var pendingImport: ShareableTemplate?
    @State private var showImportAlert = false

    @StateObject private var storeManager = StoreManager()
    
    /// Root view hierarchy.
    var body: some Scene {
        WindowGroup {
            Group {
                if !store.isLoaded {
                    // K4: Show splash until async disk load + migrations complete.
                    // Prevents views from rendering against an empty store state.
                    ZStack {
                        Color.black.ignoresSafeArea()
                        VStack(spacing: 16) {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.white.opacity(0.8))
                            ProgressView()
                                .tint(.white)
                        }
                    }
                } else if hasSeenOnboarding {
                    AppTabView()
                        .fullScreenCover(isPresented: Binding(
                            get: { !hasSeenAIOnboarding },
                            set: { if !$0 { hasSeenAIOnboarding = true } }
                        )) {
                            ExistingUserAIOnboardingView(onDismiss: {
                                hasSeenAIOnboarding = true
                            })
                            .environmentObject(store)
                            .environmentObject(ThemeManager.shared)
                        }
                } else {
                    OnboardingView()
                }
            }
            .environmentObject(store)
            .environmentObject(store.proteinStore)
            .environmentObject(store.workoutStore)
            .environmentObject(store.settingsStore)
            .environmentObject(storeManager)
            .environmentObject(NotificationManager.shared)
            .environmentObject(weightStore)
            .environmentObject(ThemeManager.shared) // Global Theme Injection
            .preferredColorScheme(.dark) // Force dark mode globally (keyboard, alerts, etc.)
            .alert("Error", isPresented: Binding<Bool>(
                get: { store.lastErrorMessage != nil },
                set: { _ in store.lastErrorMessage = nil }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(store.lastErrorMessage ?? "An unknown error occurred.")
            }
            // MARK: - Deep Link Import Handler
            .onOpenURL { url in
                if url.scheme == "repmate" && url.host == "stoptimer" {
                    store.stopRestTimer()
                } else if let shareable = ShareableTemplate.fromURL(url) {
                    pendingImport = shareable
                    showImportAlert = true
                }
            }
            .alert("Import Workout", isPresented: $showImportAlert) {
                Button("Import") {
                    if let shareable = pendingImport {
                        if let template = shareable.toWorkoutTemplate(
                            exerciseLibrary: store.exerciseLibrary,
                            addExercise: { name, category in
                                store.addExercise(name: name, category: category)
                            }
                        ) {
                            store.addWorkoutTemplate(template)
                            HapticManager.shared.success()
                        } else {
                            store.lastErrorMessage = "Template contains too many exercises and could not be imported."
                            HapticManager.shared.error()
                        }
                    }
                    pendingImport = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingImport = nil
                }
            } message: {
                if let shareable = pendingImport {
                    Text("Add \"\(shareable.name)\" with \(shareable.exercises.count) exercises to your workout templates?")
                }
            }
        }
    }
}
