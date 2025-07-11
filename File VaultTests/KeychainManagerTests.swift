//
//  KeychainManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
@testable import File_Vault

struct KeychainManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func testKeychainManagerSingleton() async throws {
        let manager1 = KeychainManager.shared
        let manager2 = KeychainManager.shared
        
        #expect(manager1 === manager2, "KeychainManager should be a singleton")
    }
    
    // MARK: - Password Management Tests
    
    @Test func testPasswordStorage() async throws {
        let manager = KeychainManager.shared
        let testPassword = "TestPassword123!"
        
        // Test storing password
        try manager.savePassword(testPassword)
        
        // Test password exists
        #expect(manager.isPasswordSet() == true, "Password should be set after storing")
        
        // Test retrieving password
        let retrievedPassword = try manager.getPassword()
        #expect(retrievedPassword == testPassword, "Retrieved password should match stored password")
        
        // Cleanup
        try manager.deletePassword()
    }
    
    @Test func testPasswordDeletion() async throws {
        let manager = KeychainManager.shared
        let testPassword = "TestPassword123!"
        
        // Store password first
        try manager.savePassword(testPassword)
        #expect(manager.isPasswordSet() == true, "Password should be set")
        
        // Delete password
        try manager.deletePassword()
        #expect(manager.isPasswordSet() == false, "Password should not be set after deletion")
        
        // Test that getting password after deletion throws error
        #expect(throws: KeychainError.self) {
            try manager.getPassword()
        }
    }
    
    @Test func testPasswordOverwrite() async throws {
        let manager = KeychainManager.shared
        let firstPassword = "FirstPassword123!"
        let secondPassword = "SecondPassword456!"
        
        // Store first password
        try manager.savePassword(firstPassword)
        let retrieved1 = try manager.getPassword()
        #expect(retrieved1 == firstPassword, "First password should be stored correctly")
        
        // Overwrite with second password
        try manager.savePassword(secondPassword)
        let retrieved2 = try manager.getPassword()
        #expect(retrieved2 == secondPassword, "Second password should overwrite first")
        
        // Cleanup
        try manager.deletePassword()
    }
    
    // MARK: - Biometric Settings Tests
    
    @Test func testBiometricSettings() async throws {
        let manager = KeychainManager.shared
        
        // Test default state
        let defaultState = manager.isBiometricEnabled()
        
        // Test enabling biometric
        manager.setBiometricEnabled(true)
        #expect(manager.isBiometricEnabled() == true, "Biometric should be enabled")
        
        // Test disabling biometric
        manager.setBiometricEnabled(false)
        #expect(manager.isBiometricEnabled() == false, "Biometric should be disabled")
        
        // Restore original state
        manager.setBiometricEnabled(defaultState)
    }
    
    // MARK: - Lock Timeout Tests
    
    @Test func testLockTimeoutSettings() async throws {
        let manager = KeychainManager.shared
        
        // Test default timeout
        let defaultTimeout = manager.getLockTimeout()
        #expect(defaultTimeout == .thirtySeconds, "Default lock timeout should be 30 seconds")
        
        // Test setting different timeouts
        let testTimeouts: [KeychainManager.LockTimeout] = [
            .immediate, .fiveSeconds, .tenSeconds, .fifteenSeconds,
            .thirtySeconds, .oneMinute, .fiveMinutes, .never
        ]
        
        for timeout in testTimeouts {
            manager.setLockTimeout(timeout)
            let retrievedTimeout = manager.getLockTimeout()
            #expect(retrievedTimeout == timeout, "Lock timeout should be set correctly for \(timeout)")
        }
        
        // Restore default
        manager.setLockTimeout(defaultTimeout)
    }
    
    @Test func testLockTimeoutDisplayNames() async throws {
        let testCases: [(KeychainManager.LockTimeout, String)] = [
            (.immediate, "Immediately"),
            (.fiveSeconds, "5 Seconds"),
            (.tenSeconds, "10 Seconds"),
            (.fifteenSeconds, "15 Seconds"),
            (.thirtySeconds, "30 Seconds"),
            (.oneMinute, "1 Minute"),
            (.fiveMinutes, "5 Minutes"),
            (.never, "Never")
        ]
        
        for (timeout, expectedName) in testCases {
            #expect(timeout.displayName == expectedName, "Display name for \(timeout) should be \(expectedName)")
        }
    }
    
    // MARK: - Background Time Management Tests
    
    @Test func testBackgroundTimeManagement() async throws {
        let manager = KeychainManager.shared
        
        // Clear any existing background time
        manager.clearLastBackgroundTime()
        
        // Test that authentication is required when no background time is set
        #expect(manager.shouldRequireAuthentication() == true, "Should require authentication when no background time is set")
        
        // Set background time
        manager.setLastBackgroundTime()
        
        // Test immediate timeout
        manager.setLockTimeout(.immediate)
        #expect(manager.shouldRequireAuthentication() == true, "Should always require authentication with immediate timeout")
        
        // Test never timeout
        manager.setLockTimeout(.never)
        #expect(manager.shouldRequireAuthentication() == false, "Should never require authentication with never timeout")
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(.thirtySeconds)
    }
    
    @Test func testBackgroundTimeoutLogic() async throws {
        let manager = KeychainManager.shared
        
        // Test with 5 second timeout
        manager.setLockTimeout(.fiveSeconds)
        manager.setLastBackgroundTime()
        
        // Immediately check - should not require auth
        #expect(manager.shouldRequireAuthentication() == false, "Should not require authentication immediately")
        
        // Wait a bit and check again (simulated by clearing and setting old time)
        manager.clearLastBackgroundTime()
        
        // Simulate old background time by directly setting it
        let oldDate = Date().addingTimeInterval(-10) // 10 seconds ago
        UserDefaults.standard.set(oldDate, forKey: "lastBackgroundTime")
        
        #expect(manager.shouldRequireAuthentication() == true, "Should require authentication after timeout period")
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(.thirtySeconds)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testKeychainErrorHandling() async throws {
        let manager = KeychainManager.shared
        
        // Test getting password when none is set
        try manager.deletePassword() // Ensure no password is set
        
        #expect(throws: KeychainError.self) {
            try manager.getPassword()
        }
        
        // Test that isPasswordSet returns false when no password
        #expect(manager.isPasswordSet() == false, "Should return false when no password is set")
    }
    
    @Test func testInvalidPasswordHandling() async throws {
        let manager = KeychainManager.shared
        
        // Test empty password
        #expect(throws: Error.self) {
            try manager.savePassword("")
        }
        
        // Test storing nil-like password (empty string should fail)
        #expect(throws: Error.self) {
            try manager.savePassword("")
        }
    }
    
    // MARK: - Data Persistence Tests
    
    @Test func testDataPersistence() async throws {
        let manager = KeychainManager.shared
        let testPassword = "PersistenceTest123!"
        
        // Store password and settings
        try manager.savePassword(testPassword)
        manager.setBiometricEnabled(true)
        manager.setLockTimeout(.oneMinute)
        
        // Verify persistence (simulate app restart by creating new manager instance)
        // Note: Since it's a singleton, we test the persistence through the same instance
        #expect(manager.isPasswordSet() == true, "Password should persist")
        #expect(manager.isBiometricEnabled() == true, "Biometric setting should persist")
        #expect(manager.getLockTimeout() == .oneMinute, "Lock timeout should persist")
        
        // Cleanup
        try manager.deletePassword()
        manager.setBiometricEnabled(false)
        manager.setLockTimeout(.thirtySeconds)
    }
    
    // MARK: - Performance Tests
    
    @Test func testKeychainPerformance() async throws {
        let manager = KeychainManager.shared
        let testPassword = "PerformanceTest123!"
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple operations
        for i in 0..<10 {
            try manager.savePassword("\(testPassword)\(i)")
            _ = try manager.getPassword()
            _ = manager.isPasswordSet()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #expect(timeElapsed < 1.0, "Keychain operations should complete within 1 second")
        
        // Cleanup
        try manager.deletePassword()
    }
    
    // MARK: - Security Tests
    
    @Test func testPasswordSecurity() async throws {
        let manager = KeychainManager.shared
        let testPassword = "SecurePassword123!"
        
        // Store password
        try manager.savePassword(testPassword)
        
        // Verify password is not stored in UserDefaults (basic security check)
        let userDefaults = UserDefaults.standard
        let allKeys = userDefaults.dictionaryRepresentation().keys
        
        for key in allKeys {
            if let value = userDefaults.object(forKey: key) as? String {
                #expect(value != testPassword, "Password should not be stored in UserDefaults")
            }
        }
        
        // Cleanup
        try manager.deletePassword()
    }
} 