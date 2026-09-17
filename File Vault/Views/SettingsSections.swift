import SwiftUI

struct SettingsSecuritySection: View {
    @Binding var screenshotProtection: Bool
    @Binding var recordingProtection: Bool
    @Binding var shakeToLock: Bool
    @Binding var flipToLock: Bool
    let updateScreenshotProtection: (Bool) -> Void
    let updateRecordingProtection: (Bool) -> Void
    let updateShakeToLock: (Bool) -> Void
    let updateFlipToLock: (Bool) -> Void

    var body: some View {
        Section("Advanced Security") {
            Toggle("Screenshot Protection", isOn: $screenshotProtection)
                .accessibilityIdentifier("settings.screenshotProtection")
                .onChange(of: screenshotProtection) { _, value in updateScreenshotProtection(value) }
            Toggle("Screen Recording Protection", isOn: $recordingProtection)
                .accessibilityIdentifier("settings.recordingProtection")
                .onChange(of: recordingProtection) { _, value in updateRecordingProtection(value) }
            Toggle("Shake to Lock", isOn: $shakeToLock)
                .accessibilityIdentifier("settings.shakeToLock")
                .onChange(of: shakeToLock) { _, value in updateShakeToLock(value) }
            Toggle("Flip to Lock", isOn: $flipToLock)
                .accessibilityIdentifier("settings.flipToLock")
                .onChange(of: flipToLock) { _, value in updateFlipToLock(value) }
            VStack(alignment: .leading, spacing: 5) {
                Text("Enhanced Protection").font(.caption).foregroundColor(.secondary)
                Text("• Screenshots: the vault stays on screen; Photos gets a blank image\n• Screen recording: a black cover while a recording is in progress\n• Shake to Lock: locks the app when the device is shaken vigorously\n• Flip to Lock: locks the app when the device is flipped face-down")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct SettingsAuthenticationSection: View {
    let currentAuthType: AuthenticationType
    let isFakePasswordSet: Bool
    @Binding var lockTimeout: Int
    @Binding var biometricEnabled: Bool
    let showChangeAuthentication: () -> Void
    let showFakePasswordSetup: () -> Void
    let removeFakePassword: () -> Void
    let updateLockTimeout: (Int) -> Void
    let updateBiometric: (Bool) -> Void

    var body: some View {
        Section("Security") {
            HStack {
                Text("Current Method")
                Spacer()
                Text(currentAuthType.displayName).foregroundColor(.secondary)
            }
            Button(action: showChangeAuthentication) {
                HStack {
                    Text("Change Authentication")
                    Spacer()
                    Image(systemName: "chevron.right").foregroundColor(.secondary).font(.caption)
                }
            }
            .foregroundColor(.primary)
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
            Button(action: showFakePasswordSetup) {
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
                Button("Remove Fake Password", role: .destructive, action: removeFakePassword)
            }
            Picker("Auto-Lock", selection: $lockTimeout) {
                ForEach(KeychainManager.LockTimeout.allCases, id: \.self) { timeout in
                    Text(timeout.displayName).tag(timeout.rawValue)
                }
            }
            .accessibilityIdentifier("settings.autoLock")
            .onChange(of: lockTimeout) { _, value in updateLockTimeout(value) }
            Toggle("Enable Biometric Authentication", isOn: $biometricEnabled)
                .accessibilityIdentifier("settings.biometric")
                .onChange(of: biometricEnabled) { _, value in updateBiometric(value) }
            biometricStatus
        }
    }

    private var biometricStatus: some View {
        let isAvailable = BiometricAuthManager.shared.canUseBiometrics()
        let isFaceID = BiometricAuthManager.shared.biometricType() == .faceID
        return HStack {
            Image(systemName: isAvailable ? (isFaceID ? "faceid" : "touchid") : "exclamationmark.circle")
                .foregroundColor(isAvailable ? .green : .orange)
            Text(isAvailable ? "\(isFaceID ? "Face ID" : "Touch ID") Available" : "Biometric authentication not available")
                .foregroundColor(.secondary)
                .font(.caption)
        }
    }
}

struct SettingsTrashDataSections: View {
    @Binding var trashEnabled: Bool
    let trashItemCount: Int
    let fileCount: Int
    let formattedUsedSpace: String
    let updateTrashEnabled: (Bool) -> Void

    var body: some View {
        Group {
            Section("Trash") {
                Toggle("Enable Trash", isOn: $trashEnabled)
                    .accessibilityIdentifier("settings.trash")
                    .onChange(of: trashEnabled) { _, value in updateTrashEnabled(value) }
                if trashEnabled {
                    NavigationLink(destination: TrashView()) {
                        HStack {
                            Text("View Trash")
                            Spacer()
                            if trashItemCount > 0 {
                                Text("\(trashItemCount)").foregroundColor(.secondary)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                    Text("Deleted files are moved to trash instead of being permanently deleted.")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            Section("Disk") {
                LabeledContent("Total Files", value: "\(fileCount)")
                LabeledContent("Total Size", value: formattedUsedSpace)
            }
        }
    }
}

struct SettingsWebBackgroundSection: View {
    let lockTimeoutDisplayName: String
    let lockBehaviorDescription: String

    var body: some View {
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
}

#if DEBUG
struct SettingsDebugSection: View {
    let completeReset: () -> Void
    let simulateFirstLaunch: () -> Void
    let deleteAllFiles: () -> Void

    var body: some View {
        Section("Developer Options") {
            Button(action: completeReset) {
                Label("Complete App Reset", systemImage: "exclamationmark.triangle").foregroundColor(.red)
            }
            Button(action: simulateFirstLaunch) {
                Label("Simulate First Launch Cleanup", systemImage: "arrow.clockwise").foregroundColor(.orange)
            }
            Button(action: deleteAllFiles) {
                Label("Delete All Files & Folders", systemImage: "trash.fill").foregroundColor(.orange)
            }
        }
    }
}
#endif
