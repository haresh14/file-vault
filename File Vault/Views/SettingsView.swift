//
//  SettingsView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import CoreData

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var biometricEnabled = KeychainManager.shared.isBiometricEnabled()
    @State private var showResetAlert = false
    @State private var showResetConfirmation = false
    @State private var showDeleteFilesAlert = false
    @State private var lockTimeout = KeychainManager.shared.getLockTimeout()
    
    private var lockTimeoutDisplayName: String {
        guard let lockTimeoutEnum = KeychainManager.LockTimeout(rawValue: lockTimeout) else {
            return "Unknown"
        }
        return lockTimeoutEnum.displayName
    }
    @State private var showBiometricAlert = false
    @State private var showChangeAuthSheet = false
    @State private var showFakePasswordSheet = false
    @State private var showFakePasswordAlert = false
    @State private var fakePasswordAlertMessage = ""
    @State private var showAuthChangeAlert = false
    @State private var isFakePasswordSet = false
    @StateObject private var securityManager = SecurityManager.shared
    @StateObject private var loginStateManager = LoginStateManager.shared
    @State private var storageInfo: (fileCount: Int, usedSpace: Int64) = (0, 0)
    @State private var trashEnabled = UserDefaults.standard.bool(forKey: "trashEnabled")
    @State private var showDisableTrashAlert = false

    @State private var trashItemCount = 0
    
    private var currentAuthType: AuthenticationType {
        KeychainManager.shared.getAuthenticationType()
    }
    
    var body: some View {
        NavigationView {
            Form {
                if loginStateManager.canAccessFullSettings {
                    securitySection
                    advancedSecuritySection
                    trashSection
                    lockBehaviorSection
                    infoSection
                    
                    #if DEBUG
                    developerSection
                    #endif
                }
                
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            // Removed Done button from toolbar
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
                    showChangeAuthSheet = false
                    
                    // If fake password is set, remove it and show alert
                    if KeychainManager.shared.isFakePasswordSet() {
                        // Remove fake password in background
                        do {
                            try KeychainManager.shared.deleteFakePassword()
                            isFakePasswordSet = false
                            print("DEBUG: Fake password automatically removed due to auth method change")
                        } catch {
                            print("DEBUG: Failed to remove fake password: \(error)")
                        }
                        
                        // Show alert to inform user
                        showAuthChangeAlert = true
                    }
                }
            )
        }
        .alert("Fake Password Removed", isPresented: $showAuthChangeAlert) {
            Button("Set New Fake Password") {
                showFakePasswordSheet = true
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Your authentication method has changed. The fake password has been automatically removed for security. You can set a new fake password matching the new authentication format if needed.")
        }
        .alert("Fake Password", isPresented: $showFakePasswordAlert) {
            Button("OK") { }
        } message: {
            Text(fakePasswordAlertMessage)
        }
        .sheet(isPresented: $showFakePasswordSheet) {
            NavigationView {
                if currentAuthType.isPasscode {
                    PasscodeSetupView(
                        authType: currentAuthType,
                        onPasscodeSet: {
                            showFakePasswordSheet = false
                            isFakePasswordSet = true
                            fakePasswordAlertMessage = "Fake passcode set successfully."
                            showFakePasswordAlert = true
                        },
                        onCancel: {
                            showFakePasswordSheet = false
                        },
                        isFakePasswordSetup: true
                    )
                } else {
                    PasswordSetupView(
                        onPasswordSet: {
                                showFakePasswordSheet = false
                                isFakePasswordSet = true
                                fakePasswordAlertMessage = "Fake password set successfully."
                                showFakePasswordAlert = true
                            },
                        onCancel: {
                            showFakePasswordSheet = false
                        },
                        isFakePasswordSetup: true
                    )
                }
            }
        }

        .onAppear {
            loadStorageInfo()
            isFakePasswordSet = KeychainManager.shared.isFakePasswordSet()
            loadTrashCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))) { _ in
            loadStorageInfo()
            loadTrashCount()
        }
    }
    
    // MARK: - Section Views
    
    private var securitySection: some View {
        Section("Security") {
            authenticationInfoView
            changeAuthButton
            
            // Fake Password Settings
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Fake Password")
                    Spacer()
                    Text(isFakePasswordSet ? "Set" : "Not Set")
                        .foregroundColor(isFakePasswordSet ? .green : .secondary)
                        .font(.caption)
                }
                
                Text("Create a decoy password that shows an empty vault when used")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Button(action: { showFakePasswordSheet = true }) {
                HStack {
                    Text(isFakePasswordSet ? "Change Fake Password" : "Set Fake Password")
                    Spacer()
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                        .font(.caption)
                }
            }
            .foregroundColor(.primary)
            
            if isFakePasswordSet {
                Button(action: { 
                    removeFakePassword()
                }) {
                    Text("Remove Fake Password")
                        .foregroundColor(.red)
                }
            }
            
            lockTimeoutPicker
            biometricToggle
            biometricStatusView
        }
    }
    
    private var advancedSecuritySection: some View {
        Section("Advanced Security") {
            Toggle("Screenshot Protection", isOn: $securityManager.isScreenshotProtectionEnabled)
                .onChange(of: securityManager.isScreenshotProtectionEnabled) { _, newValue in
                    securityManager.enableScreenshotProtection(newValue)
                }
            
            Toggle("Screen Recording Protection", isOn: $securityManager.isRecordingProtectionEnabled)
                .onChange(of: securityManager.isRecordingProtectionEnabled) { _, newValue in
                    securityManager.enableRecordingProtection(newValue)
                }
            
            Toggle("Shake to Lock", isOn: $securityManager.isShakeToLockEnabled)
                .onChange(of: securityManager.isShakeToLockEnabled) { _, newValue in
                    securityManager.enableShakeToLock(newValue)
                }
            
            Toggle("Flip to Lock", isOn: $securityManager.isFlipToLockEnabled)
                .onChange(of: securityManager.isFlipToLockEnabled) { _, newValue in
                    securityManager.enableFlipToLock(newValue)
                }
            
            VStack(alignment: .leading, spacing: 5) {
                Text("Enhanced Protection")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• Screenshot/Recording: Protects vault contents from capture attempts\n• Shake to Lock: Locks app when device is shaken vigorously\n• Flip to Lock: Locks app when device is flipped face-down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var trashSection: some View {
        Section(header: Text("Trash")) {
            Toggle("Enable Trash", isOn: $trashEnabled)
                .onChange(of: trashEnabled) { _, newValue in
                    if newValue {
                        // Enabling trash - no confirmation needed
                        UserDefaults.standard.set(newValue, forKey: "trashEnabled")
                    } else {
                        // Disabling trash - check if there are items in trash
                        if trashItemCount > 0 {
                            // Show confirmation alert
                            showDisableTrashAlert = true
                            // Revert the toggle until user confirms
                            trashEnabled = true
                        } else {
                            // No items in trash - disable immediately
                            UserDefaults.standard.set(newValue, forKey: "trashEnabled")
                        }
                    }
                }
            
            if trashEnabled {
                NavigationLink(destination: TrashView()) {
                    HStack {
                        Text("View Trash")
                        Spacer()
                        if trashItemCount > 0 {
                            Text("\(trashItemCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .foregroundColor(.primary)
                
                Text("Deleted files are moved to trash instead of being permanently deleted.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .alert("Disable Trash", isPresented: $showDisableTrashAlert) {
            Button("Cancel", role: .cancel) {
                // Keep trash enabled (toggle is already reverted)
            }
            Button("Empty Trash & Disable", role: .destructive) {
                // Empty trash and disable
                emptyTrashAndDisable()
            }
        } message: {
            Text("There are \(trashItemCount) item(s) in trash. Disabling trash will permanently delete all items. This action cannot be undone.")
        }
    }
    
    private var lockBehaviorSection: some View {
        Section("Lock Behavior") {
            VStack(alignment: .leading, spacing: 5) {
                Text("Current Setting: \(lockTimeoutDisplayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(lockBehaviorDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var infoSection: some View {
        Section("Disk") {
            HStack {
                Text("Total Files")
                Spacer()
                Text("\(storageInfo.fileCount)")
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Text("Total Size")
                Spacer()
                Text(formatFileSize(storageInfo.usedSpace))
                    .foregroundColor(.secondary)
            }
        }
    }
    
    #if DEBUG
    private var developerSection: some View {
        Section(header: Text("Developer Options")) {
            Button(action: { showResetAlert = true }) {
                Label("Complete App Reset", systemImage: "exclamationmark.triangle")
                    .foregroundColor(.red)
            }
            
            Button(action: { 
                performFirstLaunchCleanup() 
            }) {
                Label("Simulate First Launch Cleanup", systemImage: "arrow.clockwise")
                    .foregroundColor(.orange)
            }
            
            Button(action: { showDeleteFilesAlert = true }) {
                Label("Delete All Files & Folders", systemImage: "trash.fill")
                    .foregroundColor(.orange)
            }
        }
        .alert("Complete App Reset", isPresented: $showResetAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Reset", role: .destructive) {
                performCompleteReset()
            }
        } message: {
            Text("This will completely reset the app to first-launch state. All data including keychain, files, and settings will be deleted.")
        }
        .alert("Delete All Files", isPresented: $showDeleteFilesAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete All", role: .destructive) {
                performDeleteAllFiles()
            }
        } message: {
            Text("This will delete all files and folders in your vault but keep your passcode and settings.")
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
                Text(timeout.displayName).tag(timeout.rawValue)
            }
        }
        .onChange(of: lockTimeout) { _, newValue in
            KeychainManager.shared.setLockTimeout(newValue)
        }
    }
    
    private var biometricToggle: some View {
        Toggle("Enable Biometric Authentication", isOn: $biometricEnabled)
            .onChange(of: biometricEnabled) { _, newValue in
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
        case 0: // immediate
            return "App will lock immediately when backgrounded"
        case 5: // fiveSeconds
            return "App will lock after 5 seconds in background"
        case 10: // tenSeconds
            return "App will lock after 10 seconds in background"
        case 15: // fifteenSeconds
            return "App will lock after 15 seconds in background"
        case 30: // thirtySeconds
            return "App will lock after 30 seconds in background"
        case 60: // oneMinute
            return "App will lock after 1 minute in background"
        case 300: // fiveMinutes
            return "App will lock after 5 minutes in background"
        case -1: // never
            return "App will never lock automatically (not recommended)"
        default:
            return "App will lock after \(lockTimeout) seconds in background"
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
    
    private func performCompleteReset() {
        print("DEBUG: Developer triggered complete app reset")
        AppDataManager.shared.performCompleteAppReset()
        showResetConfirmation = true
    }
    
    private func performFirstLaunchCleanup() {
        print("DEBUG: Developer triggered first launch cleanup simulation")
        AppDataManager.shared.clearAllAppData()
        
        // Refresh the view and show success
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        }
        
        dismiss()
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
        
        // Delete all folders from Core Data
        let folders = CoreDataManager.shared.fetchAllFolders()
        
        for folder in folders {
            CoreDataManager.shared.deleteFolder(folder)
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
    
    private func loadStorageInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let info = FileStorageManager.shared.getStorageInfo()
            DispatchQueue.main.async {
                self.storageInfo = info
            }
        }
    }
    
    private func loadTrashCount() {
        DispatchQueue.global(qos: .userInitiated).async {
            let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
            request.predicate = NSPredicate(format: "isTrashed == true")
            
            do {
                let count = try CoreDataManager.shared.context.count(for: request)
                DispatchQueue.main.async {
                    self.trashItemCount = count
                }
            } catch {
                DispatchQueue.main.async {
                    self.trashItemCount = 0
                }
            }
        }
    }
    
    private func emptyTrashAndDisable() {
        // Fetch all trashed items
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        request.predicate = NSPredicate(format: "isTrashed == true")
        
        do {
            let trashedItems = try CoreDataManager.shared.context.fetch(request)
            
            // Permanently delete each item
            for item in trashedItems {
                do {
                    try FileStorageManager.shared.permanentlyDeleteFile(vaultItem: item)
                } catch {
                    print("Error permanently deleting trashed file: \(error)")
                }
            }
            
            // Save context to ensure changes are persisted
            CoreDataManager.shared.save()
            
            // Disable trash
            UserDefaults.standard.set(false, forKey: "trashEnabled")
            trashEnabled = false
            
            // Refresh trash count
            loadTrashCount()
            
            // Notify other views to refresh
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            
        } catch {
            print("Error fetching trashed items: \(error)")
        }
    }
    
    private func removeFakePassword() {
        do {
            try KeychainManager.shared.deleteFakePassword()
            isFakePasswordSet = false
            fakePasswordAlertMessage = "Fake password removed successfully."
            showFakePasswordAlert = true
        } catch {
            fakePasswordAlertMessage = "Failed to remove fake password."
            showFakePasswordAlert = true
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
} 