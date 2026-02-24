import SwiftUI

/// First-run onboarding flow — 4 swipeable pages.
/// Controlled by `@AppStorage("hasSeenOnboarding")` in VextApp.
struct OnboardingView: View {
    @EnvironmentObject var store: AppDataStore
    @ObservedObject var themeManager = ThemeManager.shared
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var bodyWeight = ""
    
    private let backgrounds = ["onboarding_bg_1", "onboarding_bg_2", "onboarding_bg_3", "onboarding_bg_4"]
    
    var body: some View {
        TabView(selection: $currentPage) {
            OnboardingWelcomeSlide(onNext: advancePage)
                .tag(0)
            
            OnboardingNutritionSlide(
                bodyWeight: $bodyWeight,
                onNext: { saveProteinFromWeight(); advancePage() }
            )
            .tag(1)
            
            OnboardingTutorialSlide(onNext: advancePage)
                .tag(2)
            
            OnboardingStartSlide(onStart: completeOnboarding)
                .tag(3)
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
        .indexViewStyle(.page(backgroundDisplayMode: .always))
        .animation(.easeInOut(duration: 0.3), value: currentPage)
        .background(
            ZStack {
                GeometryReader { geo in
                    ForEach(0..<4, id: \.self) { index in
                        Image(backgrounds[index])
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geo.size.width, height: geo.size.height)
                            .clipped()
                            .opacity(currentPage == index ? 1 : 0)
                            .animation(.easeInOut(duration: 0.6), value: currentPage)
                    }
                }
                .ignoresSafeArea(.all)
                
                Color.black.opacity(0.5)
            }
            .ignoresSafeArea(.all)
        )
    }
    
    private func advancePage() {
        withAnimation { currentPage += 1 }
    }
    
    private func saveProteinFromWeight() {
        let sanitized = bodyWeight.replacingOccurrences(of: ",", with: ".")
        if let weight = Double(sanitized), weight > 0 {
            let target = Int((weight * 1.6).rounded())
            store.updateDailyProteinTarget(target)
        }
    }
    
    private func completeOnboarding() {
        saveProteinFromWeight()
        withAnimation(.easeInOut(duration: 0.4)) {
            hasSeenOnboarding = true
        }
        HapticManager.shared.success()
    }
}

// MARK: - Glass Container Modifier

struct OnboardingGlassCard: ViewModifier {
    func body(content: Content) -> some View {
        content
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.05), lineWidth: 1)
                    )
            )
    }
}

extension View {
    func onboardingGlass() -> some View {
        modifier(OnboardingGlassCard())
    }
}

// MARK: - Slide 1: Welcome & Theme

struct OnboardingWelcomeSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("👋")
                .font(.system(size: 72))
            
            Text("Welcome to\n**Vext**")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundColor(.white)
            
            Text("Choose your vibe")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            
            // Theme selector in glass container
            HStack(spacing: 20) {
                ForEach(ThemeManager.availableThemes.filter { $0 != .custom }, id: \.self) { variant in
                    ThemeBubble(variant: variant)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .onboardingGlass()
            
            Spacer()
            
            OnboardingNextButton(action: onNext)
        }
        .padding(32)
    }
}

struct ThemeBubble: View {
    @ObservedObject var themeManager = ThemeManager.shared
    let variant: ThemeVariant
    
    private var isActive: Bool { themeManager.activeTheme == variant }
    
    var body: some View {
        Button {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                themeManager.activeTheme = variant
            }
            HapticManager.shared.selection()
        } label: {
            VStack(spacing: 8) {
                Circle()
                    .fill(variant.palette.accent)
                    .frame(width: isActive ? 56 : 44, height: isActive ? 56 : 44)
                    .shadow(color: variant.palette.accent.opacity(isActive ? 0.7 : 0.3), radius: isActive ? 12 : 4)
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isActive ? 0.6 : 0), lineWidth: 2)
                    )
                    .scaleEffect(isActive ? 1.0 : 0.85)
                
                Text(variant.displayName.components(separatedBy: " ").first ?? "")
                    .font(.caption2)
                    .fontWeight(isActive ? .bold : .regular)
                    .foregroundColor(isActive ? .white : .white.opacity(0.6))
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Slide 2: Nutrition (Body Weight → Protein)

struct OnboardingNutritionSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @Binding var bodyWeight: String
    var onNext: () -> Void
    @FocusState private var isWeightFocused: Bool
    
    private var calculatedProtein: Int? {
        let sanitized = bodyWeight.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(sanitized), weight > 0 else { return nil }
        return Int((weight * 1.6).rounded())
    }
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            Text("🥩")
                .font(.system(size: 72))
            
            Text("Set Your Goal")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            Text("Enter your body weight")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))
            
            weightInput
            presetButtons
            
            // Show calculated protein space reserved via opacity
            Text("Your target: **\(calculatedProtein ?? 150)g protein/day**")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(themeManager.palette.accent)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    Capsule()
                        .fill(.ultraThinMaterial.opacity(0.6))
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.05), lineWidth: 1)
                        )
                )
                .opacity(calculatedProtein != nil ? 1 : 0)
                .animation(.easeInOut, value: calculatedProtein)
            
            Text("Based on 1.6g protein per kg body weight")
                .font(.caption)
                .foregroundColor(.white.opacity(0.5))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            
            Spacer()
            
            OnboardingNextButton(action: {
                isWeightFocused = false
                onNext()
            })
        }
        .padding(32)
        .animation(.easeOut(duration: 0.2), value: calculatedProtein)
        .contentShape(Rectangle())
        .onTapGesture { isWeightFocused = false }
    }
    
    private var weightInput: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            TextField("80", text: $bodyWeight)
                .keyboardType(.decimalPad)
                .focused($isWeightFocused)
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundColor(themeManager.palette.accent)
                .multilineTextAlignment(.center)
                .frame(width: 160)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isWeightFocused = false }
                            .fontWeight(.semibold)
                    }
                }
            
            Text("kg")
                .font(.system(size: 28, weight: .medium, design: .rounded))
                .foregroundColor(themeManager.palette.accent.opacity(0.6))
        }
    }
    
    private var presetButtons: some View {
        HStack(spacing: 12) {
            ForEach([60, 70, 80, 90, 100], id: \.self) { preset in
                Button {
                    bodyWeight = "\(preset)"
                    isWeightFocused = false
                    HapticManager.shared.lightImpact()
                } label: {
                    Text("\(preset)")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(
                            bodyWeight == "\(preset)"
                                ? AnyShapeStyle(themeManager.palette.accent)
                                : AnyShapeStyle(.ultraThinMaterial)
                        )
                        .foregroundColor(
                            bodyWeight == "\(preset)" ? .black : .white
                        )
                        .cornerRadius(20)
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(Color.white.opacity(bodyWeight == "\(preset)" ? 0 : 0.05), lineWidth: 1)
                        )
                }
            }
        }
    }
}

// MARK: - Slide 3: Tutorial

struct OnboardingTutorialSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Text("🎓")
                .font(.system(size: 64))
            
            Text("How It Works")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            
            ghostDataCard
            swipeCard
            arrowsCard
            
            Spacer()
            
            OnboardingNextButton(action: onNext)
        }
        .padding(32)
    }
    
    private var ghostDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.palette.accent)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ghost Data")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Grey numbers show your last session. Beat them for progressive overload!")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            GhostDataDemoRow()
        }
        .onboardingGlass()
    }
    
    private var swipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.palette.accent)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Swipe to Delete")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Swipe left on any row to remove it.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            SwipeDeleteDemoRow()
        }
        .onboardingGlass()
    }
    
    private var arrowsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 24))
                    .foregroundColor(themeManager.palette.accent)
                    .frame(width: 40)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("Target Rep Range")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                    Text("Arrows guide you to increase (green) or decrease (red) weight based on your rep targets.")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            ArrowsDemoRow()
        }
        .onboardingGlass()
    }
}

// MARK: - Tutorial Demo Rows

struct GhostDataDemoRow: View {
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Text("1")
                .font(.caption).bold()
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 20)
            
            Text("80")
                .font(.system(size: 15, weight: .semibold, design: .monospaced))
                .foregroundColor(themeManager.palette.accent)
                .frame(width: 50)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.1))
                .cornerRadius(6)
            
            ghostCell("75")
            ghostCell("2")
            
            Spacer()
            
            HStack(spacing: 2) {
                Text("←").font(.caption2)
                Text("Ghost").font(.caption2)
            }
            .foregroundColor(.white.opacity(0.4))
        }
    }
    
    private func ghostCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold, design: .monospaced))
            .foregroundColor(.white.opacity(0.25))
            .frame(width: 50)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.1))
            .cornerRadius(6)
    }
}

struct SwipeDeleteDemoRow: View {
    @State private var swipeOffset: CGFloat = 0
    @State private var isVisible = false
    
    var body: some View {
        ZStack(alignment: .trailing) {
            // Red delete background
            HStack {
                Spacer()
                Image(systemName: "trash.fill")
                    .foregroundColor(.white)
                    .padding(.trailing, 16)
            }
            .frame(height: 40)
            .background(Color.red.opacity(0.8))
            .cornerRadius(8)
            
            // Sliding row — NO user interaction
            HStack(spacing: 8) {
                Text("1")
                    .font(.caption).bold()
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Bench Press")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("80 kg × 8")
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(Color(white: 0.15))
            .cornerRadius(8)
            .offset(x: swipeOffset)
        }
        .allowsHitTesting(false)
        .onAppear {
            isVisible = true
            startAnimation()
        }
        .onDisappear {
            isVisible = false
            swipeOffset = 0
        }
    }
    
    private func startAnimation() {
        guard isVisible else { return }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            guard isVisible else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                swipeOffset = -80
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.2) {
            guard isVisible else { return }
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                swipeOffset = 0
            }
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            guard isVisible else { return }
            startAnimation()
        }
    }
}

struct ArrowsDemoRow: View {
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack {
            HStack(spacing: 8) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.green)
                Text("Too Light")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            Divider().background(Color.white.opacity(0.3)).frame(height: 20)
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.red)
                Text("Too Heavy")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Slide 4: Get Started

struct OnboardingStartSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("🚀")
                .font(.system(size: 80))
            
            Text("Let's Lift")
                .font(.system(size: 40, weight: .heavy, design: .rounded))
                .foregroundColor(.white)
            
            Text("You're all set.")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Button {
                onStart()
            } label: {
                Text("Start Lifting")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(
                        Capsule()
                            .fill(themeManager.palette.accent)
                            .shadow(color: themeManager.palette.accent.opacity(0.5), radius: 16, x: 0, y: 6)
                    )
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .padding(32)
    }
}

// MARK: - Shared Next Button

struct OnboardingNextButton: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var action: () -> Void
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                Text("Next")
                    .fontWeight(.semibold)
                Image(systemName: "arrow.right")
            }
            .foregroundColor(.black)
            .padding(.horizontal, 32)
            .padding(.vertical, 14)
            .background(
                Capsule()
                    .fill(themeManager.palette.accent)
            )
        }
        .padding(.bottom, 24)
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppDataStore())
        .environmentObject(ThemeManager.shared)
}
