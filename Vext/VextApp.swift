import SwiftUI

/// App entry point that wires the shared store into the tabbed interface.
@main
struct RepMateApp: App {
    @StateObject private var store = AppDataStore()
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    
    // Deep-link import state
    @State private var pendingImport: ShareableTemplate?
    @State private var showImportAlert = false

    @StateObject private var storeManager = StoreManager()
    
    /// Creates the main window group and injects `AppDataStore` into the view
    /// hierarchy.
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
            .environmentObject(storeManager)
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
                if let shareable = ShareableTemplate.fromURL(url) {
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
