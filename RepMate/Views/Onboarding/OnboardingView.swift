import SwiftUI

/// First-run onboarding flow with 4 swipeable pages.
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
                Color.black.opacity(0.65).ignoresSafeArea()
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
        }
        .glowingPanelButton()
        .padding(.horizontal, 24)
        .padding(.bottom, 24) // Leaves room for custom pagination dots
    }
}
    
    // MARK: - Slide 1: Welcome & Theme
    
    struct OnboardingWelcomeSlide: View {
        @ObservedObject var themeManager = ThemeManager.shared
        var onNext: () -> Void
        
        var body: some View {
            VStack(spacing: 0) {
                Spacer()
                
                VStack(spacing: 8) {
                    Text("Welcome to\nRepMate")
                        .font(.system(size: 42, weight: .bold)) // Larger, matching image
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 4)
                    
                    Text("Reps, sets, lifts & progress")
                        .font(.system(size: 16, weight: .regular)) // Cleaner sans-serif
                        .foregroundColor(.white)
                    
                    // Theme selector
                    HStack(spacing: 24) {
                        ForEach(ThemeManager.availableThemes.filter { $0 != .custom }, id: \.self) { variant in
                            ThemeBubble(variant: variant)
                        }
                    }
                    .padding(.top, 32)
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
                .padding(.horizontal, 24)
                
                Spacer()
                
                OnboardingNextButton(action: onNext, title: "NEXT", icon: nil) // No icon in Welcome screen to match design
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
                ZStack {
                    // Inactive state: Dark metallic circle
                    Circle()
                        .fill(Color(white: 0.15))
                        .frame(width: 56, height: 56)
                        .overlay(
                            Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                        )
                    
                    // Inner color fill (gradient for tactile feel)
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: [variant.palette.accent.opacity(isActive ? 1.0 : 0.8), variant.palette.accent.opacity(isActive ? 0.7 : 0.5)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 48, height: 48)
                    
                    // Active ring layer
                    if isActive {
                        Circle()
                            .stroke(variant.palette.accent.opacity(0.8), lineWidth: 3) // Glowing active ring
                            .frame(width: 64, height: 64)
                            .blur(radius: 2) // Slight glow on the active ring itself
                        
                        Circle()
                            .stroke(variant.palette.accent, lineWidth: 2) // Crisp inner ring
                            .frame(width: 64, height: 64)
                    }
                }
                .scaleEffect(isActive ? 1.05 : 1.0)
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
                    
                    Text("Estimate your body weight")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white)
                    
                    weightInput
                    presetButtons
                    
                    // Show calculated protein space reserved via opacity
                    Text("Your target: **\(calculatedProtein ?? 150)g protein/day**")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 14)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 16).fill(.ultraThinMaterial)
                                Theme.active.verticalGradient.opacity(0.4)
                            }
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .strokeBorder(Theme.active.accent.opacity(0.8), lineWidth: 1.5)
                        )
                        .shadow(color: Theme.active.accent.opacity(0.3), radius: 8, x: 0, y: 0)
                        .opacity(calculatedProtein != nil ? 1 : 0)
                        .animation(.easeInOut, value: calculatedProtein)
                    
                    Text("Based on 1.6g protein per kg body weight")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 32)
                .padding(.horizontal, 24)
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
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        // Start lower to allow 80 to be in the middle, and go up higher
                        ForEach([40, 50, 60, 70, 80, 90, 100, 110, 120, 130, 140, 150], id: \.self) { preset in
                            let isActive = bodyWeight == "\(preset)"
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                    bodyWeight = "\(preset)"
                                    proxy.scrollTo(preset, anchor: .center)
                                }
                                isWeightFocused = false
                                HapticManager.shared.lightImpact()
                            } label: {
                                Text("\(preset)")
                                    .font(.system(size: 14, weight: .bold))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(
                                        ZStack {
                                            if isActive {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(.ultraThinMaterial)
                                                Theme.active.verticalGradient.opacity(0.4)
                                                    .cornerRadius(12)
                                            } else {
                                                RoundedRectangle(cornerRadius: 12)
                                                    .fill(Color(white: 0.15))
                                            }
                                        }
                                        .clipShape(RoundedRectangle(cornerRadius: 12))
                                    )
                                    .foregroundColor(.white)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(isActive ? Theme.active.accent.opacity(0.8) : Color.clear, lineWidth: 1.5)
                                    )
                            }
                            .id(preset) // Enable scroll to
                        }
                    }
                    .padding(.horizontal, 24) // Ensures first and last items are centered nicely without truncation
                }
                .onAppear {
                    // Determine starting preset
                    let startValue = Int(bodyWeight) ?? 80
                    // Default body weight value to 80 if it's currently empty
                    if bodyWeight.isEmpty {
                        bodyWeight = "80"
                    }
                    // Scroll to active item on appear
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation {
                            proxy.scrollTo(startValue, anchor: .center)
                        }
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
                .padding(24)
                .padding(.horizontal, 24)
                
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
                            .foregroundColor(.white)
                    }
                }
                
                GhostDataDemoRow()
            }
            .padding(16)
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
                            .foregroundColor(.white)
                    }
                }
                
                SwipeDeleteDemoRow()
            }
            .padding(16)
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
                            .foregroundColor(.white)
                    }
                }
                
                ArrowsDemoRow()
            }
            .padding(16)
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
                .padding(.vertical, 40)
                .padding(.horizontal, 24)
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

