import SwiftUI

/// Grid picker for alternate app icons.
/// Placeholder keys are used — actual icon assets will be added later.
struct CustomIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showPaywall = false
    @State private var currentIcon: String? = UIApplication.shared.alternateIconName
    
    // Stealth is free. Gold and Forged Iron are Pro.
    private let icons: [(key: String?, name: String, colors: [Color], isProPath: Bool)] = [
        (nil, "Stealth", [Color(white: 0.15), Color(white: 0.05)], false),
        ("AppIcon_gold", "Gold", [.yellow, .orange], true),
        ("AppIcon_forged", "Forged Iron", [.gray, .black], true)
    ]
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: 24) {
                    Text("Choose your app icon")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 8)
                    
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 20) {
                        ForEach(icons, id: \.name) { icon in
                            iconCell(icon: icon)
                        }
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
    }
    
    @ViewBuilder
    private func iconCell(icon: (key: String?, name: String, colors: [Color], isProPath: Bool)) -> some View {
        let isSelected = currentIcon == icon.key
        let isLocked = icon.isProPath && !storeManager.isPro
        
        Button {
            if isLocked {
                showPaywall = true
                HapticManager.shared.lightImpact()
            } else {
                setIcon(icon.key)
            }
        } label: {
            VStack(spacing: 10) {
                // Placeholder icon visual
                RoundedRectangle(cornerRadius: 16)
                    .fill(
                        LinearGradient(
                            colors: icon.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 72, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.white : Color.white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay(
                        Group {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white)
                                    .shadow(radius: 4)
                            } else if isLocked {
                                Image(systemName: "lock.fill")
                                    .font(.system(size: 22))
                                    .foregroundColor(.white.opacity(0.8))
                                    .shadow(radius: 4)
                            }
                        }
                    )
                    .shadow(color: isSelected ? icon.colors.first!.opacity(0.5) : .clear, radius: 8)
                    .opacity(isLocked ? 0.6 : 1.0)
                
                HStack(spacing: 4) {
                    Text(icon.name)
                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                        .foregroundColor(isSelected ? .white : .secondary)
                }
            }
        }
    }
    
    private func setIcon(_ iconName: String?) {
        // Eagerly update UI state (fixing simulator bugs where the API throws a spurious error but still succeeds)
        currentIcon = iconName
        HapticManager.shared.success()
        
        UIApplication.shared.setAlternateIconName(iconName) { error in
            if let error = error {
                print("Note: Icon setting returned an error (common in Simulator): \(error.localizedDescription)")
            }
        }
    }
}
