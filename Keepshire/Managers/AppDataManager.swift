//
//  AppDataManager.swift
//  Keepshire
//
//  Created on [Date].
//

import Foundation
import Photos

class AppDataManager: AppDataManaging {
    static let shared = AppDataManager()
    
    private let hasLaunchedBeforeKey = "hasLaunchedBefore"
    
    private init() {}
    
    // MARK: - First Launch Detection
    
    var isFirstLaunch: Bool {
        return !UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
    }
    
    func markAppAsLaunched() {
        UserDefaults.standard.set(true, forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.synchronize()
        VaultLog.debug("DEBUG: App marked as launched before")
    }
    
    // MARK: - Complete App Reset
    
    func performFirstLaunchCleanup() {
        VaultLog.debug("DEBUG: 🚀 Performing first launch cleanup - clearing all stored data...")
        
        // Clear all data types
        clearAllAppData()
        
        // Set default app preferences for new installations
        setDefaultAppPreferences()
        
        // Mark that we've done the cleanup
        markAppAsLaunched()
        
        VaultLog.debug("DEBUG: ✅ First launch cleanup completed")
    }
    
    func clearAllAppData() {
        VaultLog.debug("DEBUG: 🧹 Starting complete app data cleanup...")
        
        // 1. Clear file storage first so vault bytes never outlive the metadata
        FileStorageManager.shared.clearAllStoredFiles()
        
        // 2. Clear Keychain data
        KeychainManager.shared.clearAllKeychainData()
        
        // 3. Clear UserDefaults data (except the launch flag)
        clearUserDefaultsExceptLaunchFlag()
        
        // 4. Clear Core Data
        CoreDataManager.shared.clearAllCoreData()
        
        // 5. Reset biometric failure state
        BiometricAuthManager.shared.resetFailureCount()
        
        // 6. Clear any permission-related cached state (Photos framework doesn't allow programmatic permission reset)
        // The user will be re-prompted for permissions naturally
        
        VaultLog.debug("DEBUG: ✅ Complete app data cleanup finished")
    }
    
    // MARK: - Default Preferences
    
    private func setDefaultAppPreferences() {
        VaultLog.debug("DEBUG: Setting default app preferences...")
        
        // Enable trash by default for new installations
        UserDefaults.standard.set(true, forKey: "trashEnabled")
        UserDefaults.standard.synchronize()
        
        VaultLog.debug("DEBUG: ✅ Default preferences set - trash enabled by default")
    }
    
    // MARK: - Nuclear Option - Complete Reset
    
    func performCompleteAppReset() {
        VaultLog.debug("DEBUG: 💥 Performing COMPLETE app reset - deleting all files and data...")
        
        // 1. Delete all storage directories first: removing the Core Data store can tear down
        // live fetches, and vault bytes must not survive that.
        FileStorageManager.shared.deleteAllStorageDirectories()
        
        // 2. Clear Keychain data
        KeychainManager.shared.clearAllKeychainData()
        
        // 3. Clear ALL UserDefaults data (including launch flag to trigger fresh setup)
        clearAllUserDefaults()
        
        // 4. Delete Core Data store files completely
        CoreDataManager.shared.deleteCoreDataStore()
        
        // 5. Reset biometric failure state
        BiometricAuthManager.shared.resetFailureCount()
        
        VaultLog.debug("DEBUG: ✅ Complete app reset finished - app will behave as fresh install")
    }
    
    // MARK: - Private Helper Methods
    
    private func clearUserDefaultsExceptLaunchFlag() {
        VaultLog.debug("DEBUG: Clearing UserDefaults data except launch flag...")
        
        // Store the launch flag temporarily
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        
        // Clear all app-specific UserDefaults
        KeychainManager.shared.clearAllUserDefaultsData()
        
        // Restore the launch flag
        UserDefaults.standard.set(hasLaunched, forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.synchronize()
        
        VaultLog.debug("DEBUG: UserDefaults cleared (launch flag preserved)")
    }
    
    private func clearAllUserDefaults() {
        VaultLog.debug("DEBUG: Clearing ALL UserDefaults data...")
        
        // Clear all app-specific UserDefaults
        KeychainManager.shared.clearAllUserDefaultsData()
        
        // Also clear the launch flag
        UserDefaults.standard.removeObject(forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.synchronize()
        
        VaultLog.debug("DEBUG: All UserDefaults cleared")
    }
    
    // MARK: - Development/Testing Helper
    
    #if DEBUG
    func resetAppForTesting() {
        VaultLog.debug("DEBUG: 🧪 Resetting app for testing purposes...")
        performCompleteAppReset()
    }
    #endif
} 