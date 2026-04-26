import SwiftUI

struct AddProteinEntryView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var storeManager: StoreManager
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var showCamera = false
    @State private var showPaywall = false

    @State private var gramsText: String = ""
    @State private var note: String = ""
    @State private var showScanner = false
    @State private var isLookingUp = false
    @State private var scanError: String?
    @State private var isAIProcessing = false
    @State private var aiNoteError: String?
    @State private var showRateLimitAlert = false
    @State private var isRateLimitFreeError = false
    @State private var rateLimitAlertMessage = ""

    private let aiService = ProteinAIService()
    
    @State private var unknownBarcode: String?
    @State private var showRegisterSheet = false
    @State private var newProductName: String = ""
    @State private var newProductProtein: String = ""
    @State private var lookupTask: Task<Void, Never>?
    @State private var toastTask: Task<Void, Never>?
    
    @FocusState private var focusedField: Field?
    
    private enum Field {
        case grams, note
    }

    @State private var selectedFilter: FilterOption = .recents
    
    private enum FilterOption: String, CaseIterable, Identifiable {
        case recents = "Recents"
        case favorites = "Favorites"
        var id: String { rawValue }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background
                    .ignoresSafeArea()
                    .onTapGesture {
                        hideKeyboard()
                    }
                
                VStack(spacing: 0) {
                    // Manual Entry Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("MANUAL ENTRY")
                            .sectionHeader()
                            .padding(.horizontal)
                        
                        HStack(spacing: 10) {
                            BufferedInputView(
                                value: $gramsText,
                                placeholder: "Grams",
                                keyboardType: .numberPad,
                                color: .white,
                                alignment: .leading,
                                font: .body,
                                backgroundColor: Theme.Colors.cardBackground,
                                cornerRadius: Theme.Spacing.cornerRadius
                            )
                            .frame(width: 100)
                            .onChange(of: gramsText) { _, newValue in
                                // Cap manual entry to 10,000g to prevent absurd values
                                if let val = Int(newValue), val > 10000 {
                                    gramsText = "10000"
                                }
                            }
                            
                            // Note field + sparkle AI button side-by-side
                            ZStack(alignment: .trailing) {
                                BufferedInputView(
                                    value: $note,
                                    placeholder: "Note (optional)",
                                    keyboardType: .default,
                                    color: .white,
                                    alignment: .leading,
                                    font: .body,
                                    backgroundColor: Theme.Colors.cardBackground,
                                    cornerRadius: Theme.Spacing.cornerRadius
                                )
                                .padding(.trailing, note.trimmingCharacters(in: .whitespaces).isEmpty ? 0 : 48)
                                // Sparkle button — visible only when note has text
                                if !note.trimmingCharacters(in: .whitespaces).isEmpty {
                                    Button {
                                        processNotesWithAI()
                                        HapticManager.shared.lightImpact()
                                    } label: {
                                        Image(systemName: "sparkles")
                                            .font(.system(size: 16, weight: .semibold))
                                            .foregroundColor(themeManager.palette.accent)
                                            .frame(width: 36, height: 36)
                                            .background(themeManager.palette.accent.opacity(0.12))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                    .padding(.trailing, 6)
                                    .transition(.scale.combined(with: .opacity))
                                }
                            }
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: note.isEmpty)

                            // AI Camera Button
                            Button {
                                showCamera = true
                                HapticManager.shared.lightImpact()
                            } label: {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(themeManager.palette.accent)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.Colors.cardBackground)
                                    .cornerRadius(Theme.Spacing.cornerRadius)
                            }

                            // Barcode Scan Button
                            Button {
                                showScanner = true
                            } label: {
                                Image(systemName: "barcode.viewfinder")
                                    .font(.system(size: 20))
                                    .foregroundColor(themeManager.palette.accent)
                                    .frame(width: 44, height: 44)
                                    .background(Theme.Colors.cardBackground)
                                    .cornerRadius(Theme.Spacing.cornerRadius)
                            }
                        }
                        .padding(.horizontal)
                        
                        // Main Log Button (Moved from bottom)
                        // Always visible, disabled state indicated by color
                        Button(action: save) {
                            Text("Log entry")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundColor(isValidManualEntry ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isValidManualEntry ? Theme.Colors.accent : Theme.Colors.cardBackground)
                                .cornerRadius(Theme.Spacing.cornerRadius)
                                .contentShape(Rectangle())
                        }
                        .disabled(!isValidManualEntry)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                    
                    // Filter Chips
                    HStack(spacing: 12) {
                        ForEach(FilterOption.allCases) { option in
                            Button {
                                selectedFilter = option
                                HapticManager.shared.selection()
                            } label: {
                                Text(option.rawValue)
                                    .font(.system(size: 14, weight: .semibold))
                                    .pillButton(
                                        backgroundColor: selectedFilter == option ? Theme.Colors.accent : Theme.Colors.cardBackground,
                                        foregroundColor: selectedFilter == option ? .black : .white
                                    )
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 16)
                    
                    // Vertical List
                    List {
                        if filteredEntries.isEmpty {
                            Text("No \(selectedFilter.rawValue.lowercased()) found")
                                .foregroundColor(.secondary)
                                .padding(.top, 40)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(filteredEntries) { entry in
                                let isFavorite = store.isFavorite(entry: entry)
                                HStack {
                                    // Star indicator for favorites (matching HomeView)
                                    if isFavorite {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Theme.active.accent)
                                    }
                                    
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(entry.note ?? "Protein")
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundColor(Theme.Colors.textPrimary)
                                        
                                        Text("\(entry.grams)g")
                                            .font(.system(size: 13))
                                            .foregroundColor(isFavorite ? Theme.active.accent : Theme.Colors.textSecondary)
                                    }
                                    
                                    Spacer()
                                    
                                    OledPlusButton(action: {
                                        quickAdd(grams: entry.grams, note: entry.note)
                                    })
                                }
                                .padding(.leading, 16)
                                .padding(.trailing, 8) 
                                .padding(.vertical, 8)
                                .background(Theme.Colors.cardBackground)
                                .cornerRadius(Theme.Spacing.cornerRadius)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                         if selectedFilter == .favorites {
                                             if let index = store.favoriteProteinItems.firstIndex(where: { $0.grams == entry.grams && $0.note == entry.note }) {
                                                 store.favoriteProteinItems.remove(at: index)
                                             }
                                         }
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                    .tint(.red)
                                }
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        let temp = ProteinEntry(grams: entry.grams, note: entry.note)
                                        store.toggleFavorite(entry: temp)
                                        HapticManager.shared.success()
                                    } label: {
                                        Label("Favorite", systemImage: "star.fill")
                                    }
                                    .tint(.yellow) // Always yellow for favorites
                                }
                            }
                        }
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .scrollDismissesKeyboard(.interactively)
                    .toolbar {
                        ToolbarItemGroup(placement: .keyboard) {
                            Spacer()
                            Button("Done") {
                                hideKeyboard()
                            }
                            .fontWeight(.semibold)
                        }
                    }
                    // Removed padding(.bottom, 100) to allow list to maximize height
                }
                .ignoresSafeArea(.keyboard, edges: .bottom) 
            }
            .navigationTitle("Log Protein")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
        .presentationBackground {
             Theme.Colors.background.opacity(0.98) 
        }
        .onDisappear {
            lookupTask?.cancel()
        }
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView { barcode in
                handleBarcodeScan(barcode)
            }
            .environmentObject(themeManager)
        }
        .overlay {
            if isLookingUp || isAIProcessing {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(themeManager.palette.accent)
                            .scaleEffect(1.3)
                        Text(isAIProcessing ? "Beregner protein..." : "Looking up product...")
                            .font(.caption)
                            .foregroundColor(.white)
                    }
                    .padding(24)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }
            }
        }
        .overlay(alignment: .bottom) {
            // Unified toast: scan errors + AI note errors
            let toastMessage = scanError ?? aiNoteError
            if let message = toastMessage {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(Capsule())
                .padding(.bottom, 40)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .onAppear {
                    toastTask?.cancel()
                    toastTask = Task {
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            withAnimation {
                                scanError = nil
                                aiNoteError = nil
                            }
                        }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: scanError)
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: aiNoteError)
        .sheet(isPresented: $showRegisterSheet) {
            registerNewProductSheet
        }
        .sheet(isPresented: $showCamera) {
            CameraView()
                .environmentObject(store)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environmentObject(storeManager)
        }
        .alert(isRateLimitFreeError ? "Daily Limit Reached" : "Limit Reached", isPresented: $showRateLimitAlert) {
            if isRateLimitFreeError {
                Button("Upgrade to Pro") { showPaywall = true }
            }
            Button(isRateLimitFreeError ? "Cancel" : "OK", role: .cancel) {}
        } message: {
            Text(rateLimitAlertMessage)
        }
    }
    
    // MARK: - Subviews
    
    private var registerNewProductSheet: some View {
        NavigationStack {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()
                
                VStack(spacing: 24) {
                    Text("Unknown Barcode")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(Theme.Colors.textPrimary)
                        .padding(.top, 20)
                    
                    Text("Product not found. Enter the details below to save it for next time.")
                        .font(.subheadline)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    VStack(spacing: 16) {
                        BufferedInputView(
                            value: $newProductName,
                            placeholder: "Product Name (e.g. YT 330ml)",
                            keyboardType: .default,
                            color: .white,
                            alignment: .leading,
                            font: .body,
                            backgroundColor: Theme.Colors.cardBackground,
                            cornerRadius: Theme.Spacing.cornerRadius
                        )
                        
                        BufferedInputView(
                            value: $newProductProtein,
                            placeholder: "Protein per serving (Grams)",
                            keyboardType: .numberPad,
                            color: .white,
                            alignment: .leading,
                            font: .body,
                            backgroundColor: Theme.Colors.cardBackground,
                            cornerRadius: Theme.Spacing.cornerRadius
                        )
                    }
                    .padding(.horizontal)
                    
                    Spacer()
                    
                    Button {
                        saveNewBarcodeProduct()
                    } label: {
                        Text("Save & Log Protein")
                            .font(.headline)
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Theme.Colors.accent)
                            .cornerRadius(16)
                            .shadow(color: Theme.Colors.accent.opacity(0.4), radius: 8, x: 0, y: 4)
                            .contentShape(Rectangle())
                    }
                    .padding(.horizontal)
                    .disabled(newProductName.trimmingCharacters(in: .whitespaces).isEmpty || newProductProtein.isEmpty)
                    .opacity((newProductName.trimmingCharacters(in: .whitespaces).isEmpty || newProductProtein.isEmpty) ? 0.5 : 1.0)
                    .padding(.bottom, 32)
                }
            }
            .navigationBarHidden(true)
            .overlay(alignment: .topTrailing) {
                Button {
                    showRegisterSheet = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(Theme.Colors.textSecondary)
                        .padding()
                }
            }
        }
        .presentationDetents([.fraction(0.55)])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Helpers
    
    private var isValidManualEntry: Bool {
        return !gramsText.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    // Determine what to show based on filter
    private var filteredEntries: [ProteinEntry] {
        switch selectedFilter {
        case .recents:
            return store.getRecentUniqueEntries() 
        case .favorites:
            return store.favoriteProteinItems.map { ProteinEntry(id: $0.id, grams: $0.grams, note: $0.note) }
        }
    }
    
    // Helper to find exact entry if needed (optional)
    private func findEntry(grams: Int, note: String?) -> ProteinEntry? {
        // Just purely structural matching for fav toggle
        return nil 
    }
    
    private func quickAdd(grams: Int, note: String?) {
        HapticManager.shared.impact()
        store.addProteinEntry(grams: grams, note: note)
        dismiss()
    }

    private func save() {
        guard let grams = Int(gramsText), grams > 0 else { return }
        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalNote = trimmedNote.isEmpty ? nil : trimmedNote

        HapticManager.shared.success()
        store.addProteinEntry(grams: grams, note: finalNote)
        dismiss()
    }

    // MARK: - AI Notes Processing
    private func processNotesWithAI() {
        let trimmed = note.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        isAIProcessing = true
        aiNoteError = nil
        // NOTE: Do NOT dismiss keyboard here.
        // We dismiss it atomically with the result below so the view
        // only re-layouts once — preventing the scroll jump.

        Task {
            do {
                let response = try await aiService.analyzeInput(text: trimmed, isPro: storeManager.isPro)
                await MainActor.run {
                    // Dismiss keyboard and apply result in the same frame.
                    focusedField = nil
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.85)) {
                        isAIProcessing = false
                        if response.protein_grams == -1 {
                            // Lambda sentinel: gibberish/not food
                            aiNoteError = "I couldn't understand that. Try writing something like '2 eggs'."
                            HapticManager.shared.error()
                        } else {
                            // >= 0 is valid (0g is real food like water/black coffee)
                            gramsText = "\(response.protein_grams)"
                            HapticManager.shared.success()
                        }
                    }
                }
            } catch ProteinAIService.AIError.rateLimitReached(let isPro) {
                await MainActor.run {
                    focusedField = nil
                    isAIProcessing = false
                    isRateLimitFreeError = !isPro
                    rateLimitAlertMessage = isPro ? "You've reached your 50 daily Pro sessions. Take some rest and come back tomorrow!" 
                                                  : "You've used your 5 free AI sessions for today. Upgrade to RepMate Pro for 50 daily sessions!"
                    showRateLimitAlert = true
                    HapticManager.shared.error()
                }
            } catch ProteinAIService.AIError.serverError(_, let message) {
                await MainActor.run {
                    focusedField = nil
                    withAnimation {
                        isAIProcessing = false
                        aiNoteError = message
                    }
                    HapticManager.shared.error()
                }
            } catch {
                await MainActor.run {
                    focusedField = nil
                    withAnimation {
                        isAIProcessing = false
                        aiNoteError = "Could not calculate protein, please be more specific"
                    }
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func handleBarcodeScan(_ barcode: String) {
        // 1. Check Custom Local Barcodes First
        if let customEntry = store.customBarcodes[barcode] {
            HapticManager.shared.success()
            gramsText = "\(customEntry.proteinGrams)"
            note = customEntry.name
            return
        }
        
        // 2. Fallback to OpenFoodFacts API
        isLookingUp = true
        scanError = nil
        
        lookupTask?.cancel()
        lookupTask = Task {
            do {
                if let product = try await OpenFoodFactsService.fetchProduct(barcode: barcode) {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        // Prefer per-serving protein if available, otherwise use per-100g
                        let protein: Int
                        if let perServing = product.proteinPerServing, perServing > 0 {
                            protein = Int(perServing.rounded())
                        } else {
                            protein = Int(product.proteinPer100g.rounded())
                        }
                        
                        gramsText = "\(protein)"
                        note = product.name
                        isLookingUp = false
                    }
                } else {
                    if Task.isCancelled { return }
                    await MainActor.run {
                        isLookingUp = false
                        unknownBarcode = barcode
                        newProductName = ""
                        newProductProtein = ""
                        HapticManager.shared.lightImpact()
                        showRegisterSheet = true
                    }
                }
            } catch {
                if Task.isCancelled { return }
                await MainActor.run {
                    isLookingUp = false
                    scanError = "Network error: Could not lookup product."
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func saveNewBarcodeProduct() {
        guard let barcode = unknownBarcode,
              let protein = Int(newProductProtein), protein > 0 else { return }
        
        let trimmedName = newProductName.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty else { return }
        
        // Save to local custom mapping
        store.customBarcodes[barcode] = CustomBarcodeEntry(name: trimmedName, proteinGrams: protein)
        
        // Log it immediately for today
        store.addProteinEntry(grams: protein, note: trimmedName)
        
        HapticManager.shared.success()
        showRegisterSheet = false
        dismiss()
    }
}

#Preview {
    AddProteinEntryView()
        .environmentObject(AppDataStore())
        .environmentObject(ThemeManager.shared)
        .environmentObject(StoreManager())
}
