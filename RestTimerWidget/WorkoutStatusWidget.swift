import WidgetKit
import SwiftUI

struct WorkoutStatusEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
    let workoutName: String?
    let durationSeconds: Int?
    let exercisesCompleted: Int
}

struct WorkoutStatusProvider: TimelineProvider {
    func placeholder(in context: Context) -> WorkoutStatusEntry {
        WorkoutStatusEntry(date: Date(), isActive: true, workoutName: "Leg Day", durationSeconds: 3600, exercisesCompleted: 4)
    }

    func getSnapshot(in context: Context, completion: @escaping (WorkoutStatusEntry) -> ()) {
        let entry = WorkoutStatusEntry(date: Date(), isActive: true, workoutName: "Leg Day", durationSeconds: 3600, exercisesCompleted: 4)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WorkoutStatusEntry>) -> ()) {
        let defaults = UserDefaults(suiteName: "group.no.amundsen.repmate")
        let isActive = defaults?.bool(forKey: "isWorkoutActive") ?? false
        let name = defaults?.string(forKey: "activeWorkoutName")
        let count = defaults?.integer(forKey: "exercisesCompleted") ?? 0
        
        let entry = WorkoutStatusEntry(
            date: Date(),
            isActive: isActive,
            workoutName: name,
            durationSeconds: nil,
            exercisesCompleted: count
        )
        let timeline = Timeline(entries: [entry], policy: .atEnd)
        completion(timeline)
    }
}

struct WorkoutStatusWidgetView: View {
    var entry: WorkoutStatusEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundColor(.orange)
                Text("REPMATE")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1)
            }
            
            Spacer()
            
            if entry.isActive {
                Text(entry.workoutName ?? "Workout")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Image(systemName: "clock")
                    Text("ACTIVE")
                        .fontWeight(.bold)
                }
                .font(.caption)
                .foregroundColor(.orange)
                
                Text("\(entry.exercisesCompleted) exercises")
                    .font(.caption2)
                    .foregroundColor(.gray)
            } else {
                Text("Start Lifting")
                    .font(.headline)
                
                Text("No active session")
                    .font(.caption)
                    .foregroundColor(.gray)
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
            }
        }
        .padding()
        .containerBackground(Color.black.opacity(0.8), for: .widget)
    }
}

struct WorkoutStatusWidget: Widget {
    let kind: String = "WorkoutStatusWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WorkoutStatusProvider()) { entry in
            WorkoutStatusWidgetView(entry: entry)
        }
        .configurationDisplayName("Workout Status")
        .description("See your current workout progress.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
