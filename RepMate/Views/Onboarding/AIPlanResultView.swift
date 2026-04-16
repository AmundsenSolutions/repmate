import SwiftUI

// MARK: - AI Plan Result View

/// Displays the AI-generated plan summary and lets the user save it as templates.
struct AIPlanResultView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var storeManager: StoreManager

    let plan: AIPlanResponse
    var isOnboarding: Bool = false
    var onDismiss: () -> Void

    @State private var isSaving = false
    @State private var didSave = false
    @State private var savedCount = 0
    @State private var showSaveError = false

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 28) {

                    // MARK: Header
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(themeManager.palette.accent.opacity(0.15))
                                .frame(width: 88, height: 88)
                                .blur(radius: 16)

                            Image(systemName: "brain.head.profile")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundStyle(themeManager.palette.accent)
                        }

                        Text("Your Personalised Plan")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(themeManager.palette.accent)
                            .tracking(1.5)
                            .textCase(.uppercase)

                        Text(plan.plan_name)
                            .font(.system(size: 28, weight: .black))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                    }
                    .padding(.top, 24)
                    .padding(.horizontal, 24)

                    // MARK: Rationale
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Why This Plan?", systemImage: "lightbulb.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundColor(themeManager.palette.accent)
                            .tracking(1)
                            .textCase(.uppercase)

                        Text(plan.rationale)
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.85))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                            
                        Divider()
                            .background(Color.white.opacity(0.1))
                            .padding(.vertical, 2)
                        
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.4))
                            Text("RIR (Reps in Reserve) marks your intensity. E.g., RIR 2 means stopping when you only have 2 reps left in the tank.")
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.4))
                                .lineSpacing(2)
                        }
                    }
                    .padding(20)
                    .background(
                        RoundedRectangle(cornerRadius: 18)
                            .fill(.ultraThinMaterial)
                            .environment(\.colorScheme, .dark)
                            .overlay(
                                RoundedRectangle(cornerRadius: 18)
                                    .stroke(themeManager.palette.accent.opacity(0.18), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)

                    // MARK: Workout Days Preview
                    VStack(spacing: 12) {
                        ForEach(Array(plan.workouts.enumerated()), id: \.offset) { index, workout in
                            WorkoutDayPreviewCard(workout: workout, index: index)
                        }
                    }
                    .padding(.horizontal, 20)

                    // MARK: Save Button & Actions
                    VStack(spacing: 16) {
                        if didSave {
                            // Success text
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("\(savedCount) workout\(savedCount == 1 ? "" : "s") saved!")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(themeManager.palette.accent)
                            .transition(.opacity)
                            
                            // New Primary Button: Start Lifting
                            Button {
                                onDismiss()
                            } label: {
                                Text("Start Lifting")
                                    .font(.system(size: 17, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .background(Capsule().fill(themeManager.palette.gradient))
                                    .foregroundColor(.white)
                                    .shadow(color: themeManager.palette.accent.opacity(0.4), radius: 12, y: 4)
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                            .transition(.scale.combined(with: .opacity))
                            
                        } else {
                            // The original Save Button
                            Button {
                                saveTemplates()
                            } label: {
                                Group {
                                    if isSaving {
                                        HStack(spacing: 10) {
                                            ProgressView()
                                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                                .scaleEffect(0.8)
                                            Text("Saving…")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    } else {
                                        HStack(spacing: 8) {
                                            Image(systemName: "square.and.arrow.down.fill")
                                            Text("Save to My Templates")
                                                .font(.system(size: 16, weight: .semibold))
                                        }
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    Capsule().fill(themeManager.palette.gradient)
                                )
                                .foregroundColor(.white)
                            }
                            .disabled(isSaving)
                            .padding(.horizontal, 24)
                            
                            // Original Skip Button
                            Button {
                                onDismiss()
                            } label: {
                                Text("Maybe Later")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(Color.white.opacity(0.5))
                            }
                            .padding(.bottom, 32)
                        }
                    }
                    .animation(.spring(response: 0.4, dampingFraction: 0.7), value: didSave)
                }
            }
        }
        .alert("Save Failed", isPresented: $showSaveError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Something went wrong while saving your templates. Please try again.")
        }
    }

    // MARK: - Save Logic

    private func saveTemplates() {
        isSaving = true
        HapticManager.shared.lightImpact()

        // Perform the save synchronously on the MainActor via a Task
        Task { @MainActor in
            // If saving an onboarding plan, wipe out default templates so they don't get duplicates
            // from previous failed/skipped onboarding attempts.
            if isOnboarding {
                store.workoutTemplates.removeAll { template in
                    ["UPPER", "LOWER", "Upper Body Power", "Lower Body Hypertrophy", "Full Body Basics"].contains(template.name)
                }
            }

            var count = 0
            for workout in plan.workouts {
                // Feature Flag: Enforce free template limit dynamically during creation
                if !storeManager.isPro && store.workoutTemplates.count >= 3 {
                    break
                }
                
                var exerciseIds: [UUID] = []
                var targets: [UUID: TemplateTarget] = [:]

                for ex in workout.exercises {
                    // Find existing exercise (case-insensitive) or create it
                    let exerciseId: UUID
                    if let existing = store.exerciseLibrary.first(where: {
                        $0.name.localizedCaseInsensitiveCompare(ex.name) == .orderedSame
                    }) {
                        exerciseId = existing.id
                    } else {
                        let newEx = store.addExercise(name: ex.name, category: "Other")
                        exerciseId = newEx.id
                    }

                    exerciseIds.append(exerciseId)
                    targets[exerciseId] = TemplateTarget(
                        sets: String(ex.sets),
                        reps: ex.reps,
                        rir: String(ex.rir),
                        rest: 180
                    )
                }

                let template = WorkoutTemplate(
                    id: UUID(),
                    name: workout.day_name,
                    exerciseIds: exerciseIds,
                    targets: targets.isEmpty ? nil : targets,
                    note: nil,
                    category: plan.plan_name
                )
                store.addWorkoutTemplate(template)
                count += 1
            }

            savedCount = count
            isSaving = false

            // Prevent default Upper/Lower templates from being seeded when
            // finalDismiss() fires — the user has their AI plan, they don't need them.
            UserDefaults.standard.set(true, forKey: "hasSeededDefaultWorkouts")

            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                didSave = true
            }
            HapticManager.shared.success()
        }
    }
}

// MARK: - Workout Day Preview Card

private struct WorkoutDayPreviewCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    let workout: AIPlanWorkout
    let index: Int

    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    isExpanded.toggle()
                }
                HapticManager.shared.selection()
            } label: {
                HStack(spacing: 12) {
                    // Day number badge
                    Text("\(index + 1)")
                        .font(.system(size: 13, weight: .black))
                        .foregroundColor(.black)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(themeManager.palette.accent))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(workout.day_name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.white)
                        Text("\(workout.exercises.count) exercises")
                            .font(.system(size: 12))
                            .foregroundColor(Color.white.opacity(0.5))
                    }

                    Spacer()

                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(Color.white.opacity(0.4))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            // Expanded exercise list
            if isExpanded {
                Divider()
                    .background(Color.white.opacity(0.08))

                VStack(spacing: 0) {
                    ForEach(Array(workout.exercises.enumerated()), id: \.offset) { idx, ex in
                        HStack(spacing: 10) {
                            // Index
                            Text("\(idx + 1).")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.35))
                                .frame(width: 20, alignment: .trailing)

                            // Name
                            Text(ex.name)
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white)
                                .lineLimit(1)

                            Spacer()

                            // Sets × Reps
                            Text("\(ex.sets) × \(ex.reps)")
                                .font(.system(size: 12, weight: .bold, design: .monospaced))
                                .foregroundColor(themeManager.palette.accent)

                            // RIR badge
                            Text("RIR \(ex.rir)")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundColor(Color.white.opacity(0.45))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(Color.white.opacity(0.07))
                                )
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)

                        if idx < workout.exercises.count - 1 {
                            Divider()
                                .background(Color.white.opacity(0.05))
                                .padding(.leading, 46)
                        }
                    }

                    // Notes snippet (first exercise with a note)
                    if let firstNote = workout.exercises.first(where: { !$0.notes.isEmpty })?.notes {
                        Divider().background(Color.white.opacity(0.05))
                        HStack(spacing: 8) {
                            Image(systemName: "text.quote")
                                .font(.system(size: 11))
                                .foregroundColor(themeManager.palette.accent.opacity(0.7))
                            Text(firstNote)
                                .font(.system(size: 12))
                                .foregroundColor(Color.white.opacity(0.5))
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.Colors.cardBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.07), lineWidth: 1)
                )
        )
    }
}
