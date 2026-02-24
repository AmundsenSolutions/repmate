import SwiftUI

struct ProteinHeatmapView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedDate: DateWrapper?
    
    private let calendar = Calendar.current
    
    // Color Palette - using Theme for consistency
    private let level0 = Color.clear
    private let level1 = Theme.Colors.heatmapLow // Little
    private let level2 = Theme.Colors.heatmapMedium // OK
    private let level3 = Theme.Colors.heatmapHigh // Reached
    
    // Static formatter for performance
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    // Last 30 days
    private var daysToDisplay: [Date] {
        let today = calendar.startOfDay(for: Date())
        var days: [Date] = []
        // 0 to 29 (30 days total)
        for i in (0..<30).reversed() {
            if let date = calendar.date(byAdding: .day, value: -i, to: today) {
                days.append(date)
            }
        }
        return days
    }
    
    var body: some View {
        VStack(spacing: 24) {
            // Header
            HStack {
                Text("Last 30 Days")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Spacer()
                
                // Streak indicator
                HStack(spacing: 4) {
                     Image(systemName: "flame.fill")
                        .foregroundColor(.orange)
                     Text("\(store.proteinStreak()) day streak")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // Grid (5 Columns x 6 Rows = 30)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 5), spacing: 10) {
                ForEach(daysToDisplay, id: \.self) { date in
                    dayCell(for: date)
                }
            }
            .padding(.horizontal)
            
            Spacer()
            
            // Legend
            HStack(spacing: 16) {
                Text("Little")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level0)
                        .frame(width: 16, height: 16)
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level1)
                        .frame(width: 16, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level2)
                        .frame(width: 16, height: 16)
                    
                    RoundedRectangle(cornerRadius: 4)
                        .fill(level3)
                        .frame(width: 16, height: 16)
                }
                
                Text("Reached")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.bottom, 40)
        }
        .background(Theme.Colors.background.edgesIgnoringSafeArea(.all)) // Ensure OLED background
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $selectedDate) { wrapper in
             ProteinHistoryView(initialDate: wrapper.date)
        }
    }
    
    private func dayCell(for date: Date) -> some View {
        let total = store.totalProteinFor(date: date)
        let target = max(store.settings.dailyProteinTarget, 1)
        let ratio = Double(total) / Double(target)
        let color = colorForRatio(ratio)
        let isToday = calendar.isDateInToday(date)
        let dayString = Self.dayFormatter.string(from: date)
        
        return Button {
            selectedDate = DateWrapper(date)
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(color)
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.1), lineWidth: ratio == 0 ? 1 : 0) // Outline for empty
                    )
                
                Text(dayString)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(textColor(for: ratio))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)

                if isToday {
                     RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white, lineWidth: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }
    
    private func colorForRatio(_ ratio: Double) -> Color {
        if ratio == 0 { return level0 }
        if ratio < 0.5 { return level1 } // Little (< 50%)
        if ratio < 1.0 { return level2 } // OK (50-99%)
        return level3 // Reached (100%+)
    }
    
    private func textColor(for ratio: Double) -> Color {
        if ratio == 0 { return .secondary }
        if ratio < 0.5 { return .white } 
        return .black
    }
}

// DateWrapper is now defined in Utils/Extensions.swift

#Preview {
    ProteinHeatmapView()
        .preferredColorScheme(.dark)
        .environmentObject(AppDataStore())
}
