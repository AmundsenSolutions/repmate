import Foundation
import Combine

// MARK: - Data Model

/// A single body-weight log entry.
struct WeightEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let date: Date
    let weight: Double   // kg

    init(id: UUID = UUID(), date: Date = Date(), weight: Double) {
        self.id = id
        self.date = date
        self.weight = weight
    }
}

// MARK: - Weight Store

/// Manages body-weight entries in isolation from workout data.
/// Persists to `weight_data.json` via the shared `PersistenceManager`.
@MainActor
final class WeightStore: ObservableObject {

    @Published var entries: [WeightEntry] = []
    @Published var isLoaded: Bool = false

    private let fileName = "weight_data.json"

    init() {
        Task { await loadAsync() }
    }

    // MARK: - Public API

    /// Logs today's weight, replacing any existing entry for the same calendar day.
    func logWeight(_ kg: Double) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        // Replace if an entry already exists for today
        if let index = entries.firstIndex(where: { calendar.isDate($0.date, inSameDayAs: today) }) {
            entries[index] = WeightEntry(id: entries[index].id, date: Date(), weight: kg)
        } else {
            entries.append(WeightEntry(weight: kg))
        }
        entries.sort { $0.date < $1.date }
        save()
    }

    /// Removes a weight entry by ID.
    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        save()
    }

    /// Returns the entry for today, if any.
    func todayEntry() -> WeightEntry? {
        let calendar = Calendar.current
        return entries.first(where: { calendar.isDateInToday($0.date) })
    }

    // MARK: - Trend (SMA with Sparse-Data Fallback)

    /// A single point on the trend line.
    struct TrendPoint: Identifiable {
        let id = UUID()
        let date: Date
        let value: Double
    }

    /// Builds a continuous trend line from all weight entries.
    ///
    /// **Algorithm:**
    /// For each raw entry date we compute a smoothed value:
    /// 1. **Primary**: 7-day trailing SMA — average of all entries within [date-6d … date].
    /// 2. **Fallback (sparse data)**: If the 7-day window contains fewer than 2 entries,
    ///    use the last 3 entries (regardless of time span) to avoid breaking the trend line.
    ///
    /// This guarantees a continuous curve even when the user weighs in every few weeks.
    func trendLine() -> [TrendPoint] {
        guard entries.count >= 2 else {
            // With 0-1 entries there's nothing to smooth.
            return entries.map { TrendPoint(date: $0.date, value: $0.weight) }
        }

        let sorted = entries.sorted { $0.date < $1.date }
        var result: [TrendPoint] = []

        for (index, entry) in sorted.enumerated() {
            let calendar = Calendar.current
            guard let windowStart = calendar.date(byAdding: .day, value: -6, to: entry.date) else {
                result.append(TrendPoint(date: entry.date, value: entry.weight))
                continue
            }

            // Collect entries inside the 7-day trailing window
            let windowEntries = sorted.filter { $0.date >= windowStart && $0.date <= entry.date }

            let smoothed: Double
            if windowEntries.count >= 2 {
                // Primary path: true 7-day SMA
                smoothed = windowEntries.map(\.weight).reduce(0, +) / Double(windowEntries.count)
            } else {
                // Sparse-data fallback: use up to 3 most recent entries ending at this point
                let recentSlice = sorted.prefix(through: index).suffix(3)
                smoothed = recentSlice.map(\.weight).reduce(0, +) / Double(recentSlice.count)
            }

            result.append(TrendPoint(date: entry.date, value: smoothed))
        }

        return result
    }

    /// Returns a weight delta over a given number of days (e.g. 7, 30).
    /// Positive = gained, negative = lost.
    func delta(days: Int) -> Double? {
        guard let latest = entries.last else { return nil }
        let calendar = Calendar.current
        guard let cutoff = calendar.date(byAdding: .day, value: -days, to: latest.date) else { return nil }

        // Find the entry closest to the cutoff date
        let older = entries
            .filter { $0.date <= cutoff }
            .max(by: { $0.date < $1.date })

        guard let baseline = older else { return nil }
        return latest.weight - baseline.weight
    }

    // MARK: - Persistence

    private func loadAsync() async {
        // Disk read on a detached task to avoid blocking the main thread
        let data: Data? = await Task.detached(priority: .userInitiated) { [fileName] in
            guard let url = try? PersistenceManager.shared.fileURL(for: fileName),
                  FileManager.default.fileExists(atPath: url.path) else {
                return nil as Data?
            }
            return try? Data(contentsOf: url)
        }.value

        // Apply on MainActor
        if let data {
            do {
                let decoded = try JSONDecoder().decode([WeightEntry].self, from: data)
                self.entries = decoded.sorted { $0.date < $1.date }
            } catch {
                // File exists but is corrupt/empty — start fresh instead of crashing
                print("[WeightStore] Decoding failed, resetting: \(error)")
                self.entries = []
            }
        }

        isLoaded = true
    }

    private func save() {
        let snapshot = entries
        PersistenceManager.shared.save(snapshot, to: fileName) { result in
            if case .failure(let error) = result {
                print("[WeightStore] Save failed: \(error)")
            }
        }
    }
}
