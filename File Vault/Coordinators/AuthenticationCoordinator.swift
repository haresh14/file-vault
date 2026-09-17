import SwiftUI
import UIKit

final class AuthenticationCoordinator: ObservableObject {
    @Published var isAuthenticated = false
    @Published var isPasswordSet = false
    @Published var isAuthTypeSet = false
    @Published var selectedAuthType: AuthenticationType?
    @Published var isInBackground = false
    @Published var isCheckingBiometric = false
    @Published var shouldShowPasscode = false
    @Published var shouldShowPrivacyOverlay = false

    private let keychainManager: KeychainManaging
    private let biometricManager: any BiometricAuthManaging
    private let loginStateManager: any LoginStateManaging
    private let fileStorageManager: FileStorageManaging

    init(
        keychainManager: KeychainManaging = KeychainManager.shared,
        biometricManager: any BiometricAuthManaging = BiometricAuthManager.shared,
        loginStateManager: any LoginStateManaging = LoginStateManager.shared,
        fileStorageManager: FileStorageManaging = FileStorageManager.shared
    ) {
        self.keychainManager = keychainManager
        self.biometricManager = biometricManager
        self.loginStateManager = loginStateManager
        self.fileStorageManager = fileStorageManager
    }

    func handleAuthTypeSelected(_ authType: AuthenticationType) {
        selectedAuthType = authType
        isAuthTypeSet = true
        handlePasscodeSet()
    }

    func handleOnAppear() {
        isPasswordSet = keychainManager.isPasswordSet()
        isAuthTypeSet = keychainManager.isAuthenticationTypeSet()

        // Preserve migration for existing users who predate authentication type storage.
        if isPasswordSet && !isAuthTypeSet {
            keychainManager.setAuthenticationType(.password)
            isAuthTypeSet = true
            selectedAuthType = .password
        }

        if isAuthTypeSet && selectedAuthType == nil {
            selectedAuthType = keychainManager.getAuthenticationType()
        }

        if isPasswordSet && !isAuthenticated {
            checkBiometricAuthentication()
        }
    }

    func handleWillResignActive() {
        if isPasswordSet {
            shouldShowPrivacyOverlay = true
            keychainManager.setLastBackgroundTime()
        }
        isInBackground = true
    }

    func handleDidBecomeActive() {
        shouldShowPrivacyOverlay = false
        isInBackground = false
    }

    func handleWillEnterForeground() {
        shouldShowPrivacyOverlay = false

        if keychainManager.shouldRequireAuthentication() {
            isAuthenticated = false
            isCheckingBiometric = false
            shouldShowPasscode = false
            loginStateManager.resetLoginState()

            if isPasswordSet && !isAuthenticated {
                checkBiometricAuthentication()
            }
        }
    }

    func handleDidEnterBackground() {
        if isPasswordSet {
            shouldShowPrivacyOverlay = true
            VaultLog.debug("DEBUG: App entered background, showing enhanced privacy overlay")
        }
    }

    func handleScenePhaseChange(to newPhase: ScenePhase) {
        if newPhase == .background {
            handleWillResignActive()
        } else if newPhase == .active {
            handleDidBecomeActive()
        }
    }

    func handlePasscodeSet() {
        isPasswordSet = true
        isAuthenticated = true
        setupEncryptionKey()
    }

    func handleAuthentication() {
        isAuthenticated = true
        shouldShowPasscode = false
        biometricManager.resetFailureCount()
        setupEncryptionKey()
    }

    func handleSecurityLockTrigger() {
        guard isAuthenticated else { return }

        isAuthenticated = false
        loginStateManager.resetLoginState()
        keychainManager.setLastBackgroundTime()

        DispatchQueue.main.async {
            let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
            impactFeedback.impactOccurred()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.checkBiometricAuthentication()
        }
    }

    private func checkBiometricAuthentication() {
        guard keychainManager.isBiometricEnabled(), biometricManager.canUseBiometrics() else {
            shouldShowPasscode = true
            return
        }

        isCheckingBiometric = true
        shouldShowPasscode = false

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.biometricManager.authenticateWithBiometrics(reason: "Unlock your vault") { [weak self] success, error in
                DispatchQueue.main.async {
                    guard let self = self else { return }
                    if success {
                        self.keychainManager.clearLastBackgroundTime()
                        self.isAuthenticated = true
                        self.isCheckingBiometric = false
                        self.loginStateManager.setLoginState(isFakeLogin: false)
                        self.setupEncryptionKey()
                    } else {
                        self.isCheckingBiometric = false
                        self.shouldShowPasscode = true
                        if let error = error {
                            VaultLog.debug("DEBUG: Biometric authentication failed: \(error.localizedDescription)")
                        }
                    }
                }
            }
        }
    }

    private func setupEncryptionKey() {
        if let password = try? keychainManager.getPassword() {
            fileStorageManager.setupEncryptionKey(from: password)
        }
    }
}
