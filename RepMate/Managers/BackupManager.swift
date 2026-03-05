//
//  BackupManager.swift
//  RepMate
//
//  Created by Auto-Agent on 02/02/2026.
//

import Foundation

class BackupManager {
    static let shared = BackupManager()
    
    private let fileManager = FileManager.default
    private let backupDirectoryName = "Backups"
    private let maxBackups = 5
    private let minimumBackupInterval: TimeInterval = 300 // 5 minutes between backups
    
    private var lastBackupTime: Date?
    
    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private var backupDirectory: URL {
        if let ubiquityURL = fileManager.url(forUbiquityContainerIdentifier: nil) {
            // Safe to store in iCloud Drive's Documents folder so it syncs and is user-visible
            let icloudDocs = ubiquityURL.appendingPathComponent("Documents")
            return icloudDocs.appendingPathComponent(backupDirectoryName)
        } else {
            return documentsDirectory.appendingPathComponent(backupDirectoryName)
        }
    }
    
    private init() {}
    
    /// Creates a backup of the specified file URL.
    /// Throttled to only create one backup per 5 minutes.
    /// - Parameter sourceURL: The URL of the file to back up (e.g. repmate_data.json)
    func backup(sourceURL: URL) {
        // Throttle: Skip if we backed up less than 5 minutes ago
        if let lastBackup = lastBackupTime,
           Date().timeIntervalSince(lastBackup) < minimumBackupInterval {
            return
        }
        // Ensure backup directory exists
        if !fileManager.fileExists(atPath: backupDirectory.path) {
            do {
                try fileManager.createDirectory(at: backupDirectory, withIntermediateDirectories: true)
            } catch {
                print("BackupManager: Failed to create backup directory: \(error)")
                return
            }
        }
        
        // 1. Check if source file exists
        guard fileManager.fileExists(atPath: sourceURL.path) else {
            // Nothing to back up yet (fresh install)
            return
        }
        
        // 2. Generate Backup Filename: filename_yyyyMMdd_HHmmss.json
        let timestamp = ISO8601DateFormatter().string(from: Date())
            .replacingOccurrences(of: ":", with: "-") // Sanitize for filename
            .replacingOccurrences(of: ".", with: "-")
        
        let originalName = sourceURL.deletingPathExtension().lastPathComponent
        let extensionName = sourceURL.pathExtension
        let backupFilename = "\(originalName)_\(timestamp).\(extensionName)"
        let backupURL = backupDirectory.appendingPathComponent(backupFilename)
        
        // 3. Skip if backup file already exists (same-second collision)
        guard !fileManager.fileExists(atPath: backupURL.path) else {
            return
        }
        
        // 4. Copy File
        do {
            try fileManager.copyItem(at: sourceURL, to: backupURL)
            lastBackupTime = Date() // Update throttle timer on success
            print("BackupManager: Created backup at \(backupURL.path)")
        } catch {
            print("BackupManager: Failed to create backup: \(error)")
        }
        
        // 5. Prune Old Backups
        pruneBackups()
    }
    
    private func pruneBackups() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: backupDirectory, includingPropertiesForKeys: [.creationDateKey], options: .skipsHiddenFiles)
            
            // Sort by creation date (newest first)
            let sortedFiles = fileURLs.sorted { url1, url2 in
                let date1 = (try? url1.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                let date2 = (try? url2.resourceValues(forKeys: [.creationDateKey]))?.creationDate ?? Date.distantPast
                return date1 > date2
            }
            
            // Keep top N, delete the rest
            if sortedFiles.count > maxBackups {
                let filesToDelete = sortedFiles.suffix(from: maxBackups)
                for fileURL in filesToDelete {
                    try fileManager.removeItem(at: fileURL)
                    print("BackupManager: Pruned old backup \(fileURL.lastPathComponent)")
                }
            }
        } catch {
            print("BackupManager: Error pruning backups: \(error)")
        }
    }
}
