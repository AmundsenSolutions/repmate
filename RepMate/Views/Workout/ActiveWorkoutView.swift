import SwiftUI
import StoreKit

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @StateObject private var vm = ActiveWorkoutViewModel()

    @State private var showExitDialog = false
    @State private var showFinishConfirmation = false
    @State private var showingRestPicker = false
    @State private var showWorkoutSavedOverlay = false
    
    @AppStorage("workoutsCompletedCount") private var workoutsCompletedCount = 0
    
    // Menu State
    @State private var showRestartConfirmation = false
    @State private var showDeleteConfirmation = false
    
    @State private var showingReorderView = false
    @FocusState private var isAnyFieldFocused: Bool
    

    private var active: ActiveWorkout? { store.activeWorkout }

    private var template: WorkoutTemplate? {
        guard let aw = active else { return nil }
        return store.workoutTemplates.first(where: { $0.id == aw.templateId })
    }

    var body: some View {
        ZStack {
            Theme.Colors.background.ignoresSafeArea()
                .onTapGesture {
                    isAnyFieldFocused = false
                    hideKeyboard()
                }
            
            if active == nil && !showWorkoutSavedOverlay {
                emptyStateView
            } else if !showWorkoutSavedOverlay {
                activeWorkoutContent
                
                // Bottom Floating Area: Timer + Finish Button
                // Context: Sits above content, aligned to bottom
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Timer Overlay (only if active)
                    if vm.isTimerActive {
                        timerOverlay
                            .padding(.bottom, vm.keyboardVisible ? 0 : 10)
                            // Hide timer if keyboard is up to avoid blocking input
                            .opacity(vm.keyboardVisible ? 0 : 1)
                            .animation(.easeInOut(duration: 0.2), value: vm.keyboardVisible)
                    }
                    
                    if !vm.keyboardVisible && !showWorkoutSavedOverlay {
                        finishButton
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .zIndex(20) // Ensure it floats above everything
                .animation(.easeInOut(duration: 0.2), value: vm.keyboardVisible)
            }
            
            if showWorkoutSavedOverlay {
                ZStack {
                    Color.black.opacity(0.85)
                        .ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 72))
                            .foregroundColor(Theme.Colors.accent)
                        Text("Workout Complete! 💪")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .transition(.opacity)
                .zIndex(100)
            }
            
            
        }
        .navigationBarBackButtonHidden(true)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    handleBack()
                } label: {
                    Image(systemName: "chevron.left")
                        .foregroundColor(Theme.Colors.accent)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .confirmationDialog(
                    "Exit Workout",
                    isPresented: $showExitDialog,
                    titleVisibility: .visible
                ) {
                    Button("Save and Exit") {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                            dismiss()
                        }
                    }
                    .contentShape(Rectangle())
                    Button("Discard Workout", role: .destructive) {
                        store.discardActiveWorkout()
                        dismiss()
                    }
                    .contentShape(Rectangle())
                } message: {
                    Text("Your progress will be saved so you can continue later, or you can discard this workout.")
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 8) {
                    // Rest Timer Button
                    Button {
                        vm.startRestTimer(templateName: template?.name, exerciseLibrary: store.exerciseLibrary)
                    } label: {
                        Image(systemName: "timer")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .background(Theme.Colors.cardBackground)
                            .clipShape(Circle())
                    }
                    .simultaneousGesture(LongPressGesture().onEnded { _ in
                         showingRestPicker = true
                         HapticManager.shared.selection()
                    })
                    
                    // Workout Menu (...)
                    Menu {
                        // Target Mode
                        Menu {
                            ForEach(GhostDataSource.allCases, id: \.self) { source in
                                Button {
                                    store.ghostDataSource = source
                                } label: {
                                    if store.ghostDataSource == source {
                                        Label(source.rawValue, systemImage: "checkmark")
                                    } else {
                                        Text(source.rawValue)
                                    }
                                }
                            }
                        } label: {
                            Label("Compare to: \(store.ghostDataSource.rawValue)", systemImage: "arrow.triangle.2.circlepath")
                        }
                        
                        // Reorder Exercises
                        Button {
                            showingReorderView = true
                        } label: {
                            Label("Reorder Exercises", systemImage: "arrow.up.arrow.down")
                        }
                        
                        // Save as Template
                        Button {
                            vm.requestSaveAsTemplate(
                                isPro: storeManager.isPro,
                                templateCount: store.workoutTemplates.count,
                                suggestedName: template?.name ?? "My Workout"
                            )
                        } label: {
                            Label("Save as Template", systemImage: "square.and.arrow.down")
                        }
                        
                        // Share Workout
                        if let t = template,
                           let shareURL = t.shareURL(exercises: store.exerciseLibrary) {
                            ShareLink(item: shareURL) {
                                Label("Share Workout", systemImage: "square.and.arrow.up")
                            }
                        }
                        
                        // Restart Workout
                        Button {
                            showRestartConfirmation = true
                        } label: {
                            Label("Restart Workout", systemImage: "arrow.counterclockwise")
                        }
                        
                        Divider()
                        
                        // Delete Workout (Destructive)
                        Button(role: .destructive) {
                            showDeleteConfirmation = true
                        } label: {
                            Label("Delete Workout", systemImage: "trash")
                                .foregroundColor(.red)
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.Colors.textPrimary)
                            .frame(width: 36, height: 36)
                            .contentShape(Rectangle())
                    }
                }
            }
        }
        .alert("Rest Timer", isPresented: $showingRestPicker) {
            Button("1 min") { store.updateRestTime(60) }
            Button("1.5 min") { store.updateRestTime(90) }
            Button("2 min") { store.updateRestTime(120) }
            Button("3 min") { store.updateRestTime(180) }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Set default rest time")
        }
        .onAppear {
            store.isViewingActiveWorkout = true
            vm.attach(store: store, themeManager: themeManager)
            vm.restoreTimerState(templateName: template?.name, exerciseLibrary: store.exerciseLibrary)
        }
        .onDisappear {
            store.isViewingActiveWorkout = false
            // Only cancel the local Combine subscription —
            // do NOT end the Live Activity, it should keep running on the Lock Screen.
            vm.cancelLocalTimer()
        }
        .onChange(of: active) { _, newValue in
            if newValue == nil && !showWorkoutSavedOverlay { dismiss() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                vm.restoreTimerState(templateName: template?.name, exerciseLibrary: store.exerciseLibrary)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            vm.handleKeyboardWillShow()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            vm.handleKeyboardWillHide()
        }
        .onChange(of: store.activeWorkout?.timerTargetDate) { _, newTarget in
            if newTarget == nil {
                vm.stopTimer()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("StartAutoRestTimer"))) { notification in
            if let duration = notification.object as? Int {
                vm.startRestTimer(templateName: template?.name, exerciseLibrary: store.exerciseLibrary, customDuration: duration)
            }
        }
        // Menu Dialogs
        .alert("Save as Template", isPresented: $vm.showSaveTemplateAlert) {
            TextField("Template Name", text: $vm.newTemplateName)
            Button("Save") { saveAsTemplate() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Enter a name for the new template.")
        }
        .confirmationDialog("Restart Workout?", isPresented: $showRestartConfirmation, titleVisibility: .visible) {
            Button("Restart", role: .destructive) { restartWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear all entered weights, reps, and RIR values.")
        }
        .confirmationDialog("Delete Workout?", isPresented: $showDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deleteWorkout() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This workout and all its data will be permanently deleted.")
        }
        .sheet(isPresented: $showingReorderView) {
            ReorderExercisesView()
        }
        .sheet(isPresented: $vm.showPaywall) {
            PaywallView()
        }
    }


    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("No active workout.")
                .foregroundColor(Theme.Colors.textSecondary)
            Button("Back") { dismiss() }
        }
    }

    private var activeWorkoutContent: some View {
        VStack(spacing: 0) {
            // Workout Name
            if let templateName = template?.name {
                Text(templateName.uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(Theme.Colors.textPrimary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
            }
            
            // Header Component
            ActiveWorkoutHeaderView()
            
            // List Component
            ActiveExerciseListView()
        }
    }

    private var finishButton: some View {
        Button {
            showFinishConfirmation = true
        } label: {
            HStack(spacing: 8) {
                Text("Finish Workout")
                    .font(.system(size: 16, weight: .semibold))
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(store.hasValidActiveSets ? themeManager.palette.accent : Color.gray.opacity(0.3))
            )
            .foregroundColor(store.hasValidActiveSets ? .black : .gray)
            .contentShape(Rectangle())
        }
        .disabled(!store.hasValidActiveSets)
        .confirmationDialog(
            "Finish Workout",
            isPresented: $showFinishConfirmation,
            titleVisibility: .visible
        ) {
            Button("Finish & Save Log", role: .none) {
                finishWorkout()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you sure you want to finish this session?")
        }
        .buttonStyle(PlainButtonStyle())
    }

    // MARK: - Logic

    private func handleBack() {
        guard store.activeWorkout != nil else {
            dismiss()
            return
        }
        showExitDialog = true
    }
    
    private func finishWorkout() {
        HapticManager.shared.success()
        if store.finishActiveWorkout() {
            workoutsCompletedCount += 1
            
            if [3, 10, 25].contains(workoutsCompletedCount) {
                if let scene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene {
                    SKStoreReviewController.requestReview(in: scene)
                }
            }
        }
        
        withAnimation(.easeIn(duration: 0.2)) {
            showWorkoutSavedOverlay = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            guard showWorkoutSavedOverlay else { return }
            dismiss()
        }
    }
    
    private func saveAsTemplate() {
        guard let aw = active else { return }
        let name = vm.newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        
        let newTemplate = WorkoutTemplate(
            id: UUID(),
            name: name,
            exerciseIds: aw.exerciseIds,
            targets: aw.targets,
            note: aw.note
        )
        store.addWorkoutTemplate(newTemplate)
        HapticManager.shared.success()
    }
    
    private func restartWorkout() {
        guard let aw = active,
              let template = store.workoutTemplates.first(where: { $0.id == aw.templateId })
        else { return }
        
        // Hard Reset: Re-initialize from template to restore default sets/targets
        // We keep the same ID to prevent the sheet from dismissing/flickering
        var newWorkout = ActiveWorkout.start(from: template)
        newWorkout.id = aw.id 
        // Reset timer target if any
        newWorkout.timerTargetDate = nil
        
        store.updateActiveWorkout(newWorkout)
        HapticManager.shared.success()
    }
    
    private func deleteWorkout() {
        store.discardActiveWorkout()
        HapticManager.shared.success()
        dismiss()
    }
    
    
    // MARK: - Timer UI

    private var timerOverlay: some View {
        HStack(spacing: 12) {
            // -15s
            Button {
                vm.adjustTimer(-15)
            } label: {
                Image(systemName: "gobackward.15")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }

            // Circular Timer
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)
                
                Circle()
                    .trim(from: 0, to: CGFloat(vm.timeRemaining) / CGFloat(max(vm.initialTimerDuration, 1)))
                    .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: vm.timeRemaining)
                
                Text(formatTime(vm.timeRemaining))
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
            .frame(width: 80, height: 80)
            .background(.ultraThinMaterial)
            .clipShape(Circle())
            .overlay(
                Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .onTapGesture {
                // Tapping circle also skips? Or nothing?
                // Let's keep it simple for now.
            }
            
            // +15s
             Button {
                vm.adjustTimer(15)
            } label: {
                Image(systemName: "goforward.15")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
                    .overlay(
                        Circle().stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
            }
            
            // Skip (X)
            Button {
                vm.skipTimer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Theme.Colors.danger.opacity(0.9))
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal)
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
    
    private func formatTime(_ totalSeconds: Int) -> String {
        let seconds = totalSeconds % 60
        let minutes = totalSeconds / 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

