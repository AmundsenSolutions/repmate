import Foundation
import Combine

@MainActor
final class WorkoutStore: ObservableObject {
    private weak var store: AppDataStore?
    private var cancellable: AnyCancellable?

    init(store: AppDataStore) {
        self.store = store
        self.cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var workoutTemplates: [WorkoutTemplate] {
        get { store?.workoutTemplates ?? [] }
    }

    var workoutSessions: [WorkoutSession] {
        get { store?.workoutSessions ?? [] }
    }

    var exerciseLibrary: [Exercise] {
        get { store?.exerciseLibrary ?? [] }
    }

    var activeWorkout: ActiveWorkout? {
        get { store?.activeWorkout }
        set { store?.activeWorkout = newValue }
    }

    func startWorkout(template: WorkoutTemplate, force: Bool = false) {
        store?.startWorkout(template: template, force: force)
    }

    func discardActiveWorkout() {
        store?.discardActiveWorkout()
    }

    func updateActiveWorkout(_ workout: ActiveWorkout) {
        store?.updateActiveWorkout(workout)
    }

    func silentUpdateActiveWorkout(_ workout: ActiveWorkout) {
        store?.silentUpdateActiveWorkout(workout)
    }
}

