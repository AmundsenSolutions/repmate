import SwiftUI
import Charts

enum StatsTimeFilter: String, CaseIterable, Identifiable {
    case week = "7d"
    case month = "30d"
    case year = "1y"
    
    var id: String { rawValue }
    
    var days: Int {
        switch self {
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

struct StatsView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager // Use environment for reactivity
    @EnvironmentObject var storeManager: StoreManager
    
    @State private var selectedFilter: StatsTimeFilter = .month
    @State private var showPaywall = false
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                ScrollView {
                    VStack(spacing: Theme.Spacing.standard * 1.25) { // 20 -> 16 * 1.25 = 20. Or just use 20. Let's Stick to standard 20 spacing for outer stack.
                        // Time Filter Chips
                        HStack(spacing: Theme.Spacing.tight) {
                            ForEach(StatsTimeFilter.allCases) { filter in
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        selectedFilter = filter
                                    }
                                    HapticManager.shared.selection()
                                } label: {
                                    Text(filter.rawValue)
                                        .font(.system(size: 14, weight: .semibold))
                                        .padding(.horizontal, Theme.Spacing.standard)
                                        .padding(.vertical, Theme.Spacing.tight)
                                        .background(selectedFilter == filter ? themeManager.palette.accent : Theme.Colors.cardBackground)
                                        .foregroundColor(selectedFilter == filter ? .black : .white)
                                        .cornerRadius(20)
                                }
                            }
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                        
                        // 2. Activity / Consistency
                        ActivityHeatmapView(days: selectedFilter.days, showPaywall: $showPaywall)
                        
                        // 3. Strength & PR
                        StrengthStatsSection(days: selectedFilter.days, showPaywall: $showPaywall)
                        
                        // 4. 1RM Calculator (Free)
                        OneRMCalculatorCard()
                        
                        // 5. Muscle Map (Mixed Free/Pro)
                        MuscleMapView(days: selectedFilter.days, showPaywall: $showPaywall)
                        
                        // 6. Nutrition Stats
                        NutritionStatsSection(days: selectedFilter.days, showPaywall: $showPaywall)
                            
                        // 7. Smart Insights (Pro Locked)
                        ProLockedOverlay(isPro: storeManager.isPro, paywallAction: { showPaywall = true }) {
                            SmartInsightsRow(days: selectedFilter.days)
                        }
                        
                        // Bottom Spacing
                        Spacer(minLength: 100)
                    }
                    .padding(Theme.Spacing.standard)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Stats")
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }
}

// MARK: - Pro Locked Overlay
struct ProLockedOverlay<Content: View>: View {
    let isPro: Bool
    let paywallAction: () -> Void
    let content: Content

    init(isPro: Bool, paywallAction: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isPro = isPro
        self.paywallAction = paywallAction
        self.content = content()
    }

    var body: some View {
        if isPro {
            content
        } else {
            ZStack {
                content
                    .blur(radius: 6)
                    .allowsHitTesting(false)
                
                VStack(spacing: 8) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.yellow)
                        .shadow(color: .yellow.opacity(0.5), radius: 10, x: 0, y: 0)
                    
                    Text("Unlock Vext Pro")
                        .font(.headline)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .background(Color.black.opacity(0.6))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
                .onTapGesture {
                    paywallAction()
                    HapticManager.shared.lightImpact()
                }
            }
        }
    }
}

