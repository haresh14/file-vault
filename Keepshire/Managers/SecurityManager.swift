//
//  SecurityManager.swift
//  Keepshire
//
//  Created on 11/07/25.
//

import Foundation
import UIKit

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
    private let captureBlanker = ScreenCaptureBlanker()
    private var lastScreenshotNotice: Date?
    private static let screenshotNoticeWindow: TimeInterval = 1.5

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
        syncRecordingProtection()
        refreshCaptureBlanking()
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
            self?.handleScreenshot()
        }
        captureMonitor.onCaptureChanged = { [weak self] _ in
            self?.syncRecordingProtection()
        }
        captureMonitor.onWillResignActive = { [weak self] in
            guard let self, self.isScreenshotProtectionEnabled else { return }
            self.overlayPresenter.showProtection(for: .inactive)
        }
        captureMonitor.onDidBecomeActive = { [weak self] in
            guard let self else { return }
            self.overlayPresenter.hideProtection(for: .inactive)
            // A recording that started while the app was away never posted a change.
            self.syncRecordingProtection()
            self.refreshCaptureBlanking()
        }
        motionDetector.onLockRequested = { [weak self] reason in
            self?.triggerSecurityLock(reason: reason)
        }
    }

    /// iOS can post the screenshot notification more than once for a single capture,
    /// so one capture is collapsed into one log entry and one notice.
    func handleScreenshot() {
        let now = Date()
        if let last = lastScreenshotNotice, now.timeIntervalSince(last) < Self.screenshotNoticeWindow {
            return
        }
        lastScreenshotNotice = now

        VaultLog.debug("DEBUG: Screenshot detected")
        eventLogger.log("Screenshot taken")
        guard isScreenshotProtectionEnabled else { return }
        DispatchQueue.main.async { [weak self] in
            self?.overlayPresenter.showScreenshotAlert()
        }
    }

    func enableScreenshotProtection(_ enabled: Bool) {
        isScreenshotProtectionEnabled = enabled
        defaults.set(enabled, forKey: "screenshotProtectionEnabled")
        if !enabled {
            overlayPresenter.hideProtection(for: .inactive)
        }
        refreshCaptureBlanking()
    }

    func enableRecordingProtection(_ enabled: Bool) {
        isRecordingProtectionEnabled = enabled
        defaults.set(enabled, forKey: "recordingProtectionEnabled")
        syncRecordingProtection()
    }

    /// Covers the screen while a recording or mirroring session is running.
    private func syncRecordingProtection() {
        let shouldCover = isRecordingProtectionEnabled && captureMonitor.isScreenBeingCaptured
        if shouldCover {
            overlayPresenter.showProtection(for: .recording)
        } else {
            overlayPresenter.hideProtection(for: .recording)
        }
    }

    /// Attaches or detaches blanking on the app's window. Safe to call repeatedly.
    func refreshCaptureBlanking() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard self.isScreenshotProtectionEnabled else {
                self.captureBlanker.remove()
                return
            }
            guard let window = Self.appWindow() else { return }
            self.captureBlanker.apply(to: window)
        }
    }

    private static func appWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        let ordered = scenes.filter { $0.activationState == .foregroundActive } + scenes
        for scene in ordered {
            if let window = scene.windows.first(where: { $0.isKeyWindow && !($0 is SecurityOverlayWindow) })
                ?? scene.windows.first(where: { !($0 is SecurityOverlayWindow) }) {
                return window
            }
        }
        return nil
    }

    func getSecurityLogs() -> [String] {
        eventLogger.logs()
    }

    func clearSecurityLogs() {
        eventLogger.clear()
    }

    func activateScreenProtection() {
        if isScreenshotProtectionEnabled {
            overlayPresenter.showProtection(for: .inactive)
        }
        if isRecordingProtectionEnabled {
            overlayPresenter.showProtection(for: .recording)
        }
    }

    func deactivateScreenProtection() {
        overlayPresenter.hideAllProtection()
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
        VaultLog.debug("DEBUG: Security lock triggered - \(reason)")
        eventLogger.log(reason)
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .triggerSecurityLock, object: nil)
        }
    }
} 