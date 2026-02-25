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
                // Pure OLED Black background
                Color.black.ignoresSafeArea()
                
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 24) {
                        
                        // MARK: - Pro Status Header
                        proHeaderCard
                        
                        // MARK: - Appearance
                        cyberGlassSection(title: "Appearance") {
                            // Theme Picker
                            settingsRow(title: "Theme", icon: "paintpalette") {
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
                                    valueDisplay(
                                        text: themeManager.activeTheme.displayName,
                                        icon: "chevron.up.chevron.down",
                                        accentPrefix: true
                                    )
                                }
                            }
                            
                            divider
                            
                            // App Icon
                            NavigationLink(destination: CustomIconPickerView()) {
                                navRow(title: "App Icon", icon: "app.badge")
                            }
                        }
                        
                        // MARK: - Training
                        cyberGlassSection(title: "Training") {
                            // Default Rest Time
                            settingsRow(title: "Default Rest Time", icon: "timer") {
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
                                    valueDisplay(
                                        text: "\(store.settings.restTime)s",
                                        icon: "chevron.up.chevron.down"
                                    )
                                }
                            }
                            
                            divider
                            
                            // Target Rep Range
                            settingsRow(title: "Target Rep Range", icon: "arrow.up.arrow.down") {
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
                                        compactValueDisplay("\(store.settings.minReps)")
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
                                        compactValueDisplay("\(store.settings.maxReps)")
                                    }
                                }
                            }
                        }
                        
                        // MARK: - Nutrition
                        cyberGlassSection(title: "Nutrition") {
                            // Daily Target
                            settingsRow(title: "Daily Target (g)", icon: "fork.knife") {
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
                            
                            divider
                            
                            // Protein Calculator
                            VStack(spacing: Theme.Spacing.compact) {
                                HStack(spacing: 8) {
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
                                    
                                    Button(action: {
                                        calculateProtein()
                                        hideKeyboard()
                                        HapticManager.shared.lightImpact()
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
                                        divider.padding(.vertical, 4)
                                        
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
                        cyberGlassSection(title: "Management") {
                            NavigationLink(destination: ExerciseLibraryView()) {
                                navRow(title: "Exercises & Categories", icon: "dumbbell")
                            }
                        }
                        
                        // MARK: - About & Support
                        cyberGlassSection(title: "About & Support") {
                            Link(destination: URL(string: "mailto:amundsen.dev@gmail.com")!) {
                                navRow(title: "Send Feedback", icon: "envelope.fill", isExternal: true)
                            }
                            divider
                            Link(destination: URL(string: "https://vextapp.com/privacy")!) {
                                navRow(title: "Privacy Policy", icon: "hand.raised.fill", isExternal: true)
                            }
                            divider
                            Link(destination: URL(string: "https://vextapp.com/terms")!) {
                                navRow(title: "Terms of Service", icon: "doc.text.fill", isExternal: true)
                            }
                            
                            divider
                            
                            Toggle(isOn: $shareAnalytics) {
                                Label("Share Anonymous Analytics", systemImage: "chart.pie.fill")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(NeonToggleStyle(onColor: themeManager.palette.accent))
                            .frame(height: 44)
                            
                            divider
                            
                            Toggle(isOn: $sendCrashReports) {
                                Label("Send Crash Reports", systemImage: "ladybug.fill")
                                    .font(Theme.Fonts.body)
                                    .foregroundColor(.white)
                            }
                            .toggleStyle(NeonToggleStyle(onColor: themeManager.palette.accent))
                            .frame(height: 44)
                        }
                        
                        // MARK: - Advanced
                        cyberGlassSection(title: "Advanced") {
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
                                        .foregroundColor(Theme.Colors.textDim)
                                }
                                .frame(height: 44)
                            }
                            
                            divider
                            
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
                            
                            divider
                            
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
                    .padding(.bottom, store.activeWorkout != nil ? 100 : 20)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
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
    
    // MARK: - Components
    
    @ViewBuilder
    private func cyberGlassSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.7))
                .padding(.leading, 8)
                .shadow(color: themeManager.palette.accent.opacity(0.3), radius: 4)
            
            VStack(spacing: 0) {
                content()
            }
            .padding(16)
            .cyberGlass(glowColor: themeManager.palette.accent, cornerRadius: 20)
        }
    }
    
    @ViewBuilder
    private func settingsRow<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(Theme.Fonts.body)
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(themeManager.palette.accent)
                    .shadow(color: themeManager.palette.accent.opacity(0.4), radius: 3)
            }
            Spacer()
            content()
        }
        .frame(minHeight: 44)
    }
    
    @ViewBuilder
    private func navRow(title: String, icon: String, isExternal: Bool = false) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(Theme.Fonts.body)
                    .foregroundColor(.white)
            } icon: {
                Image(systemName: icon)
                    .foregroundColor(themeManager.palette.accent)
                    .shadow(color: themeManager.palette.accent.opacity(0.4), radius: 3)
            }
            Spacer()
            Image(systemName: isExternal ? "arrow.up.right" : "chevron.right")
                .foregroundColor(Theme.Colors.textDim)
                .font(.system(size: 14, weight: .semibold))
        }
        .frame(height: 44)
        .contentShape(Rectangle())
    }
    
    private var divider: some View {
        Divider()
            .background(Color.white.opacity(0.1))
            .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private func valueDisplay(text: String, icon: String, accentPrefix: Bool = false) -> some View {
        HStack(spacing: 8) {
            if accentPrefix {
                Circle()
                    .fill(themeManager.palette.accent)
                    .frame(width: 8, height: 8)
                    .shadow(color: themeManager.palette.accent.opacity(0.6), radius: 3)
            }
            
            Text(text)
                .font(Theme.Fonts.value)
                .foregroundColor(accentPrefix ? .white : themeManager.palette.accent)
            
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(Theme.Colors.textDim)
        }
        .frame(height: 38)
        .padding(.horizontal, 14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(Theme.Spacing.compact)
    }
    
    @ViewBuilder
    private func compactValueDisplay(_ text: String) -> some View {
        Text(text)
            .font(Theme.Fonts.value)
            .foregroundColor(themeManager.palette.accent)
            .frame(width: 44, height: 38)
            .background(Color.white.opacity(0.06))
            .cornerRadius(Theme.Spacing.compact)
    }
    
    // MARK: - Pro Header Card
    
    private var proHeaderCard: some View {
        Button {
            showPaywall = true
            HapticManager.shared.lightImpact()
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Vext")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                    
                    if storeManager.isPro {
                        HStack(spacing: 6) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.yellow)
                            Text("Pro")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(.yellow)
                        }
                    }
                }
                
                Spacer()
                
                if storeManager.isPro {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 34))
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
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(24)
                }
            }
            .padding(20)
            .cyberGlass(glowColor: storeManager.isPro ? .yellow : themeManager.palette.accent, cornerRadius: 24)
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
        .environmentObject(StoreManager())
}
