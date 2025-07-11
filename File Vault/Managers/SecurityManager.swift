//
//  SecurityManager.swift
//  File Vault
//
//  Created on 11/07/25.
//

import Foundation
import UIKit
import SwiftUI

class SecurityManager: ObservableObject {
    static let shared = SecurityManager()
    
    @Published var isScreenshotProtectionEnabled = true
    @Published var isRecordingProtectionEnabled = true
    
    private var overlayWindow: UIWindow?
    private var isProtectionActive = false
    
    private init() {
        setupScreenshotProtection()
        setupRecordingProtection()
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
    
    private func logSecurityEvent(_ event: String) {
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
    
    deinit {
        NotificationCenter.default.removeObserver(self)
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