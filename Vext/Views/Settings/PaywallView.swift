import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var storeManager: StoreManager
    
    var body: some View {
        ZStack {
            // Cyber Glass Background
            Theme.Colors.background.ignoresSafeArea()
            
            VStack(spacing: 0) {
                
                // Header Image / Icon
                ZStack {
                    Circle()
                        .fill(Theme.Colors.accent.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 60))
                        .foregroundColor(Theme.Colors.accent)
                        .shadow(color: Theme.Colors.accent.opacity(0.6), radius: 10)
                }
                .padding(.top, 40)
                .padding(.bottom, 24)
                
                // Title
                Text("Unlock Vext Pro")
                    .font(.system(size: 32, weight: .bold, design: .default))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, 8)
                
                Text("One-time purchase. Forged, not rented.")
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.bottom, 40)
                
                // Features List
                VStack(alignment: .leading, spacing: 24) {
                    FeatureRow(icon: "infinity", title: "Unlimited Templates", subtitle: "Break the 3 template limit. Build the ultimate library.")
                    FeatureRow(icon: "paintpalette.fill", title: "Premium App Icons", subtitle: "Unlock the exclusive 'Gold' and 'Forged Iron' stealth icons.")
                    FeatureRow(icon: "chart.line.uptrend.xyaxis", title: "Pro Stats", subtitle: "Exclusive insights into 1RM projections and volume trends.")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Pricing & Purchase Button
                VStack(spacing: 16) {
                    if !storeManager.isPro {
                        if let product = storeManager.products.first(where: { $0.id == "vext_pro_lifetime" }) {
                            Text(product.displayPrice)
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            Button {
                                Task {
                                    try? await storeManager.purchase(product)
                                    if storeManager.isPro {
                                        dismiss()
                                    }
                                }
                            } label: {
                                Text("Upgrade to Pro")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.Colors.accent)
                                    .cornerRadius(16)
                                    .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 32)
                        } else {
                            // Fallback button for when Products don't load (e.g. in Simulator without StoreKit Config)
                            Text("$4.99")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Theme.Colors.textPrimary)
                            
                            Button {
                                // Simulate successful purchase in development
                                storeManager.isPro = true
                                HapticManager.shared.success()
                                dismiss()
                            } label: {
                                Text("Upgrade to Pro (Dev Mode)")
                                    .font(.headline)
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Theme.Colors.accent)
                                    .cornerRadius(16)
                                    .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                            }
                            .padding(.horizontal, 32)
                            
                            Text("StoreKit is not configured for this simulator. Dev Mode bypasses the App Store.")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textDim)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                                .padding(.top, 4)
                        }
                    } else {
                        Text("You have unlocked Vext Pro!")
                            .font(.headline)
                            .foregroundColor(Theme.Colors.accent)
                            .padding(.bottom, 8)
                    }
                    
                    // Restore Button
                    Button("Restore Purchases") {
                        storeManager.restorePurchases()
                    }
                    .font(.footnote)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding(.top, 8)
                }
                .padding(.bottom, 40)
            }
        }
        // Auto-dismiss if purchase succeeds while open
        .onChange(of: storeManager.isPro) { _, isPro in
            if isPro {
                HapticManager.shared.success()
                dismiss()
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .padding()
            }
        }
    }
}

// MARK: - Subviews
private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(Theme.Colors.accent)
                .frame(width: 32)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(Theme.Colors.textPrimary)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(Theme.Colors.textSecondary)
                    .lineLimit(2)
            }
        }
    }
}

#Preview {
    PaywallView()
        .environmentObject(StoreManager())
}
