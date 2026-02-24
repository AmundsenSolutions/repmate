import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @State private var targetText: String = ""
    @State private var showingCustomTheme = false
    @State private var weightString = ""
    @State private var calculatedProtein: Int?
    @State private var showResetAlert = false
    @EnvironmentObject var storeManager: StoreManager
    @State private var showPaywall = false
    
    // Analytics & Crash Reporting
    @AppStorage("shareAnalytics") private var shareAnalytics = true
    @AppStorage("sendCrashReports") private var sendCrashReports = true
    
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        // MARK: - Pro Status Header
                        proHeaderCard
                        
                        // MARK: - Appearance
                        GlassSection(title: "Appearance") {
                            // Theme Picker
                            HStack {
                                Label("Theme", systemImage: "paintpalette")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                Menu {
                                    ForEach(ThemeManager.availableThemes) { theme in
                                        Button {
                                            themeManager.activeTheme = theme
                                            HapticManager.shared.lightImpact()
                                        } label: {
                                            HStack {
                                                Text(theme.displayName)
                                                if themeManager.activeTheme == theme {
                                                    Image(systemName: "checkmark")
                                                }
                                            }
                                        }
                                    }
                                    
                                    Divider()
                                    
                                    Button {
                                        if storeManager.isPro {
                                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                                showingCustomTheme = true
                                            }
                                        } else {
                                            showPaywall = true
                                        }
                                        HapticManager.shared.lightImpact()
                                    } label: {
                                        if storeManager.isPro {
                                            Label("Create Custom Theme", systemImage: "paintbrush.fill")
                                        } else {
                                            Label("Custom Theme (Pro)", systemImage: "crown.fill")
                                        }
                                    }
                                    
                                } label: {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(themeManager.palette.accent)
                                            .frame(width: 10, height: 10)
                                            .shadow(color: themeManager.palette.accent.opacity(0.6), radius: 3)
                                        
                                        Text(themeManager.activeTheme.displayName)
                                            .font(Theme.Fonts.body)
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                            .foregroundColor(Theme.Colors.textDim)
                                    }
                                    .frame(height: 44)
                                    .padding(.horizontal, 12)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(Theme.Spacing.compact)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // App Icon
                            NavigationLink(destination: CustomIconPickerView()) {
                                HStack {
                                    Label("App Icon", systemImage: "app.badge")
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Theme.Colors.textDim)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(height: 44)
                            }
                        }
                        
                        // MARK: - Training
                        GlassSection(title: "Training") {
                            // Default Rest Time
                            HStack {
                                Label("Default Rest Time", systemImage: "timer")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                Menu {
                                    Picker("Rest Time", selection: Binding(
                                        get: { store.settings.restTime },
                                        set: { store.updateRestTime($0) }
                                    )) {
                                        Text("30s").tag(30)
                                        Text("45s").tag(45)
                                        Text("60s").tag(60)
                                        Text("90s").tag(90)
                                        Text("120s").tag(120)
                                        Text("180s").tag(180)
                                        Text("240s").tag(240)
                                        Text("300s").tag(300)
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(store.settings.restTime)s")
                                            .font(Theme.Fonts.value)
                                            .foregroundColor(Theme.Colors.accent)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption)
                                            .foregroundColor(Theme.Colors.accent)
                                    }
                                    .frame(height: 44)
                                    .padding(.horizontal, 12)
                                    .background(Color.white.opacity(0.06))
                                    .cornerRadius(Theme.Spacing.compact)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Target Rep Range
                            HStack {
                                Label("Target Rep Range", systemImage: "arrow.up.arrow.down")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                HStack(spacing: 8) {
                                    Menu {
                                        Picker("Min", selection: Binding(
                                            get: { store.settings.minReps },
                                            set: { 
                                                let newMax = max($0, store.settings.maxReps)
                                                store.updateTargetRepRange(min: $0, max: newMax) 
                                            }
                                        )) {
                                            ForEach(1..<20, id: \.self) { val in
                                                Text("\(val)").tag(val)
                                            }
                                        }
                                    } label: {
                                        Text("\(store.settings.minReps)")
                                            .font(Theme.Fonts.value)
                                            .foregroundColor(Theme.Colors.accent)
                                            .frame(width: 36, height: 44)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(Theme.Spacing.compact)
                                    }
                                    
                                    Text("to")
                                        .font(.caption)
                                        .foregroundColor(Theme.Colors.textDim)
                                    
                                    Menu {
                                        Picker("Max", selection: Binding(
                                            get: { store.settings.maxReps },
                                            set: { 
                                                let newMin = min($0, store.settings.minReps)
                                                store.updateTargetRepRange(min: newMin, max: $0) 
                                            }
                                        )) {
                                            ForEach(1..<31, id: \.self) { val in
                                                Text("\(val)").tag(val)
                                            }
                                        }
                                    } label: {
                                        Text("\(store.settings.maxReps)")
                                            .font(Theme.Fonts.value)
                                            .foregroundColor(Theme.Colors.accent)
                                            .frame(width: 36, height: 44)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(Theme.Spacing.compact)
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Nutrition
                        GlassSection(title: "Nutrition") {
                            // Daily Target
                            HStack {
                                Label("Daily Target (g)", systemImage: "fork.knife")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(.white)
                                Spacer()
                                
                                BufferedInputView(
                                    value: $targetText,
                                    placeholder: "150",
                                    keyboardType: .numberPad,
                                    color: Theme.Colors.accent,
                                    alignment: .trailing,
                                    font: Theme.Fonts.value,
                                    backgroundColor: Color.white.opacity(0.06),
                                    cornerRadius: Theme.Spacing.compact
                                )
                                .frame(width: 80, height: 44)
                                .onChange(of: targetText) { _, newValue in
                                    if let grams = Int(newValue), grams > 0 {
                                        store.updateDailyProteinTarget(grams)
                                    }
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Protein Calculator
                            VStack(spacing: Theme.Spacing.compact) {
                                HStack {
                                    BufferedInputView(
                                        value: $weightString,
                                        placeholder: "Weight (kg)",
                                        keyboardType: .decimalPad,
                                        color: .white,
                                        alignment: .leading,
                                        font: Theme.Fonts.body,
                                        backgroundColor: Color.white.opacity(0.06),
                                        cornerRadius: Theme.Spacing.compact
                                    )
                                    .frame(height: 44)
                                    .frame(minWidth: 0, maxWidth: .infinity)
                                    
                                    Button(action: {
                                        calculateProtein()
                                        hideKeyboard()
                                    }) {
                                        Text("Calculate")
                                            .font(Theme.Fonts.value)
                                            .foregroundColor(Theme.Colors.accent)
                                            .frame(height: 44)
                                            .padding(.horizontal, 16)
                                            .background(Color.white.opacity(0.06))
                                            .cornerRadius(Theme.Spacing.compact)
                                    }
                                }
                                
                                if let result = calculatedProtein {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Divider().background(Color.white.opacity(0.1)).padding(.vertical, 4)
                                        
                                        Text("Recommended: ~\(result) g/day")
                                            .font(.headline)
                                            .foregroundColor(Theme.Colors.accent)
                                        
                                        Text("Based on ~1.6g protein per kg bodyweight.")
                                            .font(.caption)
                                            .foregroundColor(Theme.Colors.textSecondary)
                                        
                                        Button(action: {
                                            targetText = String(result)
                                            store.updateDailyProteinTarget(result)
                                            calculatedProtein = nil
                                            HapticManager.shared.success()
                                        }) {
                                            Text("Set Target to \(result)g")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(.black)
                                                .frame(maxWidth: .infinity)
                                                .padding(.vertical, 10)
                                                .background(Theme.Colors.accent)
                                                .cornerRadius(Theme.Spacing.compact)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                                    .padding(.top, 4)
                                }
                            }
                            .animation(.spring(response: 0.4, dampingFraction: 0.7), value: calculatedProtein)
                        }
                        
                        // MARK: - Management
                        GlassSection(title: "Management") {
                            NavigationLink(destination: ExerciseLibraryView()) {
                                HStack {
                                    Label("Exercises & Categories", systemImage: "dumbbell")
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(Theme.Colors.textDim)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                                .frame(height: 44)
                            }
                        }
                        
                        // MARK: - About & Support
                        GlassSection(title: "About & Support") {
                            // Send Feedback
                            Link(destination: URL(string: "mailto:support@vextapp.com")!) {
                                HStack {
                                    Label("Send Feedback", systemImage: "envelope.fill")
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(Theme.Colors.textDim)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(height: 44)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Privacy Policy
                            Link(destination: URL(string: "https://vextapp.com/privacy")!) {
                                HStack {
                                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(Theme.Colors.textDim)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(height: 44)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            // Terms of Service
                            Link(destination: URL(string: "https://vextapp.com/terms")!) {
                                HStack {
                                    Label("Terms of Service", systemImage: "doc.text.fill")
                                        .font(Theme.Fonts.body)
                                        .foregroundColor(Theme.Colors.textPrimary)
                                    Spacer()
                                    Image(systemName: "arrow.up.right")
                                        .foregroundColor(Theme.Colors.textDim)
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(height: 44)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Toggle(isOn: $shareAnalytics) {
                                Label("Share Anonymous Analytics", systemImage: "chart.pie.fill")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            .tint(themeManager.palette.accent)
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Toggle(isOn: $sendCrashReports) {
                                Label("Send Crash Reports", systemImage: "ladybug.fill")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(Theme.Colors.textPrimary)
                            }
                            .tint(themeManager.palette.accent)
                        }
                        
                        // MARK: - Advanced
                        GlassSection(title: "Advanced") {
                            Button(action: {
                                UserDefaults.standard.removeObject(forKey: "hasSeenOnboarding")
                                HapticManager.shared.success()
                            }) {
                                HStack {
                                    Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
                                        .font(Theme.Fonts.value)
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("Restart app")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.4))
                                }
                                .frame(height: 44)
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            if storeManager.isPro {
                                ShareLink(
                                    item: DataExportManager.CSVExport(
                                        csvText: DataExportManager.generateWorkoutsCSV(
                                            sessions: store.workoutSessions,
                                            exerciseLibrary: store.exerciseLibrary
                                        )
                                    ),
                                    preview: SharePreview("Vext Workouts Data")
                                ) {
                                    HStack {
                                        Label("Export Data (CSV)", systemImage: "square.and.arrow.up")
                                            .font(Theme.Fonts.value)
                                            .foregroundColor(.white)
                                        Spacer()
                                    }
                                    .frame(height: 44)
                                }
                            } else {
                                Button(action: {
                                    showPaywall = true
                                    HapticManager.shared.lightImpact()
                                }) {
                                    HStack {
                                        Label("Export Data (Pro)", systemImage: "crown.fill")
                                            .font(Theme.Fonts.value)
                                            .foregroundColor(.yellow)
                                        Spacer()
                                    }
                                    .frame(height: 44)
                                }
                            }
                            
                            Divider().background(Color.white.opacity(0.1))
                            
                            Button(action: {
                                showResetAlert = true
                            }) {
                                HStack {
                                    Label("Reset All Data", systemImage: "trash.fill")
                                        .font(Theme.Fonts.value)
                                        .foregroundColor(.red)
                                    Spacer()
                                }
                                .frame(height: 44)
                            }
                        }
                    }
                    .padding()
                    .padding(.bottom, store.activeWorkout != nil ? 80 : 0)
                }
            }
            .navigationTitle("Settings")
            .onAppear {
                targetText = String(store.settings.dailyProteinTarget)
            }
            .alert("Reset All Data?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    store.resetAllData()
                    HapticManager.shared.success()
                }
            } message: {
                Text("This will delete all workouts, protein entries, and settings. This cannot be undone.")
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $showingCustomTheme) {
            CustomThemeView()
        }
    }
    
    // MARK: - Pro Header Card
    
    private var proHeaderCard: some View {
        Button {
            showPaywall = true
            HapticManager.shared.lightImpact()
        } label: {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Vext")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                        
                        if storeManager.isPro {
                            HStack(spacing: 6) {
                                Image(systemName: "crown.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(.yellow)
                                Text("Pro")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.yellow)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if storeManager.isPro {
                        Image(systemName: "checkmark.seal.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                    } else {
                        Text("Get Pro")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 10)
                            .background(
                                LinearGradient(
                                    colors: [.yellow, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(20)
                    }
                }
            }
            .padding(Theme.Spacing.standard)
            .glassCard(style: .primary)
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Helpers
    
    private func calculateProtein() {
        let sanitized = weightString.replacingOccurrences(of: ",", with: ".")
        guard let weight = Double(sanitized) else { return }
        let protein = weight * 1.6
        calculatedProtein = Int(protein.rounded())
    }
    
    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

// MARK: - Keep legacy SettingsCard for backward compatibility
struct SettingsCard<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.gray)
                .padding(.leading, 4)
            
            VStack {
                content
            }
            .oledCard()
        }
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppDataStore())
        .environmentObject(ThemeManager.shared)
}
