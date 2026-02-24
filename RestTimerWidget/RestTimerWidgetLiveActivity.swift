import ActivityKit
import WidgetKit
import SwiftUI

/// Live Activity widget for the rest timer — shown on Lock Screen and Dynamic Island.
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
                    Image(systemName: "dumbbell.fill")
                        .font(.title2)
                        .foregroundColor(accentColor(from: context))
                        .padding(.leading, 8)
                        .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: "timer")
                        .font(.title2)
                        .foregroundColor(accentColor(from: context))
                        .padding(.trailing, 8)
                        .padding(.top, 8)
                }
                
                DynamicIslandExpandedRegion(.center) {
                    VStack(alignment: .center, spacing: 4) {
                        Text("REST TIMER")
                            .font(.system(size: 12, weight: .bold, design: .default))
                            .foregroundColor(.white.opacity(0.7))
                            .tracking(2)
                        
                        if context.state.endTime > Date() {
                            Text(timerInterval: Date()...context.state.endTime, countsDown: true)
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor(from: context))
                                .monospacedDigit()
                                .shadow(color: accentColor(from: context).opacity(0.8), radius: 8, x: 0, y: 0)
                        } else {
                            Text("0:00")
                                .font(.system(size: 40, weight: .bold, design: .monospaced))
                                .foregroundColor(accentColor(from: context))
                                .monospacedDigit()
                                .shadow(color: accentColor(from: context).opacity(0.8), radius: 8, x: 0, y: 0)
                        }
                    }
                    .padding(.top, 4)
                }
                
                DynamicIslandExpandedRegion(.bottom) {
                    if context.state.endTime > Date() {
                        Link(destination: URL(string: "vext://workout")!) {
                            HStack(spacing: 8) {
                                Image(systemName: "stop.fill")
                                Text("Stop Timer")
                            }
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 24)
                            .background(accentColor(from: context))
                            .clipShape(Capsule())
                            .shadow(color: accentColor(from: context).opacity(0.6), radius: 6, x: 0, y: 2)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 8)
                    }
                }
            } compactLeading: {
                // Compact: Single icon
                Image(systemName: "dumbbell.fill")
                    .foregroundColor(accentColor(from: context))
                    .padding(.leading, 4)
            } compactTrailing: {
                // Compact: Single combined ring + timer text natively powered by ProgressView
                if context.state.endTime > Date() {
                    ProgressView(timerInterval: Date()...context.state.endTime, countsDown: true) { EmptyView() }
                        .progressViewStyle(.circular)
                        .tint(accentColor(from: context))
                } else {
                    Text("0:00")
                        .font(.system(size: 14, weight: .bold, design: .monospaced))
                        .foregroundColor(accentColor(from: context))
                }
            } minimal: {
                // Minimal: Progress ring
                if context.state.endTime > Date() {
                    ProgressView(timerInterval: Date()...context.state.endTime, countsDown: true) { EmptyView() }
                        .progressViewStyle(.circular)
                        .tint(accentColor(from: context))
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
                // Left: Dumbbell Icon
                Image(systemName: "dumbbell.fill")
                    .font(.system(size: 32))
                    .foregroundColor(accent)
                    .padding(16)
                    .background(
                        Circle()
                            .fill(Color.black.opacity(0.5))
                            .overlay(Circle().stroke(accent.opacity(0.4), lineWidth: 1))
                            .shadow(color: accent.opacity(0.4), radius: 6)
                    )
                
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
