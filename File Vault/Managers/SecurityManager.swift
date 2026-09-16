//
//  SecurityManager.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation

class SecurityManager: ObservableObject, SecurityManaging {
    static let shared = SecurityManager()
    
    @Published var isScreenshotProtectionEnabled = true
    @Published var isRecordingProtectionEnabled = true
    @Published var isShakeToLockEnabled = false
    @Published var isFlipToLockEnabled = false

    private let defaults: UserDefaults
    private let captureMonitor: SecurityCaptureMonitor
    private let overlayPresenter: SecurityOverlayPresenter
    private let motionDetector: SecurityMotionDetector
    private let eventLogger: SecurityEventLogger

    private init() {
        defaults = .standard
        captureMonitor = SecurityCaptureMonitor()
        overlayPresenter = SecurityOverlayPresenter()
        motionDetector = SecurityMotionDetector()
        eventLogger = SecurityEventLogger(defaults: .standard)
        loadSettings()
        configureCollaborators()
        captureMonitor.start()
        motionDetector.setup(
            shakeEnabled: isShakeToLockEnabled,
            flipEnabled: isFlipToLockEnabled
        )
    }

    /// Creates a settings-only instance for deterministic tests.
    init(defaults: UserDefaults) {
        self.defaults = defaults
        captureMonitor = SecurityCaptureMonitor()
        overlayPresenter = SecurityOverlayPresenter()
        motionDetector = SecurityMotionDetector()
        eventLogger = SecurityEventLogger(defaults: defaults)
        loadSettings()
        configureCollaborators()
    }

    private func configureCollaborators() {
        captureMonitor.onScreenshot = { [weak self] in
            print("DEBUG: Screenshot detected - Security alert triggered")
            self?.eventLogger.log("Screenshot taken")
            DispatchQueue.main.async {
                self?.overlayPresenter.showScreenshotAlert()
            }
        }
        captureMonitor.onCaptureChanged = { [weak self] isBeingCaptured in
            guard let self = self else { return }
            print("DEBUG: Screen recording status changed: \(isBeingCaptured)")
            if isBeingCaptured && self.isRecordingProtectionEnabled {
                print("DEBUG: Screen recording detected - Showing protection overlay")
                self.overlayPresenter.showProtection()
            } else {
                print("DEBUG: Screen recording stopped - Hiding protection overlay")
                self.overlayPresenter.hideProtection()
            }
        }
        captureMonitor.onWillResignActive = { [weak self] in
            guard let self = self, self.isScreenshotProtectionEnabled else { return }
            self.overlayPresenter.showProtection()
        }
        captureMonitor.onDidBecomeActive = { [weak self] in
            self?.overlayPresenter.hideProtection()
        }
        motionDetector.onLockRequested = { [weak self] reason in
            self?.triggerSecurityLock(reason: reason)
        }
    }

    func enableScreenshotProtection(_ enabled: Bool) {
        isScreenshotProtectionEnabled = enabled
        if !enabled {
            overlayPresenter.hideProtection()
        }
    }

    func enableRecordingProtection(_ enabled: Bool) {
        isRecordingProtectionEnabled = enabled
        if !enabled {
            print("DEBUG: Screen recording stopped - Hiding protection overlay")
            overlayPresenter.hideProtection()
        }
    }

    func getSecurityLogs() -> [String] {
        eventLogger.logs()
    }

    func clearSecurityLogs() {
        eventLogger.clear()
    }

    func activateScreenProtection() {
        if isScreenshotProtectionEnabled {
            overlayPresenter.showProtection()
        }
        if isRecordingProtectionEnabled {
            print("DEBUG: Screen recording detected - Showing protection overlay")
            overlayPresenter.showProtection()
        }
    }

    func deactivateScreenProtection() {
        overlayPresenter.hideProtection()
        print("DEBUG: Screen recording stopped - Hiding protection overlay")
        overlayPresenter.hideProtection()
    }

    func lockApp() {
        triggerSecurityLock(reason: "Manual lock")
    }

    func saveSettings() {
        defaults.set(isShakeToLockEnabled, forKey: "shakeToLockEnabled")
        defaults.set(isFlipToLockEnabled, forKey: "flipToLockEnabled")
        defaults.set(isScreenshotProtectionEnabled, forKey: "screenshotProtectionEnabled")
        defaults.set(isRecordingProtectionEnabled, forKey: "recordingProtectionEnabled")
    }

    func loadSettings() {
        isShakeToLockEnabled = defaults.bool(forKey: "shakeToLockEnabled")
        isFlipToLockEnabled = defaults.bool(forKey: "flipToLockEnabled")
        isScreenshotProtectionEnabled = defaults.object(forKey: "screenshotProtectionEnabled") as? Bool ?? true
        isRecordingProtectionEnabled = defaults.object(forKey: "recordingProtectionEnabled") as? Bool ?? true
    }
    
    func enableShakeToLock(_ enabled: Bool) {
        isShakeToLockEnabled = enabled
        defaults.set(enabled, forKey: "shakeToLockEnabled")
        motionDetector.setShakeDetectionEnabled(enabled)
    }

    func enableFlipToLock(_ enabled: Bool) {
        isFlipToLockEnabled = enabled
        defaults.set(enabled, forKey: "flipToLockEnabled")
        motionDetector.setFlipDetectionEnabled(enabled)
    }

    private func triggerSecurityLock(reason: String) {
        print("DEBUG: Security lock triggered - \(reason)")
        eventLogger.log(reason)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .triggerSecurityLock, object: nil)
        }
    }
} 