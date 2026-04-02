import SwiftUI
import UIKit

enum ImageSourceType: Identifiable {
    case camera, library
    var id: Self { self }
}

struct CameraView: View {
    @EnvironmentObject var store: AppDataStore
    @Environment(\.dismiss) var dismiss
    @State private var image: UIImage?
    @State private var activeSource: ImageSourceType? = nil
    @State private var isLoading = false
    @State private var loadingPhraseIndex = 0
    @State private var phraseTask: Task<Void, Never>? = nil

    private let loadingPhrases = [
        "Preparing image...",
        "Optimizing quality...",
        "Analyzing food...",
        "Calculating macros...",
        "Almost done..."
    ]
    @State private var aiResponse: ProteinResponse?
    @State private var error: String?
    
    private let aiService = ProteinAIService()
    
    var body: some View {
        NavigationView {
            ZStack {
                Theme.Colors.background.ignoresSafeArea()

                
                VStack(spacing: 24) {
                    if let image = image {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                            .frame(height: 250)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color.white.opacity(0.1), lineWidth: 1))
                            .padding(.horizontal)
                    } else {
                        VStack(spacing: 16) {
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 60))
                                .foregroundColor(Theme.Colors.textDim)
                            Text("Take a photo of your food\nto analyze protein content")
                                .multilineTextAlignment(.center)
                                .foregroundColor(Theme.Colors.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 250)
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                    
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(Theme.Colors.accent)
                            Text(loadingPhrases[loadingPhraseIndex])
                                .font(.caption)
                                .foregroundColor(Theme.Colors.textDim)
                                .transition(.opacity)
                                .id(loadingPhraseIndex)
                        }
                    } else if let response = aiResponse {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text(response.food_item)
                                    .font(.title3.bold())
                                    .foregroundColor(.white)
                                Spacer()
                                Text("\(response.protein_grams)g Protein")
                                    .font(.headline)
                                    .foregroundColor(Theme.Colors.accent)
                            }
                            
                            Text(response.description)
                                .font(.subheadline)
                                .foregroundColor(Theme.Colors.textSecondary)
                            
                            Button {
                                saveEntry(response)
                            } label: {
                                Text("Log to Today")
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Theme.Colors.accent)
                                    .foregroundColor(.black)
                                    .font(.headline)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                            }
                            .padding(.top, 8)
                        }
                        .padding()
                        .background(Theme.Colors.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal)
                    }
                    
                    if let error = error {
                        VStack(spacing: 12) {
                            Text(error)
                                .font(.caption)
                                .foregroundColor(.red)
                            
                            Button {
                                analyzeImage()
                            } label: {
                                Label("Try Again", systemImage: "arrow.clockwise")
                                    .font(.subheadline.bold())
                                    .foregroundColor(Theme.Colors.accent)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 16)
                                    .background(Theme.Colors.accent.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
                        
                        Button {
                            if cameraAvailable {
                                activeSource = .camera
                            }
                        } label: {
                            Label("Take Photo", systemImage: "camera.fill")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(cameraAvailable ? Color.white.opacity(0.1) : Color.gray.opacity(0.1))
                                .foregroundColor(cameraAvailable ? .white : .gray)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .disabled(!cameraAvailable)
                        
                        Button {
                            activeSource = .library
                        } label: {
                            Label("Gallery", systemImage: "photo.on.rectangle")
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.white.opacity(0.1))
                                .foregroundColor(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
            .onAppear { aiService.warmUpConnection() }
            .navigationTitle("AI Food Analysis")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        phraseTask?.cancel()
                        phraseTask = nil
                        dismiss()
                    }
                }
            }
            .onDisappear {
                phraseTask?.cancel()
                phraseTask = nil
            }
            .sheet(item: $activeSource) { source in
                ImagePicker(
                    image: $image,
                    sourceType: source == .camera ? .camera : .photoLibrary
                )
            }
            .onChange(of: image) { oldImage, newImage in
                if newImage != nil { analyzeImage() }
            }
        }
        .preferredColorScheme(.dark)
    }
    
    private func analyzeImage() {
        guard let image = image else { return }
        isLoading = true
        loadingPhraseIndex = 0
        error = nil
        aiResponse = nil

        // Cancel any previous phrase-rotation task before starting a new one
        phraseTask?.cancel()
        phraseTask = Task {
            while isLoading && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_200_000_000)
                guard isLoading && !Task.isCancelled else { break }
                withAnimation(.easeInOut(duration: 0.4)) {
                    loadingPhraseIndex = (loadingPhraseIndex + 1) % loadingPhrases.count
                }
            }
        }
        
        Task {
            do {
                let response = try await aiService.analyzeImage(image)
                await MainActor.run {
                    self.isLoading = false
                    self.phraseTask?.cancel()
                    self.phraseTask = nil
                    if response.protein_grams == -1 {
                        // Lambda sentinel: image does not contain food
                        self.error = "No food detected in the image — try another photo"
                        HapticManager.shared.error()
                    } else {
                        self.aiResponse = response
                        HapticManager.shared.success()
                    }
                }
            } catch ProteinAIService.AIError.serverError(_, let message) {
                await MainActor.run {
                    self.error = message
                    self.isLoading = false
                    self.phraseTask?.cancel()
                    self.phraseTask = nil
                    HapticManager.shared.error()
                }
            } catch {
                await MainActor.run {
                    self.error = "Analysis failed. Please try again."
                    self.isLoading = false
                    self.phraseTask?.cancel()
                    self.phraseTask = nil
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func saveEntry(_ response: ProteinResponse) {
        store.addProteinEntry(grams: response.protein_grams, note: response.food_item)
        HapticManager.shared.success()
        dismiss()
    }
}