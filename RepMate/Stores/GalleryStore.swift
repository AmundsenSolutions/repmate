import SwiftUI
import Combine

@MainActor
final class GalleryStore: ObservableObject {
    @Published var photos: [ProgressPhoto] = []
    
    private let fileName = "repmate_gallery.json"
    
    init() {
        Task {
            await loadAsync()
        }
    }
    
    // MARK: - File I/O for Images
    
    /// Documents directory URL
    private var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }
    
    /// Saves a UIImage to disk and records it in the gallery.
    func saveImage(_ image: UIImage, date: Date = Date()) {
        // Compress JPEG to save space
        guard let data = image.jpegData(compressionQuality: 0.8),
              let docDir = documentsDirectory else { return }
        
        let filename = UUID().uuidString + ".jpg"
        let fileURL = docDir.appendingPathComponent(filename)
        
        do {
            try data.write(to: fileURL)
            let photo = ProgressPhoto(date: date, filename: filename)
            photos.append(photo)
            // Sort newest first
            photos.sort(by: { $0.date > $1.date })
            save()
            HapticManager.shared.success()
        } catch {
            print("[GalleryStore] Error saving image: \(error)")
            HapticManager.shared.error()
        }
    }
    
    /// Loads a UIImage from disk using its filename.
    func loadImage(for filename: String) -> UIImage? {
        guard let docDir = documentsDirectory else { return nil }
        let fileURL = docDir.appendingPathComponent(filename)
        
        if let data = try? Data(contentsOf: fileURL) {
            return UIImage(data: data)
        }
        return nil
    }
    
    /// Deletes a photo from disk and removes its metadata.
    func deletePhoto(_ photo: ProgressPhoto) {
        photos.removeAll { $0.id == photo.id }
        
        if let docDir = documentsDirectory {
            let fileURL = docDir.appendingPathComponent(photo.filename)
            try? FileManager.default.removeItem(at: fileURL)
        }
        
        save()
    }
    
    // MARK: - Persistence for Metadata
    
    private func loadAsync() async {
        let data: Data? = await Task.detached(priority: .userInitiated) { [fileName] in
            guard let url = try? await PersistenceManager.shared.fileURL(for: fileName),
                  FileManager.default.fileExists(atPath: url.path) else { return nil }
            return try? Data(contentsOf: url)
        }.value
        
        if let data {
            do {
                let decoded = try JSONDecoder().decode([ProgressPhoto].self, from: data)
                self.photos = decoded.sorted { $0.date > $1.date }
            } catch {
                print("[GalleryStore] Decoding error: \(error)")
                self.photos = []
            }
        }
    }
    
    private func save() {
        let snapshot = photos
        PersistenceManager.shared.save(snapshot, to: fileName) { result in
            if case .failure(let error) = result {
                print("[GalleryStore] Save failed: \(error)")
            }
        }
    }
}
