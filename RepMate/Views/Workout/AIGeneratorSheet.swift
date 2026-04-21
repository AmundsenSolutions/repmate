import SwiftUI

// MARK: - AI Generator Sheet

/// A focused sheet where users describe what they want to train,
/// then generate a full AI plan using the existing AIPlanService + AIPlanResultView.
struct AIGeneratorSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeManager: StoreManager
    @Environment(\.dismiss) private var dismiss

    // MARK: State
    @State private var prompt = ""
    @State private var isLoading = false
    @State private var generatedPlan: AIPlanResponse?
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var isRateLimitFreeError = false
    @State private var showPaywall = false
    @FocusState private var isTextFocused: Bool

    private let service = AIPlanService()
    private var canGenerate: Bool { prompt.trimmingCharacters(in: .whitespacesAndNewlines).count >= 5 }

    // MARK: Body

    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()

            // Accent glow
            Circle()
                .fill(themeManager.palette.accent.opacity(0.10))
                .frame(width: 360, height: 360)
                .blur(radius: 70)
                .offset(y: -200)
                .allowsHitTesting(false)

            if let plan = generatedPlan {
                // Reuse AIPlanResultView — same as onboarding
                AIPlanResultView(plan: plan) {
                    dismiss()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))
            } else if isLoading {
                OnboardingLoadingView()
                    .transition(.opacity)
            } else {
                promptContent
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: isLoading)
        .animation(.easeInOut(duration: 0.45), value: generatedPlan != nil)
        .alert(isRateLimitFreeError ? "Daily Limit Reached" : "Generation Failed", isPresented: $showError) {
            if isRateLimitFreeError {
                Button("Upgrade to Pro") { showPaywall = true }
            } else {
                Button("Try Again") { generate() }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "Something went wrong. Please try again.")
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
    }

    // MARK: - Prompt Screen

    private var promptContent: some View {
        VStack(spacing: 0) {
            // Drag handle
            RoundedRectangle(cornerRadius: 3)
                .fill(Color.white.opacity(0.2))
                .frame(width: 40, height: 5)
                .padding(.top, 12)

            // Header
            VStack(spacing: 8) {
                HStack {
                    Image(systemName: "sparkles")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(themeManager.palette.gradient)
                    Text("Create Workout with AI")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(Color.white.opacity(0.3))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Divider().background(Color.white.opacity(0.08))
            }

            ScrollView {
                VStack(spacing: 24) {

                    // Instruction
                    VStack(alignment: .leading, spacing: 10) {
                        Text("What do you want to train?")
                            .font(.system(size: 22, weight: .black))
                            .foregroundColor(.white)

                        Text("Describe your session — the AI will build a complete, science-based plan.")
                            .font(.system(size: 14))
                            .foregroundColor(Color.white.opacity(0.5))
                            .lineSpacing(3)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.top, 20)

                    aiProfileChips
                        .padding(.horizontal, 20)

                    // Text Editor
                    ZStack(alignment: .topLeading) {
                        // Placeholder
                        if prompt.isEmpty {
                            Text("e.g. 45-min heavy leg day focusing on quads, or a quick upper body push session with dumbbells only…")
                                .font(.system(size: 15))
                                .foregroundColor(Color.white.opacity(0.25))
                                .padding(.horizontal, 16)
                                .padding(.vertical, 14)
                                .allowsHitTesting(false)
                        }

                        TextEditor(text: $prompt)
                            .focused($isTextFocused)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .scrollContentBackground(.hidden)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(minHeight: 140)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        isTextFocused
                                            ? themeManager.palette.accent.opacity(0.5)
                                            : Color.white.opacity(0.08),
                                        lineWidth: 1.5
                                    )
                            )
                    )
                    .padding(.horizontal, 20)
                    .animation(.easeInOut(duration: 0.2), value: isTextFocused)

                    // Example prompts
                    VStack(alignment: .leading, spacing: 10) {
                        Text("QUICK IDEAS")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(Color.white.opacity(0.3))
                            .tracking(1.2)

                        LazyVGrid(columns: [GridItem(.flexible())], spacing: 10) {
                            ForEach(quickIdeas, id: \.self) { idea in
                                Button {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                        prompt = idea
                                    }
                                    isTextFocused = false
                                    HapticManager.shared.selection()
                                } label: {
                                    Text(idea)
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundColor(Color.white.opacity(0.75))
                                        .multilineTextAlignment(.leading)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 10)
                                        .background(
                                            RoundedRectangle(cornerRadius: 12)
                                                .fill(Color.white.opacity(0.04))
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 12)
                                                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                                                )
                                        )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    Color.clear.frame(height: 100) // Scroll padding
                }
            }
            .onTapGesture { isTextFocused = false }

            // Generate button pinned at bottom
            VStack(spacing: 0) {
                Divider().background(Color.white.opacity(0.06))

                Button {
                    isTextFocused = false
                    generate()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 15, weight: .bold))
                        Text("Generate Plan")
                            .font(.system(size: 16, weight: .bold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        Capsule()
                            .fill(canGenerate
                                  ? themeManager.palette.gradient
                                  : LinearGradient(colors: [Color.white.opacity(0.08)],
                                                   startPoint: .leading, endPoint: .trailing))
                    )
                    .foregroundColor(canGenerate ? .white : Color.white.opacity(0.25))
                }
                .disabled(!canGenerate)
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .animation(.easeInOut(duration: 0.2), value: canGenerate)
            }
            .background(Color.black)
        }
    }

    // MARK: - Logic

    private var aiProfileChips: some View {
        HStack(spacing: 10) {
            profileChip(
                icon: "person.fill",
                title: store.settings.experienceLevel.rawValue
            ) {
                Picker("Experience Level", selection: Binding(
                    get: { store.settings.experienceLevel },
                    set: { newValue in
                        store.settings.experienceLevel = newValue
                        store.saveSettings()
                        HapticManager.shared.selection()
                    }
                )) {
                    ForEach(ExperienceLevel.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
            }

            profileChip(
                icon: "dumbbell.fill",
                title: store.settings.equipmentAccess.rawValue
            ) {
                Picker("Equipment Access", selection: Binding(
                    get: { store.settings.equipmentAccess },
                    set: { newValue in
                        store.settings.equipmentAccess = newValue
                        store.saveSettings()
                        HapticManager.shared.selection()
                    }
                )) {
                    ForEach(EquipmentAccess.allCases, id: \.self) { equipment in
                        Text(equipment.rawValue).tag(equipment)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func profileChip<Content: View>(
        icon: String,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        Menu {
            content()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(themeManager.palette.accent)

                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(Color.white.opacity(0.86))
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Color.white.opacity(0.45))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func generate() {
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 5 else { return }

        withAnimation { isLoading = true }
        HapticManager.shared.lightImpact()

        Task {
            do {
                let formattedAnswers = "User Profile: \(store.settings.experienceLevel.rawValue). Equipment Access: \(store.settings.equipmentAccess.rawValue). Custom Request: \(trimmed)"
                let plan = try await service.generateAIPlan(answers: formattedAnswers, isPro: storeManager.isPro)
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

    // MARK: - Quick Ideas

    private let quickIdeas = [
        "Full body - training only twice a week",
        "Upper body with extra focus on biceps",
        "Leg day (only have dumbbells available)",
        "Whole body workout in 45 minutes"
    ]
}
