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
    @State private var showDeleteFilesAlert = false
    @State private var lockTimeout = KeychainManager.shared.getLockTimeout()
    @State private var showBiometricAlert = false
    @State private var showChangeAuthSheet = false
    @State private var showChangeAuthConfirmation = false
    @StateObject private var securityManager = SecurityManager.shared
    
    private var currentAuthType: AuthenticationType {
        KeychainManager.shared.getAuthenticationType()
    }
    
    var body: some View {
        NavigationView {
            Form {
                securitySection
                advancedSecuritySection
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
        .sheet(isPresented: $showChangeAuthSheet) {
            ChangeAuthenticationView(
                currentAuthType: currentAuthType,
                onAuthChanged: {
                    showChangeAuthConfirmation = true
                    showChangeAuthSheet = false
                }
            )
        }
        .alert("Authentication Changed", isPresented: $showChangeAuthConfirmation) {
            Button("OK") { }
        } message: {
            Text("Your authentication method has been updated successfully.")
        }
    }
    
    // MARK: - Section Views
    
    private var securitySection: some View {
        Section("Security") {
            authenticationInfoView
            changeAuthButton
            lockTimeoutPicker
            biometricToggle
            biometricStatusView
        }
    }
    
    private var advancedSecuritySection: some View {
        Section("Advanced Security") {
            Toggle("Screenshot Protection", isOn: $securityManager.isScreenshotProtectionEnabled)
                .onChange(of: securityManager.isScreenshotProtectionEnabled) { newValue in
                    securityManager.enableScreenshotProtection(newValue)
                }
            
            Toggle("Screen Recording Protection", isOn: $securityManager.isRecordingProtectionEnabled)
                .onChange(of: securityManager.isRecordingProtectionEnabled) { newValue in
                    securityManager.enableRecordingProtection(newValue)
                }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Enhanced Protection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("Protects your vault contents from screenshots and screen recording attempts.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
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
        Section(header: Text("Developer Options")) {
            Button(action: { showResetAlert = true }) {
                Label("Reset App (Delete All Data)", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
            
            Button(action: { showDeleteFilesAlert = true }) {
                Label("Delete All Files Only", systemImage: "trash.fill")
                    .foregroundColor(.orange)
            }
        }
        .alert("Reset App", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                resetApp()
            }
        } message: {
            Text("This will delete all data including your passcode and files. You'll need to set up the app again.")
        }
        .alert("Delete All Files", isPresented: $showDeleteFilesAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                performDeleteAllFiles()
            }
        } message: {
            Text("This will delete all files in your vault but keep your passcode and settings.")
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
    
    private var authenticationInfoView: some View {
        HStack {
            Text("Current Method")
            Spacer()
            Text(currentAuthType.displayName)
                .foregroundColor(.secondary)
        }
    }
    
    private var changeAuthButton: some View {
        Button(action: { showChangeAuthSheet = true }) {
            HStack {
                Text("Change Authentication")
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .foregroundColor(.primary)
    }
    
    private var lockTimeoutPicker: some View {
        Picker("Auto-Lock", selection: $lockTimeout) {
            ForEach(KeychainManager.LockTimeout.allCases, id: \.self) { timeout in
                Text(timeout.displayName).tag(timeout)
            }
        }
        .onChange(of: lockTimeout) { newValue in
            KeychainManager.shared.setLockTimeout(newValue)
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
    
    private func performDeleteAllFiles() {
        // Delete all vault items from Core Data
        let vaultItems = CoreDataManager.shared.fetchAllVaultItems()
        
        for item in vaultItems {
            // Delete file from storage
            do {
                try FileStorageManager.shared.deleteFile(vaultItem: item)
            } catch {
                print("Error deleting file: \(error)")
            }
            
            // Delete from Core Data
            CoreDataManager.shared.deleteVaultItem(item)
        }
        
        // Save context to ensure changes are persisted
        CoreDataManager.shared.save()
        
        // Send multiple notifications to ensure all views refresh
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            NotificationCenter.default.post(name: .NSManagedObjectContextDidSave, object: CoreDataManager.shared.context)
        }
        
        // Additional delayed notification for stubborn views
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        }
        
        dismiss()
    }
} 