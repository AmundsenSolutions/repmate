//
//  AddProteinEntryView.swift
//  Vext
//
//  Created by Aleksander Amundsen on 11/12/2025.
//


import SwiftUI

struct AddProteinEntryView: View {
    @EnvironmentObject var store: AppDataStore
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @State private var gramsText: String = ""
    @State private var note: String = ""
    @State private var showScanner = false
    @State private var isLookingUp = false
    @State private var scanError: String?
    
    // New Barcode Registration State
    @State private var unknownBarcode: String?
    @State private var showRegisterSheet = false
    @State private var newProductName: String = ""
    @State private var newProductProtein: String = ""
    
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
                                .font(.system(size: 16, weight: .bold)) // Bold for primary action
                                .foregroundColor(isValidManualEntry ? .black : .gray)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(isValidManualEntry ? Theme.Colors.accent : Theme.Colors.cardBackground)
                                .cornerRadius(Theme.Spacing.cornerRadius)
                        }
                        .disabled(!isValidManualEntry)
                        .padding(.horizontal)
                        .padding(.top, 12)
                    }
                    .padding(.top, 20)
                    .padding(.bottom, 24)
                    
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
        .fullScreenCover(isPresented: $showScanner) {
            BarcodeScannerView { barcode in
                handleBarcodeScan(barcode)
            }
            .environmentObject(themeManager)
        }
        .overlay {
            if isLookingUp {
                ZStack {
                    Color.black.opacity(0.4).ignoresSafeArea()
                    VStack(spacing: 12) {
                        ProgressView()
                            .tint(themeManager.palette.accent)
                            .scaleEffect(1.3)
                        Text("Looking up product...")
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
            if let error = scanError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text(error)
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        withAnimation { scanError = nil }
                    }
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.85), value: scanError)
        .sheet(isPresented: $showRegisterSheet) {
            registerNewProductSheet
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
        
        Task {
            if let product = await OpenFoodFactsService.fetchProduct(barcode: barcode) {
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
                await MainActor.run {
                    isLookingUp = false
                    unknownBarcode = barcode
                    newProductName = ""
                    newProductProtein = ""
                    HapticManager.shared.lightImpact()
                    showRegisterSheet = true
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
}
