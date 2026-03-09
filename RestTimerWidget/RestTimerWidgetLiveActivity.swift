import ActivityKit
import WidgetKit
import SwiftUI

/// Defines the UI layout for the Rest Timer widget across all Dynamic Island and Lock Screen contexts.
struct RestTimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RestTimerAttributes.self) { context in
            // MARK: - Lock Screen / Banner View
            lockScreenView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.6))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading, spacing: 2) {
                        if let template = context.attributes.templateName {
                            Text(template.uppercased())
                                .font(.system(size: 11, weight: .black))
                                .foregroundColor(accentColor(from: context).opacity(0.8))
                                .tracking(1.5)
                        }
                        Text(context.attributes.exerciseName ?? "Resting")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundColor(.white)
                            .lineLimit(1)
                            .minimumScaleFactor(0.4)
                        if let setInfo = context.attributes.setInfo {
                            Text(setInfo)
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    .padding(.leading, 4)
                    .padding(.vertical, 8)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    Group {
                        if context.state.endTime > Date() {
                            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor(from: context))
                                .monospacedDigit()
                                .frame(minWidth: 80, alignment: .trailing)
                        } else {
                            Text("0:00")
                                .font(.system(size: 34, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor(from: context))
                                .monospacedDigit()
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .padding(.trailing, 4)
                }
            } compactLeading: {
                // Compact: Single icon
                Image(systemName: "timer")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accentColor(from: context))
                    .padding(.leading, 2)
            } compactTrailing: {
                // Compact: Just the countdown number
                if context.state.endTime > Date() {
                    Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor(from: context))
                        .monospacedDigit()
                        .frame(maxWidth: 48)
                        .padding(.trailing, 2)
                } else {
                    Text("0:00")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor(from: context))
                        .monospacedDigit()
                        .padding(.trailing, 2)
                }
            } minimal: {
                // Minimal: Progress ring
                if context.state.endTime > Date() {
                    ZStack {
                        ProgressView(timerInterval: context.attributes.startTime...context.state.endTime, countsDown: true) { EmptyView() }
                            .progressViewStyle(.circular)
                            .tint(accentColor(from: context))
                    }
                } else {
                    Image(systemName: "timer")
                        .foregroundColor(accentColor(from: context))
                }
            }
            .keylineTint(accentColor(from: context))
        }
    }
    
    // MARK: - Lock Screen View
    
    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<RestTimerAttributes>) -> some View {
        let end = context.state.endTime
        let accent = accentColor(from: context)
        
        ZStack {
            // Dark Frosted Cyber Glass Material
            ContainerRelativeShape()
                .fill(.ultraThinMaterial)
            
            ContainerRelativeShape()
                .fill(Color.black.opacity(0.4)) // Extra darkening for constrast
            
            HStack(spacing: 0) {
                // Left: Exercise Details
                VStack(alignment: .leading, spacing: 4) {
                    if let template = context.attributes.templateName {
                        Text(template.uppercased())
                            .font(.system(size: 11, weight: .black, design: .default))
                            .foregroundColor(accent.opacity(0.8))
                            .tracking(1.5)
                    }
                    
                    Text(context.attributes.exerciseName ?? "Resting")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    
                    if let setInfo = context.attributes.setInfo {
                        Text(setInfo)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .padding(.leading, 4)
                
                Spacer()
                
                // Right: Countdown Timer
                VStack(alignment: .trailing, spacing: 4) {
                    Text("REST TIMER")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                        .tracking(1)
                    
                    if end > Date() {
                        Text(timerInterval: Date()...end, countsDown: true)
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(accent)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .shadow(color: accent.opacity(0.8), radius: 8, x: 0, y: 0) // Neon Glow
                    } else {
                        Text("0:00")
                            .font(.system(size: 42, weight: .bold, design: .monospaced))
                            .foregroundColor(accent)
                            .monospacedDigit()
                            .multilineTextAlignment(.trailing)
                            .shadow(color: accent.opacity(0.8), radius: 8, x: 0, y: 0) // Neon Glow
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
    }
    
    // MARK: - Helpers
    
    private func accentColor(from context: ActivityViewContext<RestTimerAttributes>) -> Color {
        Color(
            red: context.attributes.accentR,
            green: context.attributes.accentG,
            blue: context.attributes.accentB
        )
    }
}
