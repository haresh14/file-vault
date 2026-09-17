import Foundation
import CoreData
import Combine
import PhotosUI
@testable import Keepshire

@MainActor
enum TestCoreDataStore {
    /// Suites run in parallel, so every test gets its own in-memory stack rather than
    /// sharing one store that other suites can wipe mid-test.
    static func reset() -> CoreDataManager {
        CoreDataManager(inMemory: true)
    }
}

@MainActor
final class IsolatedTestDependencies {
    let rootURL: URL
    let defaults: UserDefaults
    let keychainManager: KeychainManager
    let coreDataManager: CoreDataManager
    let fileStorageManager: FileStorageManager
    let securityManager: SecurityManager

    private let defaultsSuiteName: String
    private let previousTrashSetting: Any?

    init() throws {
        defaultsSuiteName = "KeepshireTests-\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: defaultsSuiteName)!
        keychainManager = KeychainManager(service: defaultsSuiteName, defaults: defaults)
        securityManager = SecurityManager(defaults: defaults)
        // A private stack per test: the metadata sealer binds to one store at a time.
        coreDataManager = CoreDataManager(inMemory: true)

        rootURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(defaultsSuiteName, isDirectory: true)
        try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: true)
        fileStorageManager = FileStorageManager(
            documentsDirectory: rootURL,
            coreDataManager: coreDataManager,
            keyDerivationStore: KeychainVaultKeyDerivationStore(keychain: keychainManager)
        )

        previousTrashSetting = UserDefaults.standard.object(forKey: "trashEnabled")
        UserDefaults.standard.set(false, forKey: "trashEnabled")
    }

    deinit {
        try? keychainManager.deletePassword()
        try? keychainManager.deleteFakePassword()
        keychainManager.deleteKeyDerivationRecord()
        defaults.removePersistentDomain(forName: defaultsSuiteName)
        try? FileManager.default.removeItem(at: rootURL)

        if let previousTrashSetting {
            UserDefaults.standard.set(previousTrashSetting, forKey: "trashEnabled")
        } else {
            UserDefaults.standard.removeObject(forKey: "trashEnabled")
        }
    }
}

final class FakeLoginStateManager: ObservableObject, LoginStateManaging {
    @Published var isFakeLogin = false
    var canAddFiles: Bool { !isFakeLogin }
    var canCreateFolders: Bool { !isFakeLogin }
    var canChangePassword: Bool { !isFakeLogin }
    var canAccessFullSettings: Bool { !isFakeLogin }
    var shouldShowEmptyVault: Bool { isFakeLogin }
    var emptyVaultItems: [VaultItem] { [] }
    var emptyFolders: [Folder] { [] }
    var visibleSettingSections: [SettingsSection] { [] }
    func setLoginState(isFakeLogin: Bool) { self.isFakeLogin = isFakeLogin }
    func resetLoginState() { isFakeLogin = false }
}

final class FakeVaultImportService: VaultImportServicing {
    private(set) var assetTargetFolder: Folder?
    private(set) var documentTargetFolder: Folder?
    private(set) var importedDocumentNames: [String] = []

    func importAssets(
        _ results: [PHPickerResult],
        targetFolder: Folder?,
        progress: @escaping (Double, Double) -> Void,
        completion: @escaping () -> Void
    ) {
        assetTargetFolder = targetFolder
        progress(Double(results.count), Double(results.count))
        completion()
    }

    func importDocuments(
        _ documents: [(Data, String)],
        targetFolder: Folder?,
        progress: @escaping (Double, Double) -> Void,
        completion: @escaping () -> Void
    ) {
        documentTargetFolder = targetFolder
        importedDocumentNames = documents.map(\.1)
        for index in documents.indices {
            progress(Double(index + 1), Double(documents.count))
        }
        completion()
    }
}

final class FakeFileStorageManager: FileStorageManaging {
    struct Save {
        let data: Data
        let fileName: String
        let fileType: String
        let targetFolder: Folder?
    }

    private(set) var saves: [Save] = []
    private(set) var encryptionPasswords: [String] = []
    var duplicateFileNames: Set<String> = []
    private let coreDataManager: CoreDataManager

    init(coreDataManager: CoreDataManager) {
        self.coreDataManager = coreDataManager
    }

    func saveFile(data: Data, fileName: String, fileType: String, targetFolder: Folder?) throws -> VaultItem {
        saves.append(Save(data: data, fileName: fileName, fileType: fileType, targetFolder: targetFolder))
        if duplicateFileNames.contains(fileName) { throw FileStorageError.duplicateFile }
        return coreDataManager.createVaultItem(fileType: fileType, fileName: fileName, folder: targetFolder)!
    }

    func loadFile(vaultItem: VaultItem) throws -> Data { Data() }
    func deleteFile(vaultItem: VaultItem) throws {}
    func permanentlyDeleteFile(vaultItem: VaultItem) throws {}
    func loadThumbnail(for vaultItem: VaultItem) -> Data? { nil }
    func loadImage(for vaultItem: VaultItem) async throws -> Data { Data() }
    func determineFileType(from fileName: String) -> String {
        fileName.hasSuffix(".pdf") ? "application/pdf" : "application/octet-stream"
    }
    func setupEncryptionKey(from password: String) { encryptionPasswords.append(password) }
    func migrateFilesToNewEncryptionKey(
        oldPassword: String,
        newPassword: String,
        progress: @escaping (Int, Int) -> Void
    ) async throws {}
    func toggleFavorite(for vaultItem: VaultItem) { vaultItem.isFavorite.toggle() }
    func fetchFavoriteItems() -> [VaultItem] { [] }
    func renameFile(vaultItem: VaultItem, newFileName: String) throws {}
    func prepareForSharing(vaultItem: VaultItem) throws -> URL { URL(fileURLWithPath: "/tmp/test") }
    func cleanupTemporaryFile(at url: URL) {}
    func clearAllStoredFiles() {}
    func getStorageInfo() -> (fileCount: Int, usedSpace: Int64) { (0, 0) }
}
