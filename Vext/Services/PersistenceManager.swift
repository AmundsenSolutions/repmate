//
//  PersistenceManager.swift
//  Vext
//
//  Created by Aleksander Amundsen on 2026.
//

import Foundation

/// Errors that can occur during persistence operations.
enum PersistenceError: Error {
    case fileNotFound
    case decodingFailed(Error)
    case encodingFailed(Error)
    case writingFailed(Error)
}

/// A generic, thread-safe manager for saving and loading `Codable` objects to disk.
class PersistenceManager {
    static let shared = PersistenceManager()
    
    private let fileManager = FileManager.default
    private let dispatchQueue = DispatchQueue(label: "com.vext.persistence", qos: .background)
    
    private init() {}
    
    /// Returns the URL for the documents directory.
    private func documentsDirectory() -> URL {
        do {
            return try fileManager.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        } catch {
            print("CRITICAL: Falling back to temporary directory due to: \(error)")
            return fileManager.temporaryDirectory
        }
    }
    
    /// Saves a `Codable` object to a file in the documents directory with a backup rotation.
    /// - Parameters:
    ///   - object: The object to save.
    ///   - filename: The name of the file (e.g., "data.json").
    ///   - completion: Optional completion handler returning logic result (success/failure).
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
    
    /// Loads a `Codable` object from a file, with fallback to backup if corruption occurs.
    /// - Parameters:
    ///   - type: The type of object to decode.
    ///   - filename: The name of the file.
    /// - Returns: The decoded object, or throws an error.
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
                print("⚠️ Primary data file corrupted: \(error). Attempting backup restore...")
                
                // 2. Try backup file
                if fileManager.fileExists(atPath: backupUrl.path) {
                    do {
                        let backupData = try loadFrom(backupUrl)
                        print("✅ Backup restored successfully.")
                        return backupData
                    } catch {
                        print("❌ Backup also corrupted or unreadable: \(error)")
                        throw PersistenceError.decodingFailed(error)
                    }
                } else {
                    print("❌ No backup file found.")
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
    
    /// Returns the full URL for a file in the documents directory.
    func fileURL(for filename: String) -> URL? {
        documentsDirectory().appendingPathComponent(filename)
    }
    
    /// Checks if a file exists.
    func fileExists(_ filename: String) -> Bool {
        let url = documentsDirectory().appendingPathComponent(filename)
        return fileManager.fileExists(atPath: url.path)
    }
}
