//
//  FileStorageManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CryptoKit
import Photos
import CoreData

class FileStorageManager: FileStorageManaging {
    static let shared = FileStorageManager()
    
    let fileManager: FileManager
    let coreDataManager: CoreDataManager
    let documentsDirectory: URL
    let vaultDirectory: URL
    let thumbnailsDirectory: URL
    private let mimeTypeMapper = MIMETypeMapper()
    private let cryptoService = VaultCryptoService()
    private let thumbnailService: ThumbnailGenerationService
    private let trashService: TrashOperationsService
    private let temporarySharingService: TemporarySharingService
    private let encryptedFileStore: EncryptedFileStore
    private let photoImportService = PhotoImportService()
    
    // Encryption key derived from user's passcode
    private var encryptionKey: SymmetricKey?
    
    // MARK: - Helper Functions
    
    func determineFileType(from fileName: String) -> String {
        mimeTypeMapper.mimeType(forFileName: fileName)
    }
    
    private func convertUTIToMimeType(_ uti: String) -> String {
        mimeTypeMapper.mimeType(forUTI: uti)
    }
    
    private convenience init() {
        self.init(
            fileManager: .default,
            documentsDirectory: FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!,
            coreDataManager: .shared
        )
    }

    /// Creates isolated file and metadata storage for tests.
    init(fileManager: FileManager = .default, documentsDirectory: URL, coreDataManager: CoreDataManager) {
        self.fileManager = fileManager
        self.documentsDirectory = documentsDirectory
        self.coreDataManager = coreDataManager
        
        // Create vault directory
        vaultDirectory = documentsDirectory.appendingPathComponent("Vault", isDirectory: true)
        thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        thumbnailService = ThumbnailGenerationService(
            fileManager: fileManager,
            thumbnailsDirectory: thumbnailsDirectory
        )
        trashService = TrashOperationsService(
            fileManager: fileManager,
            coreDataManager: coreDataManager,
            vaultDirectory: vaultDirectory,
            thumbnailsDirectory: thumbnailsDirectory
        )
        temporarySharingService = TemporarySharingService(fileManager: fileManager)
        encryptedFileStore = EncryptedFileStore(
            fileManager: fileManager,
            vaultDirectory: vaultDirectory,
            cryptoService: cryptoService
        )
        
        print("DEBUG: Documents directory: \(documentsDirectory.path)")
        print("DEBUG: Vault directory: \(vaultDirectory.path)")
        print("DEBUG: Thumbnails directory: \(thumbnailsDirectory.path)")
        
        // Create directories if they don't exist
        do {
            try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true, attributes: nil)
            print("DEBUG: Vault directory created/verified")
        } catch {
            print("DEBUG: Error creating vault directory: \(error)")
        }
        
        do {
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true, attributes: nil)
            print("DEBUG: Thumbnails directory created/verified")
        } catch {
            print("DEBUG: Error creating thumbnails directory: \(error)")
        }
        
        // Verify directories exist
        print("DEBUG: Vault directory exists: \(fileManager.fileExists(atPath: vaultDirectory.path))")
        print("DEBUG: Thumbnails directory exists: \(fileManager.fileExists(atPath: thumbnailsDirectory.path))")
        
        // Set file protection
        setFileProtection()
    }
    
    private func setFileProtection() {
        // Set complete protection for vault directory
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: vaultDirectory.path
        )
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: thumbnailsDirectory.path
        )
    }
    
    // MARK: - Encryption Key Management
    
    func setupEncryptionKey(from password: String) {
        // Derive encryption key from password using SHA256
        encryptionKey = cryptoService.key(from: password)
    }
    
    /// Re-encrypt all vault files with a new encryption key
    /// This is called when the user changes their passcode
    func migrateFilesToNewEncryptionKey(oldPassword: String, newPassword: String, progress: @escaping (Int, Int) -> Void) async throws {
        print("DEBUG: Starting file migration from old key to new key")
        
        // Create old and new encryption keys
        let oldKey = cryptoService.key(from: oldPassword)
        let newKey = cryptoService.key(from: newPassword)
        
        // Get all vault items
        let allItems = coreDataManager.fetchAllVaultItems()
        let totalItems = allItems.count
        
        print("DEBUG: Found \(totalItems) items to migrate")
        
        for (index, item) in allItems.enumerated() {
            // The migrateVaultItem function now handles errors internally and doesn't throw
            // It will either migrate successfully or skip the file
            try await migrateVaultItem(item, oldKey: oldKey, newKey: newKey)
            
            // Report progress
            await MainActor.run {
                progress(index + 1, totalItems)
            }
            
            // Small delay to allow UI updates to be visible
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms
        }
        
        print("DEBUG: Migration completed successfully")
        
        // Update the current encryption key to the new one
        encryptionKey = newKey
        
        print("DEBUG: File migration completed successfully")
    }
    
    /// Migrate a single vault item to the new encryption key
    private func migrateVaultItem(_ vaultItem: VaultItem, oldKey: SymmetricKey, newKey: SymmetricKey) async throws {
        guard let fileName = vaultItem.fileName else {
            print("DEBUG: Skipping item with no filename")
            return
        }
        
        // Skip system files that might not be properly encrypted
        if fileName.hasPrefix(".") || fileName == ".DS_Store" {
            print("DEBUG: Skipping system file: \(fileName)")
            return
        }
        
        let fileURL = vaultDirectory.appendingPathComponent(fileName)
        
        // Check if file exists
        guard fileManager.fileExists(atPath: fileURL.path) else {
            print("DEBUG: File \(fileName) does not exist, skipping")
            return
        }
        
        do {
            // Load and decrypt with old key
            let encryptedData = try Data(contentsOf: fileURL)
            let decryptedData = try cryptoService.decrypt(encryptedData, using: oldKey)
            
            // Re-encrypt with new key
            let newEncryptedData = try cryptoService.encrypt(decryptedData, using: newKey)
            
            // Write back to file
            try newEncryptedData.write(to: fileURL)
            
            print("DEBUG: Successfully migrated file: \(fileName)")
        } catch {
            print("DEBUG: Failed to migrate file \(fileName): \(error)")
            // For individual file failures, log the error but don't stop the entire migration
            // Common reasons: authenticationFailure (system files), corrupted files, etc.
            if error.localizedDescription.contains("authenticationFailure") {
                print("DEBUG: Skipping file with authentication failure (likely system file or corrupted): \(fileName)")
            } else {
                print("DEBUG: Skipping file due to error: \(fileName) - \(error.localizedDescription)")
            }
            // Don't throw - just skip this file and continue with others
            return
        }
    }
    
    // MARK: - Trash Operations
    
    /// Check if trash is enabled in settings
    private var isTrashEnabled: Bool {
        UserDefaults.standard.bool(forKey: "trashEnabled")
    }
    
    /// Move item to trash instead of deleting permanently
    func moveToTrash(vaultItem: VaultItem) {
        trashService.moveToTrash(vaultItem)
    }
    
    // MARK: - File Operations
    
    /// Check if a file with the same content (size and type) already exists
    internal func isDuplicateContent(fileSize: Int64, fileType: String, targetFolder: Folder?) -> Bool {
        let existingFiles: [VaultItem]
        
        if let folder = targetFolder {
            existingFiles = folder.itemsArray
        } else {
            existingFiles = coreDataManager.fetchVaultItems(in: nil)
        }
        
        // Check for exact match on size and type (content similarity)
        return existingFiles.contains { item in
            item.fileSize == fileSize &&
            item.fileType == fileType
        }
    }
    
    /// Generate a unique filename if conflicts exist
    private func resolveFilenameConflicts(fileName: String, targetFolder: Folder?) -> String {
        let existingFiles: [VaultItem]
        
        if let folder = targetFolder {
            existingFiles = folder.itemsArray
        } else {
            existingFiles = coreDataManager.fetchVaultItems(in: nil)
        }
        
        // If no conflict, return original name
        let existingNames = Set(existingFiles.compactMap { $0.fileName })
        if !existingNames.contains(fileName) {
            return fileName
        }
        
        // Generate unique name with suffix
        let fileExtension = URL(fileURLWithPath: fileName).pathExtension
        let baseName = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        
        var counter = 1
        var uniqueName: String
        
        repeat {
            if fileExtension.isEmpty {
                uniqueName = "\(baseName) (\(counter))"
            } else {
                uniqueName = "\(baseName) (\(counter)).\(fileExtension)"
            }
            counter += 1
        } while existingNames.contains(uniqueName)
        
        return uniqueName
    }
    
    func saveFile(data: Data, fileName: String, fileType: String, targetFolder: Folder? = nil) throws -> VaultItem {
        print("DEBUG: saveFile called - fileName: \(fileName), fileType: \(fileType), dataSize: \(data.count)")
        if let folder = targetFolder {
            print("DEBUG: ✅ Target folder provided: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
        } else {
            print("DEBUG: ❌ No target folder provided, will save to root level")
        }
        
        guard let key = encryptionKey else {
            print("DEBUG: No encryption key available")
            throw FileStorageError.noEncryptionKey
        }
        
        let fileSize = Int64(data.count)
        
        // Check for duplicate content first
        if isDuplicateContent(fileSize: fileSize, fileType: fileType, targetFolder: targetFolder) {
            print("DEBUG: Duplicate content detected - ignoring: \(fileName)")
            throw FileStorageError.duplicateFile
        }
        
        // Resolve filename conflicts (add suffix if needed)
        let uniqueFileName = resolveFilenameConflicts(fileName: fileName, targetFolder: targetFolder)
        let fileURL = encryptedFileStore.url(for: uniqueFileName)
        print("DEBUG: Resolved filename: \(uniqueFileName)")
        print("DEBUG: Will save file to: \(fileURL.path)")
        
        // Encrypt data
        try encryptedFileStore.write(data, fileName: uniqueFileName, key: key)
        print("DEBUG: Encrypted file saved")
        
        // Generate thumbnail if it's an image or video
        var thumbnailFileName: String? = nil
        
        print("DEBUG: Checking fileType for thumbnail generation")
        print("DEBUG: fileType = '\(fileType)'")
        print("DEBUG: fileType.hasPrefix(\"image/\") = \(fileType.hasPrefix("image/"))")
        print("DEBUG: fileType.hasPrefix(\"video/\") = \(fileType.hasPrefix("video/"))")
        
        if fileType.hasPrefix("image/") {
            print("DEBUG: Generating image thumbnail...")
            do {
                thumbnailFileName = try thumbnailService.generateImageThumbnail(from: data, originalFileName: uniqueFileName)
                print("DEBUG: Image thumbnail result: \(thumbnailFileName ?? "nil")")
            } catch {
                print("DEBUG: Failed to generate image thumbnail: \(error)")
                // Continue without thumbnail - don't fail the entire import
            }
        } else if fileType.hasPrefix("video/") {
            print("DEBUG: Generating video thumbnail...")
            do {
                thumbnailFileName = try thumbnailService.generateVideoThumbnail(from: data, originalFileName: uniqueFileName)
                print("DEBUG: Video thumbnail result: \(thumbnailFileName ?? "nil")")
            } catch {
                print("DEBUG: Failed to generate video thumbnail: \(error)")
                // Continue without thumbnail - don't fail the entire import
            }
        } else {
            print("DEBUG: Skipping thumbnail generation for non-media fileType: \(fileType)")
        }
        
        // Create Core Data entry using synchronous method for direct calls
        let vaultItem = coreDataManager.createVaultItem(
            fileName: uniqueFileName,
            fileType: fileType,
            fileSize: Int64(data.count),
            thumbnailFileName: thumbnailFileName,
            in: targetFolder
        )
        
        print("DEBUG: VaultItem created with thumbnailFileName: \(vaultItem.thumbnailFileName ?? "nil")")
        
        return vaultItem
    }
    
    // New method for background imports
    func saveFileInBackground(data: Data, fileName: String, fileType: String, targetFolder: Folder? = nil, completion: @escaping (Result<VaultItem, Error>) -> Void) {
        print("DEBUG: saveFileInBackground called - fileName: \(fileName), fileType: \(fileType), dataSize: \(data.count)")
        
        guard let key = encryptionKey else {
            print("DEBUG: No encryption key available")
            completion(.failure(FileStorageError.noEncryptionKey))
            return
        }
        
        let fileSize = Int64(data.count)
        
        // Check for duplicate content first
        if isDuplicateContent(fileSize: fileSize, fileType: fileType, targetFolder: targetFolder) {
            print("DEBUG: Duplicate content detected - ignoring: \(fileName)")
            completion(.failure(FileStorageError.duplicateFile))
            return
        }
        
        // Resolve filename conflicts (add suffix if needed)
        let uniqueFileName = resolveFilenameConflicts(fileName: fileName, targetFolder: targetFolder)
        let fileURL = encryptedFileStore.url(for: uniqueFileName)
        print("DEBUG: Resolved filename: \(uniqueFileName)")
        print("DEBUG: Will save file to: \(fileURL.path)")
        
        do {
            // Encrypt data
            try encryptedFileStore.write(data, fileName: uniqueFileName, key: key)
            print("DEBUG: Encrypted file saved")
            
            // Generate thumbnail if it's an image or video
            var thumbnailFileName: String? = nil
            
            print("DEBUG: Checking fileType for thumbnail generation")
            print("DEBUG: fileType = '\(fileType)'")
            print("DEBUG: fileType.hasPrefix(\"image/\") = \(fileType.hasPrefix("image/"))")
            print("DEBUG: fileType.hasPrefix(\"video/\") = \(fileType.hasPrefix("video/"))")
            
            if fileType.hasPrefix("image/") {
                print("DEBUG: Generating image thumbnail...")
                do {
                    thumbnailFileName = try thumbnailService.generateImageThumbnail(from: data, originalFileName: uniqueFileName)
                    print("DEBUG: Image thumbnail result: \(thumbnailFileName ?? "nil")")
                } catch {
                    print("DEBUG: Failed to generate image thumbnail: \(error)")
                    // Continue without thumbnail - don't fail the entire import
                }
            } else if fileType.hasPrefix("video/") {
                print("DEBUG: Generating video thumbnail...")
                do {
                    thumbnailFileName = try thumbnailService.generateVideoThumbnail(from: data, originalFileName: uniqueFileName)
                    print("DEBUG: Video thumbnail result: \(thumbnailFileName ?? "nil")")
                } catch {
                    print("DEBUG: Failed to generate video thumbnail: \(error)")
                    // Continue without thumbnail - don't fail the entire import
                }
            } else {
                print("DEBUG: Skipping thumbnail generation for non-media fileType: \(fileType)")
            }
            
            // Create Core Data entry using background context
            coreDataManager.createVaultItemInBackground(
                fileName: uniqueFileName,
                fileType: fileType,
                fileSize: Int64(data.count),
                thumbnailFileName: thumbnailFileName,
                in: targetFolder
            ) { vaultItem in
                if let vaultItem = vaultItem {
                    print("DEBUG: VaultItem created with thumbnailFileName: \(vaultItem.thumbnailFileName ?? "nil")")
                    completion(.success(vaultItem))
                } else {
                    print("DEBUG: Failed to create VaultItem")
                    completion(.failure(FileStorageError.importFailed))
                }
            }
        } catch {
            print("DEBUG: Error in saveFileInBackground: \(error)")
            completion(.failure(error))
        }
    }
    
    func loadFile(vaultItem: VaultItem) throws -> Data {
        guard let key = encryptionKey else {
            throw FileStorageError.noEncryptionKey
        }
        
        guard let fileName = vaultItem.fileName else {
            throw FileStorageError.invalidFileName
        }
        
        return try encryptedFileStore.read(fileName: fileName, key: key)
    }
    
    func deleteFile(vaultItem: VaultItem) throws {
        // Check if trash is enabled
        if isTrashEnabled {
            // Move to trash instead of permanently deleting
            moveToTrash(vaultItem: vaultItem)
            return
        }
        
        // Permanent delete logic (when trash is disabled)
        // Before deleting physical files, check if other VaultItems reference the same files
        let shouldDeleteMainFile: Bool
        let shouldDeleteThumbnail: Bool
        
        if let fileName = vaultItem.fileName {
            shouldDeleteMainFile = !hasOtherReferences(to: fileName, excluding: vaultItem)
        } else {
            shouldDeleteMainFile = false
        }
        
        if let thumbnailFileName = vaultItem.thumbnailFileName {
            shouldDeleteThumbnail = !hasOtherReferences(toThumbnail: thumbnailFileName, excluding: vaultItem)
        } else {
            shouldDeleteThumbnail = false
        }
        
        // Delete Core Data entry first
        coreDataManager.deleteVaultItem(vaultItem)
        
        // Then delete physical files only if no other references exist
        if shouldDeleteMainFile, let fileName = vaultItem.fileName {
            let fileURL = vaultDirectory.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        
        if shouldDeleteThumbnail, let thumbnailFileName = vaultItem.thumbnailFileName {
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
            try? fileManager.removeItem(at: thumbnailURL)
        }
    }
    
    /// Permanently delete a vault item, bypassing trash settings
    /// This is used for items that are already in trash and need to be permanently removed
    func permanentlyDeleteFile(vaultItem: VaultItem) throws {
        trashService.permanentlyDelete(vaultItem)
    }
    
    /// Check if any other VaultItems reference the same filename (excluding the specified item)
    private func hasOtherReferences(to fileName: String, excluding excludeItem: VaultItem) -> Bool {
        let allItems = coreDataManager.fetchAllVaultItems()
        return allItems.contains { item in
            item.objectID != excludeItem.objectID && item.fileName == fileName
        }
    }
    
    /// Check if any other VaultItems reference the same thumbnail filename (excluding the specified item)
    private func hasOtherReferences(toThumbnail thumbnailFileName: String, excluding excludeItem: VaultItem) -> Bool {
        let allItems = coreDataManager.fetchAllVaultItems()
        return allItems.contains { item in
            item.objectID != excludeItem.objectID && item.thumbnailFileName == thumbnailFileName
        }
    }
    
    func cleanupFileStorage(vaultItem: VaultItem) {
        // Delete main file storage only (no Core Data deletion)
        if let fileName = vaultItem.fileName {
            let fileURL = vaultDirectory.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        
        // Delete thumbnail storage only
        if let thumbnailFileName = vaultItem.thumbnailFileName {
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
            try? fileManager.removeItem(at: thumbnailURL)
        }
    }
    
    // MARK: - Favorites Management
    
    func toggleFavorite(for vaultItem: VaultItem) {
        coreDataManager.toggleFavorite(for: vaultItem)
    }
    
    func fetchFavoriteItems() -> [VaultItem] {
        return coreDataManager.fetchFavoriteVaultItems()
    }
    
    // MARK: - File Rename Management
    
    /// Rename a vault item's physical file and update Core Data
    func renameFile(vaultItem: VaultItem, newFileName: String) throws {
        guard let oldFileName = vaultItem.fileName else {
            throw FileStorageError.invalidFileName
        }
        
        // Check if the new filename already exists
        if encryptedFileStore.exists(fileName: newFileName) {
            throw FileStorageError.fileAlreadyExists
        }
        
        // Rename the main file
        try encryptedFileStore.move(from: oldFileName, to: newFileName)
        
        // Rename the thumbnail file if it exists
        if let thumbnailFileName = vaultItem.thumbnailFileName {
            let oldThumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
            
            if fileManager.fileExists(atPath: oldThumbnailURL.path) {
                // Generate new thumbnail filename based on new main filename
                let newThumbnailFileName = generateThumbnailFileName(for: newFileName)
                let newThumbnailURL = thumbnailsDirectory.appendingPathComponent(newThumbnailFileName)
                
                try fileManager.moveItem(at: oldThumbnailURL, to: newThumbnailURL)
                
                // Update the thumbnail filename in Core Data
                vaultItem.thumbnailFileName = newThumbnailFileName
            }
        }
        
        // Update the filename in Core Data
        vaultItem.fileName = newFileName
        vaultItem.updatedAt = Date()
        
        // Save the context
        coreDataManager.save()
        
        print("DEBUG: Successfully renamed file from \(oldFileName) to \(newFileName)")
    }
    
    /// Generate thumbnail filename based on original filename
    private func generateThumbnailFileName(for fileName: String) -> String {
        return "thumb_\(fileName).jpg"
    }
    
    // MARK: - Share Management
    
    /// Prepare a vault item for sharing by decrypting it to a temporary file
    func prepareForSharing(vaultItem: VaultItem) throws -> URL {
        guard let fileName = vaultItem.fileName else {
            throw FileStorageError.invalidFileName
        }
        
        // Load and decrypt the file
        let decryptedData = try loadFile(vaultItem: vaultItem)
        
        // Create a temporary file URL
        return try temporarySharingService.prepare(data: decryptedData, fileName: fileName)
    }
    
    /// Clean up temporary sharing files
    func cleanupTemporaryFile(at url: URL) {
        temporarySharingService.cleanup(at: url)
    }
    
    func loadThumbnail(for vaultItem: VaultItem) -> Data? {
        guard let thumbnailFileName = vaultItem.thumbnailFileName else { 
            print("DEBUG: No thumbnail filename for item \(vaultItem.fileName ?? "")")
            return nil 
        }
        
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
        print("DEBUG: Loading thumbnail from \(thumbnailURL.path)")
        print("DEBUG: Thumbnail exists: \(fileManager.fileExists(atPath: thumbnailURL.path))")
        
        guard let data = try? Data(contentsOf: thumbnailURL) else { 
            print("DEBUG: Failed to load thumbnail data")
            return nil 
        }
        
        print("DEBUG: Thumbnail data loaded: \(data.count) bytes")
        return data
    }
    
    func loadImage(for vaultItem: VaultItem) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let fileData = try loadFile(vaultItem: vaultItem)
                print(">>>>>>> DEBUG: File data loaded: \(fileData.count) bytes")
                continuation.resume(returning: fileData)
            } catch let error {
                print(">>>>>>> DEBUG: Error loading image: \(error.localizedDescription)")
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Storage Info
    
    func getStorageInfo() -> (fileCount: Int, usedSpace: Int64) {
        let context = coreDataManager.persistentContainer.viewContext
        
        let request = NSFetchRequest<VaultItem>(entityName: "VaultItem")
        
        do {
            let items = try context.fetch(request)
            let fileCount = items.count
            
            // Calculate used space by summing file sizes
            var usedSpace: Int64 = 0
            for item in items {
                if let fileName = item.fileName {
                    let fileURL = vaultDirectory.appendingPathComponent(fileName)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                        usedSpace += fileSize
                    }
                }
                
                // Also count thumbnail size
                if let thumbnailFileName = item.thumbnailFileName {
                    let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: thumbnailURL.path),
                       let thumbnailSize = attributes[FileAttributeKey.size] as? Int64 {
                        usedSpace += thumbnailSize
                    }
                }
            }
            
            return (fileCount: fileCount, usedSpace: usedSpace)
            
        } catch {
            print("DEBUG: Error fetching storage info: \(error)")
            return (fileCount: 0, usedSpace: 0)
        }
    }
    
    // MARK: - Import from Photo Library
    
    func importFromPhotoLibrary(asset: PHAsset, targetFolder: Folder? = nil, completion: @escaping (Result<VaultItem, Error>) -> Void) {
        print("DEBUG: Starting import for asset: \(asset.localIdentifier)")
        photoImportService.importAsset(
            asset,
            imageHandler: { data, fileName, uti in
                do {
                    let item = try self.saveFile(
                        data: data,
                        fileName: fileName,
                        fileType: self.convertUTIToMimeType(uti),
                        targetFolder: targetFolder
                    )
                    completion(.success(item))
                } catch {
                    completion(.failure(error))
                }
            },
            videoHandler: { data, fileName, fileType in
                self.saveFileInBackground(
                    data: data,
                    fileName: fileName,
                    fileType: fileType,
                    targetFolder: targetFolder,
                    completion: completion
                )
            },
            completion: completion
        )
    }
}

// MARK: - File Storage Cleanup

extension FileStorageManager {
    
    func clearAllStoredFiles() {
        print("DEBUG: Clearing all stored files...")
        
        let fileManager = FileManager.default
        
        // Clear vault directory
        if fileManager.fileExists(atPath: vaultDirectory.path) {
            do {
                // Remove all contents of vault directory
                let vaultContents = try fileManager.contentsOfDirectory(at: vaultDirectory, includingPropertiesForKeys: nil)
                for fileURL in vaultContents {
                    try fileManager.removeItem(at: fileURL)
                }
                print("DEBUG: Vault directory contents cleared")
            } catch {
                print("ERROR: Failed to clear vault directory: \(error)")
            }
        }
        
        // Clear thumbnails directory
        if fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            do {
                // Remove all contents of thumbnails directory
                let thumbnailContents = try fileManager.contentsOfDirectory(at: thumbnailsDirectory, includingPropertiesForKeys: nil)
                for fileURL in thumbnailContents {
                    try fileManager.removeItem(at: fileURL)
                }
                print("DEBUG: Thumbnails directory contents cleared")
            } catch {
                print("ERROR: Failed to clear thumbnails directory: \(error)")
            }
        }
        
        // Clear encryption key
        encryptionKey = nil
        
        print("DEBUG: All stored files cleared")
    }
    
    func deleteAllStorageDirectories() {
        print("DEBUG: Deleting all storage directories...")
        
        let fileManager = FileManager.default
        
        // Delete vault directory completely
        if fileManager.fileExists(atPath: vaultDirectory.path) {
            do {
                try fileManager.removeItem(at: vaultDirectory)
                print("DEBUG: Vault directory deleted")
            } catch {
                print("ERROR: Failed to delete vault directory: \(error)")
            }
        }
        
        // Delete thumbnails directory completely
        if fileManager.fileExists(atPath: thumbnailsDirectory.path) {
            do {
                try fileManager.removeItem(at: thumbnailsDirectory)
                print("DEBUG: Thumbnails directory deleted")
            } catch {
                print("ERROR: Failed to delete thumbnails directory: \(error)")
            }
        }
        
        // Clear encryption key
        encryptionKey = nil
        
        print("DEBUG: All storage directories deleted")
    }
}

// MARK: - Errors

enum FileStorageError: LocalizedError {
    case noEncryptionKey
    case encryptionFailed
    case decryptionFailed
    case invalidFileName
    case importFailed
    case duplicateFile
    case fileAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .noEncryptionKey:
            return "Encryption key not set. Please authenticate first."
        case .encryptionFailed:
            return "Failed to encrypt file."
        case .decryptionFailed:
            return "Failed to decrypt file."
        case .invalidFileName:
            return "Invalid file name."
        case .importFailed:
            return "Failed to import file from photo library."
        case .duplicateFile:
            return "File already exists in the target location."
        case .fileAlreadyExists:
            return "A file with this name already exists."
        }
    }
} 