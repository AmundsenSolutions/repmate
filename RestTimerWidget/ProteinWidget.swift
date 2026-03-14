import WidgetKit
import SwiftUI

struct ProteinEntry: TimelineEntry {
    let date: Date
    let amount: Int
    let goal: Int
    let isPro: Bool
}

struct ProteinProvider: TimelineProvider {
    func placeholder(in context: Context) -> ProteinEntry {
        ProteinEntry(date: Date(), amount: 150, goal: 200, isPro: true)
    }

    func getSnapshot(in context: Context, completion: @escaping (ProteinEntry) -> ()) {
        let entry = ProteinEntry(date: Date(), amount: 150, goal: 200, isPro: true)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ProteinEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: "group.no.amundsen.repmate")
        let amount = defaults?.integer(forKey: "todayProtein") ?? 0
        let goal = defaults?.integer(forKey: "proteinGoal") ?? 180
        
        let entry = ProteinEntry(date: Date(), amount: amount, goal: goal, isPro: true)
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct ProteinWidgetView: View {
    var entry: ProteinEntry
    
    // RepMate Blue Accent
    private let accentColor = Color(red: 0.0, green: 0.5, blue: 1.0)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(accentColor)
                    .font(.system(size: 10, weight: .bold))
                Text("PROTEIN")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(entry.amount)")
                        .font(.system(size: 36, weight: .medium, design: .rounded))
                        .foregroundColor(.white)
                    Text("g")
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundColor(accentColor)
                }
                
                Text("\(entry.goal)g goal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: Double(entry.amount), total: Double(entry.goal))
                .tint(accentColor)
                .progressViewStyle(.linear)
                .scaleEffect(x: 1, y: 1.5, anchor: .center)
                .clipShape(Capsule())
        }
        .padding(16)
        .containerBackground(for: .widget) {
            ZStack {
                Color.black
                accentColor.opacity(0.05).blur(radius: 20)
            }
        }
    }
}

struct ProteinWidget: Widget {
    let kind: String = "ProteinWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ProteinProvider()) { entry in
            ProteinWidgetView(entry: entry)
        }
        .configurationDisplayName("Protein Tracker")
        .description("Track your protein intake for today.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
