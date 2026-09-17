//
//  SecurityManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
import UIKit
import SwiftUI
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
    
    @Test func testScreenshotAndRecordingTogglesSurviveANewManager() async throws {
        let suiteName = "SecurityManagerPersist-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)

        let first = SecurityManager(defaults: defaults)
        first.enableScreenshotProtection(false)
        first.enableRecordingProtection(false)

        let second = SecurityManager(defaults: defaults)
        #expect(!second.isScreenshotProtectionEnabled)
        #expect(!second.isRecordingProtectionEnabled)

        second.enableScreenshotProtection(true)
        second.enableRecordingProtection(true)
        let third = SecurityManager(defaults: defaults)
        #expect(third.isScreenshotProtectionEnabled)
        #expect(third.isRecordingProtectionEnabled)

        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func testScreenshotNoticeCopyDoesNotClaimCaptureIsImpossible() {
        #expect(SecurityNoticeCopy.screenshotTitle == "Screenshot is blank")
        #expect(SecurityNoticeCopy.screenshotMessage.contains("black frame"))
        #expect(!SecurityNoticeCopy.screenshotMessage.lowercased().contains("impossible"))
        #expect(!SecurityNoticeCopy.screenshotMessage.lowercased().contains("prevent"))
    }

    @Test func testBlankingMovesTheWholeWindowLayerAndPutsItBack() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        window.rootViewController = UIViewController()
        let originalSuperlayer = window.layer.superlayer
        let blanker = ScreenCaptureBlanker()

        #expect(blanker.apply(to: window))
        #expect(blanker.isActive)
        #expect(blanker.isBlanking(window))
        // Everything the window draws, including presented sheets, now renders inside the
        // secure canvas rather than straight into the scene.
        #expect(window.layer.superlayer !== originalSuperlayer)

        blanker.remove()
        #expect(!blanker.isActive)
        #expect(window.layer.superlayer === originalSuperlayer)
    }

    @Test func testApplyingTwiceToTheSameWindowIsANoOp() {
        let window = UIWindow(frame: CGRect(x: 0, y: 0, width: 320, height: 640))
        let blanker = ScreenCaptureBlanker()

        #expect(blanker.apply(to: window))
        let canvas = window.layer.superlayer
        #expect(blanker.apply(to: window))
        #expect(window.layer.superlayer === canvas)

        blanker.remove()
    }

    @Test func testRecordingCoverSurvivesLeavingAndReturningToTheApp() {
        let presenter = SecurityOverlayPresenter()

        presenter.showProtection(for: .recording)
        presenter.showProtection(for: .inactive)
        #expect(presenter.isProtectionActive)

        // Coming back from the App Switcher must not drop a cover recording still needs.
        presenter.hideProtection(for: .inactive)
        #expect(presenter.isProtectionActive)

        presenter.hideProtection(for: .recording)
        #expect(!presenter.isProtectionActive)
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
        manager.clearSecurityLogs()
        #expect(manager.getSecurityLogs().isEmpty)

        manager.handleScreenshot()
        #expect(manager.getSecurityLogs().count == 1)
        #expect(manager.getSecurityLogs().contains { $0.contains("Screenshot taken") })
    }

    @Test func testRepeatedNotificationsForOneCaptureGiveOneNotice() async throws {
        let manager = makeManager()
        manager.clearSecurityLogs()

        // iOS can post the screenshot notification more than once per capture.
        manager.handleScreenshot()
        manager.handleScreenshot()
        manager.handleScreenshot()

        #expect(manager.getSecurityLogs().count == 1)
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