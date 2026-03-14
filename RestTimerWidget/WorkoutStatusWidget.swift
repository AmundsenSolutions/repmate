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
    
    // RepMate Orange Accent
    private let accentColor = Color(red: 1.0, green: 0.4, blue: 0.1)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "figure.strengthtraining.traditional")
                    .foregroundColor(accentColor)
                    .font(.system(size: 10, weight: .bold))
                Text("REPMATE")
                    .font(.system(size: 10, weight: .black))
                    .tracking(1.5)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
            
            if entry.isActive {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.workoutName ?? "Active Workout")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                        Text("ACTIVE")
                            .fontWeight(.black)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(accentColor)
                }
                
                Spacer()
                
                Text("\(entry.exercisesCompleted) exercises completed")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ready to lift?")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    
                    Text("No active session")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }
                
                Spacer()
                
                HStack {
                    Spacer()
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(accentColor)
                }
            }
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
