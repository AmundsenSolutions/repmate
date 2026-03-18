import Foundation
import Combine

@MainActor
final class SettingsStore: ObservableObject {
    private unowned let store: AppDataStore
    private var cancellable: AnyCancellable?

    init(store: AppDataStore) {
        self.store = store
        self.cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var settings: AppSettings {
        get { store.settings }
        set { store.settings = newValue }
    }

    func save() {
        store.saveSettings()
    }

    func updateDailyProteinTarget(_ grams: Int) {
        store.updateDailyProteinTarget(grams)
    }

    func updateRestTime(_ seconds: Int) {
        store.updateRestTime(seconds)
    }

    func updateTargetRepRange(min: Int, max: Int) {
        store.updateTargetRepRange(min: min, max: max)
    }

    func updateTrackedMuscles(_ muscles: [String]) {
        store.updateTrackedMuscles(muscles)
    }
}

