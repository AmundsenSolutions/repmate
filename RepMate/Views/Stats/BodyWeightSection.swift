import SwiftUI
import Charts

/// Body-weight tracking section displayed in StatsView under the "Body" tab.
struct BodyWeightSection: View {
    @EnvironmentObject var weightStore: WeightStore
    @EnvironmentObject var themeManager: ThemeManager
    let days: Int

    @State private var weightInput: String = ""
    @State private var isEditing: Bool = false
    @FocusState private var inputFocused: Bool

    // MARK: - Computed

    private var todayEntry: WeightEntry? {
        weightStore.todayEntry()
    }

    private var filteredEntries: [WeightEntry] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: today) else { return weightStore.entries }
        return weightStore.entries.filter { $0.date >= cutoff }
    }

    private var trend: [WeightStore.TrendPoint] {
        // Filter trend to visible window
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: today) else { return weightStore.trendLine() }
        return weightStore.trendLine().filter { $0.date >= cutoff }
    }

    private var latestWeight: Double? {
        weightStore.entries.last?.weight
    }

    private var periodDelta: Double? {
        weightStore.delta(days: days)
    }

    private var deltaFormatted: String {
        guard let d = periodDelta else { return "—" }
        let sign = d >= 0 ? "+" : ""
        return "\(sign)\(String(format: "%.1f", d)) kg"
    }

    private var deltaColor: Color {
        guard let d = periodDelta else { return .gray }
        if abs(d) < 0.1 { return .gray }
        return d > 0 ? Theme.Colors.cyberGold : themeManager.palette.accent
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 24) {
            // Today's weight input card
            todayWeightCard

            // Summary stat cards
            summaryCards

            // Weight trend chart
            weightChart
        }
    }

    // MARK: - Today's Weight Card

    @ViewBuilder
    private var todayWeightCard: some View {
        GlassSection(title: "Today's Weight") {
            HStack(spacing: 12) {
                if let entry = todayEntry, !isEditing {
                    // Logged state
                    HStack(spacing: 10) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundColor(Theme.Colors.success)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Logged")
                                .font(.caption)
                                .foregroundColor(.gray)
                            Text(String(format: "%.1f kg", entry.weight))
                                .font(.system(size: 22, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        Spacer()

                        Button {
                            weightInput = String(format: "%.1f", entry.weight)
                            isEditing = true
                            inputFocused = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 24))
                                .foregroundColor(themeManager.palette.accent.opacity(0.7))
                        }
                    }
                    .padding(Theme.Spacing.standard)
                } else {
                    // Input state
                    HStack(spacing: 10) {
                        Image(systemName: "scalemass.fill")
                            .font(.system(size: 18))
                            .foregroundColor(themeManager.palette.accent)

                        TextField("e.g. 78.5", text: $weightInput)
                            .keyboardType(.decimalPad)
                            .focused($inputFocused)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.white)
                            .accentColor(themeManager.palette.accent)

                        Text("kg")
                            .font(.subheadline)
                            .foregroundColor(.gray)

                        Spacer()

                        Button {
                            submitWeight()
                        } label: {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 28))
                                .foregroundColor(weightInput.isEmpty ? .gray.opacity(0.4) : themeManager.palette.accent)
                        }
                        .disabled(weightInput.isEmpty)
                    }
                    .padding(Theme.Spacing.standard)
                }
            }
        }
    }

    // MARK: - Summary Cards

    @ViewBuilder
    private var summaryCards: some View {
        HStack(spacing: 8) {
            StatCard(
                title: "Current",
                value: latestWeight.map { String(format: "%.1f kg", $0) } ?? "—",
                icon: "scalemass.fill",
                color: themeManager.palette.accent
            )

            StatCard(
                title: "Entries (\(daysLabel))",
                value: "\(filteredEntries.count)",
                icon: "list.bullet",
                color: .gray
            )

            StatCard(
                title: "Change (\(daysLabel))",
                value: deltaFormatted,
                icon: periodDelta.map { $0 >= 0 ? "arrow.up.right" : "arrow.down.right" } ?? "minus",
                color: deltaColor
            )
        }
    }

    private var daysLabel: String {
        switch days {
        case 7: return "7d"
        case 30: return "30d"
        case 365: return "1y"
        default: return "\(days)d"
        }
    }

    // MARK: - Weight Chart

    @ViewBuilder
    private var weightChart: some View {
        GlassSection(title: "Weight Trend") {
            if filteredEntries.isEmpty {
                emptyState
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    chartView
                        .frame(height: 200)
                        .padding(12)
                }
                .padding(.vertical, Theme.Spacing.tight)
            }
        }
    }

    @ViewBuilder
    private var chartView: some View {
        Chart {
            // Background: actual data points (semi-transparent)
            ForEach(filteredEntries) { entry in
                PointMark(
                    x: .value("Date", entry.date, unit: .day),
                    y: .value("Weight", entry.weight)
                )
                .symbol(Circle())
                .symbolSize(40)
                .foregroundStyle(themeManager.palette.accent.opacity(0.35))
            }

            // Foreground: smooth SMA trend line
            ForEach(trend) { point in
                LineMark(
                    x: .value("Date", point.date, unit: .day),
                    y: .value("Trend", point.value)
                )
                .interpolationMethod(.catmullRom)
                .lineStyle(StrokeStyle(lineWidth: 3, lineCap: .round))
                .foregroundStyle(themeManager.palette.accent)
            }

            // Gradient area under the trend line
            ForEach(trend) { point in
                AreaMark(
                    x: .value("Date", point.date, unit: .day),
                    yStart: .value("Min", 0),
                    yEnd: .value("Trend", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(
                    LinearGradient(
                        colors: [themeManager.palette.accent.opacity(0.25), .clear],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .chartYScale(domain: .automatic(includesZero: false))
        .chartYAxis {
            AxisMarks(position: .leading) { _ in
                AxisGridLine().foregroundStyle(Color.gray.opacity(0.15))
                AxisValueLabel().foregroundStyle(Color.gray)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic) { _ in
                AxisValueLabel(format: .dateTime.month().day()).foregroundStyle(Color.gray)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.largeTitle)
                .foregroundColor(.gray.opacity(0.3))
            Text("No weight data for this period")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Log your first weigh-in above to start tracking")
                .font(.caption2)
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 200)
        .padding(Theme.Spacing.standard)
    }

    // MARK: - Helpers

    private func submitWeight() {
        // Support both comma and period as decimal separator
        let cleaned = weightInput.replacingOccurrences(of: ",", with: ".")
        guard let value = Double(cleaned), value > 0, value < 500 else {
            // Simple validation: reasonable human weight range
            return
        }

        weightStore.logWeight(value)
        weightInput = ""
        isEditing = false
        inputFocused = false
        HapticManager.shared.success()
    }
}
