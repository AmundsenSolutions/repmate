import SwiftUI

// MARK: - Unified Onboarding (New Users)

/// Single, unified onboarding flow shown to first-time users.
/// Combines the original body-weight setup with the AI plan generation
/// using the premium AI design aesthetic throughout.
struct OnboardingView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storeManager: StoreManager

    @AppStorage("hasSeenOnboarding")   private var hasSeenOnboarding   = false
    @AppStorage("hasSeenAIOnboarding") private var hasSeenAIOnboarding = false

    // MARK: Navigation
    @State private var currentPage = 0
    private let totalPages = 5  // 0=Welcome, 1=Weight, 2=Experience, 3=Days, 4=Equipment

    // MARK: Body Weight
    @State private var bodyWeight = ""
    @FocusState private var isWeightFocused: Bool

    // MARK: AI Questions
    @State private var selectedExperience: AIOnboardingAnswers.ExperienceLevel?
    @State private var selectedDays: AIOnboardingAnswers.TrainingDays?
    @State private var selectedEquipment: AIOnboardingAnswers.Equipment?

    // MARK: Generation
    @State private var isLoading = false
    @State private var generatedPlan: AIPlanResponse?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isRateLimitFreeError = false
    @State private var showPaywall = false
    private let service = AIPlanService()

    // MARK: Can Advance?
    private var canAdvance: Bool {
        switch currentPage {
        case 0: return true
        case 1: return bodyWeight.isValidWeight
        case 2: return selectedExperience != nil
        case 3: return selectedDays != nil
        case 4: return selectedEquipment != nil
        default: return false
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.black, Color(white: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            // Ambient accent glow
            Circle()
                .fill(themeManager.palette.accent.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -220)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if let plan = generatedPlan {
                // Result screen
                AIPlanResultView(plan: plan, isOnboarding: true, onDismiss: finalDismiss)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else if isLoading {
                OnboardingLoadingView()
                    .transition(.opacity)
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isLoading)
        .animation(.easeInOut(duration: 0.5), value: generatedPlan != nil)
        .alert(isRateLimitFreeError ? "Daily Limit Reached" : "Couldn't Generate Plan", isPresented: $showError) {
            if isRateLimitFreeError {
                Button("Upgrade to Pro") { showPaywall = true }
            } else {
                Button("Try Again") { runGeneration() }
            }
            Button("Skip", role: .cancel) { skipFromAISection() }
        } message: {
            Text(errorMessage ?? "An unknown error occurred. Please try again.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            // Top bar: Skip only visible on AI question slides
            HStack {
                Spacer()
                if currentPage >= 2 {
                    Button("Skip") { skipFromAISection() }
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.4))
                        .padding(.trailing, 24)
                }
            }
            .frame(height: 44)

            // Progress bar (hidden on welcome slide)
            if currentPage > 0 {
                HStack(spacing: 6) {
                    ForEach(1..<totalPages, id: \.self) { idx in
                        Capsule()
                            .fill(idx <= currentPage
                                  ? themeManager.palette.accent
                                  : Color.white.opacity(0.15))
                            .frame(height: 3)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
                .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentPage)
            }

            // Slides
            TabView(selection: $currentPage) {
                welcomeSlide.tag(0)
                bodyWeightSlide.tag(1)

                AIQuestionSlide(
                    icon: "figure.strengthtraining.traditional",
                    title: "Experience Level",
                    subtitle: "How long have you been training consistently?",
                    options: AIOnboardingAnswers.ExperienceLevel.allCases.map {
                        QuestionOption(id: $0.rawValue, title: $0.rawValue, icon: experienceIcon($0))
                    },
                    selectedId: selectedExperience?.rawValue,
                    onSelect: { id in
                        selectedExperience = .init(rawValue: id)
                        HapticManager.shared.selection()
                    }
                ).tag(2)

                AIQuestionSlide(
                    icon: "calendar.badge.clock",
                    title: "Training Days per Week",
                    subtitle: "How many days can you realistically commit to?",
                    options: AIOnboardingAnswers.TrainingDays.allCases.map {
                        QuestionOption(id: $0.rawValue, title: $0.rawValue, icon: daysIcon($0))
                    },
                    selectedId: selectedDays?.rawValue,
                    onSelect: { id in
                        selectedDays = .init(rawValue: id)
                        HapticManager.shared.selection()
                    }
                ).tag(3)

                AIQuestionSlide(
                    icon: "dumbbell.fill",
                    title: "Available Equipment",
                    subtitle: "What do you have access to for training?",
                    options: AIOnboardingAnswers.Equipment.allCases.map {
                        QuestionOption(id: $0.rawValue, title: $0.rawValue, icon: equipmentIcon($0))
                    },
                    selectedId: selectedEquipment?.rawValue,
                    onSelect: { id in
                        selectedEquipment = .init(rawValue: id)
                        HapticManager.shared.selection()
                    }
                ).tag(4)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
            .gesture(DragGesture()) // Button-only navigation

            // Bottom button
            bottomButton
        }
    }

    // MARK: - Welcome Slide

    private var welcomeSlide: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 24) {
                // Icon cluster
                ZStack {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(themeManager.palette.accent.opacity(0.06 - Double(i) * 0.015))
                            .frame(width: CGFloat(100 + i * 44), height: CGFloat(100 + i * 44))
                    }
                    Image("Preview_Blue")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(themeManager.palette.accent, lineWidth: 1.5))
                        .shadow(color: themeManager.palette.accent.opacity(0.3), radius: 10)
                }

                // Text
                VStack(spacing: 8) {
                    Text("RepMate")
                        .font(.system(size: 52, weight: .black))
                        .foregroundColor(.white)

                    Text("AI-Powered Fitness")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(themeManager.palette.accent)
                        .tracking(0.5)
                }

                Text("Answer a few quick questions and get\na science-based workout plan\nbuilt specifically for you.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 16)
            }

            Spacer()
        }
    }

    // MARK: - Body Weight Slide

    private var bodyWeightSlide: some View {
        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 22) {
                // Header
                VStack(spacing: 10) {
                    Image(systemName: "scalemass.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundStyle(themeManager.palette.gradient)

                    Text("What's your body weight?")
                        .font(.system(size: 26, weight: .black))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)

                    Text("We'll calculate your daily protein goal.")
                        .font(.system(size: 15))
                        .foregroundColor(Color.white.opacity(0.55))
                        .multilineTextAlignment(.center)
                }

                // Large number input
                VStack(spacing: 4) {
                    TextField("80", text: $bodyWeight)
                        .keyboardType(.decimalPad)
                        .focused($isWeightFocused)
                        .font(.system(size: 64, weight: .bold))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 160)
                        .toolbar {
                            ToolbarItemGroup(placement: .keyboard) {
                                Spacer()
                                Button("Done") { isWeightFocused = false }
                                    .fontWeight(.semibold)
                            }
                        }

                    Rectangle()
                        .frame(width: 140, height: 1)
                        .foregroundColor(Color.white.opacity(0.25))
                        .padding(.bottom, 4)

                    Text("kg")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(Color.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity)

                // Preset chips
                weightPresets

                // Protein preview
                if let protein = calculatedProtein {
                    VStack(spacing: 6) {
                        HStack(alignment: .firstTextBaseline, spacing: 4) {
                            Text("\(protein)")
                                .font(.system(size: 42, weight: .black, design: .rounded))
                                .foregroundStyle(themeManager.palette.gradient)
                                .contentTransition(.numericText())
                            Text("g")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(themeManager.palette.accent.opacity(0.8))
                        }
                        Text("DAILY PROTEIN GOAL")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color.white.opacity(0.35))
                            .tracking(1.2)
                        Text("Based on 1.6g per kg of body weight")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.35))
                    }
                    .transition(.scale.combined(with: .opacity))
                }

                // Validation error
                if !bodyWeight.isEmpty && !bodyWeight.isValidWeight {
                    Text("Enter a weight between 1 and 300 kg")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.red.opacity(0.85))
                        .transition(.opacity)
                }
            }
            .padding(.horizontal, 24)
            .animation(.easeOut(duration: 0.2), value: calculatedProtein)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { isWeightFocused = false }
    }

    private var weightPresets: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach([55, 60, 65, 70, 75, 80, 85, 90, 95, 100, 110, 120], id: \.self) { preset in
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
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isActive
                                              ? themeManager.palette.accent.opacity(0.2)
                                              : Color.white.opacity(0.06))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(
                                                    isActive
                                                        ? themeManager.palette.accent.opacity(0.7)
                                                        : Color.clear,
                                                    lineWidth: 1.5
                                                )
                                        )
                                )
                                .foregroundColor(isActive ? .white : Color.white.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                        .id(preset)
                    }
                }
                .padding(.horizontal, 24)
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation { proxy.scrollTo(80, anchor: .center) }
                }
            }
        }
    }

    // MARK: - Bottom Button

    @ViewBuilder
    private var bottomButton: some View {
        if currentPage < totalPages - 1 {
            Button {
                if currentPage == 1 { isWeightFocused = false }
                guard canAdvance else { return }
                withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
            } label: {
                HStack(spacing: 8) {
                    Text(currentPage == 0 ? "Get Started" : "Continue")
                        .font(.system(size: 16, weight: .bold))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    Capsule()
                        .fill(canAdvance
                              ? themeManager.palette.gradient
                              : LinearGradient(colors: [Color.white.opacity(0.1)],
                                               startPoint: .leading, endPoint: .trailing))
                )
                .foregroundColor(canAdvance ? .white : Color.white.opacity(0.3))
            }
            .disabled(!canAdvance)
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .animation(.easeInOut(duration: 0.2), value: canAdvance)
        } else {
            // Last slide: Generate button
            VStack(spacing: 12) {
                Button {
                    guard canAdvance else { return }
                    runGeneration()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 16, weight: .bold))
                        Text("Generate My Science-Based Plan")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(canAdvance
                                  ? themeManager.palette.gradient
                                  : LinearGradient(colors: [Color.white.opacity(0.1)],
                                                   startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(canAdvance ? .white : Color.white.opacity(0.3))
                }
                .disabled(!canAdvance)
                .animation(.easeInOut(duration: 0.2), value: canAdvance)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
        }
    }

    // MARK: - Logic

    private var calculatedProtein: Int? {
        let s = bodyWeight.replacingOccurrences(of: ",", with: ".")
        guard let w = Double(s), w > 0 else { return nil }
        return Int((w * 1.6).rounded())
    }

    private func saveProteinFromWeight() {
        let s = bodyWeight.replacingOccurrences(of: ",", with: ".")
        if let w = Double(s), w > 0 && w <= 300 {
            store.updateDailyProteinTarget(Int((w * 1.6).rounded()))
        }
    }

    private func runGeneration() {
        guard let exp = selectedExperience,
              let days = selectedDays,
              let equip = selectedEquipment else { return }

        let answers = AIOnboardingAnswers(
            experienceLevel: exp, trainingDays: days, equipment: equip
        ).formattedString

        withAnimation { isLoading = true }

        Task {
            do {
                let plan = try await service.generateAIPlan(answers: answers, isPro: storeManager.isPro)
                await MainActor.run {
                    withAnimation { isLoading = false }
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        generatedPlan = plan
                    }
                    HapticManager.shared.success()
                }
            } catch AIPlanService.AIPlanError.rateLimitReached(let isPro) {
                await MainActor.run {
                    withAnimation { isLoading = false }
                    errorMessage = AIPlanService.AIPlanError.rateLimitReached(isPro: isPro).localizedDescription
                    isRateLimitFreeError = !isPro
                    showError = true
                    HapticManager.shared.error()
                }
            } catch {
                await MainActor.run {
                    withAnimation { isLoading = false }
                    errorMessage = error.localizedDescription
                    isRateLimitFreeError = false
                    showError = true
                    HapticManager.shared.error()
                }
            }
        }
    }

    /// Called when AI plan saved or result screen dismissed. Marks both flags done.
    private func finalDismiss() {
        saveProteinFromWeight()
        hasSeenOnboarding   = true
        hasSeenAIOnboarding = true
        store.seedDefaultWorkoutsIfNeeded()
        HapticManager.shared.success()
    }

    /// Called when user taps Skip on an AI question slide. Still saves weight.
    private func skipFromAISection() {
        saveProteinFromWeight()
        hasSeenOnboarding   = true
        hasSeenAIOnboarding = true
        store.seedDefaultWorkoutsIfNeeded()
    }

    // MARK: - Icon Helpers

    private func experienceIcon(_ v: AIOnboardingAnswers.ExperienceLevel) -> String {
        switch v {
        case .beginner:     return "1.circle.fill"
        case .intermediate: return "2.circle.fill"
        case .advanced:     return "3.circle.fill"
        }
    }

    private func daysIcon(_ v: AIOnboardingAnswers.TrainingDays) -> String {
        switch v {
        case .light:    return "calendar"
        case .moderate: return "calendar.badge.plus"
        case .high:     return "calendar.badge.exclamationmark"
        }
    }

    private func equipmentIcon(_ v: AIOnboardingAnswers.Equipment) -> String {
        switch v {
        case .fullGym:    return "building.2.fill"
        case .homeGym:    return "house.fill"
        case .bodyweight: return "figure.arms.open"
        }
    }
}

// MARK: - Weight Validation

extension String {
    var isValidWeight: Bool {
        let sanitized = replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(sanitized) else { return false }
        return weight > 0 && weight <= 300
    }
}

// MARK: - Minimal Card (kept for backward compat)

struct MinimalCardModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(Theme.Colors.cardBackground)
            .cornerRadius(16)
    }
}

extension View {
    func minimalCard() -> some View {
        modifier(MinimalCardModifier())
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
        .environmentObject(AppDataStore())
        .environmentObject(ThemeManager.shared)
}
