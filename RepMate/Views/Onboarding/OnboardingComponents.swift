import SwiftUI

// MARK: - Question Option Model

struct QuestionOption: Identifiable {
    let id: String
    let title: String
    let icon: String
}

// MARK: - Question Slide

/// Reusable full-page question slide used in both new-user onboarding
/// and the existing-user AI prompt flow.
struct AIQuestionSlide: View {
    @EnvironmentObject var themeManager: ThemeManager

    let icon: String
    let title: String
    let subtitle: String
    let options: [QuestionOption]
    let selectedId: String?
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(themeManager.palette.gradient)
                    .padding(.top, 20)

                Text(title)
                    .font(.system(size: 26, weight: .black))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)

                Text(subtitle)
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.55))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
                    .padding(.horizontal, 16)
            }
            .padding(.horizontal, 24)

            Spacer(minLength: 20)

            VStack(spacing: 14) {
                ForEach(options) { option in
                    AIOptionCard(
                        option: option,
                        isSelected: selectedId == option.id,
                        onTap: { onSelect(option.id) }
                    )
                }
            }
            .padding(.horizontal, 24)

            Spacer()
        }
    }
}

// MARK: - Option Card

struct AIOptionCard: View {
    @EnvironmentObject var themeManager: ThemeManager

    let option: QuestionOption
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(isSelected
                              ? themeManager.palette.accent.opacity(0.2)
                              : Color.white.opacity(0.06))
                        .frame(width: 48, height: 48)

                    Image(systemName: option.icon)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(isSelected
                                         ? themeManager.palette.gradient
                                         : Color.white.opacity(0.5).asGradient)
                }

                Text(option.title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(isSelected ? .white : Color.white.opacity(0.7))
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()

                ZStack {
                    Circle()
                        .fill(isSelected ? themeManager.palette.accent : Color.white.opacity(0.08))
                        .frame(width: 24, height: 24)
                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .black))
                            .foregroundColor(.black)
                    }
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(isSelected
                          ? themeManager.palette.accent.opacity(0.08)
                          : Color.white.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18)
                            .stroke(
                                isSelected
                                    ? themeManager.palette.accent.opacity(0.6)
                                    : Color.white.opacity(0.08),
                                lineWidth: isSelected ? 1.5 : 1
                            )
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 18))
            .scaleEffect(isSelected ? 1.01 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isSelected)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Loading Step Row

struct LoadingStepRow: View {
    @EnvironmentObject var themeManager: ThemeManager

    let text: String
    let delay: Double

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(themeManager.palette.gradient)

            Text(text)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Color.white.opacity(0.75))
        }
        .opacity(isVisible ? 1 : 0)
        .offset(x: isVisible ? 0 : -12)
        .onAppear {
            withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                isVisible = true
            }
        }
    }
}

// MARK: - Shared Loading View

/// Animated "thinking" screen shown while Lambda is generating the plan.
struct OnboardingLoadingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @State private var loadingPhase = 0

    var body: some View {
        VStack(spacing: 36) {
            Spacer()

            ZStack {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(themeManager.palette.accent.opacity(0.08 - Double(i) * 0.02))
                        .frame(width: CGFloat(90 + i * 36), height: CGFloat(90 + i * 36))
                        .scaleEffect(loadingPhase == i + 1 ? 1.08 : 1.0)
                        .animation(
                            .easeInOut(duration: 1.2)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.3),
                            value: loadingPhase
                        )
                }
                Image(systemName: "sparkles")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(themeManager.palette.gradient)
                    .symbolEffect(.pulse)
            }

            VStack(spacing: 10) {
                Text("Analysing Your Profile")
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(.white)

                Text("Our AI is building a personalised,\nscience-based training plan just for you.")
                    .font(.system(size: 15))
                    .foregroundColor(Color.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            VStack(alignment: .leading, spacing: 14) {
                LoadingStepRow(text: "Reading your experience level", delay: 0.0)
                LoadingStepRow(text: "Calibrating volume & intensity",  delay: 0.6)
                LoadingStepRow(text: "Selecting optimal exercises",      delay: 1.2)
                LoadingStepRow(text: "Applying progressive overload",    delay: 1.8)
            }
            .padding(.horizontal, 40)

            Spacer()
        }
        .onAppear { loadingPhase = 1 }
    }
}

// MARK: - Color Gradient Convenience

extension Color {
    /// Wraps a single Color as a LinearGradient for use in `.foregroundStyle`.
    var asGradient: LinearGradient {
        LinearGradient(colors: [self], startPoint: .leading, endPoint: .trailing)
    }
}
