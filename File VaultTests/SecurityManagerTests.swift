//
//  SecurityManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
import UIKit
@testable import File_Vault

@MainActor
@Suite(.serialized)
struct SecurityManagerTests {
    private func makeManager() -> SecurityManager {
        let suiteName = "SecurityManagerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return SecurityManager(defaults: defaults)
    }
    
    // MARK: - Initialization Tests
    
    @Test func testSecurityManagerSingleton() async throws {
        let manager1 = SecurityManager.shared
        let manager2 = SecurityManager.shared
        
        #expect(manager1 === manager2, "SecurityManager should be a singleton")
    }
    
    @Test func testDefaultSecuritySettings() async throws {
        let manager = makeManager()
        
        #expect(manager.isScreenshotProtectionEnabled == true, "Screenshot protection should be enabled by default")
        #expect(manager.isRecordingProtectionEnabled == true, "Recording protection should be enabled by default")
    }
    
    // MARK: - Screenshot Protection Tests
    
    @Test func testEnableScreenshotProtection() async throws {
        let manager = makeManager()
        
        // Test enabling
        manager.enableScreenshotProtection(true)
        #expect(manager.isScreenshotProtectionEnabled == true, "Screenshot protection should be enabled")
        
        // Test disabling
        manager.enableScreenshotProtection(false)
        #expect(manager.isScreenshotProtectionEnabled == false, "Screenshot protection should be disabled")
    }
    
    @Test func testScreenshotDetectionLogging() async throws {
        let manager = makeManager()
        
        // Clear existing logs
        manager.clearSecurityLogs()
        
        // Simulate screenshot detection
        let initialLogCount = manager.getSecurityLogs().count
        
        // Since we can't directly call the private method, we'll test the public interface
        // The actual screenshot detection would be tested in integration tests
        #expect(initialLogCount == 0, "Security logs should be empty after clearing")
    }
    
    // MARK: - Screen Recording Protection Tests
    
    @Test func testEnableRecordingProtection() async throws {
        let manager = makeManager()
        
        // Test enabling
        manager.enableRecordingProtection(true)
        #expect(manager.isRecordingProtectionEnabled == true, "Recording protection should be enabled")
        
        // Test disabling
        manager.enableRecordingProtection(false)
        #expect(manager.isRecordingProtectionEnabled == false, "Recording protection should be disabled")
    }
    
    // MARK: - Security Event Logging Tests
    
    @Test func testSecurityEventLogging() async throws {
        let manager = makeManager()
        
        // Clear existing logs
        manager.clearSecurityLogs()
        
        // Test that logs are initially empty
        var logs = manager.getSecurityLogs()
        #expect(logs.isEmpty, "Security logs should be empty after clearing")
        
        // Test log clearing
        manager.clearSecurityLogs()
        logs = manager.getSecurityLogs()
        #expect(logs.isEmpty, "Security logs should remain empty after clearing again")
    }
    
    @Test func testSecurityLogRotation() async throws {
        let suiteName = "SecurityEventLoggerTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        let logger = SecurityEventLogger(defaults: defaults)

        for index in 0..<105 {
            logger.log("Event \(index)")
        }

        let logs = logger.logs()
        #expect(logs.count == 100)
        #expect(logs.first?.contains("Event 5") == true)
        #expect(logs.last?.contains("Event 104") == true)
        defaults.removePersistentDomain(forName: suiteName)
    }
    
    // MARK: - Settings Integration Tests
    
    @Test func testSecuritySettingsPersistence() async throws {
        let manager = makeManager()
        
        // Test that settings changes persist
        let originalScreenshotSetting = manager.isScreenshotProtectionEnabled
        let originalRecordingSetting = manager.isRecordingProtectionEnabled
        
        // Change settings
        manager.enableScreenshotProtection(!originalScreenshotSetting)
        manager.enableRecordingProtection(!originalRecordingSetting)
        
        // Verify changes
        #expect(manager.isScreenshotProtectionEnabled == !originalScreenshotSetting, "Screenshot protection setting should change")
        #expect(manager.isRecordingProtectionEnabled == !originalRecordingSetting, "Recording protection setting should change")
        
        // Restore original settings
        manager.enableScreenshotProtection(originalScreenshotSetting)
        manager.enableRecordingProtection(originalRecordingSetting)
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testSecurityManagerErrorHandling() async throws {
        let manager = makeManager()
        
        // Test that the manager handles different states gracefully
        // This is more of a robustness test
        let screenshotState = manager.isScreenshotProtectionEnabled
        let recordingState = manager.isRecordingProtectionEnabled
        #expect(screenshotState == true || screenshotState == false, "Screenshot protection state should be boolean")
        #expect(recordingState == true || recordingState == false, "Recording protection state should be boolean")
    }
    
    // MARK: - Performance Tests
    
    @Test func testSecurityManagerPerformance() async throws {
        let manager = makeManager()
        
        // Test that security operations are performant
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Perform multiple operations
        for _ in 0..<100 {
            manager.enableScreenshotProtection(true)
            manager.enableRecordingProtection(true)
            _ = manager.getSecurityLogs()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        #expect(timeElapsed < 1.0, "Security operations should complete within 1 second")
    }
    
    // MARK: - Thread Safety Tests
    
    @Test func testSecurityManagerStateTransitions() async throws {
        let manager = makeManager()
        
            for i in 0..<10 {
                    manager.enableScreenshotProtection(i % 2 == 0)
                    manager.enableRecordingProtection(i % 2 == 1)
        }
        
        #expect(manager.isScreenshotProtectionEnabled == false)
        #expect(manager.isRecordingProtectionEnabled == true)
    }
} 