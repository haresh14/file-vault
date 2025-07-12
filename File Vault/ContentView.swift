//
//  ContentView.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI
import Photos

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isPasswordSet = false
    @State private var isAuthTypeSet = false
    @State private var selectedAuthType: AuthenticationType?
    @State private var isInBackground = false
    @State private var isCheckingBiometric = false
    @State private var shouldShowPasscode = false
    @State private var shouldShowPrivacyOverlay = false
    @StateObject private var securityManager = SecurityManager.shared
    @Environment(\.scenePhase) var scenePhase
    
    // Check if password is already set
    private var hasPassword: Bool {
        return KeychainManager.shared.isPasswordSet()
    }
    
    // Check if auth type is already set
    private var hasAuthType: Bool {
        return KeychainManager.shared.isAuthenticationTypeSet()
    }
    
    var body: some View {
        ZStack {
            mainContent
            
            // Only show privacy overlay if user is fully registered and authenticated
            if shouldShowPrivacyOverlay && isPasswordSet {
                EnhancedPrivacyOverlay()
            }
        }
        .onAppear(perform: handleOnAppear)
        .onChange(of: scenePhase) { oldPhase, newPhase in
            handleScenePhaseChange(from: oldPhase, to: newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleWillEnterForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            handleDidEnterBackground()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if !isAuthTypeSet {
            // First time setup - choose auth type
            AuthTypeSelectionView { authType in
                selectedAuthType = authType
                isAuthTypeSet = true
            }
        } else if !isPasswordSet {
            // Setup the chosen authentication method
            if let authType = selectedAuthType {
                if authType.isPasscode {
                    PasscodeSetupView(authType: authType, onPasscodeSet: {
                        handlePasscodeSet()
                    }, onCancel: {
                        // Go back to auth type selection
                        selectedAuthType = nil
                        isAuthTypeSet = false
                    })
                } else {
                    PasswordSetupView(onPasswordSet: {
                        handlePasswordSet()
                    }, onCancel: {
                        // Go back to auth type selection
                        selectedAuthType = nil
                        isAuthTypeSet = false
                    })
                }
            } else {
                // Fallback to existing flow
                PasscodeView(isSettingPasscode: true) {
                    handlePasscodeSet()
                }
            }
        } else if !isAuthenticated {
            if isCheckingBiometric {
                // Show loading state while checking biometric
                BiometricCheckView()
            } else if shouldShowPasscode {
                // Only show passcode after biometric check is complete
                PasscodeView(isSettingPasscode: false) {
                    handleAuthentication()
                }
            }
        } else {
            MainTabView()
        }
    }
    
    private func handleOnAppear() {
        isPasswordSet = KeychainManager.shared.isPasswordSet()
        isAuthTypeSet = KeychainManager.shared.isAuthenticationTypeSet()
        
        // For existing users who have password but no auth type set, default to password
        if isPasswordSet && !isAuthTypeSet {
            KeychainManager.shared.setAuthenticationType(.password)
            isAuthTypeSet = true
            selectedAuthType = .password
        }
        
        // If auth type is set but no selected type, get it from storage
        if isAuthTypeSet && selectedAuthType == nil {
            selectedAuthType = KeychainManager.shared.getAuthenticationType()
        }
        
        // ContentView appeared - checking authentication state
        
        // Request photo library permission
        requestPhotoLibraryPermission()
        
        // If password is set but not authenticated, check if we should show biometric
        if isPasswordSet && !isAuthenticated {
            checkBiometricAuthentication()
        }
    }
    
    private func handleWillResignActive() {
        // Only activate privacy protection if registration is complete
        if isPasswordSet {
            shouldShowPrivacyOverlay = true
            KeychainManager.shared.setLastBackgroundTime()
            print("DEBUG: App going to background, showing enhanced privacy overlay")
        }
        isInBackground = true
    }
    
    private func handleDidBecomeActive() {
        shouldShowPrivacyOverlay = false
        isInBackground = false
        print("DEBUG: App became active, hiding privacy overlay")
    }
    
    private func handleWillEnterForeground() {
        shouldShowPrivacyOverlay = false
        
        if KeychainManager.shared.shouldRequireAuthentication() {
            isAuthenticated = false
            isCheckingBiometric = false
            shouldShowPasscode = false
            print("DEBUG: App coming to foreground, requires authentication")
            
            // Check biometric when coming from background
            if isPasswordSet && !isAuthenticated {
                checkBiometricAuthentication()
            }
        } else {
            print("DEBUG: App coming to foreground, within timeout period - no auth needed")
        }
    }
    
    private func handleDidEnterBackground() {
        // Only activate privacy protection if registration is complete
        if isPasswordSet {
            shouldShowPrivacyOverlay = true
            print("DEBUG: App entered background, showing enhanced privacy overlay")
        }
    }
    
    private func handleScenePhaseChange(from oldPhase: ScenePhase, to newPhase: ScenePhase) {
        if newPhase == .background {
            handleWillResignActive()
        } else if newPhase == .active {
            handleDidBecomeActive()
        }
    }
    
    private func checkBiometricAuthentication() {
        // Check if biometric is enabled and available
        if KeychainManager.shared.isBiometricEnabled() && BiometricAuthManager.shared.canUseBiometrics() {
            isCheckingBiometric = true
            shouldShowPasscode = false
            
            // Small delay to ensure UI is ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                BiometricAuthManager.shared.authenticateWithBiometrics(reason: "Unlock your vault") { success, error in
                    DispatchQueue.main.async {
                        if success {
                            KeychainManager.shared.clearLastBackgroundTime()
                            isAuthenticated = true
                            isCheckingBiometric = false
                            // Biometric authentication successful
                            
                            // Setup encryption key for file storage
                            if let password = try? KeychainManager.shared.getPassword() {
                                FileStorageManager.shared.setupEncryptionKey(from: password)
                            }
                        } else {
                            // Show passcode screen on failure or cancel
                            isCheckingBiometric = false
                            shouldShowPasscode = true
                            
                            if let error = error {
                                print("DEBUG: Biometric authentication failed: \(error.localizedDescription)")
                            }
                        }
                    }
                }
            }
        } else {
            // No biometric available, show passcode immediately
            shouldShowPasscode = true
        }
    }
    
    private func handlePasscodeSet() {
        // Passcode set successfully
        isPasswordSet = true
        isAuthenticated = true
        
        // Setup encryption key for file storage
        if let password = try? KeychainManager.shared.getPassword() {
            FileStorageManager.shared.setupEncryptionKey(from: password)
        }
    }
    
    private func handlePasswordSet() {
        // Password set successfully
        isPasswordSet = true
        isAuthenticated = true
        
        // Setup encryption key for file storage
        if let password = try? KeychainManager.shared.getPassword() {
            FileStorageManager.shared.setupEncryptionKey(from: password)
        }
    }
    
    private func handleAuthentication() {
        // Authentication successful
        isAuthenticated = true
        shouldShowPasscode = false
        
        // Reset biometric failure count after successful passcode entry
        BiometricAuthManager.shared.resetFailureCount()
        
        // Setup encryption key for file storage
        if let password = try? KeychainManager.shared.getPassword() {
            FileStorageManager.shared.setupEncryptionKey(from: password)
        }
    }
    
    private func requestPhotoLibraryPermission() {
        let photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        
        switch photoLibraryStatus {
        case .authorized:
            print("DEBUG: Photo library permission already granted.")
        case .limited:
            print("DEBUG: Photo library permission limited. User can select specific photos.")
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
                if status == .authorized || status == .limited {
                    print("DEBUG: Photo library permission granted (full or limited).")
                } else {
                    print("DEBUG: Photo library permission denied or restricted.")
                }
            }
        case .denied, .restricted:
            print("DEBUG: Photo library permission denied or restricted. Please enable it in Settings.")
        @unknown default:
            print("DEBUG: Unknown photo library status.")
        }
    }
}

// Loading view while checking biometric
struct BiometricCheckView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("Checking Authentication...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
}

// Enhanced privacy overlay with better visual design
struct EnhancedPrivacyOverlay: View {
    var body: some View {
        ZStack {
            Color.black
                .opacity(0.8)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text("File Vault")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your vault is protected by advanced security measures.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Text("App is in background to ensure your privacy.")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.bottom)
    }
}
    }
}


#Preview {
    ContentView()
}
