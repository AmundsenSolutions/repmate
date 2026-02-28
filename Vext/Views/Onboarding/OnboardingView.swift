import SwiftUI

/// First-run onboarding flow — 4 swipeable pages.
/// Controlled by `@AppStorage("hasSeenOnboarding")` in VextApp.
struct OnboardingView: View {
    @EnvironmentObject var store: AppDataStore
    @ObservedObject var themeManager = ThemeManager.shared
    
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false
    @State private var currentPage = 0
    @State private var bodyWeight = ""
    
    var body: some View {
        ZStack {
            // Background Layer
            GeometryReader { proxy in
                TabView(selection: $currentPage) {
                    Image("onboarding_bg_1").resizable().scaledToFill().ignoresSafeArea().tag(0)
                    Image("onboarding_bg_2").resizable().scaledToFill().ignoresSafeArea().tag(1)
                    Image("onboarding_bg_3").resizable().scaledToFill().ignoresSafeArea().tag(2)
                    Image("onboarding_bg_4").resizable().scaledToFill().ignoresSafeArea().tag(3)
                }
                .tabViewStyle(.page(indexDisplayMode: .never)) // Hide native index since we want custom placement
                .frame(width: proxy.size.width, height: proxy.size.height)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.8), value: currentPage)
                
                // Heavy dark overlay to make text premium and legible
                Color.black.opacity(0.7).ignoresSafeArea()
            }
            .ignoresSafeArea()
            
            // Content Layer
            VStack {
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
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut(duration: 0.3), value: currentPage)
                
                // Custom Pagination Dots placed explicitly so they don't overlap the NEXT button
                HStack(spacing: 8) {
                    ForEach(0..<4) { index in
                        Circle()
                            .fill(currentPage == index ? themeManager.palette.accent : Color.white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .animation(.spring(), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
            }
        }
        .background(Color.black.ignoresSafeArea(.all)) // Base color beneath images
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

// MARK: - Minimal Card Modifier

struct MinimalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardBackground) // Exact match to Workouts tab (Color(uiColor: .tertiarySystemFill) / white: 0.1)
            .cornerRadius(16) // Exact match to Workouts tab standard
    }
}

extension View {
    func minimalCard() -> some View {
        modifier(MinimalCardModifier())
    }
}

// MARK: - Shared Next Button

struct OnboardingNextButton: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var action: () -> Void
    var title: String
    var icon: String? = "arrow.right"
    
    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 16, weight: .bold)) // Clean sans-serif
                if let icon = icon {
                    Image(systemName: icon)
                }
            }
            .foregroundColor(themeManager.activeTheme == .arcticWhite ? .black : .white) // High contrast
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(themeManager.palette.accent) // Solid color, no glow
            .clipShape(Capsule()) // Pill-shaped
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }
}

// MARK: - Slide 1: Welcome & Theme

struct OnboardingWelcomeSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 16) {
                Text("👋")
                    .font(.system(size: 64))
                
                Text("Welcome to\nVext")
                    .font(.system(size: 32, weight: .bold)) // Sans-serif, no glow
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Choose your vibe")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                // Theme selector in minimal panel
                HStack(spacing: 20) {
                    ForEach(ThemeManager.availableThemes.filter { $0 != .custom }, id: \.self) { variant in
                        ThemeBubble(variant: variant)
                    }
                }
                .padding(.vertical, 20)
                .padding(.horizontal, 16)
                .background(Color(white: 0.05))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                )
            }
            .padding(24)
            .minimalCard()
            .padding(.horizontal, 24)
            
            Spacer()
            
            OnboardingNextButton(action: onNext, title: "NEXT")
        }
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
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(isActive ? 0.8 : 0), lineWidth: 2)
                    )
                
                Text(variant.displayName.components(separatedBy: " ").first ?? "")
                    .font(.system(size: 12, weight: isActive ? .bold : .medium))
                    .foregroundColor(isActive ? themeManager.palette.accent : .white.opacity(0.6))
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
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                Text("🥩")
                    .font(.system(size: 64))
                
                Text("Set Your Goal")
                    .font(.system(size: 32, weight: .bold)) // Sans-serif, no glow
                    .foregroundColor(.white)
                
                Text("Enter your body weight")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                
                weightInput
                presetButtons
                
                // Show calculated protein space reserved via opacity
                Text("Your target: **\(calculatedProtein ?? 150)g protein/day**")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(themeManager.activeTheme == .arcticWhite ? .black : .white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 14)
                    .background(themeManager.palette.accent)
                    .cornerRadius(12)
                    .opacity(calculatedProtein != nil ? 1 : 0)
                    .animation(.easeInOut, value: calculatedProtein)
                
                Text("Based on 1.6g protein per kg body weight")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundColor(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 20)
            }
            .padding(24)
            .minimalCard()
            .padding(.horizontal, 24)
            
            Spacer()
            
            OnboardingNextButton(action: {
                isWeightFocused = false
                onNext()
            }, title: "NEXT")
        }
        .animation(.easeOut(duration: 0.2), value: calculatedProtein)
        .contentShape(Rectangle())
        .onTapGesture { isWeightFocused = false }
    }
    
    private var weightInput: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            TextField("80", text: $bodyWeight)
                .keyboardType(.decimalPad)
                .focused($isWeightFocused)
                .font(.system(size: 56, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .frame(width: 140)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") { isWeightFocused = false }
                            .fontWeight(.semibold)
                    }
                }
            
            Text("kg")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white.opacity(0.6))
        }
    }
    
    private var presetButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach([50, 60, 70, 80, 90, 100, 110, 120, 130], id: \.self) { preset in
                    Button {
                        bodyWeight = "\(preset)"
                        isWeightFocused = false
                        HapticManager.shared.lightImpact()
                    } label: {
                        Text("\(preset)")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(
                                bodyWeight == "\(preset)"
                                    ? themeManager.palette.accent
                                    : Color(white: 0.15)
                            )
                            .foregroundColor(
                                bodyWeight == "\(preset)"
                                    ? (themeManager.activeTheme == .arcticWhite ? .black : .white)
                                    : .white
                            )
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 24) // Ensures first and last items are centered nicely without truncation
        }
    }
}

// MARK: - Slide 3: Tutorial

struct OnboardingTutorialSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var onNext: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 20)
            
            VStack(spacing: 16) {
                Text("🎓")
                    .font(.system(size: 48))
                
                Text("How It Works")
                    .font(.system(size: 28, weight: .bold)) // Sans-serif
                    .foregroundColor(.white)
                    .padding(.bottom, 8)
                
                ghostDataCard
                swipeCard
                arrowsCard
            }
            .padding(16)
            
            Spacer(minLength: 20)
            
            OnboardingNextButton(action: onNext, title: "NEXT")
        }
        .padding(.top, 40)
    }
    
    private var ghostDataCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.palette.accent)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ghost Data")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Grey numbers show your last session.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            GhostDataDemoRow()
        }
        .padding(16)
        .minimalCard()
        .padding(.horizontal, 24)
    }
    
    private var swipeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "hand.draw")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.palette.accent)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Swipe to Delete")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Swipe left on any row to remove it.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            SwipeDeleteDemoRow()
        }
        .padding(16)
        .minimalCard()
        .padding(.horizontal, 24)
    }
    
    private var arrowsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "arrow.up.arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundColor(themeManager.palette.accent)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Target Rep Range")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.white)
                    Text("Arrows guide weight adjustments.")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            ArrowsDemoRow()
        }
        .padding(16)
        .minimalCard()
        .padding(.horizontal, 24)
    }
}

// MARK: - Tutorial Demo Rows

struct GhostDataDemoRow: View {
    @ObservedObject var themeManager = ThemeManager.shared
    
    var body: some View {
        HStack(spacing: 8) {
            Text("1")
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(.white.opacity(0.5))
                .frame(width: 16)
            
            Text("80")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(themeManager.palette.accent)
                .frame(width: 44)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.4))
                .cornerRadius(6)
            
            ghostCell("75")
            ghostCell("2")
            
            Spacer()
            
            HStack(spacing: 4) {
                Text("←").font(.system(size: 10, weight: .bold))
                Text("Ghost").font(.system(size: 10, weight: .bold))
            }
            .foregroundColor(.white.opacity(0.5))
        }
    }
    
    private func ghostCell(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .bold))
            .foregroundColor(.white.opacity(0.3))
            .frame(width: 44)
            .padding(.vertical, 6)
            .background(Color(white: 0.15))
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
                    .padding(.trailing, 28) // Moved slightly more to the right so it doesn't overlap text
            }
            .frame(height: 44)
            .background(Color.red.opacity(0.8))
            .cornerRadius(8)
            
            // Sliding row — NO user interaction
            HStack(spacing: 8) {
                Text("1")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.white.opacity(0.5))
                
                Text("Bench")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Text("80 kg × 8")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.trailing, 8) // ensuring left clearance from the right edge
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color(white: 0.2))
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
                    .font(.system(size: 16))
                Text("Too Light")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            
            Divider().background(Color.white.opacity(0.2)).frame(height: 20)
            
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundColor(.red)
                    .font(.system(size: 16))
                Text("Too Heavy")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 12)
        .background(Color(white: 0.15))
        .cornerRadius(8)
    }
}

// MARK: - Slide 4: Get Started

struct OnboardingStartSlide: View {
    @ObservedObject var themeManager = ThemeManager.shared
    var onStart: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            VStack(spacing: 24) {
                Text("🚀")
                    .font(.system(size: 72))
                
                Text("Let's Lift")
                    .font(.system(size: 40, weight: .heavy)) // Sans-serif
                    .foregroundColor(.white)
                
                Text("You're all set.")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(32)
            .minimalCard()
            .padding(.horizontal, 24)
            
            Spacer()
            
            OnboardingNextButton(action: onStart, title: "START LIFTING", icon: "play.fill")
        }
    }
}

#Preview {
    OnboardingView()
        .environmentObject(AppDataStore())
        .environmentObject(ThemeManager.shared)
}
