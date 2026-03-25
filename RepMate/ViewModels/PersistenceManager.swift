import Foundation

/// File system operational errors.
enum PersistenceError: Error {
    case fileNotFound
    case decodingFailed(Error)
    case encodingFailed(Error)
    case writingFailed(Error)
}

/// Thread-safe local file storage manager.
class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let fileManager = FileManager.default
    private let dispatchQueue = DispatchQueue(label: "com.repmate.persistence", qos: .background)
    
    private init() {}
    
    /// Resolves app documents directory.
    private func documentsDirectory() -> URL {
        do {
            return try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            return fileManager.temporaryDirectory
        }
    }
    
    /// Safely writes an object to disk with automatic backups.
    func save<T: Encodable>(_ object: T, to filename: String, completion: ((Result<Void, PersistenceError>) -> Void)? = nil) {
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }
            do {
                let url = self.documentsDirectory().appendingPathComponent(filename)
                let backupUrl = url.appendingPathExtension("bak")
                
                // 1. Create backup of current file if it exists
                if self.fileManager.fileExists(atPath: url.path) {
                    try? self.fileManager.removeItem(at: backupUrl) // Remove old backup
                    try? self.fileManager.copyItem(at: url, to: backupUrl)
                }
                
                // 2. Write new data atomically
                let data = try JSONEncoder().encode(object)
                try data.write(to: url, options: [.atomic])
                completion?(.success(()))
            } catch {
                completion?(.failure(.writingFailed(error)))
            }
        }
    }
    
    /// Loads a saved object from disk, falling back to backups if corrupted.
    func load<T: Decodable>(_ type: T.Type, from filename: String) throws -> T {
        let url = documentsDirectory().appendingPathComponent(filename)
        let backupUrl = url.appendingPathExtension("bak")
        
        // Helper to load from a specific URL
        func loadFrom(_ specificUrl: URL) throws -> T {
            let data = try Data(contentsOf: specificUrl)
            return try JSONDecoder().decode(T.self, from: data)
        }
        
        // 1. Try primary file
        if fileManager.fileExists(atPath: url.path) {
            do {
                return try loadFrom(url)
            } catch {
                
                // 2. Try backup file
                if fileManager.fileExists(atPath: backupUrl.path) {
                    do {
                        let backupData = try loadFrom(backupUrl)
                        return backupData
                    } catch {
                        throw PersistenceError.decodingFailed(error)
                    }
                } else {
                    throw PersistenceError.decodingFailed(error)
                }
            }
        } else {
            // No primary file, try backup just in case (e.g. accidental deletion)
            if fileManager.fileExists(atPath: backupUrl.path) {
                 return try loadFrom(backupUrl)
            }
            throw PersistenceError.fileNotFound
        }
    }
    
    /// Resolves absolute file URL.
    func fileURL(for filename: String) -> URL? {
        documentsDirectory().appendingPathComponent(filename)
    }
    
    /// Checks for file existence.
    func fileExists(_ filename: String) -> Bool {
        let url = documentsDirectory().appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path)
    }
}
