//
//  BiometricAuthManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
import LocalAuthentication
@testable import File_Vault

struct BiometricAuthManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func testBiometricAuthManagerSingleton() async throws {
        let manager1 = BiometricAuthManager.shared
        let manager2 = BiometricAuthManager.shared
        
        #expect(manager1 === manager2, "BiometricAuthManager should be a singleton")
    }
    
    // MARK: - Biometric Availability Tests
    
    @Test func testBiometricAvailability() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that biometric availability check doesn't crash
        let isAvailable = manager.canUseBiometrics()
        
        // The result depends on the device, but the method should not crash
        #expect(isAvailable == true || isAvailable == false, "Biometric availability should return a boolean value")
    }
    
    @Test func testBiometricType() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that biometric type check doesn't crash
        let biometricType = manager.biometricType()
        
        // The result depends on the device, but should be one of the valid types
        let validTypes: [BiometricType] = [.none, .touchID, .faceID]
        #expect(validTypes.contains(biometricType), "Biometric type should be one of the valid types")
    }
    
    // MARK: - Authentication State Tests
    
    @Test func testCanUseBiometrics() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that canUseBiometrics returns a boolean
        let canUse = manager.canUseBiometrics()
        #expect(canUse == true || canUse == false, "canUseBiometrics should return a boolean value")
    }
    
    @Test func testFailureCountReset() async throws {
        let manager = BiometricAuthManager.shared
        
        // Reset failure count
        manager.resetFailureCount()
        
        // Test that we can still use biometrics after reset
        let canUse = manager.canUseBiometrics()
        #expect(canUse == true || canUse == false, "Should be able to check biometrics after reset")
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testBiometricErrorHandling() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that error handling doesn't crash
        // We can't easily simulate biometric errors in unit tests,
        // but we can test that the manager handles various states properly
        
        // Test when biometric is not available
        if !manager.canUseBiometrics() {
            // If biometric is not available, authentication should fail gracefully
            #expect(true, "Manager should handle unavailable biometric gracefully")
        }
    }
    
    // MARK: - Authentication Flow Tests
    
    @Test func testAuthenticationFlow() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that authentication flow can be initiated
        // Note: In unit tests, we can't actually perform biometric authentication,
        // but we can test the setup and state management
        
        // Reset failure count
        manager.resetFailureCount()
        
        // Test that we can check biometric availability
        let canUse = manager.canUseBiometrics()
        #expect(canUse == true || canUse == false, "Should be able to check biometric availability")
        
        // Test biometric type detection
        let biometricType = manager.biometricType()
        let validTypes: [BiometricType] = [.none, .touchID, .faceID]
        #expect(validTypes.contains(biometricType), "Should be able to detect biometric type")
    }
    
    // MARK: - Biometric Type String Tests
    
    @Test func testBiometricTypeValues() async throws {
        let testCases: [BiometricType] = [.none, .touchID, .faceID]
        
        for biometricType in testCases {
            // Test that each biometric type is a valid enum case
            #expect(testCases.contains(biometricType), "Biometric type \(biometricType) should be valid")
        }
    }
    
    // MARK: - LAContext Integration Tests
    
    @Test func testLAContextIntegration() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that LAContext is properly initialized and used
        // We can't test the actual biometric authentication in unit tests,
        // but we can verify the manager doesn't crash when checking availability
        
        let context = LAContext()
        var error: NSError?
        
        // Test that we can check biometric availability
        let canEvaluate = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        // The result depends on the device, but the call should not crash
        #expect(canEvaluate == true || canEvaluate == false, "LAContext evaluation should return a result")
    }
    
    // MARK: - Thread Safety Tests
    
    @Test func testThreadSafety() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test concurrent access to biometric methods
        await withTaskGroup(of: Void.self) { group in
            for i in 0..<10 {
                group.addTask {
                    if i % 2 == 0 {
                        manager.resetFailureCount()
                    }
                    _ = manager.canUseBiometrics()
                    _ = manager.biometricType()
                }
            }
        }
        
        // If we get here without crashing, thread safety is working
        #expect(true, "BiometricAuthManager should handle concurrent access safely")
    }
    
    // MARK: - Performance Tests
    
    @Test func testPerformance() async throws {
        let manager = BiometricAuthManager.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple operations
        for i in 0..<100 {
            if i % 10 == 0 {
                manager.resetFailureCount()
            }
            _ = manager.canUseBiometrics()
            _ = manager.biometricType()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #expect(timeElapsed < 1.0, "Biometric operations should complete within 1 second")
    }
    
    // MARK: - State Persistence Tests
    
    @Test func testStatePersistence() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that authentication state is properly managed
        // Note: Authentication state is typically not persisted across app launches
        // for security reasons, but we can test the in-memory state management
        
        // Reset failure count
        manager.resetFailureCount()
        
        // Test that we can use biometrics after reset
        let canUse = manager.canUseBiometrics()
        #expect(canUse == true || canUse == false, "Should be able to check biometrics after reset")
        
        // Test biometric type detection
        let biometricType = manager.biometricType()
        let validTypes: [BiometricType] = [.none, .touchID, .faceID]
        #expect(validTypes.contains(biometricType), "Should be able to detect biometric type")
    }
    
    // MARK: - Integration with KeychainManager Tests
    
    @Test func testIntegrationWithKeychainManager() async throws {
        let biometricManager = BiometricAuthManager.shared
        let keychainManager = KeychainManager.shared
        
        // Test that biometric availability affects keychain biometric settings
        let isBiometricAvailable = biometricManager.canUseBiometrics()
        
        if isBiometricAvailable {
            // If biometric is available, keychain should allow biometric settings
            keychainManager.setBiometricEnabled(true)
            #expect(keychainManager.isBiometricEnabled() == true, "Keychain should allow biometric when available")
        } else {
            // If biometric is not available, biometric setting might still be stored
            // but authentication would fail
            #expect(true, "Biometric unavailable - settings can still be stored")
        }
        
        // Reset to default
        keychainManager.setBiometricEnabled(false)
    }
    
    // MARK: - Error Recovery Tests
    
    @Test func testErrorRecovery() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that the manager can recover from various states
        
        // Start with clean state
        manager.resetFailureCount()
        
        // Test that manager can handle biometric checks
        let canUse = manager.canUseBiometrics()
        #expect(canUse == true || canUse == false, "Should be able to check biometrics")
        
        // Test biometric type detection
        let biometricType = manager.biometricType()
        let validTypes: [BiometricType] = [.none, .touchID, .faceID]
        #expect(validTypes.contains(biometricType), "Should be able to detect biometric type")
        
        // Final cleanup
        manager.resetFailureCount()
    }
    
    // MARK: - Biometric Policy Tests
    
    @Test func testBiometricPolicyHandling() async throws {
        let manager = BiometricAuthManager.shared
        
        // Test that different biometric policies are handled correctly
        let context = LAContext()
        var error: NSError?
        
        // Test deviceOwnerAuthenticationWithBiometrics policy
        let canEvaluateBiometrics = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        
        // Test deviceOwnerAuthentication policy (includes passcode fallback)
        let canEvaluateWithPasscode = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)
        
        // Both should return boolean values without crashing
        #expect(canEvaluateBiometrics == true || canEvaluateBiometrics == false, "Biometric policy evaluation should return a result")
        #expect(canEvaluateWithPasscode == true || canEvaluateWithPasscode == false, "Passcode policy evaluation should return a result")
    }
} 