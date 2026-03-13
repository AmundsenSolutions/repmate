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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "drop.fill")
                    .foregroundColor(.blue)
                Text("PROTEIN")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1)
            }
            
            Spacer()
            
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text("\(entry.amount)")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("g")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                
                Text("/ \(entry.goal)g goal")
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            
            ProgressView(value: Double(entry.amount), total: Double(entry.goal))
                .tint(.blue)
                .progressViewStyle(.linear)
        }
        .padding()
        .containerBackground(Color.black.opacity(0.8), for: .widget)
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
