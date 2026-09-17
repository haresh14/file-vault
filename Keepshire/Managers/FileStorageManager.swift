//
//  FileStorageManager.swift
//  Keepshire
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
    private let keyDerivationStore: VaultKeyDerivationStoring
    private let thumbnailService: ThumbnailGenerationService
    private let trashService: TrashOperationsService
    private let temporarySharingService: TemporarySharingService
    private let encryptedFileStore: EncryptedFileStore
    private let encryptedThumbnailStore: EncryptedFileStore
    private let metadataSealer: VaultMetadataSealer
    private var saveObservers: [NSObjectProtocol] = []
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
            coreDataManager: .shared,
            keyDerivationStore: KeychainVaultKeyDerivationStore(keychain: .shared)
        )
    }

    /// Creates isolated file and metadata storage for tests.
    init(
        fileManager: FileManager = .default,
        documentsDirectory: URL,
        coreDataManager: CoreDataManager,
        keyDerivationStore: VaultKeyDerivationStoring = InMemoryVaultKeyDerivationStore()
    ) {
        self.fileManager = fileManager
        self.documentsDirectory = documentsDirectory
        self.coreDataManager = coreDataManager
        self.keyDerivationStore = keyDerivationStore
        
        // Create vault directory
        vaultDirectory = documentsDirectory.appendingPathComponent("Vault", isDirectory: true)
        thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        encryptedFileStore = EncryptedFileStore(
            fileManager: fileManager,
            vaultDirectory: vaultDirectory,
            cryptoService: cryptoService
        )
        encryptedThumbnailStore = EncryptedFileStore(
            fileManager: fileManager,
            vaultDirectory: thumbnailsDirectory,
            cryptoService: cryptoService
        )
        metadataSealer = VaultMetadataSealer(cryptoService: cryptoService)
        thumbnailService = ThumbnailGenerationService(
            fileManager: fileManager,
            thumbnailStore: encryptedThumbnailStore
        )
        trashService = TrashOperationsService(
            fileManager: fileManager,
            coreDataManager: coreDataManager,
            vaultDirectory: vaultDirectory,
            thumbnailsDirectory: thumbnailsDirectory
        )
        temporarySharingService = TemporarySharingService(fileManager: fileManager)
        
        VaultLog.debug("DEBUG: Documents directory: \(documentsDirectory.path)")
        VaultLog.debug("DEBUG: Vault directory: \(vaultDirectory.path)")
        VaultLog.debug("DEBUG: Thumbnails directory: \(thumbnailsDirectory.path)")
        
        // Create directories if they don't exist
        do {
            try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true, attributes: nil)
            VaultLog.debug("DEBUG: Vault directory created/verified")
        } catch {
            VaultLog.debug("DEBUG: Error creating vault directory: \(error)")
        }
        
        do {
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true, attributes: nil)
            VaultLog.debug("DEBUG: Thumbnails directory created/verified")
        } catch {
            VaultLog.debug("DEBUG: Error creating thumbnails directory: \(error)")
        }
        
        // Verify directories exist
        VaultLog.debug("DEBUG: Vault directory exists: \(fileManager.fileExists(atPath: vaultDirectory.path))")
        VaultLog.debug("DEBUG: Thumbnails directory exists: \(fileManager.fileExists(atPath: thumbnailsDirectory.path))")
        
        // Set file protection
        setFileProtection()
        metadataSealer.attach(to: coreDataManager.context.persistentStoreCoordinator)
        registerMetadataSaveHooks()
    }

    deinit {
        saveObservers.forEach { NotificationCenter.default.removeObserver($0) }
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
        BackupExclusion.excludeFromBackup(vaultDirectory)
        BackupExclusion.excludeFromBackup(thumbnailsDirectory)
    }

    private func registerMetadataSaveHooks() {
        let center = NotificationCenter.default
        saveObservers.append(center.addObserver(
            forName: .NSManagedObjectContextWillSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            guard let context = notification.object as? NSManagedObjectContext else { return }
            self?.metadataSealer.prepareForSave(context)
        })
        saveObservers.append(center.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: nil,
            queue: nil
        ) { [weak self] notification in
            self?.metadataSealer.restoreAfterSave(from: notification)
        })
    }
    
    // MARK: - Encryption Key Management
    
    func setupEncryptionKey(from password: String) {
        if let record = keyDerivationStore.loadRecord() {
            encryptionKey = try? cryptoService.key(from: password, record: record)
        } else if vaultContainsCiphertext() {
            encryptionKey = cryptoService.legacySHA256Key(from: password)
            upgradeLegacySHA256KeyIfNeeded(password: password)
        } else {
            let record = cryptoService.makeRecord()
            do {
                try keyDerivationStore.saveRecord(record)
                encryptionKey = try cryptoService.key(from: password, record: record)
            } catch {
                VaultLog.debug("DEBUG: Failed to store key derivation record: \(error)")
                encryptionKey = cryptoService.legacySHA256Key(from: password)
            }
        }
        // Metadata must be readable before the on-disk migrations inspect stored names.
        metadataSealer.key = encryptionKey
        metadataSealer.revealLazily(in: coreDataManager.context)
        if metadataSealer.sealLegacyPlaintext(in: coreDataManager.context) {
            coreDataManager.persistChanges()
        }
        migrateOnDiskNamesToUUID()
        encryptPlaintextThumbnails()
        removeOrphanedFiles()
    }
    
    /// Re-encrypt all vault files with a new encryption key
    /// This is called when the user changes their passcode
    func migrateFilesToNewEncryptionKey(oldPassword: String, newPassword: String, progress: @escaping (Int, Int) -> Void) async throws {
        VaultLog.debug("DEBUG: Starting file migration from old key to new key")
        
        let oldKey = deriveKey(for: oldPassword)
        let newRecord = cryptoService.makeRecord()
        let newKey = try cryptoService.key(from: newPassword, record: newRecord)
        
        // Get all vault items
        let allItems = coreDataManager.fetchAllVaultItems()
        let totalItems = allItems.count
        
        VaultLog.debug("DEBUG: Found \(totalItems) items to migrate")

        var stagedNames: [String] = []
        var didCommit = false
        defer {
            if !didCommit {
                for name in stagedNames {
                    try? fileManager.removeItem(at: vaultDirectory.appendingPathComponent(name))
                    try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(name))
                }
            }
        }

        do {
            for (index, item) in allItems.enumerated() {
                stagedNames.append(contentsOf: try stageReencryptedCopies(item, oldKey: oldKey, newKey: newKey))
                await MainActor.run {
                    progress(index + 1, totalItems)
                }
                try await Task.sleep(nanoseconds: 10_000_000)
            }

            try commitStagedCopies(for: allItems)
            didCommit = true
        } catch {
            throw FileStorageError.migrationFailed
        }

        VaultLog.debug("DEBUG: Migration completed successfully")

        try keyDerivationStore.saveRecord(newRecord)
        encryptionKey = newKey
        metadataSealer.reencryptAll(
            items: coreDataManager.fetchAllVaultItems(),
            folders: coreDataManager.fetchAllFolders(),
            oldKey: oldKey,
            newKey: newKey
        )
        try coreDataManager.save()
        
        VaultLog.debug("DEBUG: File migration completed successfully")
    }
    
    private func stageReencryptedCopies(
        _ vaultItem: VaultItem,
        oldKey: SymmetricKey,
        newKey: SymmetricKey
    ) throws -> [String] {
        guard let sourceName = existingVaultFileName(for: vaultItem) else {
            throw FileStorageError.migrationFailed
        }
        if sourceName.hasPrefix(".") || sourceName == ".DS_Store" {
            return []
        }

        var staged: [String] = []
        let destinationName = vaultItem.storedBlobName ?? sourceName
        let stagedBlob = destinationName + ".migrating"
        let plaintext = try encryptedFileStore.read(fileName: sourceName, key: oldKey)
        try encryptedFileStore.write(plaintext, fileName: stagedBlob, key: newKey)
        staged.append(stagedBlob)

        if let destName = vaultItem.storedThumbnailName ?? vaultItem.thumbnailFileName,
           encryptedThumbnailStore.exists(fileName: destName)
            || vaultItem.storedThumbnailCandidates.contains(where: { encryptedThumbnailStore.exists(fileName: $0) }) {
            let stagedThumb = destName + ".migrating"
            try stageThumbnail(vaultItem, destName: destName, stagedName: stagedThumb, oldKey: oldKey, newKey: newKey)
            staged.append(stagedThumb)
        }
        return staged
    }

    private func stageThumbnail(
        _ vaultItem: VaultItem,
        destName: String,
        stagedName: String,
        oldKey: SymmetricKey,
        newKey: SymmetricKey
    ) throws {
        var sourceName = destName
        if !encryptedThumbnailStore.exists(fileName: destName) {
            sourceName = vaultItem.storedThumbnailCandidates.first { encryptedThumbnailStore.exists(fileName: $0) } ?? destName
        }
        guard encryptedThumbnailStore.exists(fileName: sourceName) else { return }
        let data = try Data(contentsOf: thumbnailsDirectory.appendingPathComponent(sourceName))
        let jpeg: Data
        if let decrypted = try? cryptoService.decrypt(data, using: oldKey) {
            jpeg = decrypted
        } else if isJPEGData(data) {
            jpeg = data
        } else {
            throw FileStorageError.migrationFailed
        }
        try encryptedThumbnailStore.write(jpeg, fileName: stagedName, key: newKey)
    }

    private func commitStagedCopies(for items: [VaultItem]) throws {
        for item in items {
            let sourceName = existingVaultFileName(for: item)
            guard let dest = item.storedBlobName ?? sourceName else { continue }
            let stagedBlob = dest + ".migrating"
            if encryptedFileStore.exists(fileName: stagedBlob) {
                if dest != stagedBlob, encryptedFileStore.exists(fileName: dest) {
                    try fileManager.removeItem(at: encryptedFileStore.url(for: dest))
                }
                try encryptedFileStore.move(from: stagedBlob, to: dest)
                if let sourceName, sourceName != dest, encryptedFileStore.exists(fileName: sourceName) {
                    try? fileManager.removeItem(at: encryptedFileStore.url(for: sourceName))
                }
            }
            if let thumb = item.storedThumbnailName ?? item.thumbnailFileName {
                let stagedThumb = thumb + ".migrating"
                if encryptedThumbnailStore.exists(fileName: stagedThumb) {
                    if encryptedThumbnailStore.exists(fileName: thumb) {
                        try fileManager.removeItem(at: encryptedThumbnailStore.url(for: thumb))
                    }
                    try encryptedThumbnailStore.move(from: stagedThumb, to: thumb)
                }
            }
        }
    }

    private func reencryptVaultItem(_ vaultItem: VaultItem, oldKey: SymmetricKey, newKey: SymmetricKey) throws {
        guard let sourceName = existingVaultFileName(for: vaultItem) else {
            throw FileStorageError.migrationFailed
        }

        if sourceName.hasPrefix(".") || sourceName == ".DS_Store" {
            return
        }

        let destinationName = vaultItem.storedBlobName ?? sourceName
        try encryptedFileStore.reencrypt(fileName: sourceName, oldKey: oldKey, newKey: newKey)
        if destinationName != sourceName {
            try encryptedFileStore.move(from: sourceName, to: destinationName)
        }
        try reencryptThumbnail(vaultItem, oldKey: oldKey, newKey: newKey)
    }

    private func deriveKey(for password: String) -> SymmetricKey {
        if let record = keyDerivationStore.loadRecord(),
           let key = try? cryptoService.key(from: password, record: record) {
            return key
        }
        return cryptoService.legacySHA256Key(from: password)
    }

    private func vaultContainsCiphertext() -> Bool {
        let urls = (try? fileManager.contentsOfDirectory(
            at: vaultDirectory,
            includingPropertiesForKeys: nil
        )) ?? []
        return urls.contains { !$0.lastPathComponent.hasPrefix(".") }
    }

    private func upgradeLegacySHA256KeyIfNeeded(password: String) {
        let oldKey = cryptoService.legacySHA256Key(from: password)
        let record = cryptoService.makeRecord()
        guard let newKey = try? cryptoService.key(from: password, record: record) else { return }

        for item in coreDataManager.fetchAllVaultItems() {
            try? reencryptVaultItem(item, oldKey: oldKey, newKey: newKey)
        }

        do {
            try keyDerivationStore.saveRecord(record)
            encryptionKey = newKey
            metadataSealer.key = newKey
            metadataSealer.reencryptAll(
                items: coreDataManager.fetchAllVaultItems(),
                folders: coreDataManager.fetchAllFolders(),
                oldKey: oldKey,
                newKey: newKey
            )
            VaultLog.debug("DEBUG: Upgraded vault key derivation to PBKDF2")
        } catch {
            VaultLog.debug("DEBUG: Failed to save PBKDF2 derivation record: \(error)")
        }
    }

    private func reencryptThumbnail(_ vaultItem: VaultItem, oldKey: SymmetricKey, newKey: SymmetricKey) throws {
        guard let destName = vaultItem.storedThumbnailName ?? vaultItem.thumbnailFileName else { return }
        let destURL = thumbnailsDirectory.appendingPathComponent(destName)
        var sourceURL = destURL
        if !fileManager.fileExists(atPath: destURL.path) {
            for name in vaultItem.storedThumbnailCandidates where name != destName {
                let candidate = thumbnailsDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: candidate.path) {
                    sourceURL = candidate
                    break
                }
            }
        }
        guard fileManager.fileExists(atPath: sourceURL.path),
              let data = try? Data(contentsOf: sourceURL) else { return }

        let jpeg: Data
        if let decrypted = try? cryptoService.decrypt(data, using: oldKey) {
            jpeg = decrypted
        } else if isJPEGData(data) {
            jpeg = data
        } else {
            throw FileStorageError.migrationFailed
        }

        try encryptedThumbnailStore.write(jpeg, fileName: destName, key: newKey)
        if sourceURL != destURL {
            try? fileManager.removeItem(at: sourceURL)
        }
    }

    private func existingVaultFileName(for item: VaultItem) -> String? {
        if let blob = item.storedBlobName, encryptedFileStore.exists(fileName: blob) {
            return blob
        }
        if let display = item.fileName, encryptedFileStore.exists(fileName: display) {
            return display
        }
        return nil
    }

    private func migrateOnDiskNamesToUUID() {
        var didChange = false
        for item in coreDataManager.fetchAllVaultItems() {
            if migrateItemOnDisk(item) {
                didChange = true
            }
        }
        if didChange {
            coreDataManager.persistChanges()
        }
    }

    @discardableResult
    private func migrateItemOnDisk(_ item: VaultItem) -> Bool {
        guard let blob = item.storedBlobName else { return false }
        var changed = false
        let dest = vaultDirectory.appendingPathComponent(blob)
        if !fileManager.fileExists(atPath: dest.path),
           let display = item.fileName,
           display != blob {
            let src = vaultDirectory.appendingPathComponent(display)
            if fileManager.fileExists(atPath: src.path) {
                try? fileManager.moveItem(at: src, to: dest)
                changed = true
            }
        }

        guard let thumbDestName = item.storedThumbnailName else { return changed }
        let thumbDest = thumbnailsDirectory.appendingPathComponent(thumbDestName)
        if !fileManager.fileExists(atPath: thumbDest.path) {
            var candidates: [String] = []
            if let old = item.thumbnailFileName { candidates.append(old) }
            if let display = item.fileName {
                candidates.append("thumb_\(display).jpg")
            }
            for name in Set(candidates) {
                let src = thumbnailsDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: src.path) {
                    try? fileManager.moveItem(at: src, to: thumbDest)
                    changed = true
                    break
                }
            }
        }
        if item.thumbnailFileName != nil,
           item.thumbnailFileName != thumbDestName,
           fileManager.fileExists(atPath: thumbDest.path) {
            item.thumbnailFileName = thumbDestName
            changed = true
        }
        return changed
    }

    private func encryptPlaintextThumbnails() {
        guard encryptionKey != nil else { return }
        for item in coreDataManager.fetchAllVaultItems() {
            upgradeThumbnailIfPlaintext(item)
        }
    }

    @discardableResult
    private func upgradeThumbnailIfPlaintext(_ item: VaultItem) -> Bool {
        guard let key = encryptionKey else { return false }
        guard let destName = item.storedThumbnailName ?? item.thumbnailFileName else { return false }
        let destURL = thumbnailsDirectory.appendingPathComponent(destName)
        var sourceURL = destURL
        if !fileManager.fileExists(atPath: destURL.path) {
            for name in item.storedThumbnailCandidates where name != destName {
                let candidate = thumbnailsDirectory.appendingPathComponent(name)
                if fileManager.fileExists(atPath: candidate.path) {
                    sourceURL = candidate
                    break
                }
            }
        }
        guard fileManager.fileExists(atPath: sourceURL.path),
              let data = try? Data(contentsOf: sourceURL),
              isJPEGData(data) else { return false }

        do {
            try encryptedThumbnailStore.write(data, fileName: destName, key: key)
            if sourceURL != destURL {
                try? fileManager.removeItem(at: sourceURL)
            }
            if item.thumbnailFileName != destName {
                item.thumbnailFileName = destName
                coreDataManager.persistChanges()
            }
            return true
        } catch {
            VaultLog.debug("DEBUG: Failed to encrypt plaintext thumbnail \(destName): \(error)")
            return false
        }
    }

    private func isJPEGData(_ data: Data) -> Bool {
        data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8
    }

    /// Drop ciphertext and thumbnails that no item claims. Skipped while the vault has
    /// no items, so an empty fetch can never clear a populated Vault directory.
    private func removeOrphanedFiles() {
        let items = coreDataManager.fetchAllVaultItems()
        guard !items.isEmpty else { return }

        var blobs: Set<String> = []
        var thumbnails: Set<String> = []
        for item in items {
            blobs.formUnion(item.storedBlobCandidates)
            thumbnails.formUnion(item.storedThumbnailCandidates)
        }

        removeUnreferencedFiles(in: vaultDirectory, keeping: blobs)
        removeUnreferencedFiles(in: thumbnailsDirectory, keeping: thumbnails)
    }

    private func removeUnreferencedFiles(in directory: URL, keeping referenced: Set<String>) {
        let urls = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        )) ?? []
        for url in urls {
            let name = url.lastPathComponent
            guard !name.hasPrefix("."), !referenced.contains(name) else { continue }
            try? fileManager.removeItem(at: url)
            VaultLog.debug("DEBUG: Removed orphaned file: \(name)")
        }
    }

    private func removeStoredFiles(for item: VaultItem) {
        removeStoredFiles(
            blobs: item.storedBlobCandidates,
            thumbnails: item.storedThumbnailCandidates
        )
    }

    private func removeStoredFiles(blobs: Set<String>, thumbnails: Set<String>) {
        for name in blobs {
            try? fileManager.removeItem(at: vaultDirectory.appendingPathComponent(name))
        }
        for name in thumbnails {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(name))
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
        VaultLog.debug("DEBUG: saveFile called - fileName: \(fileName), fileType: \(fileType), dataSize: \(data.count)")
        if let folder = targetFolder {
            VaultLog.debug("DEBUG: ✅ Target folder provided: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
        } else {
            VaultLog.debug("DEBUG: ❌ No target folder provided, will save to root level")
        }
        
        guard let key = encryptionKey else {
            VaultLog.debug("DEBUG: No encryption key available")
            throw FileStorageError.noEncryptionKey
        }
        
        let fileSize = Int64(data.count)
        
        // Check for duplicate content first
        if isDuplicateContent(fileSize: fileSize, fileType: fileType, targetFolder: targetFolder) {
            VaultLog.debug("DEBUG: Duplicate content detected - ignoring: \(fileName)")
            throw FileStorageError.duplicateFile
        }
        
        // Resolve display-name conflicts (add suffix if needed). Disk blobs use a UUID.
        let uniqueFileName = resolveFilenameConflicts(fileName: fileName, targetFolder: targetFolder)
        let persisted = try persistNewBlob(data: data, displayName: uniqueFileName, fileType: fileType, key: key)
        
        let vaultItem = try coreDataManager.createVaultItem(
            fileName: uniqueFileName,
            fileType: fileType,
            fileSize: Int64(data.count),
            thumbnailFileName: persisted.thumbnailFileName,
            in: targetFolder,
            id: persisted.blobID
        )
        
        VaultLog.debug("DEBUG: VaultItem created with thumbnailFileName: \(vaultItem.thumbnailFileName ?? "nil")")
        
        return vaultItem
    }

    func saveFile(fromFileURL url: URL, fileName: String, fileType: String, targetFolder: Folder? = nil) throws -> VaultItem {
        guard let key = encryptionKey else {
            throw FileStorageError.noEncryptionKey
        }
        let size = Int64((try url.resourceValues(forKeys: [.fileSizeKey])).fileSize ?? 0)
        if isDuplicateContent(fileSize: size, fileType: fileType, targetFolder: targetFolder) {
            throw FileStorageError.duplicateFile
        }
        let uniqueFileName = resolveFilenameConflicts(fileName: fileName, targetFolder: targetFolder)
        let persisted = try persistNewBlob(
            fromFileURL: url,
            displayName: uniqueFileName,
            fileType: fileType,
            fileSize: size,
            key: key
        )
        return try coreDataManager.createVaultItem(
            fileName: uniqueFileName,
            fileType: fileType,
            fileSize: size,
            thumbnailFileName: persisted.thumbnailFileName,
            in: targetFolder,
            id: persisted.blobID
        )
    }

    // New method for background imports
    func saveFileInBackground(data: Data, fileName: String, fileType: String, targetFolder: Folder? = nil, completion: @escaping (Result<VaultItem, Error>) -> Void) {
        VaultLog.debug("DEBUG: saveFileInBackground called - fileName: \(fileName), fileType: \(fileType), dataSize: \(data.count)")
        
        guard let key = encryptionKey else {
            VaultLog.debug("DEBUG: No encryption key available")
            completion(.failure(FileStorageError.noEncryptionKey))
            return
        }
        
        let fileSize = Int64(data.count)
        
        // Check for duplicate content first
        if isDuplicateContent(fileSize: fileSize, fileType: fileType, targetFolder: targetFolder) {
            VaultLog.debug("DEBUG: Duplicate content detected - ignoring: \(fileName)")
            completion(.failure(FileStorageError.duplicateFile))
            return
        }
        
        // Resolve display-name conflicts (add suffix if needed)
        let uniqueFileName = resolveFilenameConflicts(fileName: fileName, targetFolder: targetFolder)
        
        do {
            let persisted = try persistNewBlob(data: data, displayName: uniqueFileName, fileType: fileType, key: key)
            
            coreDataManager.createVaultItemInBackground(
                fileName: uniqueFileName,
                fileType: fileType,
                fileSize: Int64(data.count),
                thumbnailFileName: persisted.thumbnailFileName,
                in: targetFolder,
                id: persisted.blobID
            ) { vaultItem in
                if let vaultItem = vaultItem {
                    VaultLog.debug("DEBUG: VaultItem created with thumbnailFileName: \(vaultItem.thumbnailFileName ?? "nil")")
                    completion(.success(vaultItem))
                } else {
                    VaultLog.debug("DEBUG: Failed to create VaultItem")
                    completion(.failure(FileStorageError.importFailed))
                }
            }
        } catch {
            VaultLog.debug("DEBUG: Error in saveFileInBackground: \(error)")
            completion(.failure(error))
        }
    }
    
    private func persistNewBlob(
        data: Data,
        displayName: String,
        fileType: String,
        key: SymmetricKey
    ) throws -> (blobID: UUID, thumbnailFileName: String?) {
        let blobID = UUID()
        let blobName = blobID.uuidString
        try encryptedFileStore.write(data, fileName: blobName, key: key)

        var thumbnailFileName: String?
        if fileType.hasPrefix("image/") {
            thumbnailFileName = try? thumbnailService.generateImageThumbnail(
                from: data,
                storageKey: blobName,
                key: key
            )
        } else if fileType.hasPrefix("video/") {
            thumbnailFileName = try? thumbnailService.generateVideoThumbnail(
                from: data,
                storageKey: blobName,
                displayFileName: displayName,
                key: key
            )
        }
        return (blobID, thumbnailFileName)
    }

    private func persistNewBlob(
        fromFileURL source: URL,
        displayName: String,
        fileType: String,
        fileSize: Int64,
        key: SymmetricKey
    ) throws -> (blobID: UUID, thumbnailFileName: String?) {
        let blobID = UUID()
        let blobName = blobID.uuidString
        try encryptedFileStore.write(fromFileURL: source, fileName: blobName, key: key)

        var thumbnailFileName: String?
        if fileType.hasPrefix("image/"), fileSize < Int64(VaultBlobFormat.inMemoryThreshold) {
            let data = try Data(contentsOf: source, options: [.mappedIfSafe])
            thumbnailFileName = try? thumbnailService.generateImageThumbnail(
                from: data,
                storageKey: blobName,
                key: key
            )
        } else if fileType.hasPrefix("video/") {
            thumbnailFileName = try? thumbnailService.generateVideoThumbnail(
                fromFileURL: source,
                storageKey: blobName,
                displayFileName: displayName,
                key: key
            )
        }
        return (blobID, thumbnailFileName)
    }

    func loadFile(vaultItem: VaultItem) throws -> Data {
        if migrateItemOnDisk(vaultItem) {
            coreDataManager.persistChanges()
        }
        guard let key = encryptionKey else {
            throw FileStorageError.noEncryptionKey
        }
        guard let fileName = existingVaultFileName(for: vaultItem) else {
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
        
        // Permanent delete: each item has a unique UUID blob.
        let blobs = vaultItem.storedBlobCandidates
        let thumbnails = vaultItem.storedThumbnailCandidates
        coreDataManager.deleteVaultItem(vaultItem)
        removeStoredFiles(blobs: blobs, thumbnails: thumbnails)
    }
    
    /// Permanently delete a vault item, bypassing trash settings
    /// This is used for items that are already in trash and need to be permanently removed
    func permanentlyDeleteFile(vaultItem: VaultItem) throws {
        trashService.permanentlyDelete(vaultItem)
    }

    /// Delete every item and its bytes, ignoring the trash setting. The encryption key stays
    /// loaded so the vault keeps working for new imports.
    func deleteAllVaultContent() {
        for item in coreDataManager.fetchAllVaultItems() {
            trashService.permanentlyDelete(item)
        }
        emptyStorageDirectories()
    }
    
    func cleanupFileStorage(vaultItem: VaultItem) {
        removeStoredFiles(for: vaultItem)
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
        guard vaultItem.fileName != nil else {
            throw FileStorageError.invalidFileName
        }

        vaultItem.fileName = newFileName
        vaultItem.updatedAt = Date()
        try coreDataManager.save()
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

    func sweepTemporaryShareFiles() {
        temporarySharingService.sweepAll()
    }
    
    func loadThumbnail(for vaultItem: VaultItem) -> Data? {
        if migrateItemOnDisk(vaultItem) {
            coreDataManager.persistChanges()
        }
        upgradeThumbnailIfPlaintext(vaultItem)
        guard let name = vaultItem.storedThumbnailName ?? vaultItem.thumbnailFileName else { return nil }
        guard let key = encryptionKey else { return nil }
        return try? encryptedThumbnailStore.read(fileName: name, key: key)
    }
    
    func loadImage(for vaultItem: VaultItem) async throws -> Data {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let fileData = try loadFile(vaultItem: vaultItem)
                VaultLog.debug(">>>>>>> DEBUG: File data loaded: \(fileData.count) bytes")
                continuation.resume(returning: fileData)
            } catch let error {
                VaultLog.debug(">>>>>>> DEBUG: Error loading image: \(error.localizedDescription)")
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
                if let name = existingVaultFileName(for: item) {
                    let fileURL = vaultDirectory.appendingPathComponent(name)
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
            VaultLog.debug("DEBUG: Error fetching storage info: \(error)")
            return (fileCount: 0, usedSpace: 0)
        }
    }
    
    // MARK: - Import from Photo Library
    
    func importFromPhotoLibrary(asset: PHAsset, targetFolder: Folder? = nil, completion: @escaping (Result<VaultItem, Error>) -> Void) {
        VaultLog.debug("DEBUG: Starting import for asset: \(asset.localIdentifier)")
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
            videoHandler: { url, fileName, fileType in
                do {
                    let item = try self.saveFile(
                        fromFileURL: url,
                        fileName: fileName,
                        fileType: fileType,
                        targetFolder: targetFolder
                    )
                    completion(.success(item))
                } catch {
                    completion(.failure(error))
                }
            },
            completion: completion
        )
    }
}

// MARK: - File Storage Cleanup

extension FileStorageManager {
    
    func clearAllStoredFiles() {
        VaultLog.debug("DEBUG: Clearing all stored files...")
        emptyStorageDirectories()
        encryptionKey = nil
        metadataSealer.key = nil
        VaultLog.debug("DEBUG: All stored files cleared")
    }
    
    func deleteAllStorageDirectories() {
        VaultLog.debug("DEBUG: Deleting all storage directories...")

        for directory in [vaultDirectory, thumbnailsDirectory] {
            do {
                if fileManager.fileExists(atPath: directory.path) {
                    try fileManager.removeItem(at: directory)
                }
                // Recreate empty so imports work without relaunching.
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            } catch {
                VaultLog.debug("ERROR: Failed to delete \(directory.lastPathComponent) directory: \(error)")
            }
        }

        setFileProtection()
        encryptionKey = nil
        metadataSealer.key = nil

        VaultLog.debug("DEBUG: All storage directories deleted")
    }

    /// Remove every file in the vault and thumbnail directories, leaving the directories in place.
    func emptyStorageDirectories() {
        for directory in [vaultDirectory, thumbnailsDirectory] {
            guard fileManager.fileExists(atPath: directory.path) else { continue }
            do {
                for fileURL in try fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) {
                    try fileManager.removeItem(at: fileURL)
                }
            } catch {
                VaultLog.debug("ERROR: Failed to clear \(directory.lastPathComponent) directory: \(error)")
            }
        }
    }
}

// MARK: - Errors

enum FileStorageError: LocalizedError, Equatable {
    case noEncryptionKey
    case encryptionFailed
    case decryptionFailed
    case invalidFileName
    case importFailed
    case duplicateFile
    case fileAlreadyExists
    case fileTooLarge
    case saveFailed
    case migrationFailed

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
        case .fileTooLarge:
            return "This file is larger than 2 GB and cannot be imported."
        case .saveFailed:
            return "Keepshire could not save this file."
        case .migrationFailed:
            return "Keepshire could not re-encrypt every file. The previous passcode is still in use."
        }
    }
} 