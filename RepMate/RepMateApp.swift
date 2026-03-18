import SwiftUI

/// Main application entry point and global state host.
@main
struct RepMateApp: App {
    @StateObject private var store = AppDataStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    // Deep-link import state
    @State private var pendingImport: ShareableTemplate?
    @State private var showImportAlert = false

    @StateObject private var storeManager = StoreManager()
    
    /// Root view hierarchy.
    var body: some Scene {
        WindowGroup {
            Group {
                if hasSeenOnboarding {
                    AppTabView()
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
                        let template = shareable.toWorkoutTemplate(
                            exerciseLibrary: store.exerciseLibrary
                        ) { name, category in
                            store.addExercise(name: name, category: category)
                        }
                        store.addWorkoutTemplate(template)
                        HapticManager.shared.success()
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
