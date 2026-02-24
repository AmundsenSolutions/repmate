import SwiftUI

struct MuscleMapView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    var days: Int 
    @Binding var showPaywall: Bool
    
    // Dynamic Data Source for Category Volume (Most Trained)
    private var categoryData: [(name: String, count: Double, intensity: Double)] {
        let volumes = store.workoutManager.getCategoryVolume(
            sessions: store.workoutSessions, 
            exerciseLibrary: store.exerciseLibrary, 
            days: days
        )
        let maxVolume = volumes.values.max() ?? 1.0
        return volumes.map { (name: $0.key, count: $0.value, intensity: $0.value / maxVolume) }.sorted { $0.count > $1.count }
    }
    
    // Recovery Data
    private var recoveryStatus: [String: Int] {
        store.workoutManager.muscleRecoveryStatus(sessions: store.workoutSessions, exerciseLibrary: store.exerciseLibrary)
    }
    
    private var mostTrained: String {
        categoryData.first?.name ?? "N/A"
    }
    
    private var mostNeglected: String {
        guard !recoveryStatus.isEmpty else { return "N/A" }
        // Find muscle with highest days since trained
        if let maxDays = recoveryStatus.values.max(), let neglected = recoveryStatus.first(where: { $0.value == maxDays })?.key {
            return neglected
        }
        return "N/A"
    }
    
    // Combine all unique categories from library
    private var allMuscles: [String] {
        var set = Set<String>()
        for ex in store.exerciseLibrary {
            set.insert(ex.category.trimmingCharacters(in: .whitespacesAndNewlines).capitalized)
            if let sec = ex.secondaryMuscle {
                set.insert(sec.trimmingCharacters(in: .whitespacesAndNewlines).capitalized)
            }
        }
        return Array(set).sorted()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("RECOVERY & MUSCLE FOCUS")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.secondary)
            
            // Header Cards
            HStack(spacing: 8) {
                StatCard(
                    title: "Most Trained",
                    value: mostTrained,
                    icon: "flame.fill",
                    color: .orange
                )
                
                if storeManager.isPro {
                    StatCard(
                        title: "Focus Area",
                        value: mostNeglected,
                        icon: "target",
                        color: Theme.Colors.cyberGold
                    )
                } else {
                    Button(action: {
                        showPaywall = true
                        HapticManager.shared.lightImpact()
                    }) {
                        StatCard(title: "Focus Area", value: "Locked", icon: "lock.fill", color: .gray.opacity(0.5))
                    }
                }
            }
            .padding(.bottom, 4)
            
            // Recovery Grid
            if storeManager.isPro {
                recoveryGrid
            } else {
                ProLockedOverlay(isPro: false, paywallAction: { showPaywall = true }) {
                    blurredGridPreview
                }
            }
        }
    }
    
    private var recoveryGrid: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(allMuscles, id: \.self) { muscle in
                let daysSince = recoveryStatus[muscle] // nil means never trained or very long time
                recoveryCell(muscle: muscle, daysSince: daysSince)
            }
        }
        .padding(12)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Spacing.compact)
    }
    
    private func recoveryCell(muscle: String, daysSince: Int?) -> some View {
        let state = recoveryState(for: daysSince)
        
        return VStack(spacing: 4) {
            Text(muscle)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            
            Text(statusText(for: daysSince))
                .font(.system(size: 9, weight: .semibold))
                .foregroundColor(state.color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(uiColor: .tertiarySystemFill))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(state.color.opacity(0.3), lineWidth: 1)
        )
    }
    
    // Status Logic
    enum RecoveryState {
        case ready, recovering, neglected
        
        var color: Color {
            switch self {
            case .ready: return .green
            case .recovering: return .yellow
            case .neglected: return Theme.Colors.cyberRed
            }
        }
    }
    
    private func recoveryState(for days: Int?) -> RecoveryState {
        guard let days = days else { return .neglected }
        if days <= 2 { return .recovering }
        if days >= 7 { return .neglected }
        return .ready
    }
    
    private func statusText(for days: Int?) -> String {
        guard let days = days else { return "Neglected" }
        if days == 0 { return "Today" }
        return "\(days)d ago"
    }
    
    private var blurredGridPreview: some View {
        let columns = [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        let dummyMuscles = ["Chest", "Back", "Legs", "Shoulders", "Arms", "Core"]
        
        return LazyVGrid(columns: columns, spacing: 8) {
            ForEach(dummyMuscles, id: \.self) { muscle in
                VStack(spacing: 4) {
                    Text(muscle)
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.white)
                    Text("Ready")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.green)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color(uiColor: .tertiarySystemFill))
                .cornerRadius(6)
            }
        }
        .padding(12)
        .background(Theme.Colors.cardBackground)
        .cornerRadius(Theme.Spacing.compact)
    }
}
