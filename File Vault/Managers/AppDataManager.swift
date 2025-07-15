//
//  AppDataManager.swift
//  File Vault
//
//  Created on [Date].
//

import Foundation
import Photos

class AppDataManager {
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
        print("DEBUG: App marked as launched before")
    }
    
    // MARK: - Complete App Reset
    
    func performFirstLaunchCleanup() {
        print("DEBUG: 🚀 Performing first launch cleanup - clearing all stored data...")
        
        // Clear all data types
        clearAllAppData()
        
        // Mark that we've done the cleanup
        markAppAsLaunched()
        
        print("DEBUG: ✅ First launch cleanup completed")
    }
    
    func clearAllAppData() {
        print("DEBUG: 🧹 Starting complete app data cleanup...")
        
        // 1. Clear Keychain data
        KeychainManager.shared.clearAllKeychainData()
        
        // 2. Clear UserDefaults data (except the launch flag)
        clearUserDefaultsExceptLaunchFlag()
        
        // 3. Clear Core Data
        CoreDataManager.shared.clearAllCoreData()
        
        // 4. Clear file storage
        FileStorageManager.shared.clearAllStoredFiles()
        
        // 5. Reset biometric failure state
        BiometricAuthManager.shared.resetFailureCount()
        
        // 6. Clear any permission-related cached state (Photos framework doesn't allow programmatic permission reset)
        // The user will be re-prompted for permissions naturally
        
        print("DEBUG: ✅ Complete app data cleanup finished")
    }
    
    // MARK: - Nuclear Option - Complete Reset
    
    func performCompleteAppReset() {
        print("DEBUG: 💥 Performing COMPLETE app reset - deleting all files and data...")
        
        // 1. Clear Keychain data
        KeychainManager.shared.clearAllKeychainData()
        
        // 2. Clear ALL UserDefaults data (including launch flag to trigger fresh setup)
        clearAllUserDefaults()
        
        // 3. Delete Core Data store files completely
        CoreDataManager.shared.deleteCoreDataStore()
        
        // 4. Delete all storage directories
        FileStorageManager.shared.deleteAllStorageDirectories()
        
        // 5. Reset biometric failure state
        BiometricAuthManager.shared.resetFailureCount()
        
        print("DEBUG: ✅ Complete app reset finished - app will behave as fresh install")
    }
    
    // MARK: - Private Helper Methods
    
    private func clearUserDefaultsExceptLaunchFlag() {
        print("DEBUG: Clearing UserDefaults data except launch flag...")
        
        // Store the launch flag temporarily
        let hasLaunched = UserDefaults.standard.bool(forKey: hasLaunchedBeforeKey)
        
        // Clear all app-specific UserDefaults
        KeychainManager.shared.clearAllUserDefaultsData()
        
        // Restore the launch flag
        UserDefaults.standard.set(hasLaunched, forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.synchronize()
        
        print("DEBUG: UserDefaults cleared (launch flag preserved)")
    }
    
    private func clearAllUserDefaults() {
        print("DEBUG: Clearing ALL UserDefaults data...")
        
        // Clear all app-specific UserDefaults
        KeychainManager.shared.clearAllUserDefaultsData()
        
        // Also clear the launch flag
        UserDefaults.standard.removeObject(forKey: hasLaunchedBeforeKey)
        UserDefaults.standard.synchronize()
        
        print("DEBUG: All UserDefaults cleared")
    }
    
    // MARK: - Development/Testing Helper
    
    #if DEBUG
    func resetAppForTesting() {
        print("DEBUG: 🧪 Resetting app for testing purposes...")
        performCompleteAppReset()
    }
    #endif
} 