//
//  SettingsView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var biometricEnabled = KeychainManager.shared.isBiometricEnabled()
    @State private var showResetAlert = false
    @State private var showResetConfirmation = false
    @State private var lockTimeout = KeychainManager.shared.getLockTimeout()
    @State private var showBiometricAlert = false
    
    var body: some View {
        NavigationView {
            Form {
                securitySection
                lockBehaviorSection
                
                #if DEBUG
                developerSection
                #endif
                
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done", action: { dismiss() })
                }
            }
        }
        .alert("Biometric Authentication", isPresented: $showBiometricAlert) {
            Button("OK") { }
        } message: {
            Text("Biometric authentication is not available on this device. This feature requires Face ID or Touch ID.")
        }
        .alert("App Reset", isPresented: $showResetConfirmation) {
            Button("OK") { exit(0) }
        } message: {
            Text("The app has been reset. Please restart the app.")
        }
    }
    
    // MARK: - Section Views
    
    private var securitySection: some View {
        Section("Security") {
            lockTimeoutPicker
            biometricToggle
            biometricStatusView
        }
    }
    
    private var lockBehaviorSection: some View {
        Section("Lock Behavior") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Current Setting: \(lockTimeout.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(lockBehaviorDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    #if DEBUG
    private var developerSection: some View {
        Section("Developer Options") {
            Button(action: { showResetAlert = true }) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    Text("Reset App (Testing Only)")
                        .foregroundColor(.red)
                }
            }
            .alert("Reset App?", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Reset", role: .destructive) {
                    resetApp()
                }
            } message: {
                Text("This will delete your passcode and all app data. This option is only available in debug builds.")
            }
        }
    }
    #endif
    
    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    // MARK: - Component Views
    
    private var lockTimeoutPicker: some View {
        Picker("Auto-Lock", selection: $lockTimeout) {
            ForEach(KeychainManager.LockTimeout.allCases, id: \.self) { timeout in
                Text(timeout.displayName).tag(timeout)
            }
        }
        .onChange(of: lockTimeout) { newValue in
            KeychainManager.shared.setLockTimeout(newValue)
            print("DEBUG: Lock timeout changed to: \(newValue.displayName)")
        }
    }
    
    private var biometricToggle: some View {
        Toggle("Enable Biometric Authentication", isOn: $biometricEnabled)
            .onChange(of: biometricEnabled) { newValue in
                handleBiometricToggle(newValue)
            }
    }
    
    @ViewBuilder
    private var biometricStatusView: some View {
        if BiometricAuthManager.shared.canUseBiometrics() {
            HStack {
                Image(systemName: biometricIconName)
                    .foregroundColor(.green)
                Text("\(biometricTypeName) Available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        } else {
            HStack {
                Image(systemName: "exclamationmark.circle")
                    .foregroundColor(.orange)
                Text("Biometric authentication not available")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
    }
    
    // MARK: - Computed Properties
    
    private var biometricIconName: String {
        BiometricAuthManager.shared.biometricType() == .faceID ? "faceid" : "touchid"
    }
    
    private var biometricTypeName: String {
        BiometricAuthManager.shared.biometricType() == .faceID ? "Face ID" : "Touch ID"
    }
    
    private var lockBehaviorDescription: String {
        switch lockTimeout {
        case .immediate:
            return "App will lock immediately when backgrounded"
        case .fiveSeconds:
            return "App will lock after 5 seconds in background"
        case .tenSeconds:
            return "App will lock after 10 seconds in background"
        case .fifteenSeconds:
            return "App will lock after 15 seconds in background"
        case .thirtySeconds:
            return "App will lock after 30 seconds in background"
        case .oneMinute:
            return "App will lock after 1 minute in background"
        case .fiveMinutes:
            return "App will lock after 5 minutes in background"
        case .never:
            return "App will never lock automatically (not recommended)"
        }
    }
    
    // MARK: - Actions
    
    private func handleBiometricToggle(_ isEnabled: Bool) {
        if isEnabled && !BiometricAuthManager.shared.canUseBiometrics() {
            biometricEnabled = false
            showBiometricAlert = true
        } else {
            KeychainManager.shared.setBiometricEnabled(isEnabled)
        }
    }
    
    private func resetApp() {
        do {
            try KeychainManager.shared.deletePassword()
            KeychainManager.shared.setBiometricEnabled(false)
            KeychainManager.shared.clearLastBackgroundTime()
            
            if let bundleID = Bundle.main.bundleIdentifier {
                UserDefaults.standard.removePersistentDomain(forName: bundleID)
                UserDefaults.standard.synchronize()
            }
            
            showResetConfirmation = true
        } catch {
            print("Error resetting app: \(error)")
        }
    }
} 