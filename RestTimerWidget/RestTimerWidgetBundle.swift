import WidgetKit
import SwiftUI

/// Entry point for the Rest Timer widget extension.
@main
struct RestTimerWidgetBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
        ProteinWidget()
        WorkoutStatusWidget()
    }
}
