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
            backgroundGradient
            
            VStack(spacing: 30) {
                Spacer()
                
                lockIcon
                titleText
                subtitleText
                
                VStack(spacing: 20) {
                    passcodeFields
                    errorView
                    actionButton
                    cancelButton
                }
                
                Spacer()
                
                biometricButton
            }
            .padding()
        }
        .onAppear(perform: handleOnAppear)
    }
    
    // MARK: - View Components
    
    private var backgroundGradient: some View {
        LinearGradient(
            colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
    
    private var lockIcon: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 60))
            .foregroundColor(.blue)
            .padding(.bottom, 20)
            #if DEBUG
            .onLongPressGesture(minimumDuration: 3.0, perform: performDebugReset)
            #endif
    }
    
    private var titleText: some View {
        Text(isSettingPasscode ? "Set Your Passcode" : "Enter Passcode")
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    private var subtitleText: some View {
        Text(isSettingPasscode ? "Create a secure passcode to protect your vault" : "Access your secure vault")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var passcodeFields: some View {
        SecureField("Passcode", text: $passcode)
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .frame(maxWidth: 300)
            .focused($isPasscodeFocused)
            .onSubmit(handlePasscodeSubmit)
        
        if isSettingPasscode {
            SecureField("Confirm Passcode", text: $confirmPasscode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: 300)
                .onSubmit(handleSetPasscode)
        }
    }
    
    @ViewBuilder
    private var errorView: some View {
        if showError {
            Text(errorMessage)
                .foregroundColor(.red)
                .font(.caption)
                .transition(.opacity)
        }
    }
    
    private var actionButton: some View {
        Button(action: handleButtonAction) {
            Text(isSettingPasscode ? "Set Passcode" : "Unlock")
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: 300)
                .padding()
                .background(buttonBackgroundColor)
                .cornerRadius(10)
        }
        .disabled(isButtonDisabled)
    }
    
    @ViewBuilder
    private var cancelButton: some View {
        if let onCancel = onCancel {
            Button("Cancel", action: onCancel)
                .foregroundColor(.blue)
        }
    }
    
    @ViewBuilder
    private var biometricButton: some View {
        if shouldShowBiometric {
            Button(action: authenticateWithBiometrics) {
                HStack {
                    Image(systemName: biometricIconName)
                        .font(.title2)
                    Text("Use \(biometricDisplayName)")
                }
                .foregroundColor(.blue)
            }
            .padding(.bottom, 30)
        }
    }
    
    // MARK: - Computed Properties
    
    private var buttonBackgroundColor: Color {
        isButtonDisabled ? Color.gray : Color.blue
    }
    
    private var isButtonDisabled: Bool {
        passcode.isEmpty || (isSettingPasscode && confirmPasscode.isEmpty)
    }
    
    private var shouldShowBiometric: Bool {
        !isSettingPasscode && 
        KeychainManager.shared.isBiometricEnabled() && 
        BiometricAuthManager.shared.canUseBiometrics()
    }
    
    private var biometricIconName: String {
        BiometricAuthManager.shared.biometricType() == .faceID ? "faceid" : "touchid"
    }
    
    private var biometricDisplayName: String {
        BiometricAuthManager.shared.biometricType() == .faceID ? "Face ID" : "Touch ID"
    }
    
    // MARK: - Actions
    
    private func handleOnAppear() {
        isPasscodeFocused = true
        
        // Removed automatic biometric trigger - now handled by ContentView
        // to prevent UI jerking and duplicate prompts
    }
    
    private func handlePasscodeSubmit() {
        if isSettingPasscode && !confirmPasscode.isEmpty {
            handleSetPasscode()
        } else if !isSettingPasscode {
            handleAuthentication()
        }
    }
    
    private func handleButtonAction() {
        if isSettingPasscode {
            handleSetPasscode()
        } else {
            handleAuthentication()
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
            print("DEBUG: Passcode saved successfully")
            onAuthenticated()
        } catch {
            print("ERROR: Failed to save passcode: \(error)")
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
    
    #if DEBUG
    private func performDebugReset() {
        print("DEBUG: Resetting app via long press")
        try? KeychainManager.shared.deletePassword()
        KeychainManager.shared.setBiometricEnabled(false)
        KeychainManager.shared.clearLastBackgroundTime()
        exit(0)
    }
    #endif
} 