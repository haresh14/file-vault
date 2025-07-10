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
                Section("Security") {
                    // Lock Timeout Setting
                    Picker("Auto-Lock", selection: $lockTimeout) {
                        ForEach(KeychainManager.LockTimeout.allCases, id: \.self) { timeout in
                            Text(timeout.displayName).tag(timeout)
                        }
                    }
                    .onChange(of: lockTimeout) { newValue in
                        KeychainManager.shared.setLockTimeout(newValue)
                        print("DEBUG: Lock timeout changed to: \(newValue.displayName)")
                    }
                    
                    // Biometric Authentication Toggle
                    Toggle("Enable Biometric Authentication", isOn: $biometricEnabled)
                        .onChange(of: biometricEnabled) { newValue in
                            if newValue && !BiometricAuthManager.shared.canUseBiometrics() {
                                biometricEnabled = false
                                showBiometricAlert = true
                            } else {
                                KeychainManager.shared.setBiometricEnabled(newValue)
                            }
                        }
                    
                    if BiometricAuthManager.shared.canUseBiometrics() {
                        HStack {
                            Image(systemName: BiometricAuthManager.shared.biometricType() == .faceID ? "faceid" : "touchid")
                                .foregroundColor(.green)
                            Text("\(BiometricAuthManager.shared.biometricType() == .faceID ? "Face ID" : "Touch ID") Available")
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
                
                Section("Lock Behavior") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("Current Setting: \(lockTimeout.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        switch lockTimeout {
                        case .immediate:
                            Text("App will lock immediately when backgrounded")
                        case .thirtySeconds:
                            Text("App will lock after 30 seconds in background")
                        case .oneMinute:
                            Text("App will lock after 1 minute in background")
                        case .fiveMinutes:
                            Text("App will lock after 5 minutes in background")
                        case .never:
                            Text("App will never lock automatically (not recommended)")
                        }
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    }
                }
                
                #if DEBUG
                Section("Developer Options") {
                    Button(action: {
                        showResetAlert = true
                    }) {
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
                #endif
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .alert("Biometric Authentication", isPresented: $showBiometricAlert) {
            Button("OK") { }
        } message: {
            Text("Biometric authentication is not available on this device. This feature requires Face ID or Touch ID.")
        }
        .alert("App Reset", isPresented: $showResetConfirmation) {
            Button("OK") {
                // Force app to quit
                exit(0)
            }
        } message: {
            Text("The app has been reset. Please restart the app.")
        }
    }
    
    private func resetApp() {
        // Clear keychain
        do {
            try KeychainManager.shared.deletePassword()
            KeychainManager.shared.setBiometricEnabled(false)
            KeychainManager.shared.clearLastBackgroundTime()
            
            // Clear UserDefaults
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