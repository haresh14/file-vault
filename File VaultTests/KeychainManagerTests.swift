//
//  KeychainManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
@testable import File_Vault

@Suite(.serialized)
struct KeychainManagerTests {
    private final class TestKeychain {
        let suiteName = "KeychainManagerTests-\(UUID().uuidString)"
        let defaults: UserDefaults
        let manager: KeychainManager

        init() {
            defaults = UserDefaults(suiteName: suiteName)!
            manager = KeychainManager(service: suiteName, defaults: defaults)
        }

        deinit {
            try? manager.deletePassword()
            try? manager.deleteFakePassword()
            manager.deleteKeyDerivationRecord()
            defaults.removePersistentDomain(forName: suiteName)
        }
    }
    
    // MARK: - Initialization Tests
    
    @Test func testKeychainManagerSingleton() async throws {
        let manager1 = KeychainManager.shared
        let manager2 = KeychainManager.shared
        
        #expect(manager1 === manager2, "KeychainManager should be a singleton")
    }
    
    // MARK: - Password Management Tests
    
    @Test func testPasswordStorage() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
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

    @Test func testKeyDerivationRecordStorage() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        let record = VaultKeyDerivationRecord.makeCurrent(salt: Data(repeating: 9, count: 16))

        try manager.saveKeyDerivationRecord(record)
        #expect(manager.loadKeyDerivationRecord() == record)

        manager.clearAllKeychainData()
        #expect(manager.loadKeyDerivationRecord() == nil)
    }
    
    @Test func testPasswordDeletion() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
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
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
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
    
    // MARK: - Authentication Type Tests
    
    @Test func testAuthenticationTypeSettings() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test default state (should not be set initially)
        #expect(manager.isAuthenticationTypeSet() == false, "Auth type should not be set initially")
        
        // Test setting different auth types
        let testTypes: [AuthenticationType] = [.passcode4, .passcode6, .password]
        
        for authType in testTypes {
            manager.setAuthenticationType(authType)
            #expect(manager.isAuthenticationTypeSet() == true, "Auth type should be set")
            #expect(manager.getAuthenticationType() == authType, "Retrieved auth type should match set type")
        }
        
        // Test default fallback when no type is set
        testKeychain.defaults.removeObject(forKey: "authenticationType")
        let defaultType = manager.getAuthenticationType()
        #expect(defaultType == .passcode4, "Default auth type should be passcode4")
    }
    
    @Test func testAuthenticationTypeProperties() async throws {
        // Test passcode types
        #expect(AuthenticationType.passcode4.isPasscode == true, "passcode4 should be a passcode type")
        #expect(AuthenticationType.passcode6.isPasscode == true, "passcode6 should be a passcode type")
        #expect(AuthenticationType.password.isPasscode == false, "password should not be a passcode type")
        
        // Test digit counts
        #expect(AuthenticationType.passcode4.digitCount == 4, "passcode4 should have 4 digits")
        #expect(AuthenticationType.passcode6.digitCount == 6, "passcode6 should have 6 digits")
        #expect(AuthenticationType.password.digitCount == nil, "password should have no digit count")
        
        // Test display names
        #expect(AuthenticationType.passcode4.displayName == "4-Digit Passcode", "passcode4 display name should be correct")
        #expect(AuthenticationType.passcode6.displayName == "6-Digit Passcode", "passcode6 display name should be correct")
        #expect(AuthenticationType.password.displayName == "Password", "password display name should be correct")
    }
    
    // MARK: - Biometric Settings Tests
    
    @Test func testBiometricSettings() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
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
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test default timeout
        let defaultTimeout = manager.getLockTimeout()
        #expect(defaultTimeout == KeychainManager.LockTimeout.thirtySeconds.rawValue, "Default lock timeout should be 30 seconds")
        
        // Test setting different timeouts
        let testTimeouts: [KeychainManager.LockTimeout] = [
            .immediate, .fiveSeconds, .tenSeconds, .fifteenSeconds,
            .thirtySeconds, .oneMinute, .fiveMinutes, .never
        ]
        
        for timeout in testTimeouts {
            manager.setLockTimeout(timeout.rawValue)
            let retrievedTimeout = manager.getLockTimeout()
            #expect(retrievedTimeout == timeout.rawValue, "Lock timeout should be set correctly for \(timeout)")
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
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Clear any existing background time
        manager.clearLastBackgroundTime()
        
        // Test that authentication is required when no background time is set
        #expect(manager.shouldRequireAuthentication() == true, "Should require authentication when no background time is set")
        
        // Set background time
        manager.setLastBackgroundTime()
        
        // Test immediate timeout
        manager.setLockTimeout(KeychainManager.LockTimeout.immediate.rawValue)
        #expect(manager.shouldRequireAuthentication() == true, "Should always require authentication with immediate timeout")
        
        // Test never timeout
        manager.setLockTimeout(KeychainManager.LockTimeout.never.rawValue)
        #expect(manager.shouldRequireAuthentication() == false, "Should never require authentication with never timeout")
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    @Test func testBackgroundTimeoutLogic() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test with 5 second timeout
        manager.setLockTimeout(KeychainManager.LockTimeout.fiveSeconds.rawValue)
        manager.setLastBackgroundTime()
        
        // Immediately check - should not require auth
        #expect(manager.shouldRequireAuthentication() == false, "Should not require authentication immediately")
        
        // Wait a bit and check again (simulated by clearing and setting old time)
        manager.clearLastBackgroundTime()
        
        // Simulate old background time by directly setting it
        let oldDate = Date().addingTimeInterval(-10) // 10 seconds ago
        testKeychain.defaults.set(oldDate, forKey: "lastBackgroundTime")
        
        #expect(manager.shouldRequireAuthentication() == true, "Should require authentication after timeout period")
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    @Test func testImmediateLockTimeoutBugFix() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // This test specifically validates the fix for the "Immediately" timeout bug
        // where getLockTimeout() was incorrectly returning 30 instead of 0
        
        // Set timeout to "Immediately" (raw value 0)
        manager.setLockTimeout(KeychainManager.LockTimeout.immediate.rawValue)
        
        // Verify it correctly returns 0, not a default value
        let retrievedTimeout = manager.getLockTimeout()
        #expect(retrievedTimeout == 0, "Immediate timeout should return 0, not default value")
        #expect(retrievedTimeout == KeychainManager.LockTimeout.immediate.rawValue, "Retrieved timeout should match immediate raw value")
        
        // Verify shouldRequireAuthentication works correctly with immediate timeout
        manager.setLastBackgroundTime()
        #expect(manager.shouldRequireAuthentication() == true, "Should always require authentication with immediate timeout, regardless of background time")
        
        // Test all timeout values to ensure they're stored and retrieved correctly
        let allTimeouts: [KeychainManager.LockTimeout] = [
            .immediate, .fiveSeconds, .tenSeconds, .fifteenSeconds,
            .thirtySeconds, .oneMinute, .fiveMinutes, .never
        ]
        
        for timeout in allTimeouts {
            manager.setLockTimeout(timeout.rawValue)
            let retrieved = manager.getLockTimeout()
            #expect(retrieved == timeout.rawValue, "Timeout \(timeout) (raw: \(timeout.rawValue)) should be stored and retrieved correctly")
        }
        
        // Cleanup
        manager.clearLastBackgroundTime()
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testKeychainErrorHandling() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Test getting password when none is set
        try manager.deletePassword() // Ensure no password is set
        
        #expect(throws: KeychainError.self) {
            try manager.getPassword()
        }
        
        // Test that isPasswordSet returns false when no password
        #expect(manager.isPasswordSet() == false, "Should return false when no password is set")
    }
    
    @Test func testEmptyPasswordStorageAPIBehavior() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        
        // Input validation belongs to the setup UI; the storage API preserves
        // the exact string it receives.
            try manager.savePassword("")
        #expect(try manager.getPassword() == "")
    }
    
    // MARK: - Data Persistence Tests
    
    @Test func testDataPersistence() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        let testPassword = "PersistenceTest123!"
        
        // Store password and settings
        try manager.savePassword(testPassword)
        manager.setBiometricEnabled(true)
        manager.setLockTimeout(KeychainManager.LockTimeout.oneMinute.rawValue)
        
        // Verify persistence (simulate app restart by creating new manager instance)
        // Note: Since it's a singleton, we test the persistence through the same instance
        #expect(manager.isPasswordSet() == true, "Password should persist")
        #expect(manager.isBiometricEnabled() == true, "Biometric setting should persist")
        #expect(manager.getLockTimeout() == KeychainManager.LockTimeout.oneMinute.rawValue, "Lock timeout should persist")
        
        // Cleanup
        try manager.deletePassword()
        manager.setBiometricEnabled(false)
        manager.setLockTimeout(KeychainManager.LockTimeout.thirtySeconds.rawValue)
    }
    
    // MARK: - Performance Tests
    
    @Test func testKeychainPerformance() async throws {
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
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
        let testKeychain = TestKeychain()
        let manager = testKeychain.manager
        let testPassword = "SecurePassword123!"
        
        // Store password
        try manager.savePassword(testPassword)
        
        // Verify password is not stored in UserDefaults (basic security check)
        let userDefaults = testKeychain.defaults
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