import SwiftUI
import Charts
import StoreKit

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
    @State private var showingEditDashboard = false
    
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                ScrollView {
                    VStack(spacing: 24) {
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
                        
                        // Dynamic Section Order
                        ForEach(store.settings.activeStatsOrder) { section in
                            switch section {
                            case .overview:
                                StatsOverviewSection(days: selectedFilter.days)
                            case .strength:
                                StrengthStatsSection(days: selectedFilter.days, showPaywall: $showPaywall)
                            case .activity:
                                ActivityHeatmapView(days: selectedFilter.days, showPaywall: $showPaywall)
                            case .nutrition:
                                NutritionStatsSection(days: selectedFilter.days, showPaywall: $showPaywall)
                            case .muscleMap:
                                MuscleMapView(days: selectedFilter.days, showPaywall: $showPaywall)
                            case .insights:
                                ProLockedOverlay(isPro: storeManager.isPro, paywallAction: { showPaywall = true }) {
                                    SmartInsightsRow(days: selectedFilter.days)
                                }
                            case .oneRM:
                                OneRMCalculatorCard()
                            case .allTimePRs:
                                AllTimePRSection()
                            }
                        }
                        
                        // Bottom Spacing
                        Spacer(minLength: 100)
                    }
                    .padding(Theme.Spacing.standard)
                    .animation(.spring(response: 0.4, dampingFraction: 0.8), value: store.settings.activeStatsOrder)
                }
                .scrollDismissesKeyboard(.interactively)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .navigationTitle("Stats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingEditDashboard = true
                        HapticManager.shared.lightImpact()
                    } label: {
                        Image(systemName: "list.bullet")
                            .font(.system(size: 15, weight: .medium))
                    }
                }
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
            .sheet(isPresented: $showingEditDashboard) {
                EditDashboardView()
                    .environmentObject(store)
            }
        }
    }
}

// MARK: - Stats Overview
private struct StatsOverviewSection: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    let days: Int
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var workoutCount: Int {
        store.workoutManager.getWorkoutCount(sessions: store.workoutSessions, days: days)
    }

    private var weeklyAvg: Double {
        store.workoutManager.avgWorkoutsPerWeek(sessions: store.workoutSessions, days: days)
    }
    
    private var activeDays: Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let startDate = calendar.date(byAdding: .day, value: -days, to: today) else { return 0 }
        let unique = Set(store.workoutSessions.filter { $0.date >= startDate }.map { calendar.startOfDay(for: $0.date) })
        return unique.count
    }

    private var proteinAvg: Double {
        store.proteinManager.dailyAverage(entries: store.proteinEntries, days: days)
    }
    
    private var goalReached: Double {
        store.proteinManager.targetSuccessRate(
            entries: store.proteinEntries,
            target: store.settings.dailyProteinTarget,
            days: days
        )
    }

    var body: some View {
        GlassSection(title: "Overview") {
            Group {
                if horizontalSizeClass == .compact {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        overviewCards
                    }
                } else {
                    HStack(spacing: 8) {
                        overviewCards
                    }
                }
            }
            .padding(Theme.Spacing.standard)
        }
    }
    
    @ViewBuilder
    private var overviewCards: some View {
        StatCard(
            title: "Workouts",
            value: "\(workoutCount)",
            icon: "figure.strengthtraining.traditional",
            color: themeManager.palette.accent
        )
        if days == 7 {
            StatCard(
                title: "Active Days",
                value: "\(activeDays)",
                icon: "calendar.badge.checkmark",
                color: Theme.Colors.accent
            )
        } else {
            StatCard(
                title: "Avg / Week",
                value: String(format: "%.1f", weeklyAvg),
                icon: "calendar",
                color: Theme.Colors.accent
            )
        }
        StatCard(
            title: "Avg Protein",
            value: String(format: "%.0fg", proteinAvg),
            icon: "fork.knife",
            color: themeManager.palette.accent
        )
        StatCard(
            title: "Goal Reached",
            value: String(format: "%.0f%%", goalReached),
            icon: "checkmark.seal.fill",
            color: goalReached >= 70 ? .green : (goalReached >= 50 ? .yellow : Theme.Colors.cyberRed)
        )
    }
}

// MARK: - Pro Locked Overlay
struct ProLockedOverlay<Content: View>: View {
    @EnvironmentObject var storeManager: StoreManager
    let isPro: Bool
    var price: String? = nil
    let paywallAction: () -> Void
    let content: Content

    init(isPro: Bool, price: String? = nil, paywallAction: @escaping () -> Void, @ViewBuilder content: () -> Content) {
        self.isPro = isPro
        self.price = price
        self.paywallAction = paywallAction
        self.content = content()
    }
    
    private var displayPrice: String? {
        price ?? storeManager.products.first(where: { $0.id == "repmate_pro_lifetime" })?.displayPrice
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
                    
                    Text("Unlock RepMate Pro")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    if let price = displayPrice, !price.isEmpty {
                        Text(price)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundColor(.yellow)
                    }
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

