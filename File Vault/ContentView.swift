//
//  ContentView.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isPasswordSet = false
    @State private var isInBackground = false
    @State private var isCheckingBiometric = false
    @State private var shouldShowPasscode = false
    
    var body: some View {
        ZStack {
            mainContent
            
            if isInBackground {
                PrivacyOverlay()
            }
        }
        .onAppear(perform: handleOnAppear)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleWillEnterForeground()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if !isPasswordSet {
            PasscodeView(isSettingPasscode: true) {
                handlePasscodeSet()
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
            VaultMainView()
        }
    }
    
    private func handleOnAppear() {
        isPasswordSet = KeychainManager.shared.isPasswordSet()
        print("DEBUG: ContentView appeared")
        print("DEBUG: Is password set: \(isPasswordSet)")
        print("DEBUG: Is authenticated: \(isAuthenticated)")
        
        // If password is set but not authenticated, check if we should show biometric
        if isPasswordSet && !isAuthenticated {
            checkBiometricAuthentication()
        }
    }
    
    private func handleWillResignActive() {
        isInBackground = true
        KeychainManager.shared.setLastBackgroundTime()
        print("DEBUG: App going to background, showing privacy overlay")
    }
    
    private func handleDidBecomeActive() {
        isInBackground = false
        print("DEBUG: App became active, hiding privacy overlay")
    }
    
    private func handleWillEnterForeground() {
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
                            print("DEBUG: Biometric authentication successful")
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
        print("DEBUG: Passcode set successfully, updating states")
        isPasswordSet = true
        isAuthenticated = true
    }
    
    private func handleAuthentication() {
        print("DEBUG: Authentication successful, setting isAuthenticated = true")
        isAuthenticated = true
        shouldShowPasscode = false
        
        // Reset biometric failure count after successful passcode entry
        BiometricAuthManager.shared.resetFailureCount()
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

// Privacy overlay as a separate view
struct PrivacyOverlay: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 10) {
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white)
                    
                    Text("File Vault")
                        .font(.title)
                        .foregroundColor(.white)
                }
            )
    }
}

// Main vault view
struct VaultMainView: View {
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding()
                
                Text("Welcome to Your Vault")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your photos and videos are secure")
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("File Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

#Preview {
    ContentView()
}
