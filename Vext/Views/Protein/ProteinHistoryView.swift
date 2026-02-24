import SwiftUI

struct ProteinHistoryView: View {
    @EnvironmentObject var store: AppDataStore
    @State private var selectedDate: Date
    
    init(initialDate: Date = Date()) {
        _selectedDate = State(initialValue: initialDate)
    }
    
    private var entriesForDate: [ProteinEntry] {
        store.proteinEntriesFor(date: selectedDate)
    }
    
    private var totalForDate: Int {
        store.totalProteinFor(date: selectedDate)
    }
    
    private var target: Int {
        max(store.settings.dailyProteinTarget, 1)
    }
    
    private var progress: Double {
        min(Double(totalForDate) / Double(target), 1.0)
    }
    
    var body: some View {
        List {
            Section {
                DatePicker("Select Date", selection: $selectedDate, displayedComponents: .date)
                    .datePickerStyle(.compact)
            }
            
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .lastTextBaseline, spacing: 8) {
                        Text("\(totalForDate)")
                            .font(.system(size: 48, weight: .bold, design: .rounded))
                        Text("/ \(target) g")
                            .font(.title3)
                            .foregroundColor(.secondary)
                    }
                    
                    ProgressView(value: progress)
                    
                    let remaining = max(target - totalForDate, 0)
                    Text("\(remaining) g remaining")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            }
            
            Section(header: Text(formatDateHeader(selectedDate))) {
                if entriesForDate.isEmpty {
                    Text("No protein entries for this day.")
                        .foregroundColor(.secondary)
                } else {
                    ForEach(entriesForDate.sorted(by: { $0.date < $1.date })) { entry in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("\(entry.grams) g")
                                .font(.headline)
                            if let note = entry.note, !note.isEmpty {
                                Text(note)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            Text(entry.date, style: .time)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                store.deleteProteinEntry(withID: entry.id)
                                HapticManager.shared.success()
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                            .tint(.red)
                        }
                    }
                }
            }
        }
        .navigationTitle("Protein History")
    }
    
    private static let longDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .long
        return f
    }()
    
    private func formatDateHeader(_ date: Date) -> String {
        let calendar = Calendar.current
        
        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            return Self.longDateFormatter.string(from: date)
        }
    }
}

#Preview {
    NavigationStack {
        ProteinHistoryView()
            .environmentObject(AppDataStore())
    }
}
