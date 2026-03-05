import SwiftUI
import Charts

struct NutritionStatsSection: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storeManager: StoreManager
    let days: Int
    @Binding var showPaywall: Bool
    
    private var dailyAverage: Double {
        store.proteinManager.dailyAverage(entries: store.proteinEntries, days: days)
    }
    
    private var adherenceRate: Double {
        store.proteinManager.targetSuccessRate(
            entries: store.proteinEntries,
            target: store.settings.dailyProteinTarget,
            days: days
        )
    }
    
    private var streak: Int {
        store.proteinManager.proteinStreak(entries: store.proteinEntries, target: store.settings.dailyProteinTarget)
    }
    
    private var trainingVsRest: (trainingAvg: Double, restAvg: Double) {
        store.proteinManager.trainingVsRestDayProtein(entries: store.proteinEntries, sessions: store.workoutSessions, days: days)
    }
    
    var body: some View {
        GlassSection(title: "Nutrition") {
            VStack(alignment: .leading, spacing: 16) {
                // Stats Cards Row
                HStack(spacing: 8) {
                    StatCard(
                        title: "Avg Protein",
                        value: String(format: "%.0fg", dailyAverage),
                        icon: "fork.knife",
                        color: themeManager.palette.accent
                    )
                    
                    if storeManager.isPro {
                        StatCard(
                            title: "Streak",
                            value: "\(streak)d",
                            icon: "flame.fill",
                            color: .orange
                        )
                        
                        StatCard(
                            title: "Adherence",
                            value: String(format: "%.0f%%", adherenceRate),
                            icon: "bolt.fill",
                            color: adherenceRate >= 70 ? .green : (adherenceRate >= 50 ? .yellow : Theme.Colors.cyberRed)
                        )
                    } else {
                        Button(action: {
                            showPaywall = true
                            HapticManager.shared.lightImpact()
                        }) {
                            StatCard(title: "Streak", value: "Locked", icon: "lock.fill", color: .gray.opacity(0.5))
                        }
                        
                        Button(action: {
                            showPaywall = true
                            HapticManager.shared.lightImpact()
                        }) {
                            StatCard(title: "Adherence", value: "Locked", icon: "lock.fill", color: .gray.opacity(0.5))
                        }
                    }
                }
                
                // Chart Area
                if storeManager.isPro {
                    trainingVsRestChart
                } else {
                    ProLockedOverlay(isPro: false, paywallAction: { showPaywall = true }) {
                        blurredChartPreview
                    }
                }
            }
            .padding(Theme.Spacing.standard)
        }
    }
    
    private var trainingVsRestChart: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protein: Training vs Rest Days")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                BarMark(
                    x: .value("Day Type", "Training"),
                    y: .value("Protein", trainingVsRest.trainingAvg)
                )
                .foregroundStyle(themeManager.palette.accent)
                .cornerRadius(6)
                
                BarMark(
                    x: .value("Day Type", "Rest"),
                    y: .value("Protein", trainingVsRest.restAvg)
                )
                .foregroundStyle(Theme.Colors.heatmapHigh)
                .cornerRadius(6)
                
                RuleMark(y: .value("Target", store.settings.dailyProteinTarget))
                    .foregroundStyle(.green)
                    .lineStyle(StrokeStyle(lineWidth: 2, dash: [5]))
                    .annotation(position: .trailing, alignment: .leading) {
                        Text("Target")
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
            }
            .chartYScale(domain: 0...max(Double(store.settings.dailyProteinTarget) * 1.5, trainingVsRest.trainingAvg, trainingVsRest.restAvg))
            .frame(height: 160)
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.compact)
        }
    }
    
    private var blurredChartPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Protein Analytics")
                .font(.subheadline)
                .foregroundColor(.gray)
            
            Chart {
                BarMark(x: .value("Day", "T"), y: .value("P", 150))
                BarMark(x: .value("Day", "R"), y: .value("P", 100))
            }
            .foregroundStyle(themeManager.palette.accent.opacity(0.5))
            .frame(height: 160)
            .padding(12)
            .background(Theme.Colors.cardBackground)
            .cornerRadius(Theme.Spacing.compact)
        }
    }
}
