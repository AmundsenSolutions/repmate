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
                Text("RepMate Pro")
                    .font(.system(size: 36, weight: .black, design: .default))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, 4)
                
                Text("Unlock Everything.")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.bottom, 32)
                
                // Features List
                VStack(alignment: .leading, spacing: 24) {
                    FeatureRow(icon: "sparkles", title: "50 Daily AI Sessions", subtitle: "Free tier is limited to 5.")
                    FeatureRow(icon: "infinity", title: "Unlimited Workouts", subtitle: "Free tier is limited to 3 templates.")
                    FeatureRow(icon: "chart.bar.fill", title: "Pro Analytics", subtitle: "Deep insights with Muscle Map & Heatmaps.")
                    FeatureRow(icon: "paintpalette.fill", title: "Premium Branding", subtitle: "Exclusive custom themes and app icons.")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Pricing & Purchase Button
                VStack(spacing: 16) {
                    if !storeManager.isPro {
                        if let product = storeManager.products.first(where: { $0.id == "repmate_pro_monthly" }) {
                            Button {
                                Task {
                                    try? await storeManager.purchase(product)
                                    if storeManager.isPro {
                                        dismiss()
                                    }
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    Text("Get Pro for \(product.displayPrice) / month")
                                        .font(.system(size: 19, weight: .bold))
                                    Text("AUTO-RENEWING SUBSCRIPTION")
                                        .font(.system(size: 10, weight: .black))
                                        .opacity(0.7)
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .glowingPanelButton()
                            .padding(.horizontal, 32)
                            
                            Text("Payment is charged to your Apple ID. Renews automatically unless canceled 24h before period ends.")
                                .font(.system(size: 10))
                                .foregroundColor(Theme.Colors.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 4)
                        } else {
                            // Product not loaded yet — show loading state
                            ProgressView()
                                .tint(Theme.Colors.accent)
                                .padding(.bottom, 8)
                            
                            Text("Loading product info...")
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                    } else {
                        Text("You have unlocked RepMate Pro!")
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
        .alert("Restore Purchases", isPresented: Binding(
            get: { storeManager.restoreMessage != nil },
            set: { if !$0 { storeManager.restoreMessage = nil } }
        )) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(storeManager.restoreMessage ?? "")
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
