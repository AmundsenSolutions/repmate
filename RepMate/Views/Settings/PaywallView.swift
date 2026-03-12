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
                Text("Lifetime Access")
                    .font(.system(size: 36, weight: .black, design: .default))
                    .foregroundColor(Theme.Colors.textPrimary)
                    .padding(.bottom, 4)
                
                Text("One payment. Forever Yours.")
                    .font(.headline)
                    .foregroundColor(Theme.Colors.accent)
                    .padding(.bottom, 32)
                
                // Features List
                VStack(alignment: .leading, spacing: 24) {
                    FeatureRow(icon: "infinity", title: "Unlimited Workouts", subtitle: "Remove all limits. Build the ultimate routine library.")
                    FeatureRow(icon: "chart.bar.fill", title: "Master Your Progress", subtitle: "Deep insights into 1RM projections and volume trends.")
                    FeatureRow(icon: "paintpalette.fill", title: "Legendary Aesthetics", subtitle: "Unlock exclusive 'Gold' and 'Forged Iron' stealth icons.")
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // Pricing & Purchase Button
                VStack(spacing: 16) {
                    if !storeManager.isPro {
                        if let product = storeManager.products.first(where: { $0.id == "repmate_pro_lifetime" }) {
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
                                VStack(spacing: 4) {
                                    Text("Get Pro for \(product.displayPrice)")
                                        .font(.system(size: 18, weight: .bold))
                                    Text("ONE-TIME PURCHASE")
                                        .font(.system(size: 10, weight: .black))
                                        .opacity(0.8)
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    ZStack {
                                        Theme.Colors.accent
                                        LinearGradient(colors: [.white.opacity(0.3), .clear], startPoint: .top, endPoint: .bottom)
                                    }
                                )
                                .cornerRadius(16)
                                .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                            }
                            .padding(.horizontal, 32)
                            
                            Text("No subscriptions. No hidden fees.")
                                .font(.caption2)
                                .foregroundColor(Theme.Colors.textSecondary)
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
