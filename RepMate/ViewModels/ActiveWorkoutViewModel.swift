import Foundation
import Combine
import SwiftUI

@MainActor
final class ActiveWorkoutViewModel: ObservableObject {
    // Keyboard
    @Published var keyboardVisible: Bool = false

    // Rest timer
    @Published var timeRemaining: Int = 0
    @Published var initialTimerDuration: Int = 60
    @Published var isTimerActive: Bool = false
    private var timerCancellable: AnyCancellable?

    // Paywall / template saving UI
    @Published var showPaywall: Bool = false
    @Published var showSaveTemplateAlert: Bool = false
    @Published var newTemplateName: String = ""

    private weak var store: AppDataStore?
    private weak var themeManager: ThemeManager?

    func attach(store: AppDataStore, themeManager: ThemeManager) {
        self.store = store
        self.themeManager = themeManager
    }

    func handleKeyboardWillShow() {
        withAnimation { keyboardVisible = true }
    }

    func handleKeyboardWillHide() {
        withAnimation { keyboardVisible = false }
    }

    func requestSaveAsTemplate(isPro: Bool, templateCount: Int, suggestedName: String) {
        if !isPro && templateCount >= 3 {
            showPaywall = true
        } else {
            newTemplateName = suggestedName
            showSaveTemplateAlert = true
        }
    }

    func restoreTimerState(templateName: String?, exerciseLibrary: [Exercise]) {
        guard let store, let themeManager else { return }
        guard let aw = store.activeWorkout, let target = aw.timerTargetDate else { return }

        let now = Date()
        let remaining = target.timeIntervalSince(now)

        if remaining <= 0 {
            if var aw = store.activeWorkout {
                aw.timerTargetDate = nil
                store.updateActiveWorkout(aw)
            }
            LiveActivityManager.shared.endTimer()
            return
        }

        timerCancellable?.cancel()
        timerCancellable = nil

        timeRemaining = Int(remaining)
        initialTimerDuration = max(store.settings.restTime, Int(remaining))
        isTimerActive = true

        if LiveActivityManager.shared.hasActiveTimer {
            LiveActivityManager.shared.updateTimer(newEndTime: target)
        } else {
            let context = nextSetContext(activeWorkout: aw, exerciseLibrary: exerciseLibrary)
            LiveActivityManager.shared.startTimer(
                duration: Int(remaining),
                accentColor: themeManager.palette.accent,
                exerciseName: context.exerciseName,
                setInfo: context.setInfo,
                templateName: templateName,
                exerciseCategory: nil
            )
        }

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickTimer()
            }
    }

    func startRestTimer(templateName: String?, exerciseLibrary: [Exercise], customDuration: Int? = nil) {
        guard let store, let themeManager else { return }
        stopTimer()

        let duration = customDuration ?? store.settings.restTime
        initialTimerDuration = duration
        timeRemaining = duration
        isTimerActive = true
        HapticManager.shared.lightImpact()

        let targetDate = Date().addingTimeInterval(TimeInterval(duration))

        if var aw = store.activeWorkout {
            aw.timerTargetDate = targetDate
            store.updateActiveWorkout(aw)
        }

        let context = store.activeWorkout.map { nextSetContext(activeWorkout: $0, exerciseLibrary: exerciseLibrary) }
        LiveActivityManager.shared.startTimer(
            duration: duration,
            accentColor: themeManager.palette.accent,
            exerciseName: context?.exerciseName,
            setInfo: context?.setInfo,
            templateName: templateName,
            exerciseCategory: nil
        )

        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tickTimer(countdownHaptics: true)
            }
    }

    func cancelLocalTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isTimerActive = false
    }

    func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isTimerActive = false
        LiveActivityManager.shared.endTimer()
    }

    func skipTimer() {
        stopTimer()
        HapticManager.shared.selection()
    }

    func adjustTimer(_ seconds: Int) {
        guard let store else { return }
        guard var aw = store.activeWorkout, let currentTarget = aw.timerTargetDate else { return }

        let newTarget = currentTarget.addingTimeInterval(TimeInterval(seconds))
        if newTarget <= Date() {
            timeRemaining = 0
            aw.timerTargetDate = nil
            store.updateActiveWorkout(aw)
            stopTimer()
        } else {
            aw.timerTargetDate = newTarget
            store.updateActiveWorkout(aw)
            LiveActivityManager.shared.updateTimer(newEndTime: newTarget)
            timeRemaining = Int(ceil(newTarget.timeIntervalSince(Date())))
            if timeRemaining > initialTimerDuration {
                initialTimerDuration = timeRemaining
            }
        }

        HapticManager.shared.selection()
    }

    // MARK: - Internals

    private func tickTimer(countdownHaptics: Bool = false) {
        guard let store else { return }
        guard let dynamicTarget = store.activeWorkout?.timerTargetDate else { return }

        let secondsLeft = Int(ceil(dynamicTarget.timeIntervalSince(Date())))
        if secondsLeft > 0 {
            timeRemaining = secondsLeft

            if countdownHaptics {
                if secondsLeft == 5 {
                    HapticManager.shared.lightImpact()
                } else if secondsLeft == 3 {
                    HapticManager.shared.selection()
                }
            }
            return
        }

        timeRemaining = 0
        HapticManager.shared.success()

        if countdownHaptics {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                HapticManager.shared.success()
            }
        }

        if var aw = store.activeWorkout {
            aw.timerTargetDate = nil
            store.updateActiveWorkout(aw)
        }

        stopTimer()
    }

    private func nextSetContext(activeWorkout aw: ActiveWorkout, exerciseLibrary: [Exercise]) -> (exerciseName: String?, setInfo: String?) {
        for exId in aw.exerciseIds {
            if let rows = aw.rowsByExercise[exId],
               let index = rows.firstIndex(where: { !$0.isCompleted }),
               let ex = exerciseLibrary.first(where: { $0.id == exId }) {
                return (ex.name, "Set \(index + 1) of \(rows.count)")
            }
        }
        return ("Workout Complete", "Great Job!")
    }
}

