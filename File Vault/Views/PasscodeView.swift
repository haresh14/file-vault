//
//  PasscodeView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct PasscodeView: View {
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @FocusState private var isPasscodeFocused: Bool
    
    let isSettingPasscode: Bool
    let onAuthenticated: () -> Void
    let onCancel: (() -> Void)?
    
    init(isSettingPasscode: Bool = false, onAuthenticated: @escaping () -> Void, onCancel: (() -> Void)? = nil) {
        self.isSettingPasscode = isSettingPasscode
        self.onAuthenticated = onAuthenticated
        self.onCancel = onCancel
    }
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                Spacer()
                
                // Lock icon
                Image(systemName: "lock.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                    .padding(.bottom, 20)
                
                // Title
                Text(isSettingPasscode ? "Set Your Passcode" : "Enter Passcode")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                // Subtitle
                Text(isSettingPasscode ? "Create a secure passcode to protect your vault" : "Access your secure vault")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 20) {
                    // Passcode field
                    SecureField("Passcode", text: $passcode)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 300)
                        .focused($isPasscodeFocused)
                        .onSubmit {
                            if isSettingPasscode && !confirmPasscode.isEmpty {
                                handleSetPasscode()
                            } else if !isSettingPasscode {
                                handleAuthentication()
                            }
                        }
                    
                    // Confirm passcode field (only when setting)
                    if isSettingPasscode {
                        SecureField("Confirm Passcode", text: $confirmPasscode)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: 300)
                            .onSubmit {
                                handleSetPasscode()
                            }
                    }
                    
                    // Error message
                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .font(.caption)
                            .transition(.opacity)
                    }
                    
                    // Action button
                    Button(action: {
                        if isSettingPasscode {
                            handleSetPasscode()
                        } else {
                            handleAuthentication()
                        }
                    }) {
                        Text(isSettingPasscode ? "Set Passcode" : "Unlock")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: 300)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                    .disabled(passcode.isEmpty || (isSettingPasscode && confirmPasscode.isEmpty))
                    
                    // Cancel button (if available)
                    if let onCancel = onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                        .foregroundColor(.blue)
                    }
                }
                
                Spacer()
                
                // Biometric authentication option
                if !isSettingPasscode && KeychainManager.shared.isBiometricEnabled() && BiometricAuthManager.shared.canUseBiometrics() {
                    Button(action: authenticateWithBiometrics) {
                        HStack {
                            Image(systemName: BiometricAuthManager.shared.biometricType() == .faceID ? "faceid" : "touchid")
                                .font(.title2)
                            Text("Use \(BiometricAuthManager.shared.biometricType() == .faceID ? "Face ID" : "Touch ID")")
                        }
                        .foregroundColor(.blue)
                    }
                    .padding(.bottom, 30)
                }
            }
            .padding()
        }
        .onAppear {
            isPasscodeFocused = true
            
            // Auto-trigger biometric authentication if enabled
            if !isSettingPasscode && KeychainManager.shared.isBiometricEnabled() {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    authenticateWithBiometrics()
                }
            }
        }
    }
    
    private func handleSetPasscode() {
        guard passcode.count >= 4 else {
            showError(message: "Passcode must be at least 4 characters")
            return
        }
        
        guard passcode == confirmPasscode else {
            showError(message: "Passcodes don't match")
            return
        }
        
        do {
            try KeychainManager.shared.savePassword(passcode)
            onAuthenticated()
        } catch {
            showError(message: "Failed to save passcode")
        }
    }
    
    private func handleAuthentication() {
        do {
            let savedPasscode = try KeychainManager.shared.getPassword()
            if passcode == savedPasscode {
                KeychainManager.shared.clearLastBackgroundTime()
                onAuthenticated()
            } else {
                showError(message: "Incorrect passcode")
                passcode = ""
            }
        } catch {
            showError(message: "No passcode set")
        }
    }
    
    private func authenticateWithBiometrics() {
        BiometricAuthManager.shared.authenticateWithBiometrics(reason: "Unlock your vault") { success, error in
            if success {
                KeychainManager.shared.clearLastBackgroundTime()
                onAuthenticated()
            } else if let error = error {
                // User cancelled or biometric failed, show passcode field
                print("Biometric authentication failed: \(error.localizedDescription)")
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
} 