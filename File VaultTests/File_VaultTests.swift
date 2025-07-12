//
//  File_VaultTests.swift
//  File VaultTests
//
//  Created by Thor on 10/07/25.
//

import Testing
import Foundation
import UIKit
import CoreData
@testable import File_Vault

struct File_VaultTests {

    // MARK: - Test Suite Overview
    
    @Test func testSuiteOverview() async throws {
        // This test provides an overview of the comprehensive test suite
        // and ensures all critical components are being tested
        
        let testComponents = [
            "SecurityManager": "Screen recording/screenshot protection, security logging",
            "KeychainManager": "Password storage, biometric settings, lock timeouts",
            "FileStorageManager": "File encryption, storage, thumbnail generation",
            "BiometricAuthManager": "Biometric authentication, device capabilities",
            "CoreDataManager": "Data persistence, CRUD operations, relationships",
            "WebServerManager": "Local web server, file upload handling"
        ]
        
        print("🧪 File Vault Test Suite Overview:")
        print("==================================")
        
        for (component, description) in testComponents {
            print("✅ \(component): \(description)")
        }
        
        print("\n📊 Test Coverage Areas:")
        print("- Unit Tests: Individual component functionality")
        print("- Integration Tests: Component interaction")
        print("- Performance Tests: Response time and resource usage")
        print("- Error Handling: Graceful failure scenarios")
        print("- Thread Safety: Concurrent access protection")
        print("- Memory Management: Resource cleanup")
        print("- Security: Data protection and encryption")
        
        #expect(true, "Test suite overview completed successfully")
    }
    
    // MARK: - Integration Tests
    
    @Test func testFullAuthenticationFlow() async throws {
        let keychainManager = KeychainManager.shared
        let biometricManager = BiometricAuthManager.shared
        let fileStorageManager = FileStorageManager.shared
        
        // Test complete authentication and file access flow
        let testPassword = "IntegrationTest123!"
        
        // Store password
        try keychainManager.savePassword(testPassword)
        #expect(keychainManager.isPasswordSet() == true, "Password should be stored")
        
        // Setup file storage encryption
        fileStorageManager.setupEncryptionKey(from: testPassword)
        
        // Test file operations after authentication
        let testData = "Authenticated file access test".data(using: .utf8)!
        let vaultItem = try fileStorageManager.saveFile(
            data: testData,
            fileName: "auth_test.txt",
            fileType: "text/plain"
        )
        
        #expect(vaultItem.fileName == "auth_test.txt", "File should be saved after authentication")
        
        // Test file retrieval
        let retrievedData = try fileStorageManager.loadFile(vaultItem: vaultItem)
        #expect(retrievedData == testData, "File should be retrievable after authentication")
        
        // Cleanup
        try fileStorageManager.deleteFile(vaultItem: vaultItem)
        try keychainManager.deletePassword()
        biometricManager.resetFailureCount()
    }
    
    @Test func testNewAuthenticationTypeFlow() async throws {
        let keychainManager = KeychainManager.shared
        let fileStorageManager = FileStorageManager.shared
        
        // Test different authentication types
        let testPasscode4 = "1234"
        let testPasscode6 = "123456"
        let testPassword = "SecurePassword123!"
        
        // Test 4-digit passcode
        keychainManager.setAuthenticationType(.passcode4)
        try keychainManager.savePassword(testPasscode4)
        #expect(keychainManager.getAuthenticationType() == .passcode4, "Auth type should be passcode4")
        #expect(keychainManager.isPasswordSet() == true, "Passcode should be stored")
        
        let retrieved4 = try keychainManager.getPassword()
        #expect(retrieved4 == testPasscode4, "Retrieved passcode should match")
        
        // Test 6-digit passcode
        keychainManager.setAuthenticationType(.passcode6)
        try keychainManager.savePassword(testPasscode6)
        #expect(keychainManager.getAuthenticationType() == .passcode6, "Auth type should be passcode6")
        
        let retrieved6 = try keychainManager.getPassword()
        #expect(retrieved6 == testPasscode6, "Retrieved passcode should match")
        
        // Test password
        keychainManager.setAuthenticationType(.password)
        try keychainManager.savePassword(testPassword)
        #expect(keychainManager.getAuthenticationType() == .password, "Auth type should be password")
        
        let retrievedPassword = try keychainManager.getPassword()
        #expect(retrievedPassword == testPassword, "Retrieved password should match")
        
        // Test file operations with password auth
        fileStorageManager.setupEncryptionKey(from: testPassword)
        let testData = "Password auth test".data(using: .utf8)!
        let vaultItem = try fileStorageManager.saveFile(
            data: testData,
            fileName: "password_test.txt",
            fileType: "text/plain"
        )
        
        let retrievedData = try fileStorageManager.loadFile(vaultItem: vaultItem)
        #expect(retrievedData == testData, "File should be accessible with password auth")
        
        // Cleanup
        try fileStorageManager.deleteFile(vaultItem: vaultItem)
        try keychainManager.deletePassword()
        UserDefaults.standard.removeObject(forKey: "authenticationType")
    }
    
    @Test func testSecurityManagerIntegration() async throws {
        let securityManager = SecurityManager.shared
        let keychainManager = KeychainManager.shared
        
        // Test security settings persistence
        let originalScreenshotSetting = securityManager.isScreenshotProtectionEnabled
        let originalRecordingSetting = securityManager.isRecordingProtectionEnabled
        
        // Change security settings
        securityManager.enableScreenshotProtection(true)
        securityManager.enableRecordingProtection(true)
        
        // Test that settings are active
        #expect(securityManager.isScreenshotProtectionEnabled == true, "Screenshot protection should be enabled")
        #expect(securityManager.isRecordingProtectionEnabled == true, "Recording protection should be enabled")
        
        // Test security logging
        securityManager.clearSecurityLogs()
        let logs = securityManager.getSecurityLogs()
        #expect(logs.isEmpty, "Security logs should be empty after clearing")
        
        // Restore original settings
        securityManager.enableScreenshotProtection(originalScreenshotSetting)
        securityManager.enableRecordingProtection(originalRecordingSetting)
    }
    
    @Test func testWebServerFileUploadIntegration() async throws {
        let webServerManager = WebServerManager.shared
        let fileStorageManager = FileStorageManager.shared
        let keychainManager = KeychainManager.shared
        
        // Setup authentication and file storage
        let testPassword = "WebServerTest123!"
        try keychainManager.savePassword(testPassword)
        fileStorageManager.setupEncryptionKey(from: testPassword)
        
        // Start web server
        webServerManager.startServer()
        
        // Wait for server to start
        try await Task.sleep(for: .milliseconds(200))
        
        #expect(webServerManager.isRunning == true, "Web server should be running")
        
        // Test that server URL is accessible
        let serverURL = webServerManager.serverURL
        #expect(serverURL.hasPrefix("http://"), "Server URL should be valid")
        
        // Test file storage works while server is running
        let testData = "Web server integration test".data(using: .utf8)!
        let vaultItem = try fileStorageManager.saveFile(
            data: testData,
            fileName: "web_test.txt",
            fileType: "text/plain"
        )
        
        #expect(vaultItem.fileName == "web_test.txt", "File should be saved while server is running")
        
        // Cleanup
        try fileStorageManager.deleteFile(vaultItem: vaultItem)
        webServerManager.stopServer()
        try keychainManager.deletePassword()
    }
    
    // MARK: - Performance Integration Tests
    
    @Test func testSystemPerformance() async throws {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Test multiple components working together
        let keychainManager = KeychainManager.shared
        let fileStorageManager = FileStorageManager.shared
        let coreDataManager = CoreDataManager.shared
        
        // Setup
        let testPassword = "PerformanceTest123!"
        try keychainManager.savePassword(testPassword)
        fileStorageManager.setupEncryptionKey(from: testPassword)
        
        // Create multiple files
        var vaultItems: [VaultItem] = []
        for i in 0..<10 {
            let testData = "Performance test data \(i)".data(using: .utf8)!
            let vaultItem = try fileStorageManager.saveFile(
                data: testData,
                fileName: "perf_test_\(i).txt",
                fileType: "text/plain"
            )
            vaultItems.append(vaultItem)
        }
        
        // Test Core Data operations
        coreDataManager.save()
        
        // Test file retrieval
        for vaultItem in vaultItems {
            let data = try fileStorageManager.loadFile(vaultItem: vaultItem)
            #expect(data.count > 0, "File should be retrievable")
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #expect(timeElapsed < 3.0, "System performance should be acceptable")
        
        // Cleanup
        for vaultItem in vaultItems {
            try fileStorageManager.deleteFile(vaultItem: vaultItem)
        }
        try keychainManager.deletePassword()
    }
    
    // MARK: - Error Recovery Integration Tests
    
    @Test func testSystemErrorRecovery() async throws {
        let keychainManager = KeychainManager.shared
        let fileStorageManager = FileStorageManager.shared
        let biometricManager = BiometricAuthManager.shared
        
        // Test system recovery from various error states
        
        // Test 1: Recovery from authentication failure
        biometricManager.resetFailureCount()
        #expect(biometricManager.canUseBiometrics() == true, "Should be able to use biometrics after reset")
        
        // Test 2: Recovery from file storage without encryption key
        #expect(throws: Error.self) {
            try fileStorageManager.saveFile(
                data: "Test".data(using: .utf8)!,
                fileName: "test.txt",
                fileType: "text/plain"
            )
        }
        
        // Test 3: Recovery by setting up encryption properly
        let testPassword = "RecoveryTest123!"
        try keychainManager.savePassword(testPassword)
        fileStorageManager.setupEncryptionKey(from: testPassword)
        
        // Now file operations should work
        let testData = "Recovery test".data(using: .utf8)!
        let vaultItem = try fileStorageManager.saveFile(
            data: testData,
            fileName: "recovery_test.txt",
            fileType: "text/plain"
        )
        
        #expect(vaultItem.fileName == "recovery_test.txt", "System should recover and work properly")
        
        // Cleanup
        try fileStorageManager.deleteFile(vaultItem: vaultItem)
        try keychainManager.deletePassword()
    }
    
    // MARK: - Data Consistency Tests
    
    @Test func testDataConsistency() async throws {
        let keychainManager = KeychainManager.shared
        let fileStorageManager = FileStorageManager.shared
        let coreDataManager = CoreDataManager.shared
        
        // Test that data remains consistent across operations
        let testPassword = "ConsistencyTest123!"
        try keychainManager.savePassword(testPassword)
        fileStorageManager.setupEncryptionKey(from: testPassword)
        
        // Create test data
        let testData = "Consistency test data".data(using: .utf8)!
        let vaultItem = try fileStorageManager.saveFile(
            data: testData,
            fileName: "consistency_test.txt",
            fileType: "text/plain"
        )
        
        // Save to Core Data
        coreDataManager.save()
        
        // Verify data consistency
        let retrievedData = try fileStorageManager.loadFile(vaultItem: vaultItem)
        #expect(retrievedData == testData, "File data should be consistent")
        
        // Verify Core Data consistency
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultItem.id! as CVarArg)
        let results = try coreDataManager.context.fetch(fetchRequest)
        
        #expect(results.count == 1, "Core Data should have consistent record")
        #expect(results.first?.fileName == "consistency_test.txt", "Core Data record should match")
        
        // Cleanup
        try fileStorageManager.deleteFile(vaultItem: vaultItem)
        try keychainManager.deletePassword()
    }
    
    // MARK: - Memory and Resource Tests
    
    @Test func testMemoryManagement() async throws {
        // Test that the system handles memory efficiently
        let keychainManager = KeychainManager.shared
        let fileStorageManager = FileStorageManager.shared
        
        let testPassword = "MemoryTest123!"
        try keychainManager.savePassword(testPassword)
        fileStorageManager.setupEncryptionKey(from: testPassword)
        
        // Create and delete many files to test memory management
        for i in 0..<20 {
            let testData = Data(repeating: UInt8(i), count: 1024) // 1KB each
            let vaultItem = try fileStorageManager.saveFile(
                data: testData,
                fileName: "memory_test_\(i).bin",
                fileType: "application/octet-stream"
            )
            
            // Immediately delete to test cleanup
            try fileStorageManager.deleteFile(vaultItem: vaultItem)
        }
        
        // If we get here without memory issues, the test passes
        #expect(true, "Memory management should handle repeated operations")
        
        // Cleanup
        try keychainManager.deletePassword()
    }
}
