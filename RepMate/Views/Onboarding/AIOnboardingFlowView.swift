import SwiftUI

// MARK: - Existing User AI Onboarding

/// Lean 3-slide AI onboarding shown to users who already completed
/// the original onboarding but haven't yet generated an AI plan.
/// Triggered automatically once via fullScreenCover in AppTabView.
struct ExistingUserAIOnboardingView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storeManager: StoreManager

    @AppStorage("hasSeenAIOnboarding") private var hasSeenAIOnboarding = false
    var onDismiss: () -> Void

    // MARK: State
    @State private var currentPage = 0
    private let totalPages = 3  // 0=Experience, 1=Days, 2=Equipment

    @State private var selectedExperience: AIOnboardingAnswers.ExperienceLevel?
    @State private var selectedDays: AIOnboardingAnswers.TrainingDays?
    @State private var selectedEquipment: AIOnboardingAnswers.Equipment?

    @State private var isLoading = false
    @State private var generatedPlan: AIPlanResponse?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isRateLimitFreeError = false
    @State private var showPaywall = false
    private let service = AIPlanService()

    private var canAdvance: Bool {
        switch currentPage {
        case 0: return selectedExperience != nil
        case 1: return selectedDays != nil
        case 2: return selectedEquipment != nil
        default: return false
        }
    }

    // MARK: Body

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(white: 0.06)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            Circle()
                .fill(themeManager.palette.accent.opacity(0.12))
                .frame(width: 400, height: 400)
                .blur(radius: 80)
                .offset(y: -220)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if let plan = generatedPlan {
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
            Button("Skip", role: .cancel) { finalDismiss() }
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
            // Top bar
            HStack {
                // Back button (not on first page)
                if currentPage > 0 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.3)) { currentPage -= 1 }
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(Color.white.opacity(0.5))
                            .padding(.leading, 24)
                    }
                } else {
                    Color.clear.frame(width: 44)
                }

                Spacer()

                Button("Skip") { finalDismiss() }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.4))
                    .padding(.trailing, 24)
            }
            .frame(height: 44)

            // Progress bar
            HStack(spacing: 6) {
                ForEach(0..<totalPages, id: \.self) { idx in
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

            // Header (shown above slides)
            VStack(spacing: 4) {
                Text("Build Your Plan")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(themeManager.palette.accent)
                    .tracking(1.2)
                    .textCase(.uppercase)
                Text("Answer 3 quick questions")
                    .font(.system(size: 14))
                    .foregroundColor(Color.white.opacity(0.4))
            }
            .padding(.top, 8)

            // Slides
            TabView(selection: $currentPage) {
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
                ).tag(0)

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
                ).tag(1)

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
                ).tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.35), value: currentPage)
            .gesture(DragGesture())

            // Bottom button
            bottomButton
        }
    }

    // MARK: - Bottom Button

    @ViewBuilder
    private var bottomButton: some View {
        if currentPage < totalPages - 1 {
            Button {
                guard canAdvance else { return }
                withAnimation(.easeInOut(duration: 0.3)) { currentPage += 1 }
            } label: {
                HStack(spacing: 8) {
                    Text("Continue")
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
            .padding(.horizontal, 24)
            .padding(.bottom, 36)
            .animation(.easeInOut(duration: 0.2), value: canAdvance)
        }
    }

    // MARK: - Logic

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

    private func finalDismiss() {
        hasSeenAIOnboarding = true
        store.seedDefaultWorkoutsIfNeeded()
        onDismiss()
    }

    // MARK: - Icons

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
