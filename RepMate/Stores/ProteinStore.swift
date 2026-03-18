import Foundation
import Combine

@MainActor
final class ProteinStore: ObservableObject {
    private unowned let store: AppDataStore
    private var cancellable: AnyCancellable?

    init(store: AppDataStore) {
        self.store = store
        self.cancellable = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    var proteinEntries: [ProteinEntry] {
        get { store.proteinEntries }
        set { store.proteinEntries = newValue }
    }

    var favoriteProteinItems: [FavoriteProtein] {
        get { store.favoriteProteinItems }
        set { store.favoriteProteinItems = newValue }
    }

    var dailyTarget: Int {
        store.settings.dailyProteinTarget
    }

    func addEntry(grams: Int, note: String?) {
        store.addProteinEntry(grams: grams, note: note)
    }

    func deleteEntriesForToday(at offsets: IndexSet) {
        store.deleteProteinEntriesForToday(at: offsets)
    }

    func totalProtein(for date: Date) -> Int {
        store.totalProteinFor(date: date)
    }

    func streak() -> Int {
        store.proteinStreak()
    }

    func toggleFavorite(entry: ProteinEntry) {
        store.toggleFavorite(entry: entry)
    }

    func isFavorite(entry: ProteinEntry) -> Bool {
        store.isFavorite(entry: entry)
    }
}

