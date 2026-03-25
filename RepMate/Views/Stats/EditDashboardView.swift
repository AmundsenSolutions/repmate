import SwiftUI

struct EditDashboardView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss

    @State private var order: [StatCardType] = []

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                List {
                    ForEach(order) { card in
                        HStack(spacing: 14) {
                            Image(systemName: card.icon)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(Theme.Colors.accent)
                                .frame(width: 28, height: 28)

                            Text(card.displayName)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.white)

                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(Theme.Colors.cardBackground)
                        .listRowSeparatorTint(.white.opacity(0.08))
                    }
                    .onMove { source, destination in
                        order.move(fromOffsets: source, toOffset: destination)
                    }
                    .deleteDisabled(true)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
                .environment(\.editMode, .constant(.active))
            }
            .navigationTitle("Edit Dashboard")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white.opacity(0.7))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        store.settings.statsOrder = order
                        store.saveSettings()
                        HapticManager.shared.lightImpact()
                        dismiss()
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(Theme.Colors.accent)
                }
            }
        }
        .onAppear {
            order = store.settings.activeStatsOrder
        }
    }
}
