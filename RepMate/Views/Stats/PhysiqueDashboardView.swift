import SwiftUI

struct PhysiqueDashboardView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var weightStore: WeightStore
    
    let days: Int
    @Binding var showPaywall: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // Core Bodyweight Tracking
            BodyWeightSection(days: days)
            
            // Progress Pictures Gallery
            ProgressGalleryView()
            
            // Nutrition (Protein-only)
            NutritionStatsSection(days: days, showPaywall: $showPaywall)
        }
    }
}
