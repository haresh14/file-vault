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
    @State private var showPassword: Bool = false
    @FocusState private var isPasscodeFocused: Bool
    
    let isSettingPasscode: Bool
    let onAuthenticated: () -> Void
    let onCancel: (() -> Void)?
    
    private var authType: AuthenticationType {
        KeychainManager.shared.getAuthenticationType()
    }
    
    private var isPasswordType: Bool {
        authType == .password
    }
    
    private var digitCount: Int? {
        authType.digitCount
    }
    
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
                if isSettingPasscode {
                    titleText
                }
                subtitleText
                
                VStack(spacing: 20) {
                    passcodeFields
                    if !isSettingPasscode {
                        errorView
                    }
                    if isSettingPasscode {
                        errorView
                        actionButton
                    }
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
        Text(isSettingPasscode ? 
             (isPasswordType ? "Set Your Password" : "Set Your Passcode") : 
             (isPasswordType ? "Enter Password" : "Enter Passcode"))
            .font(.largeTitle)
            .fontWeight(.bold)
    }
    
    private var subtitleText: some View {
        Text(isSettingPasscode ? 
             (isPasswordType ? "Create a secure password to protect your vault" : "Create a secure passcode to protect your vault") :
             "Access your secure vault")
            .font(.subheadline)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
    }
    
    @ViewBuilder
    private var passcodeFields: some View {
        if isPasswordType {
            // Password input fields
            HStack {
                Group {
                    if showPassword {
                        TextField(isSettingPasscode ? "Password" : "Enter Password", text: $passcode)
                    } else {
                        SecureField(isSettingPasscode ? "Password" : "Enter Password", text: $passcode)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isPasscodeFocused)
                .onSubmit(handlePasscodeSubmit)
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: 300)
            
            if isSettingPasscode {
                HStack {
                    Group {
                        if showPassword {
                            TextField("Confirm Password", text: $confirmPasscode)
                        } else {
                            SecureField("Confirm Password", text: $confirmPasscode)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .onSubmit(handleSetPasscode)
                    
                    Button(action: { showPassword.toggle() }) {
                        Image(systemName: showPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: 300)
            }
        } else if let digitCount = digitCount {
            // OTP-style passcode input
            if isSettingPasscode {
                VStack(spacing: 20) {
                    OTPStylePasscodeView(digitCount: digitCount, passcode: $passcode)
                    
                    if !passcode.isEmpty && passcode.count == digitCount {
                        VStack(spacing: 16) {
                            OTPStylePasscodeView(digitCount: digitCount, passcode: $confirmPasscode)
                        }
                    }
                }
            } else {
                VStack(spacing: 16) {
                    OTPStylePasscodeView(digitCount: digitCount, passcode: $passcode)
                        .onChange(of: passcode) { _, newValue in
                            // Auto-login when passcode is complete
                            if newValue.count == digitCount {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    handleAuthentication()
                                }
                            }
                        }
                }
            }
        } else {
            // Fallback to traditional input
            SecureField(isPasswordType ? "Password" : "Passcode", text: $passcode)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(maxWidth: 300)
                .focused($isPasscodeFocused)
                .onSubmit(handlePasscodeSubmit)
            
            if isSettingPasscode {
                SecureField(isPasswordType ? "Confirm Password" : "Confirm Passcode", text: $confirmPasscode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(maxWidth: 300)
                    .onSubmit(handleSetPasscode)
            }
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
    
    @ViewBuilder
    private var actionButton: some View {
        if isSettingPasscode {
            Button(action: handleButtonAction) {
                Text(isPasswordType ? "Set Password" : "Set Passcode")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: 300)
                    .padding()
                    .background(buttonBackgroundColor)
                    .cornerRadius(10)
            }
            .disabled(isButtonDisabled)
        }
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
        let minLength = isPasswordType ? 6 : (digitCount ?? 4)
        
        guard passcode.count >= minLength else {
            let type = isPasswordType ? "Password" : "Passcode"
            showError(message: "\(type) must be at least \(minLength) characters")
            return
        }
        
        // For passcodes, validate digit count exactly
        if let digitCount = digitCount {
            guard passcode.count == digitCount && passcode.allSatisfy({ $0.isNumber }) else {
                showError(message: "Passcode must be exactly \(digitCount) digits")
                return
            }
        }
        
        guard passcode == confirmPasscode else {
            let type = isPasswordType ? "Passwords" : "Passcodes"
            showError(message: "\(type) don't match")
            return
        }
        
        do {
            try KeychainManager.shared.savePassword(passcode)
            // Password/Passcode saved successfully
            onAuthenticated()
        } catch {
            print("ERROR: Failed to save password/passcode: \(error)")
            let type = isPasswordType ? "password" : "passcode"
            showError(message: "Failed to save \(type)")
        }
    }
    
    private func handleAuthentication() {
        do {
            let savedPasscode = try KeychainManager.shared.getPassword()
            if passcode == savedPasscode {
                KeychainManager.shared.clearLastBackgroundTime()
                onAuthenticated()
            } else {
                let type = isPasswordType ? "password" : "passcode"
                showError(message: "Incorrect \(type)")
                passcode = ""
            }
        } catch {
            let type = isPasswordType ? "password" : "passcode"
            showError(message: "No \(type) set")
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
        // Resetting app via long press
        try? KeychainManager.shared.deletePassword()
        KeychainManager.shared.setBiometricEnabled(false)
        KeychainManager.shared.clearLastBackgroundTime()
        exit(0)
    }
    #endif
} 