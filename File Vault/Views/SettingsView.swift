import CoreData
import Foundation
import SwiftUI

struct SettingsView: View {
    private enum Constants {
        static let trashEnabledKey = "trashEnabled"
        static let refreshDelay: TimeInterval = 0.2
    }

    @Environment(\.dismiss) private var dismiss
    @State private var biometricEnabled = KeychainManager.shared.isBiometricEnabled()
    @State private var lockTimeout = KeychainManager.shared.getLockTimeout()
    @State private var showBiometricAlert = false
    @State private var showChangeAuthSheet = false
    @State private var showFakePasswordSheet = false
    @State private var showFakePasswordAlert = false
    @State private var fakePasswordAlertMessage = ""
    @State private var showAuthChangeAlert = false
    @State private var isFakePasswordSet = false
    @State private var storageInfo: (fileCount: Int, usedSpace: Int64) = (0, 0)
    @State private var trashEnabled = UserDefaults.standard.bool(forKey: Constants.trashEnabledKey)
    @State private var showDisableTrashAlert = false
    @State private var trashItemCount = 0
    @State private var showResetAlert = false
    @State private var showResetConfirmation = false
    @State private var showDeleteFilesAlert = false
    @StateObject private var securityManager = SecurityManager.shared
    @StateObject private var loginStateManager = LoginStateManager.shared

    private var currentAuthType: AuthenticationType {
        KeychainManager.shared.getAuthenticationType()
    }

    var body: some View {
        NavigationStack {
            Form {
                if loginStateManager.canAccessFullSettings {
                    authenticationSection
                    securitySection
                    SettingsTrashDataSections(
                        trashEnabled: $trashEnabled,
                        trashItemCount: trashItemCount,
                        fileCount: storageInfo.fileCount,
                        formattedUsedSpace: formatFileSize(storageInfo.usedSpace),
                        updateTrashEnabled: updateTrashEnabled
                    )
                    SettingsWebBackgroundSection(
                        lockTimeoutDisplayName: lockTimeoutDisplayName,
                        lockBehaviorDescription: lockBehaviorDescription
                    )
                    #if DEBUG
                    SettingsDebugSection(
                        completeReset: { showResetAlert = true },
                        simulateFirstLaunch: performFirstLaunchCleanup,
                        deleteAllFiles: { showDeleteFilesAlert = true }
                    )
                    #endif
                }
                Section("About") {
                    LabeledContent("Version", value: "1.0.0")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
        .modifier(SettingsPresentationModifier(
            showBiometricAlert: $showBiometricAlert,
            showResetConfirmation: $showResetConfirmation,
            showAuthChangeAlert: $showAuthChangeAlert,
            showFakePasswordAlert: $showFakePasswordAlert,
            showDisableTrashAlert: $showDisableTrashAlert,
            showResetAlert: $showResetAlert,
            showDeleteFilesAlert: $showDeleteFilesAlert,
            fakePasswordAlertMessage: fakePasswordAlertMessage,
            trashItemCount: trashItemCount,
            setNewFakePassword: { showFakePasswordSheet = true },
            emptyTrashAndDisable: emptyTrashAndDisable,
            performCompleteReset: performCompleteReset,
            performDeleteAllFiles: performDeleteAllFiles
        ))
        .sheet(isPresented: $showChangeAuthSheet) {
            ChangeAuthenticationView(currentAuthType: currentAuthType, onAuthChanged: authenticationChanged)
        }
        .sheet(isPresented: $showFakePasswordSheet) {
            fakePasswordSetup
        }
        .onAppear {
            loadStorageInfo()
            isFakePasswordSet = KeychainManager.shared.isFakePasswordSet()
            loadTrashCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshVaultItems)) { _ in
            loadStorageInfo()
            loadTrashCount()
        }
    }

    private var authenticationSection: some View {
        SettingsAuthenticationSection(
            currentAuthType: currentAuthType,
            isFakePasswordSet: isFakePasswordSet,
            lockTimeout: $lockTimeout,
            biometricEnabled: $biometricEnabled,
            showChangeAuthentication: { showChangeAuthSheet = true },
            showFakePasswordSetup: { showFakePasswordSheet = true },
            removeFakePassword: removeFakePassword,
            updateLockTimeout: { KeychainManager.shared.setLockTimeout($0) },
            updateBiometric: handleBiometricToggle
        )
    }

    private var securitySection: some View {
        SettingsSecuritySection(
            screenshotProtection: $securityManager.isScreenshotProtectionEnabled,
            recordingProtection: $securityManager.isRecordingProtectionEnabled,
            shakeToLock: $securityManager.isShakeToLockEnabled,
            flipToLock: $securityManager.isFlipToLockEnabled,
            updateScreenshotProtection: securityManager.enableScreenshotProtection,
            updateRecordingProtection: securityManager.enableRecordingProtection,
            updateShakeToLock: securityManager.enableShakeToLock,
            updateFlipToLock: securityManager.enableFlipToLock
        )
    }

    @ViewBuilder
    private var fakePasswordSetup: some View {
        NavigationStack {
            if currentAuthType.isPasscode {
                PasscodeSetupView(
                    authType: currentAuthType,
                    onPasscodeSet: {
                        completeFakePasswordSetup(message: "Fake passcode set successfully.")
                    },
                    onCancel: { showFakePasswordSheet = false },
                    isFakePasswordSetup: true
                )
            } else {
                PasswordSetupView(
                    onPasswordSet: {
                        completeFakePasswordSetup(message: "Fake password set successfully.")
                    },
                    onCancel: { showFakePasswordSheet = false },
                    isFakePasswordSetup: true
                )
            }
        }
    }

    private var lockTimeoutDisplayName: String {
        KeychainManager.LockTimeout(rawValue: lockTimeout)?.displayName ?? "Unknown"
    }

    private var lockBehaviorDescription: String {
        switch KeychainManager.LockTimeout(rawValue: lockTimeout) {
        case .immediate: return "App will lock immediately when backgrounded"
        case .fiveSeconds: return "App will lock after 5 seconds in background"
        case .tenSeconds: return "App will lock after 10 seconds in background"
        case .fifteenSeconds: return "App will lock after 15 seconds in background"
        case .thirtySeconds: return "App will lock after 30 seconds in background"
        case .oneMinute: return "App will lock after 1 minute in background"
        case .fiveMinutes: return "App will lock after 5 minutes in background"
        case .never: return "App will never lock automatically (not recommended)"
        case .none: return "App will lock after \(lockTimeout) seconds in background"
        }
    }

    private func authenticationChanged() {
        showChangeAuthSheet = false
        guard KeychainManager.shared.isFakePasswordSet() else { return }
        do {
            try KeychainManager.shared.deleteFakePassword()
            isFakePasswordSet = false
        } catch {
            print("Failed to remove fake password after authentication change: \(error)")
        }
        showAuthChangeAlert = true
    }

    private func completeFakePasswordSetup(message: String) {
        showFakePasswordSheet = false
        isFakePasswordSet = true
        fakePasswordAlertMessage = message
        showFakePasswordAlert = true
    }

    private func handleBiometricToggle(_ isEnabled: Bool) {
        if isEnabled && !BiometricAuthManager.shared.canUseBiometrics() {
            biometricEnabled = false
            showBiometricAlert = true
        } else {
            KeychainManager.shared.setBiometricEnabled(isEnabled)
        }
    }

    private func updateTrashEnabled(_ isEnabled: Bool) {
        if isEnabled {
            UserDefaults.standard.set(true, forKey: Constants.trashEnabledKey)
        } else if trashItemCount > 0 {
            showDisableTrashAlert = true
            trashEnabled = true
        } else {
            UserDefaults.standard.set(false, forKey: Constants.trashEnabledKey)
        }
    }

    private func performCompleteReset() {
        AppDataManager.shared.performCompleteAppReset()
        showResetConfirmation = true
    }

    private func performFirstLaunchCleanup() {
        AppDataManager.shared.clearAllAppData()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
        }
        dismiss()
    }

    private func performDeleteAllFiles() {
        FileStorageManager.shared.deleteAllVaultContent()
        CoreDataManager.shared.fetchAllFolders().forEach(CoreDataManager.shared.deleteFolder)
        CoreDataManager.shared.save()
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
            NotificationCenter.default.post(
                name: .NSManagedObjectContextDidSave,
                object: CoreDataManager.shared.context
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Constants.refreshDelay) {
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
        }
        dismiss()
    }

    private func loadStorageInfo() {
        DispatchQueue.global(qos: .userInitiated).async {
            let info = FileStorageManager.shared.getStorageInfo()
            DispatchQueue.main.async { storageInfo = info }
        }
    }

    private func loadTrashCount() {
        DispatchQueue.global(qos: .userInitiated).async {
            let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
            request.predicate = NSPredicate(format: "isTrashed == true")
            let count = (try? CoreDataManager.shared.context.count(for: request)) ?? 0
            DispatchQueue.main.async { trashItemCount = count }
        }
    }

    private func emptyTrashAndDisable() {
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        request.predicate = NSPredicate(format: "isTrashed == true")
        do {
            for item in try CoreDataManager.shared.context.fetch(request) {
                do {
                    try FileStorageManager.shared.permanentlyDeleteFile(vaultItem: item)
                } catch {
                    print("Error permanently deleting trashed file: \(error)")
                }
            }
            CoreDataManager.shared.save()
            UserDefaults.standard.set(false, forKey: Constants.trashEnabledKey)
            trashEnabled = false
            loadTrashCount()
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
        } catch {
            print("Error fetching trashed items: \(error)")
        }
    }

    private func removeFakePassword() {
        do {
            try KeychainManager.shared.deleteFakePassword()
            isFakePasswordSet = false
            fakePasswordAlertMessage = "Fake password removed successfully."
        } catch {
            fakePasswordAlertMessage = "Failed to remove fake password."
        }
        showFakePasswordAlert = true
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

private struct SettingsPresentationModifier: ViewModifier {
    @Binding var showBiometricAlert: Bool
    @Binding var showResetConfirmation: Bool
    @Binding var showAuthChangeAlert: Bool
    @Binding var showFakePasswordAlert: Bool
    @Binding var showDisableTrashAlert: Bool
    @Binding var showResetAlert: Bool
    @Binding var showDeleteFilesAlert: Bool
    let fakePasswordAlertMessage: String
    let trashItemCount: Int
    let setNewFakePassword: () -> Void
    let emptyTrashAndDisable: () -> Void
    let performCompleteReset: () -> Void
    let performDeleteAllFiles: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Biometric Authentication", isPresented: $showBiometricAlert) {
                Button("OK") {}
            } message: {
                Text("Biometric authentication is not available on this device. This feature requires Face ID or Touch ID.")
            }
            .alert("App Reset", isPresented: $showResetConfirmation) {
                Button("OK") { exit(0) }
            } message: {
                Text("The app has been reset. Please restart the app.")
            }
            .alert("Fake Password Removed", isPresented: $showAuthChangeAlert) {
                Button("Set New Fake Password", action: setNewFakePassword)
                Button("OK", role: .cancel) {}
            } message: {
                Text("Your authentication method has changed. The fake password has been automatically removed for security. You can set a new fake password matching the new authentication format if needed.")
            }
            .alert("Fake Password", isPresented: $showFakePasswordAlert) {
                Button("OK") {}
            } message: {
                Text(fakePasswordAlertMessage)
            }
            .alert("Disable Trash", isPresented: $showDisableTrashAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Empty Trash & Disable", role: .destructive, action: emptyTrashAndDisable)
            } message: {
                Text("There are \(trashItemCount) item(s) in trash. Disabling trash will permanently delete all items. This action cannot be undone.")
            }
            .alert("Complete App Reset", isPresented: $showResetAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Reset", role: .destructive, action: performCompleteReset)
            } message: {
                Text("This will completely reset the app to first-launch state. All data including keychain, files, and settings will be deleted.")
            }
            .alert("Delete All Files", isPresented: $showDeleteFilesAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete All", role: .destructive, action: performDeleteAllFiles)
            } message: {
                Text("This will delete all files and folders in your vault but keep your passcode and settings.")
            }
    }
}
