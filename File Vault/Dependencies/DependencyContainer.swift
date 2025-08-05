//
//  DependencyContainer.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import CoreData
import Combine

/// Protocol definitions for manager dependencies
protocol CoreDataManaging {
    var context: NSManagedObjectContext { get }
    func save()
    func clearAllCoreData()
    func createFolder(name: String, parent: Folder?) -> Folder?
    func updateFolder(_ folder: Folder, name: String)
    func deleteFolder(_ folder: Folder)
    func createVaultItem(fileType: String, fileName: String, folder: Folder?) -> VaultItem?
    func deleteVaultItem(_ item: VaultItem)
    func fetchAllVaultItems() -> [VaultItem]
    func fetchVaultItemsFromAllFolders() -> [VaultItem]
    func fetchRootFolders() -> [Folder]
    func fetchVaultItems(in folder: Folder?) -> [VaultItem]
    func fetchFolders(in parent: Folder?) -> [Folder]
    func moveVaultItem(_ item: VaultItem, to folder: Folder?)
    func toggleFavorite(for item: VaultItem)
    func fetchFavoriteVaultItems() -> [VaultItem]
}

protocol FileStorageManaging {
    func saveFile(data: Data, fileName: String, fileType: String, targetFolder: Folder?) throws -> VaultItem
    func loadFile(vaultItem: VaultItem) throws -> Data
    func deleteFile(vaultItem: VaultItem) throws
    func permanentlyDeleteFile(vaultItem: VaultItem) throws
    func loadThumbnail(for vaultItem: VaultItem) -> Data?
    func loadImage(for vaultItem: VaultItem) async throws -> Data
    func determineFileType(from fileName: String) -> String
    func setupEncryptionKey(from password: String)
    func migrateFilesToNewEncryptionKey(oldPassword: String, newPassword: String, progress: @escaping (Int, Int) -> Void) async throws
    func toggleFavorite(for vaultItem: VaultItem)
    func fetchFavoriteItems() -> [VaultItem]
    func renameFile(vaultItem: VaultItem, newFileName: String) throws
    func prepareForSharing(vaultItem: VaultItem) throws -> URL
    func cleanupTemporaryFile(at url: URL)
    func clearAllStoredFiles()
    func getStorageInfo() -> (fileCount: Int, usedSpace: Int64)
}

protocol KeychainManaging {
    func savePassword(_ password: String) throws
    func getPassword() throws -> String
    func deletePassword() throws
    func validatePassword(_ password: String) -> (isValid: Bool, isFakeLogin: Bool)
    func isPasswordSet() -> Bool
    func setFakePassword(_ password: String) throws
    func deleteFakePassword() throws
    func isFakePasswordSet() -> Bool
    func setBiometricEnabled(_ enabled: Bool)
    func isBiometricEnabled() -> Bool
    func setAuthenticationType(_ type: AuthenticationType)
    func getAuthenticationType() -> AuthenticationType
    func isAuthenticationTypeSet() -> Bool
    func setLockTimeout(_ timeout: Int)
    func getLockTimeout() -> Int
    func setLastBackgroundTime()
    func clearLastBackgroundTime()
    func shouldRequireAuthentication() -> Bool
    func clearAllKeychainData()
}

protocol BiometricAuthManaging: ObservableObject {
    func canUseBiometrics() -> Bool
    func biometricType() -> BiometricType
    func authenticateWithBiometrics(reason: String, completion: @escaping (Bool, Error?) -> Void)
    func resetFailureCount()
}

protocol LoginStateManaging: ObservableObject {
    var isFakeLogin: Bool { get }
    var canAddFiles: Bool { get }
    var canCreateFolders: Bool { get }
    var canChangePassword: Bool { get }
    var canAccessFullSettings: Bool { get }
    var shouldShowEmptyVault: Bool { get }
    var emptyVaultItems: [VaultItem] { get }
    var emptyFolders: [Folder] { get }
    var visibleSettingSections: [SettingsSection] { get }
    
    func setLoginState(isFakeLogin: Bool)
    func resetLoginState()
}

protocol SecurityManaging: ObservableObject {
    var isScreenshotProtectionEnabled: Bool { get set }
    var isRecordingProtectionEnabled: Bool { get set }
    var isShakeToLockEnabled: Bool { get set }
    var isFlipToLockEnabled: Bool { get set }
    
    func activateScreenProtection()
    func deactivateScreenProtection()
    func lockApp()
    func saveSettings()
    func loadSettings()
}

protocol WebServerManaging: ObservableObject {
    var isRunning: Bool { get }
    var serverURL: String { get }
    var connectedDevices: [String] { get }
    var isDownloadEnabled: Bool { get set }
    
    func startServer()
    func stopServer()
    func setDownloadEnabled(_ enabled: Bool)
}

protocol AppDataManaging {
    var isFirstLaunch: Bool { get }
    func markAppAsLaunched()
    func performFirstLaunchCleanup()
    func clearAllAppData()
    func performCompleteAppReset()
}

/// Dependency container that manages all app dependencies
final class DependencyContainer: ObservableObject {
    // MARK: - Singleton Instance
    static let shared = DependencyContainer()
    
    // MARK: - Manager Instances
    private let _coreDataManager: CoreDataManaging
    private let _fileStorageManager: FileStorageManaging
    private let _keychainManager: KeychainManaging
    private let _biometricAuthManager: any BiometricAuthManaging
    private let _loginStateManager: any LoginStateManaging
    private let _securityManager: any SecurityManaging
    private let _webServerManager: any WebServerManaging
    private let _appDataManager: AppDataManaging
    
    // MARK: - Initialization
    private init(
        coreDataManager: CoreDataManaging? = nil,
        fileStorageManager: FileStorageManaging? = nil,
        keychainManager: KeychainManaging? = nil,
        biometricAuthManager: (any BiometricAuthManaging)? = nil,
        loginStateManager: (any LoginStateManaging)? = nil,
        securityManager: (any SecurityManaging)? = nil,
        webServerManager: (any WebServerManaging)? = nil,
        appDataManager: AppDataManaging? = nil
    ) {
        // Use provided dependencies or fall back to concrete implementations
        self._coreDataManager = coreDataManager ?? CoreDataManager.shared
        self._fileStorageManager = fileStorageManager ?? FileStorageManager.shared
        self._keychainManager = keychainManager ?? KeychainManager.shared
        self._biometricAuthManager = biometricAuthManager ?? BiometricAuthManager.shared
        self._loginStateManager = loginStateManager ?? LoginStateManager.shared
        self._securityManager = securityManager ?? SecurityManager.shared
        self._webServerManager = webServerManager ?? WebServerManager.shared
        self._appDataManager = appDataManager ?? AppDataManager.shared
    }
    
    // MARK: - Dependency Access
    var coreDataManager: CoreDataManaging { _coreDataManager }
    var fileStorageManager: FileStorageManaging { _fileStorageManager }
    var keychainManager: KeychainManaging { _keychainManager }
    var biometricAuthManager: any BiometricAuthManaging { _biometricAuthManager }
    var loginStateManager: any LoginStateManaging { _loginStateManager }
    var securityManager: any SecurityManaging { _securityManager }
    var webServerManager: any WebServerManaging { _webServerManager }
    var appDataManager: AppDataManaging { _appDataManager }
    
    // MARK: - Testing Support
    static func createForTesting(
        coreDataManager: CoreDataManaging? = nil,
        fileStorageManager: FileStorageManaging? = nil,
        keychainManager: KeychainManaging? = nil,
        biometricAuthManager: (any BiometricAuthManaging)? = nil,
        loginStateManager: (any LoginStateManaging)? = nil,
        securityManager: (any SecurityManaging)? = nil,
        webServerManager: (any WebServerManaging)? = nil,
        appDataManager: AppDataManaging? = nil
    ) -> DependencyContainer {
        return DependencyContainer(
            coreDataManager: coreDataManager,
            fileStorageManager: fileStorageManager,
            keychainManager: keychainManager,
            biometricAuthManager: biometricAuthManager,
            loginStateManager: loginStateManager,
            securityManager: securityManager,
            webServerManager: webServerManager,
            appDataManager: appDataManager
        )
    }
}

/// SwiftUI Environment Key for dependency injection
struct DependencyContainerKey: EnvironmentKey {
    static let defaultValue: DependencyContainer = DependencyContainer.shared
}

extension EnvironmentValues {
    var dependencies: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}

/// Convenient view modifier for injecting dependencies
extension View {
    func dependencies(_ container: DependencyContainer) -> some View {
        environment(\.dependencies, container)
    }
}