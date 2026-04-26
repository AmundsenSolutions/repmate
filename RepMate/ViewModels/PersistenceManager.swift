import Foundation

/// File system operational errors.
enum PersistenceError: Error {
    case fileNotFound
    case decodingFailed(Error)
    case encodingFailed(Error)
    case writingFailed(Error)
    case verificationFailed  // .tmp byte-count mismatch after write
}

final class PersistenceManager: @unchecked Sendable {
    static let shared = PersistenceManager()

    private let dispatchQueue = DispatchQueue(label: "com.repmate.persistence", qos: .background)

    private init() {}

    /// Resolves app documents directory.
    /// M5 Fix: Throws on failure instead of silently falling back to temporaryDirectory,
    /// which iOS can purge at any time. A caught error will put the app in degraded mode.
    private func documentsDirectory() throws -> URL {
        try FileManager.default.url(for: .documentDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
    }

    /// K2 Fix — Safe atomic write sequence:
    ///   1. Encode data in memory.
    ///   2. Write to a `.tmp` sidecar (atomic at OS level).
    ///   3. Verify `.tmp` byte-count matches in-memory data.
    ///   4. Only after verification: remove old `.bak`, move main → `.bak` (atomic rename).
    ///   5. Move `.tmp` → main (atomic rename).
    ///
    /// The `.bak` file is NEVER deleted until the new `.tmp` is verified on disk.
    /// If any step fails, at least one valid copy of the data survives.
    func save<T: Encodable>(_ object: T, to filename: String, completion: ((Result<Void, PersistenceError>) -> Void)? = nil) {
        dispatchQueue.async { [weak self] in
            guard let self = self else { return }

            let dir: URL
            do {
                dir = try self.documentsDirectory()
            } catch {
                completion?(.failure(.writingFailed(error)))
                return
            }

            let mainURL = dir.appendingPathComponent(filename)
            let tmpURL  = dir.appendingPathComponent(filename + ".tmp")
            let bakURL  = dir.appendingPathComponent(filename + ".bak")

            // Step 1: Encode
            let data: Data
            do {
                data = try JSONEncoder().encode(object)
            } catch {
                completion?(.failure(.encodingFailed(error)))
                return
            }

            // Step 2: Write to .tmp (.atomic = OS-level crash-safe write)
            do {
                try data.write(to: tmpURL, options: [.atomic, .completeFileProtectionUnlessOpen])
            } catch {
                completion?(.failure(.writingFailed(error)))
                return
            }

            // Step 3: Verify .tmp — confirm it is readable and byte-count matches
            guard let written = try? Data(contentsOf: tmpURL), written.count == data.count else {
                try? FileManager.default.removeItem(at: tmpURL)
                completion?(.failure(.verificationFailed))
                return
            }

            // Step 4: Rotate .bak — .tmp is verified, so old .bak is now superseded.
            // Remove old .bak first, then atomically move main → .bak.
            try? FileManager.default.removeItem(at: bakURL)
            if FileManager.default.fileExists(atPath: mainURL.path) {
                try? FileManager.default.moveItem(at: mainURL, to: bakURL)
            }

            // Step 5: Promote .tmp → main (atomic rename on same filesystem)
            do {
                try FileManager.default.moveItem(at: tmpURL, to: mainURL)
            } catch {
                // Unlikely: .tmp is verified but rename failed (e.g. permissions).
                // .bak still contains the previous save, so no data is lost.
                completion?(.failure(.writingFailed(error)))
                return
            }

            // Step 6: Apply hardware encryption to main file
            try? FileManager.default.setAttributes(
                [.protectionKey: FileProtectionType.completeUnlessOpen],
                ofItemAtPath: mainURL.path
            )

            completion?(.success(()))
        }
    }

    /// Resolves absolute file URL. Throws if the documents directory is unavailable.
    func fileURL(for filename: String) throws -> URL {
        try documentsDirectory().appendingPathComponent(filename)
    }

    /// Checks for file existence.
    func fileExists(_ filename: String) -> Bool {
        guard let url = try? fileURL(for: filename) else { return false }
        return FileManager.default.fileExists(atPath: url.path)
    }
}
