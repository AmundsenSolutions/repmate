import Foundation

final class BackupManager: @unchecked Sendable {
    static let shared = BackupManager()

    private let backupDirectoryName = "Backups"
    private let maxBackups = 5
    private let minimumBackupInterval: TimeInterval = 300 // 5 minutes between backups

    // MARK: - K3 Fix: Serial queue ensures all file ops are thread-safe.
    // Called from both MainActor (init) and DispatchQueue.global (save), so
    // without this queue, lastBackupTime reads/writes and FileManager calls raced.
    private let queue = DispatchQueue(label: "com.repmate.backup", qos: .utility)
    private var lastBackupTime: Date?

    private var documentsDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var backupDirectory: URL {
        if let ubiquityURL = FileManager.default.url(forUbiquityContainerIdentifier: nil) {
            let icloudDocs = ubiquityURL.appendingPathComponent("Documents")
            return icloudDocs.appendingPathComponent(backupDirectoryName)
        } else {
            return documentsDirectory.appendingPathComponent(backupDirectoryName)
        }
    }

    private init() {}

    /// Copies the local database to a backup, max once per 5 minutes.
    /// Thread-safe: dispatches to the serial queue.
    func backup(sourceURL: URL) {
        queue.async { [weak self] in
            self?.performBackup(sourceURL: sourceURL)
        }
    }

    /// Restores a backup. Blocks the current thread (should be called on a background queue).
    func restore(from backupURL: URL, to targetURL: URL) -> Bool {
        queue.sync {
            do {
                if FileManager.default.fileExists(atPath: targetURL.path) {
                    try FileManager.default.removeItem(at: targetURL)
                }
                try FileManager.default.copyItem(at: backupURL, to: targetURL)
                return true
            } catch {
                print("BackupManager: Failed to restore backup: \(error)")
                return false
            }
        }
    }

    private func performBackup(sourceURL: URL) {
        // Throttle: skip if we backed up less than 5 minutes ago
        if let lastBackup = lastBackupTime,
           Date().timeIntervalSince(lastBackup) < minimumBackupInterval {
            return
        }

        // Ensure backup directory exists
        if !FileManager.default.fileExists(atPath: backupDirectory.path) {
            do {
                try FileManager.default.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            } catch {
                print("BackupManager: Failed to create backup directory: \(error)")
                return
            }
        }

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            return // Nothing to back up yet (fresh install)
        }

        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: ".", with: "-")

        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let extensionName = sourceURL.pathExtension
        let backupFilename = "\(originalName)_\(timestamp).\(extensionName)"
        let backupURL = backupDirectory.appendingPathComponent(backupFilename)

        guard !FileManager.default.fileExists(atPath: backupURL.path) else {
            return // Same-second collision — skip
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: backupURL)
            lastBackupTime = Date()
            print("BackupManager: Backup created — \(backupFilename)")
        } catch {
            print("BackupManager: Failed to copy backup: \(error)")
        }

        performPrune()
    }

    private func performPrune() {
        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            let sortedFiles = fileURLs.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }

            if sortedFiles.count > maxBackups {
                for fileURL in sortedFiles.suffix(from: maxBackups) {
                    do {
                        try FileManager.default.removeItem(at: fileURL)
                    } catch {
                        print("BackupManager: Failed to prune \(fileURL.lastPathComponent): \(error)")
                    }
                }
            }
        } catch {
            print("BackupManager: Failed to enumerate backups for pruning: \(error)")
        }
    }

    /// Returns the URL of the newest valid backup for the given source filename,
    /// or nil if no backups exist. Thread-safe via queue.sync.
    func latestBackupURL(for sourceFilename: String) -> URL? {
        queue.sync { [weak self] in
            self?.performLatestBackupURL(for: sourceFilename)
        }
    }

    /// Lists available backups for a given filename prefix.
    func listBackups(for baseName: String) -> [URL] {
        queue.sync { [weak self] in
            guard let self = self, FileManager.default.fileExists(atPath: self.backupDirectory.path) else { return [] }
            do {
                let fileURLs = try FileManager.default.contentsOfDirectory(
                    at: self.backupDirectory,
                    includingPropertiesForKeys: [.creationDateKey],
                    options: .skipsHiddenFiles
                )
                return fileURLs.filter { $0.lastPathComponent.hasPrefix(baseName + "_") }
                    .sorted { url1, url2 in
                        let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                        let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                        return date1 > date2
                    }
            } catch {
                return []
            }
        }
    }

    private func performLatestBackupURL(for sourceFilename: String) -> URL? {
        let baseName = (sourceFilename as NSString).deletingPathExtension

        guard FileManager.default.fileExists(atPath: backupDirectory.path) else { return nil }

        do {
            let fileURLs = try FileManager.default.contentsOfDirectory(
                at: backupDirectory,
                includingPropertiesForKeys: [.creationDateKey],
                options: .skipsHiddenFiles
            )

            let matchingFiles = fileURLs.filter { $0.lastPathComponent.hasPrefix(baseName + "_") }

            let sorted = matchingFiles.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }

            for candidate in sorted {
                if let data = try? Data(contentsOf: candidate), !data.isEmpty {
                    return candidate
                }
            }
        } catch {
            print("BackupManager: Failed to enumerate backups: \(error)")
        }
        return nil
    }
}
