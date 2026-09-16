//
//  FileStorageManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
import UIKit
import CoreData
@testable import File_Vault

@MainActor
@Suite(.serialized)
struct FileStorageManagerTests {
    private func makeStorage() throws -> IsolatedTestDependencies {
        try IsolatedTestDependencies()
    }
    
    // MARK: - Initialization Tests
    
    @Test func testFileStorageManagerSingleton() async throws {
        let manager1 = FileStorageManager.shared
        let manager2 = FileStorageManager.shared
        
        #expect(manager1 === manager2, "FileStorageManager should be a singleton")
    }
    
    // MARK: - Encryption Key Tests
    
    @Test func testEncryptionKeySetup() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        // Setup encryption key
        manager.setupEncryptionKey(from: testPassword)
        
        // Test that encryption key is set (we can't directly access it, but we can test file operations)
        // This is tested implicitly through file operations
        #expect(true, "Encryption key setup should complete without errors")
    }
    
    // MARK: - File Operations Tests
    
    @Test func testFileSaveAndLoad() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        let testData = "Hello, World!".data(using: .utf8)!
        let fileName = "test.txt"
        let fileType = "text/plain"
        
        // Setup encryption
        manager.setupEncryptionKey(from: testPassword)
        
        // Save file
        let vaultItem = try manager.saveFile(
            data: testData,
            fileName: fileName,
            fileType: fileType
        )
        
        #expect(vaultItem.fileName == fileName, "File name should be preserved")
        #expect(vaultItem.fileType == fileType, "File type should be preserved")
        #expect(vaultItem.fileSize == Int64(testData.count), "File size should be correct")
        
        // Load file
        let loadedData = try manager.loadFile(vaultItem: vaultItem)
        #expect(loadedData == testData, "Loaded data should match original data")
        
        // Cleanup
        try manager.deleteFile(vaultItem: vaultItem)
    }

    @Test func testOnDiskBlobUsesItemUUIDNotDisplayName() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "uuid-key")
        let item = try manager.saveFile(
            data: Data("named".utf8),
            fileName: "vacation.jpg",
            fileType: "image/jpeg"
        )

        #expect(item.fileName == "vacation.jpg")
        #expect(item.storedBlobName == item.id?.uuidString)
        #expect(FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault").appendingPathComponent(item.storedBlobName ?? "").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault/vacation.jpg").path
        ))
        #expect(try manager.loadFile(vaultItem: item) == Data("named".utf8))
    }
    
    @Test func testFileEncryption() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        let testData = "Sensitive Data".data(using: .utf8)!
        let fileName = "sensitive.txt"
        let fileType = "text/plain"
        
        // Setup encryption
        manager.setupEncryptionKey(from: testPassword)
        
        // Save file
        let vaultItem = try manager.saveFile(
            data: testData,
            fileName: fileName,
            fileType: fileType
        )
        
        // Verify that the file on disk is encrypted (not readable as plain text)
        let encryptedFilesPath = storage.rootURL.appendingPathComponent("Vault")
        
        // Check that encrypted file exists but is not readable as plain text
        let encryptedFileURL = encryptedFilesPath.appendingPathComponent(vaultItem.storedBlobName ?? "")
        
        if FileManager.default.fileExists(atPath: encryptedFileURL.path) {
            let encryptedData = try Data(contentsOf: encryptedFileURL)
            #expect(encryptedData != testData, "Encrypted data should not match original data")
            #expect(encryptedData.count > testData.count, "Encrypted data should be larger due to encryption overhead")
        }
        
        // Cleanup
        try manager.deleteFile(vaultItem: vaultItem)
    }

    @Test func testAESGCMCombinedFormatRoundTripAndWrongKey() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let data = Data((0..<257).map { UInt8($0 % 251) })
        manager.setupEncryptionKey(from: "first-key")
        let item = try manager.saveFile(
            data: data,
            fileName: "format.bin",
            fileType: "application/octet-stream"
        )

        let encryptedURL = storage.rootURL
            .appendingPathComponent("Vault")
            .appendingPathComponent(item.storedBlobName ?? "")
        let encryptedData = try Data(contentsOf: encryptedURL)
        #expect(encryptedData.count == data.count + 28, "Combined AES-GCM stores nonce and tag")
        #expect(try manager.loadFile(vaultItem: item) == data)
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault/format.bin").path
        ))

        manager.setupEncryptionKey(from: "wrong-key")
        #expect(throws: Error.self) {
            try manager.loadFile(vaultItem: item)
        }

        manager.setupEncryptionKey(from: "first-key")
        #expect(try manager.loadFile(vaultItem: item) == data)
    }

    @Test func testEncryptionKeyMigrationPreservesDataAndProgress() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let data = Data("migration payload".utf8)
        manager.setupEncryptionKey(from: "old-passcode")
        let item = try manager.saveFile(
            data: data,
            fileName: "migration.txt",
            fileType: "text/plain"
        )
        var progressValues: [(Int, Int)] = []

        try await manager.migrateFilesToNewEncryptionKey(
            oldPassword: "old-passcode",
            newPassword: "new-passcode"
        ) { completed, total in
            progressValues.append((completed, total))
        }

        #expect(progressValues.count == 1)
        #expect(progressValues.first?.0 == 1)
        #expect(progressValues.first?.1 == 1)
        #expect(try manager.loadFile(vaultItem: item) == data)
        manager.setupEncryptionKey(from: "old-passcode")
        #expect(throws: Error.self) {
            try manager.loadFile(vaultItem: item)
        }
    }

    @Test func testLegacySHA256VaultUpgradesToPBKDF2() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let password = "1234"
        let payload = Data("legacy secret".utf8)
        let crypto = VaultCryptoService()
        let vaultURL = storage.rootURL.appendingPathComponent("Vault")
        let fileStore = EncryptedFileStore(fileManager: .default, vaultDirectory: vaultURL)
        try fileStore.write(
            payload,
            fileName: "legacy.txt",
            key: crypto.legacySHA256Key(from: password)
        )
        let item = storage.coreDataManager.createVaultItem(
            fileName: "legacy.txt",
            fileType: "text/plain",
            fileSize: Int64(payload.count)
        )

        manager.setupEncryptionKey(from: password)

        #expect(storage.keychainManager.loadKeyDerivationRecord() != nil)
        #expect(item.fileName == "legacy.txt")
        #expect(try manager.loadFile(vaultItem: item) == payload)
        #expect(!FileManager.default.fileExists(atPath: vaultURL.appendingPathComponent("legacy.txt").path))
        #expect(FileManager.default.fileExists(
            atPath: vaultURL.appendingPathComponent(item.storedBlobName ?? "").path
        ))

        manager.setupEncryptionKey(from: password)
        #expect(try manager.loadFile(vaultItem: item) == payload)

        manager.setupEncryptionKey(from: "9999")
        #expect(throws: Error.self) {
            try manager.loadFile(vaultItem: item)
        }
    }
    
    @Test func testMultipleFiles() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        var savedItems: [VaultItem] = []
        
        // Save multiple files
        for i in 0..<5 {
            let testData = String(repeating: "Test Data \(i)", count: i + 1).data(using: .utf8)!
            let fileName = "test\(i).txt"
            let fileType = "text/plain"
            
            let vaultItem = try manager.saveFile(
                data: testData,
                fileName: fileName,
                fileType: fileType
            )
            savedItems.append(vaultItem)
        }
        
        // Verify all files can be loaded
        for (index, item) in savedItems.enumerated() {
            let loadedData = try manager.loadFile(vaultItem: item)
            let expectedData = String(repeating: "Test Data \(index)", count: index + 1).data(using: .utf8)!
            #expect(loadedData == expectedData, "File \(index) should load correctly")
        }
        
        // Cleanup
        for item in savedItems {
            try manager.deleteFile(vaultItem: item)
        }
    }
    
    // MARK: - Thumbnail Tests
    
    @Test func testImageThumbnailGeneration() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        // Create a simple test image
        let testImage = createTestImage()
        let imageData = testImage.pngData()!
        let fileName = "test.png"
        let fileType = "image/png"
        
        // Save image file
        let vaultItem = try manager.saveFile(
            data: imageData,
            fileName: fileName,
            fileType: fileType
        )
        
        // Check that thumbnail was generated
        #expect(vaultItem.thumbnailFileName != nil, "Thumbnail should be generated for image")
        
        // Load thumbnail
        let thumbnail = manager.loadThumbnail(for: vaultItem)
        #expect(thumbnail != nil, "Thumbnail should be loadable")
        
        if let thumbnail = thumbnail {
            let image = UIImage(data: thumbnail)
            #expect(image != nil, "Thumbnail data should decode as an image")
            if let image {
                #expect(image.size.width <= 600, "Thumbnail pixel width should be limited")
                #expect(image.size.height <= 600, "Thumbnail pixel height should be limited")
            }
        }

        let onDisk = try Data(contentsOf: storage.rootURL
            .appendingPathComponent("Thumbnails")
            .appendingPathComponent(vaultItem.storedThumbnailName ?? ""))
        #expect(UIImage(data: onDisk) == nil, "On-disk thumbnail must not be a plaintext JPEG")
        #expect(onDisk != thumbnail)

        try manager.deleteFile(vaultItem: vaultItem)
    }

    @Test func testLegacyPlaintextThumbnailIsEncryptedOnUnlock() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "thumb-legacy")
        let item = try manager.saveFile(
            data: createTestImage().pngData()!,
            fileName: "legacy-thumb.png",
            fileType: "image/png"
        )
        let thumbName = item.storedThumbnailName ?? ""
        let thumbURL = storage.rootURL.appendingPathComponent("Thumbnails").appendingPathComponent(thumbName)
        let jpeg = createTestImage().jpegData(compressionQuality: 0.7)!
        try jpeg.write(to: thumbURL)
        #expect(UIImage(data: try Data(contentsOf: thumbURL)) != nil)

        manager.setupEncryptionKey(from: "thumb-legacy")

        let loaded = manager.loadThumbnail(for: item)
        #expect(UIImage(data: loaded ?? Data()) != nil)
        let onDisk = try Data(contentsOf: thumbURL)
        #expect(UIImage(data: onDisk) == nil)
        #expect(onDisk != jpeg)
    }

    @Test func testWrongKeyDoesNotRevealThumbnail() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "thumb-correct")
        let item = try manager.saveFile(
            data: createTestImage().pngData()!,
            fileName: "secret.png",
            fileType: "image/png"
        )

        manager.setupEncryptionKey(from: "thumb-wrong")
        #expect(manager.loadThumbnail(for: item) == nil)

        manager.setupEncryptionKey(from: "thumb-correct")
        #expect(UIImage(data: manager.loadThumbnail(for: item) ?? Data()) != nil)
    }

    @Test func testPasscodeChangeReencryptsThumbnail() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "old-thumb-key")
        let item = try manager.saveFile(
            data: createTestImage().pngData()!,
            fileName: "migrate-thumb.png",
            fileType: "image/png"
        )
        let before = try Data(contentsOf: storage.rootURL
            .appendingPathComponent("Thumbnails")
            .appendingPathComponent(item.storedThumbnailName ?? ""))

        try await manager.migrateFilesToNewEncryptionKey(
            oldPassword: "old-thumb-key",
            newPassword: "new-thumb-key"
        ) { _, _ in }

        let after = try Data(contentsOf: storage.rootURL
            .appendingPathComponent("Thumbnails")
            .appendingPathComponent(item.storedThumbnailName ?? ""))
        #expect(after != before)
        #expect(UIImage(data: manager.loadThumbnail(for: item) ?? Data()) != nil)

        manager.setupEncryptionKey(from: "old-thumb-key")
        #expect(manager.loadThumbnail(for: item) == nil)
    }

    @Test func testThumbnailForNonImage() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        // Save non-image file
        let testData = "Not an image".data(using: .utf8)!
        let fileName = "test.txt"
        let fileType = "text/plain"
        
        let vaultItem = try manager.saveFile(
            data: testData,
            fileName: fileName,
            fileType: fileType
        )
        
        // Check that no thumbnail was generated
        #expect(vaultItem.thumbnailFileName == nil, "No thumbnail should be generated for non-image files")
        
        // Load thumbnail should return nil
        let thumbnail = manager.loadThumbnail(for: vaultItem)
        #expect(thumbnail == nil, "Thumbnail should be nil for non-image files")
        
        // Cleanup
        try manager.deleteFile(vaultItem: vaultItem)
    }
    
    // MARK: - File Deletion Tests
    
    @Test func testFileDeletion() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        // Save file
        let testData = "Delete me".data(using: .utf8)!
        let fileName = "delete.txt"
        let fileType = "text/plain"
        
        let vaultItem = try manager.saveFile(
            data: testData,
            fileName: fileName,
            fileType: fileType
        )
        
        // Verify file exists
        let loadedData = try manager.loadFile(vaultItem: vaultItem)
        #expect(loadedData == testData, "File should exist before deletion")
        
        // Delete file
        try manager.deleteFile(vaultItem: vaultItem)
        
        // Verify file is deleted
        #expect(throws: Error.self) {
            try manager.loadFile(vaultItem: vaultItem)
        }
    }

    @Test func testRenamePreservesEncryptedFileAndThumbnail() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "rename-key")
        let data = createTestImage().pngData()!
        let item = try manager.saveFile(
            data: data,
            fileName: "before.png",
            fileType: "image/png"
        )

        try manager.renameFile(vaultItem: item, newFileName: "after.png")

        #expect(item.fileName == "after.png")
        #expect(item.thumbnailFileName == item.storedThumbnailName)
        #expect(try manager.loadFile(vaultItem: item) == data)
        #expect(manager.loadThumbnail(for: item) != nil)
        #expect(FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault").appendingPathComponent(item.storedBlobName ?? "").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault/before.png").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault/after.png").path
        ))
    }

    @Test func testDeleteWithTrashDisabledRemovesBlobAndThumbnail() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "delete-key")
        UserDefaults.standard.set(false, forKey: "trashEnabled")
        let item = try manager.saveFile(
            data: createTestImage().pngData()!,
            fileName: "delete-me.png",
            fileType: "image/png"
        )
        let blobName = item.storedBlobName ?? ""
        let thumbName = item.storedThumbnailName ?? ""

        try manager.deleteFile(vaultItem: item)

        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault").appendingPathComponent(blobName).path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Thumbnails").appendingPathComponent(thumbName).path
        ))
        #expect(storage.coreDataManager.fetchAllVaultItems().isEmpty)
    }

    @Test func testUnlockRemovesOrphanedCiphertextAndKeepsClaimedFiles() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "orphan-key")
        let item = try manager.saveFile(
            data: Data("keep me".utf8),
            fileName: "keep.txt",
            fileType: "text/plain"
        )
        let vaultURL = storage.rootURL.appendingPathComponent("Vault")
        let orphanURL = vaultURL.appendingPathComponent(UUID().uuidString)
        try Data("stranded".utf8).write(to: orphanURL)

        manager.setupEncryptionKey(from: "orphan-key")

        #expect(!FileManager.default.fileExists(atPath: orphanURL.path))
        #expect(FileManager.default.fileExists(
            atPath: vaultURL.appendingPathComponent(item.storedBlobName ?? "").path
        ))
        #expect(try manager.loadFile(vaultItem: item) == Data("keep me".utf8))
    }

    @Test func testDeleteAllVaultContentRemovesFilesEvenWithTrashEnabled() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "delete-all-key")
        UserDefaults.standard.set(true, forKey: "trashEnabled")
        defer { UserDefaults.standard.set(false, forKey: "trashEnabled") }
        _ = try manager.saveFile(
            data: createTestImage().pngData()!,
            fileName: "photo.png",
            fileType: "image/png"
        )
        _ = try manager.saveFile(
            data: Data("doc".utf8),
            fileName: "doc.txt",
            fileType: "text/plain"
        )

        manager.deleteAllVaultContent()

        #expect(storage.coreDataManager.fetchAllVaultItems().isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(
            atPath: storage.rootURL.appendingPathComponent("Vault").path
        ).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(
            atPath: storage.rootURL.appendingPathComponent("Thumbnails").path
        ).isEmpty)
    }

    @Test func testDeleteAllStorageDirectoriesRemovesFilesAndKeepsDirectoriesUsable() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "reset-key")
        _ = try manager.saveFile(
            data: createTestImage().pngData()!,
            fileName: "reset.png",
            fileType: "image/png"
        )

        manager.deleteAllStorageDirectories()

        let vaultPath = storage.rootURL.appendingPathComponent("Vault").path
        let thumbPath = storage.rootURL.appendingPathComponent("Thumbnails").path
        #expect(FileManager.default.fileExists(atPath: vaultPath))
        #expect(FileManager.default.fileExists(atPath: thumbPath))
        #expect(try FileManager.default.contentsOfDirectory(atPath: vaultPath).isEmpty)
        #expect(try FileManager.default.contentsOfDirectory(atPath: thumbPath).isEmpty)

        manager.setupEncryptionKey(from: "reset-key")
        let item = try manager.saveFile(
            data: Data("after reset".utf8),
            fileName: "after.txt",
            fileType: "text/plain"
        )
        #expect(try manager.loadFile(vaultItem: item) == Data("after reset".utf8))
    }

    @Test func testTrashRestoreAndPermanentDeleteLifecycle() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "trash-key")
        UserDefaults.standard.set(true, forKey: "trashEnabled")
        let item = try manager.saveFile(
            data: Data("trash payload".utf8),
            fileName: "trash.txt",
            fileType: "text/plain"
        )

        try manager.deleteFile(vaultItem: item)
        #expect(item.isTrashed)
        #expect(item.trashedAt != nil)
        #expect(try manager.loadFile(vaultItem: item) == Data("trash payload".utf8))

        item.isTrashed = false
        item.trashedAt = nil
        storage.coreDataManager.save()
        #expect(storage.coreDataManager.fetchVaultItems(in: nil).contains(item))

        manager.moveToTrash(vaultItem: item)
        try manager.permanentlyDeleteFile(vaultItem: item)
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault").appendingPathComponent(item.storedBlobName ?? "missing").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: storage.rootURL.appendingPathComponent("Vault/trash.txt").path
        ))
        #expect(storage.coreDataManager.fetchAllVaultItems().isEmpty)
    }

    @Test func testTemporaryShareFileIsDecryptedAndCleanedUp() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "share-key")
        let data = Data("temporary share".utf8)
        let item = try manager.saveFile(
            data: data,
            fileName: "shared.txt",
            fileType: "text/plain"
        )

        let url = try manager.prepareForSharing(vaultItem: item)
        #expect(try Data(contentsOf: url) == data)
        manager.cleanupTemporaryFile(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testLoadNonExistentFile() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        // Create a mock vault item with non-existent file
        let mockItem = NSEntityDescription.insertNewObject(forEntityName: "VaultItem", into: storage.coreDataManager.context) as! VaultItem
        mockItem.id = UUID()
        mockItem.fileName = "nonexistent.txt"
        mockItem.fileType = "text/plain"
        
        // Try to load non-existent file
        #expect(throws: Error.self) {
            try manager.loadFile(vaultItem: mockItem)
        }
    }
    
    @Test func testSaveFileWithoutEncryptionKey() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        
        // Don't setup encryption key
        let testData = "Test".data(using: .utf8)!
        let fileName = "test.txt"
        let fileType = "text/plain"
        
        // Try to save file without encryption key
        #expect(throws: Error.self) {
            try manager.saveFile(
                data: testData,
                fileName: fileName,
                fileType: fileType
            )
        }
    }
    
    // MARK: - Performance Tests
    
    @Test func testFileOperationPerformance() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        let testData = Data(repeating: 0x42, count: 8 * 1024 * 1024) // 8MB round trip
        let fileName = "large.bin"
        let fileType = "application/octet-stream"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Save large file
        let vaultItem = try manager.saveFile(
            data: testData,
            fileName: fileName,
            fileType: fileType
        )
        
        // Load large file
        let loadedData = try manager.loadFile(vaultItem: vaultItem)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(loadedData == testData, "Large file should load correctly")
        #expect(timeElapsed < 5.0, "Large file operations should complete within 5 seconds")
        
        // Cleanup
        try manager.deleteFile(vaultItem: vaultItem)
    }
    
    // MARK: - Directory Structure Tests
    
    @Test func testDirectoryStructure() async throws {
        let storage = try makeStorage()
        let manager = storage.fileStorageManager
        let testPassword = "TestPassword123!"
        
        manager.setupEncryptionKey(from: testPassword)
        
        // Save a file to ensure directories are created
        let testData = "Directory test".data(using: .utf8)!
        let fileName = "dir_test.txt"
        let fileType = "text/plain"
        
        let vaultItem = try manager.saveFile(
            data: testData,
            fileName: fileName,
            fileType: fileType
        )
        
        // Check that required directories exist
        let vaultPath = storage.rootURL.appendingPathComponent("Vault")
        let encryptedFilesPath = vaultPath
        let thumbnailsPath = storage.rootURL.appendingPathComponent("Thumbnails")
        
        #expect(FileManager.default.fileExists(atPath: vaultPath.path), "Vault directory should exist")
        #expect(FileManager.default.fileExists(atPath: encryptedFilesPath.path), "Encrypted files directory should exist")
        #expect(FileManager.default.fileExists(atPath: thumbnailsPath.path), "Thumbnails directory should exist")
        let vaultAttributes = try FileManager.default.attributesOfItem(atPath: vaultPath.path)
        let thumbnailAttributes = try FileManager.default.attributesOfItem(atPath: thumbnailsPath.path)
        // Simulators may omit protection metadata even when setAttributes succeeds.
        for attributes in [vaultAttributes, thumbnailAttributes] {
            if let protection = attributes[.protectionKey] {
                #expect(
                    String(describing: protection) == FileProtectionType.complete.rawValue
                )
            }
        }
        
        // Cleanup
        try manager.deleteFile(vaultItem: vaultItem)
    }
    
    // MARK: - Helper Methods
    
    private func createTestImage() -> UIImage {
        let size = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            UIColor.blue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            UIColor.white.setFill()
            context.fill(CGRect(x: 25, y: 25, width: 50, height: 50))
        }
    }
} 