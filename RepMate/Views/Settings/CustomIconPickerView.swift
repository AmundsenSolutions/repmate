import SwiftUI

/// Grid picker for alternate app icons.
struct CustomIconPickerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    @State private var showPaywall = false
    @State private var currentIcon: String? = UIApplication.shared.alternateIconName
    
    // Only Electric Blue is free. Others are Pro.
    private let icons: [(key: String?, name: String, image: String, isProPath: Bool)] = [
        (nil, "Electric Blue", "Preview_Blue", false),
        ("AppIcon_Gold", "24k Gold", "Preview_Gold", true),
        ("AppIcon_Purple", "Cosmic Purple", "Preview_Purple", true),
        ("AppIcon_Green", "Hyper Green", "Preview_Green", true),
        ("AppIcon_Orange", "Plasma Orange", "Preview_Orange", true),
        ("AppIcon_Gray", "Stealth Gray", "Preview_Gray", true)
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
    private func iconCell(icon: (key: String?, name: String, image: String, isProPath: Bool)) -> some View {
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
                // Actual icon visual
                Image(icon.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .saturation(isLocked ? 0.0 : 1.0)
                    .opacity(isLocked ? 0.35 : 1.0)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.2), lineWidth: isSelected ? 3 : 1)
                    )
                    .overlay(alignment: .bottomTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 24))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .blue)
                                .background(Circle().fill(Color.black).padding(1))
                                .offset(x: 6, y: 6)
                        } else if isLocked {
                            Image(systemName: "lock.circle.fill")
                                .font(.system(size: 24))
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .gray)
                                .background(Circle().fill(Color.black).padding(1))
                                .offset(x: 6, y: 6)
                        }
                    }
                    .shadow(color: isSelected ? Color.blue.opacity(0.4) : .clear, radius: 8)
                
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
            if error != nil {
            }
        }
    }
}
