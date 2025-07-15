//
//  SecurityManager.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation
import UIKit
import SwiftUI
import CoreMotion

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()
    
    @Published var isScreenshotProtectionEnabled = true
    @Published var isRecordingProtectionEnabled = true
    @Published var isShakeToLockEnabled = false
    @Published var isFlipToLockEnabled = false
    
    private var overlayWindow: UIWindow?
    private var isProtectionActive = false
    
    // Motion detection
    private let motionManager = CMMotionManager()
    private var lastOrientation: UIDeviceOrientation = .portrait
    private let shakeThreshold: Double = 2.5
    private let flipDetectionInterval: TimeInterval = 0.1
    
    private init() {
        loadSettings()
        setupScreenshotProtection()
        setupRecordingProtection()
        setupMotionDetection()
    }
    
    // MARK: - Screenshot Protection
    
    private func setupScreenshotProtection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(userDidTakeScreenshot),
            name: UIApplication.userDidTakeScreenshotNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(willResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(didBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    private func setupRecordingProtection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(capturedDidChange),
            name: UIScreen.capturedDidChangeNotification,
            object: nil
        )
    }
    
    @objc private func userDidTakeScreenshot() {
        print("DEBUG: Screenshot detected - Security alert triggered")
        
        // Log security event
        logSecurityEvent("Screenshot taken")
        
        // Show alert (optional - could be intrusive)
        DispatchQueue.main.async {
            self.showScreenshotAlert()
        }
    }
    
    @objc private func capturedDidChange() {
        let isBeingCaptured = UIScreen.main.isCaptured
        print("DEBUG: Screen recording status changed: \(isBeingCaptured)")
        
        if isBeingCaptured && isRecordingProtectionEnabled {
            showRecordingProtection()
        } else {
            hideRecordingProtection()
        }
    }
    
    @objc private func willResignActive() {
        if isScreenshotProtectionEnabled {
            showScreenshotProtection()
        }
    }
    
    @objc private func didBecomeActive() {
        hideScreenshotProtection()
    }
    
    // MARK: - Protection Methods
    
    private func showScreenshotProtection() {
        guard !isProtectionActive else { return }
        
        DispatchQueue.main.async {
            self.createOverlayWindow()
            self.isProtectionActive = true
        }
    }
    
    private func hideScreenshotProtection() {
        guard isProtectionActive else { return }
        
        DispatchQueue.main.async {
            self.removeOverlayWindow()
            self.isProtectionActive = false
        }
    }
    
    private func showRecordingProtection() {
        print("DEBUG: Screen recording detected - Showing protection overlay")
        showScreenshotProtection()
    }
    
    private func hideRecordingProtection() {
        print("DEBUG: Screen recording stopped - Hiding protection overlay")
        hideScreenshotProtection()
    }
    
    private func createOverlayWindow() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }
        
        overlayWindow = UIWindow(windowScene: windowScene)
        overlayWindow?.windowLevel = UIWindow.Level.alert + 1
        overlayWindow?.backgroundColor = .black
        overlayWindow?.isHidden = false
        
        let hostingController = UIHostingController(rootView: SecurityOverlayView())
        hostingController.view.backgroundColor = .black
        overlayWindow?.rootViewController = hostingController
        
        overlayWindow?.makeKeyAndVisible()
    }
    
    private func removeOverlayWindow() {
        overlayWindow?.isHidden = true
        overlayWindow = nil
    }
    
    // MARK: - Security Events
    
    func logSecurityEvent(_ event: String) {
        let timestamp = Date()
        let logEntry = "\(timestamp): \(event)"
        print("SECURITY LOG: \(logEntry)")
        
        // Store in UserDefaults for debugging (in production, use more secure storage)
        var securityLogs = UserDefaults.standard.stringArray(forKey: "SecurityLogs") ?? []
        securityLogs.append(logEntry)
        
        // Keep only last 100 entries
        if securityLogs.count > 100 {
            securityLogs = Array(securityLogs.suffix(100))
        }
        
        UserDefaults.standard.set(securityLogs, forKey: "SecurityLogs")
    }
    
    private func showScreenshotAlert() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }
        
        let alert = UIAlertController(
            title: "Security Notice",
            message: "Screenshot detected. Please ensure your vault contents remain secure.",
            preferredStyle: .alert
        )
        
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        
        window.rootViewController?.present(alert, animated: true)
    }
    
    // MARK: - Public Methods
    
    func enableScreenshotProtection(_ enabled: Bool) {
        isScreenshotProtectionEnabled = enabled
        
        if !enabled {
            hideScreenshotProtection()
        }
    }
    
    func enableRecordingProtection(_ enabled: Bool) {
        isRecordingProtectionEnabled = enabled
        
        if !enabled {
            hideRecordingProtection()
        }
    }
    
    func getSecurityLogs() -> [String] {
        return UserDefaults.standard.stringArray(forKey: "SecurityLogs") ?? []
    }
    
    func clearSecurityLogs() {
        UserDefaults.standard.removeObject(forKey: "SecurityLogs")
    }
    
    // MARK: - Settings Management
    
    private func loadSettings() {
        isShakeToLockEnabled = UserDefaults.standard.bool(forKey: "shakeToLockEnabled")
        isFlipToLockEnabled = UserDefaults.standard.bool(forKey: "flipToLockEnabled")
    }
    
    func enableShakeToLock(_ enabled: Bool) {
        isShakeToLockEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "shakeToLockEnabled")
        
        if enabled {
            startShakeDetection()
        } else {
            stopShakeDetection()
        }
    }
    
    func enableFlipToLock(_ enabled: Bool) {
        isFlipToLockEnabled = enabled
        UserDefaults.standard.set(enabled, forKey: "flipToLockEnabled")
        
        if enabled {
            startFlipDetection()
        } else {
            stopFlipDetection()
        }
    }
    
    // MARK: - Motion Detection Setup
    
    private func setupMotionDetection() {
        if isShakeToLockEnabled {
            startShakeDetection()
        }
        
        if isFlipToLockEnabled {
            startFlipDetection()
        }
        
        // Setup device orientation monitoring
        UIDevice.current.beginGeneratingDeviceOrientationNotifications()
        lastOrientation = UIDevice.current.orientation
    }
    
    // MARK: - Shake Detection
    
    private func startShakeDetection() {
        guard motionManager.isAccelerometerAvailable else {
            print("DEBUG: Accelerometer not available for shake detection")
            return
        }
        
        motionManager.accelerometerUpdateInterval = 0.1
        motionManager.startAccelerometerUpdates(to: .main) { [weak self] (data, error) in
            guard let self = self, let accelerometerData = data else { return }
            
            let acceleration = accelerometerData.acceleration
            let magnitude = sqrt(acceleration.x * acceleration.x + 
                               acceleration.y * acceleration.y + 
                               acceleration.z * acceleration.z)
            
            if magnitude > self.shakeThreshold {
                print("DEBUG: Shake detected! Magnitude: \(magnitude)")
                self.triggerSecurityLock(reason: "Shake detected")
            }
        }
        
        print("DEBUG: Shake detection started")
    }
    
    private func stopShakeDetection() {
        motionManager.stopAccelerometerUpdates()
        print("DEBUG: Shake detection stopped")
    }
    
    // MARK: - Flip Detection
    
    private func startFlipDetection() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(deviceOrientationDidChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        print("DEBUG: Flip detection started")
    }
    
    private func stopFlipDetection() {
        NotificationCenter.default.removeObserver(
            self,
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )
        print("DEBUG: Flip detection stopped")
    }
    
    @objc private func deviceOrientationDidChange() {
        let currentOrientation = UIDevice.current.orientation
        
        // Check for face-down flip (most common flip-to-lock gesture)
        if currentOrientation == .faceDown && lastOrientation != .faceDown {
            print("DEBUG: Face-down flip detected!")
            triggerSecurityLock(reason: "Device flipped face-down")
        }
        // Check for face-up to face-down flip
        else if currentOrientation == .faceDown && lastOrientation == .faceUp {
            print("DEBUG: Face-up to face-down flip detected!")
            triggerSecurityLock(reason: "Device flipped")
        }
        
        lastOrientation = currentOrientation
    }
    
    // MARK: - Security Lock Trigger
    
    private func triggerSecurityLock(reason: String) {
        print("DEBUG: Security lock triggered - \(reason)")
        
        // Log the security event
        logSecurityEvent(reason)
        
        // Post notification to lock the app
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("TriggerSecurityLock"), object: nil)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        motionManager.stopAccelerometerUpdates()
        UIDevice.current.endGeneratingDeviceOrientationNotifications()
    }
}

// MARK: - Security Overlay View

struct SecurityOverlayView: View {
    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "eye.slash.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.white)
                
                Text("Content Protected")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text("Your vault contents are hidden for security")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
        }
    }
} 