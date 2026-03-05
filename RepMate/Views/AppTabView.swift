//
//  AppTabView.swift
//  RepMate
//
//  Created by Aleksander Amundsen on 10/12/2025.
//


import SwiftUI

struct AppTabView: View {
    @ObservedObject var themeManager = ThemeManager.shared // Observe updates

    /// Hosts the main tab navigation between home, workouts, protein, and
    /// settings screens.
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Label("Home", systemImage: "house.fill")
                }
            
            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.strengthtraining.traditional")
                }
            
            StatsView()
                .tabItem {
                    Label("Stats", systemImage: "chart.line.uptrend.xyaxis")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
        .tint(themeManager.palette.accent) // Dynamic Tab Bar Color
        .environmentObject(themeManager) // Inject for child views

        .overlay(alignment: .bottom) {
            PersistentWorkoutBanner {
                isShowingActiveWorkout = true
            }
            .padding(.bottom, 60) // Position above tab bar (approx 49pt + safe area)
            .padding(.horizontal, 16)
            .opacity((!isShowingActiveWorkout && !store.isViewingActiveWorkout) ? 1 : 0)
            .allowsHitTesting(!isShowingActiveWorkout && !store.isViewingActiveWorkout)
            .animation(.easeInOut, value: store.activeWorkout != nil)
        }
        .onChange(of: store.activeWorkout) { oldValue, newValue in
            // Auto-present active workout if a new one is started (and not already showing)
            if newValue != nil && !isShowingActiveWorkout {
                isShowingActiveWorkout = true
            }
        }
        .fullScreenCover(isPresented: $isShowingActiveWorkout) {
            NavigationStack {
                ActiveWorkoutView()
            }
            .environmentObject(themeManager) // Also inject in fullScreenCover
        }
    }
    
    @EnvironmentObject var store: AppDataStore // Ensure we have access to store
    @State private var isShowingActiveWorkout = false
}

/// Preview of `AppTabView` showing the tab bar composition.
#Preview {
    AppTabView()
}
