import CryptoKit
import Foundation
import Testing
@testable import Keepshire

@MainActor
@Suite(.serialized)
struct ReliabilityTests {
    @Test func saveWithoutChangesDoesNotThrow() throws {
        let manager = CoreDataManager(inMemory: true)
        try manager.save()
    }

    @Test func temporaryShareUsesUniqueDirectoryAndSweepRemovesIt() throws {
        let fileManager = FileManager.default
        let sharing = TemporarySharingService(fileManager: fileManager)
        sharing.sweepAll()
        let url = try sharing.prepare(data: Data("secret".utf8), fileName: "photo.jpg")
        #expect(url.path.contains(TemporarySharingService.directoryName))
        #expect(url.deletingLastPathComponent().lastPathComponent != TemporarySharingService.directoryName)
        #expect(fileManager.fileExists(atPath: url.path))
        sharing.sweepAll()
        #expect(!fileManager.fileExists(atPath: sharing.shareRoot().path))
    }

    @Test func cleanupRemovesShareSessionIfSheetNeverCompletes() throws {
        let sharing = TemporarySharingService(fileManager: .default)
        let url = try sharing.prepare(data: Data("plain".utf8), fileName: "note.txt")
        sharing.cleanup(at: url)
        #expect(!FileManager.default.fileExists(atPath: url.path))
        #expect(!FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path))
    }

    @Test func combinedBoxAndChunkedBlobsRoundTrip() throws {
        let crypto = VaultCryptoService()
        let record = VaultKeyDerivationRecord.makeCurrent()
        let key = try crypto.key(from: "chunk-key", record: record)
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let store = EncryptedFileStore(fileManager: .default, vaultDirectory: root, cryptoService: crypto)
        let small = Data("small combined box".utf8)
        try store.write(small, fileName: "small", key: key)
        let smallOnDisk = try Data(contentsOf: store.url(for: "small"))
        #expect(smallOnDisk.prefix(4) != VaultBlobFormat.magic)
        #expect(try store.read(fileName: "small", key: key) == small)

        store.plaintextChunkThreshold = 8
        let large = Data(repeating: 0x5A, count: 40)
        try store.write(large, fileName: "large", key: key)
        let largeOnDisk = try Data(contentsOf: store.url(for: "large"))
        #expect(largeOnDisk.prefix(4) == VaultBlobFormat.magic)
        #expect(try store.read(fileName: "large", key: key) == large)
    }

    @Test func saveFileFromURLMatchesDataImport() throws {
        let storage = try IsolatedTestDependencies()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "url-key")
        let payload = Data("from disk".utf8)
        let source = storage.rootURL.appendingPathComponent("source.bin")
        try payload.write(to: source)
        let item = try manager.saveFile(
            fromFileURL: source,
            fileName: "from-disk.bin",
            fileType: "application/octet-stream"
        )
        #expect(try manager.loadFile(vaultItem: item) == payload)
    }

    @Test func rejectedTooLargeImport() throws {
        #expect(VaultBlobFormat.hardCap == 2 * 1024 * 1024 * 1024)
    }

    @Test func migrateAbortsAndKeepsOldKeyWhenABlobIsCorrupt() async throws {
        let storage = try IsolatedTestDependencies()
        let manager = storage.fileStorageManager
        manager.setupEncryptionKey(from: "old-pass")
        let good = try manager.saveFile(
            data: Data("keep me".utf8),
            fileName: "good.txt",
            fileType: "text/plain"
        )
        let bad = try manager.saveFile(
            data: Data("break me".utf8),
            fileName: "bad.txt",
            fileType: "text/plain"
        )
        let blob = storage.rootURL
            .appendingPathComponent("Vault")
            .appendingPathComponent(bad.storedBlobName ?? "")
        try Data("not-a-sealed-box".utf8).write(to: blob)

        await #expect(throws: FileStorageError.migrationFailed) {
            try await manager.migrateFilesToNewEncryptionKey(
                oldPassword: "old-pass",
                newPassword: "new-pass"
            ) { _, _ in }
        }

        manager.setupEncryptionKey(from: "old-pass")
        #expect(try manager.loadFile(vaultItem: good) == Data("keep me".utf8))
    }
}
