import SwiftUI
import Combine

struct ActiveWorkoutView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var themeManager = ThemeManager.shared
    @Environment(\.scenePhase) private var scenePhase

    @State private var showExitDialog = false
    @State private var showFinishConfirmation = false
    @State private var showingRestPicker = false
    
    // Menu State
    @State private var showSaveTemplateAlert = false
    @State private var showRestartConfirmation = false
    @State private var showDeleteConfirmation = false
    @State private var newTemplateName = ""
    
    // Timer State
    @State private var timeRemaining: Int = 0
    @State private var initialTimerDuration: Int = 60 // Default for progress calculation
    @State private var timerCancellable: AnyCancellable?
    @State private var isTimerActive = false
    @State private var overtimeSeconds: Int = 0
    
    @State private var isReorderingMode = false
    @FocusState private var isAnyFieldFocused: Bool
    @State private var keyboardVisible = false

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
            
            if active == nil {
                emptyStateView
            } else {
                activeWorkoutContent
                
                // Bottom Floating Area: Timer + Finish Button
                // Context: Sits above content, aligned to bottom
                VStack(spacing: 0) {
                    Spacer()
                    
                    // Timer Overlay (only if active)
                    if isTimerActive {
                        timerOverlay
                            .padding(.bottom, keyboardVisible ? 0 : 10)
                            // Hide timer if keyboard is up to avoid blocking input
                            .opacity(keyboardVisible ? 0 : 1)
                            .animation(.easeInOut(duration: 0.2), value: keyboardVisible)
                    }
                    
                    // Finish Button (only if keyboard is hidden)
                    if !keyboardVisible {
                        finishButton
                            .padding(.bottom, 16)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                }
                .zIndex(20) // Ensure it floats above everything
                .animation(.easeInOut(duration: 0.2), value: keyboardVisible)
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
                        dismiss()
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
                        startRestTimer()
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
                            withAnimation { isReorderingMode.toggle() }
                        } label: {
                            Label(isReorderingMode ? "Done Reordering" : "Reorder Exercises",
                                  systemImage: "arrow.up.arrow.down")
                        }
                        
                        // Save as Template
                        Button {
                            newTemplateName = template?.name ?? "My Workout"
                            showSaveTemplateAlert = true
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
            restoreTimerState()
        }
        .onDisappear {
            store.isViewingActiveWorkout = false
            stopTimer()
        }
        .onChange(of: active) { _, newValue in
            if newValue == nil { dismiss() }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                restoreTimerState()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
            withAnimation { keyboardVisible = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            withAnimation { keyboardVisible = false }
        }
        // Menu Dialogs
        .alert("Save as Template", isPresented: $showSaveTemplateAlert) {
            TextField("Template Name", text: $newTemplateName)
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
            ActiveExerciseListView(isReorderingMode: $isReorderingMode)
        }
        .safeAreaInset(edge: .bottom) {
            // Invisible spacer so list content scrolls above the floating button
            Color.clear.frame(height: 70)
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
        store.finishActiveWorkout()
        dismiss()
    }
    
    private func saveAsTemplate() {
        guard let aw = active else { return }
        let name = newTemplateName.trimmingCharacters(in: .whitespacesAndNewlines)
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
    
    // MARK: - Timer Logic
    
    private func restoreTimerState() {
        guard let aw = store.activeWorkout, let target = aw.timerTargetDate else { return }
        
        let now = Date()
        let remaining = target.timeIntervalSince(now)
        
        if remaining > 0 {
            // Cancel any existing timer first to prevent stacking
            timerCancellable?.cancel()
            timerCancellable = nil
            
            timeRemaining = Int(remaining)
            initialTimerDuration = max(store.settings.restTime, Int(remaining))
            isTimerActive = true
            
            // Update Live Activity (don't start a new one — just update the end time)
            LiveActivityManager.shared.updateTimer(newEndTime: target)
            
            // Use date-based calculation on every tick for accuracy
            timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
                .autoconnect()
                .sink { [self] _ in
                    let secondsLeft = Int(target.timeIntervalSince(Date()))
                    if secondsLeft > 0 {
                        timeRemaining = secondsLeft
                    } else {
                        timeRemaining = 0
                        HapticManager.shared.success()
                        if var aw = store.activeWorkout {
                            aw.timerTargetDate = nil
                            store.updateActiveWorkout(aw)
                        }
                        stopTimer()
                    }
                }
        } else {
             if var aw = store.activeWorkout {
                aw.timerTargetDate = nil
                store.updateActiveWorkout(aw)
            }
            // Clean up any stale Live Activity
            LiveActivityManager.shared.endTimer()
        }
    }
    
    private func startRestTimer() {
        stopTimer()
        let duration = store.settings.restTime
        initialTimerDuration = duration
        timeRemaining = duration
        isTimerActive = true
        overtimeSeconds = 0
        HapticManager.shared.lightImpact()
        
        let targetDate = Date().addingTimeInterval(TimeInterval(duration))
        
        if var aw = store.activeWorkout {
            aw.timerTargetDate = targetDate
            store.updateActiveWorkout(aw)
        }
        
        // Start Live Activity (Dynamic Island + Lock Screen)
        LiveActivityManager.shared.startTimer(
            duration: duration,
            accentColor: themeManager.palette.accent
        )
        
        timerCancellable = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { [self] _ in
                let secondsLeft = Int(targetDate.timeIntervalSince(Date()))
                
                if secondsLeft > 0 {
                    timeRemaining = secondsLeft
                    
                    // Countdown haptics at 5s and 3s
                    if secondsLeft == 5 {
                        HapticManager.shared.lightImpact()
                    } else if secondsLeft == 3 {
                        HapticManager.shared.selection()
                    }
                } else {
                    timeRemaining = 0
                    // Multiple vibrations at 0 to get attention
                    HapticManager.shared.success()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        HapticManager.shared.success()
                    }
                    if var aw = store.activeWorkout {
                        aw.timerTargetDate = nil
                        store.updateActiveWorkout(aw)
                    }
                    stopTimer()
                }
            }
    }
    
    private func stopTimer() {
        timerCancellable?.cancel()
        timerCancellable = nil
        isTimerActive = false
        LiveActivityManager.shared.endTimer()
    }
    
    private func skipTimer() {
        stopTimer()
        HapticManager.shared.selection()
    }
    
    private func adjustTimer(_ seconds: Int) {
        guard var aw = store.activeWorkout, let currentTarget = aw.timerTargetDate else { return }
        
        let newTarget = currentTarget.addingTimeInterval(TimeInterval(seconds))
        
        if newTarget <= Date() {
            timeRemaining = 0
            aw.timerTargetDate = nil
            store.updateActiveWorkout(aw)
            stopTimer()
        } else {
            aw.timerTargetDate = newTarget
            store.updateActiveWorkout(aw)
            LiveActivityManager.shared.updateTimer(newEndTime: newTarget)
            timeRemaining = Int(newTarget.timeIntervalSince(Date()))
        }
        
        HapticManager.shared.selection()
    }
    
    private var timerOverlay: some View {
        HStack(spacing: 12) {
            // -15s
            Button {
                adjustTimer(-15)
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
                    .trim(from: 0, to: CGFloat(timeRemaining) / CGFloat(max(initialTimerDuration, 1)))
                    .stroke(Theme.Colors.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1.0), value: timeRemaining)
                
                Text(formatTime(timeRemaining))
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
                adjustTimer(15)
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
                skipTimer()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(Color.red.opacity(0.8))
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
    
    private func formatDuration(_ totalSeconds: Int) -> String {
        let minutes = Double(totalSeconds) / 60.0
        // If whole number, show no decimal
        if minutes.truncatingRemainder(dividingBy: 1) == 0 {
            return "\(Int(minutes))m"
        }
        return String(format: "%.1fm", minutes)
    }
}
