import SwiftUI

struct ProgressGalleryView: View {
    @EnvironmentObject var galleryStore: GalleryStore
    @EnvironmentObject var themeManager: ThemeManager
    
    @State private var selectedPhoto: ProgressPhoto? = nil
    @State private var showImagePicker = false
    @State private var activeSource: UIImagePickerController.SourceType = .photoLibrary
    @State private var photoToDelete: ProgressPhoto? = nil
    
    var body: some View {
        GlassSection(title: "Progress Pictures") {
            VStack(alignment: .leading, spacing: 16) {
                if galleryStore.photos.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 40))
                            .foregroundColor(.gray)
                        Text("No progress pictures yet.")
                            .font(.subheadline)
                            .foregroundColor(.gray)
                        Text("Add photos to track your physique changes over time.")
                            .font(.caption)
                            .foregroundColor(.gray)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                } else {
                    HStack {
                        Text("\(galleryStore.photos.count) photo\(galleryStore.photos.count == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundColor(.gray)
                        Spacer()
                        Text("Long press to delete")
                            .font(.caption2)
                            .foregroundColor(.gray.opacity(0.6))
                    }
                    .padding(.horizontal)
                    
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 16) {
                            ForEach(galleryStore.photos) { photo in
                                if let uiImage = galleryStore.loadImage(for: photo.filename) {
                                    Button {
                                        selectedPhoto = photo
                                    } label: {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(width: 120, height: 160)
                                            .clipShape(RoundedRectangle(cornerRadius: 12))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                            )
                                            .overlay(alignment: .bottom) {
                                                Text(photo.date.formatted(date: .abbreviated, time: .omitted))
                                                    .font(.caption2.bold())
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 4)
                                                    .background(Color.black.opacity(0.6))
                                                    .foregroundColor(.white)
                                                    .clipShape(Capsule())
                                                    .padding(.bottom, 6)
                                            }
                                    }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            photoToDelete = photo
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.horizontal, -16) // Bleed out of the section padding
                }
                
                HStack(spacing: 12) {
                    let cameraAvailable = UIImagePickerController.isSourceTypeAvailable(.camera)
                    
                    Button {
                        if cameraAvailable {
                            activeSource = .camera
                            showImagePicker = true
                        }
                    } label: {
                        Label("Camera", systemImage: "camera.fill")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(cameraAvailable ? themeManager.palette.accent.opacity(0.15) : Color.gray.opacity(0.1))
                            .foregroundColor(cameraAvailable ? themeManager.palette.accent : .gray)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(!cameraAvailable)
                    
                    Button {
                        activeSource = .photoLibrary
                        showImagePicker = true
                    } label: {
                        Label("Library", systemImage: "photo.on.rectangle")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(themeManager.palette.accent.opacity(0.15))
                            .foregroundColor(themeManager.palette.accent)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding()
        }
        .sheet(isPresented: $showImagePicker) {
            ImagePicker(image: Binding(get: { nil }, set: { image in
                if let newImage = image {
                    galleryStore.saveImage(newImage)
                }
            }), sourceType: activeSource)
        }
        .fullScreenCover(item: $selectedPhoto) { photo in
            FullScreenPhotoView(photo: photo)
                .environmentObject(galleryStore)
        }
        .alert("Delete Photo", isPresented: Binding(
            get: { photoToDelete != nil },
            set: { if !$0 { photoToDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { photoToDelete = nil }
            Button("Delete", role: .destructive) {
                if let photo = photoToDelete {
                    galleryStore.deletePhoto(photo)
                    photoToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this progress picture?")
        }
    }
}

struct FullScreenPhotoView: View {
    let photo: ProgressPhoto
    @Environment(\.dismiss) var dismiss
    @EnvironmentObject var galleryStore: GalleryStore
    @State private var showDeleteAlert = false
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let image = galleryStore.loadImage(for: photo.filename) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Could not load image")
                        .foregroundColor(.gray)
                }
            }
            
            VStack {
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Button {
                        showDeleteAlert = true
                    } label: {
                        Image(systemName: "trash")
                            .font(.title2)
                            .foregroundColor(.red)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                Text(photo.date.formatted(date: .long, time: .omitted))
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.black.opacity(0.6))
                    .clipShape(Capsule())
                    .padding(.bottom, 32)
            }
        }
        .alert("Delete Photo", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                galleryStore.deletePhoto(photo)
                dismiss()
            }
        } message: {
            Text("Are you sure you want to delete this progress picture?")
        }
    }
}

