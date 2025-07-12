//
//  ChangeAuthenticationView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct ChangeAuthenticationView: View {
    let currentAuthType: AuthenticationType
    let onAuthChanged: () -> Void
    
    @Environment(\.dismiss) var dismiss
    @State private var currentPassword: String = ""
    @State private var newAuthType: AuthenticationType = .passcode4
    @State private var showCurrentPassword: Bool = false
    @State private var isCurrentPasswordVerified: Bool = false
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var navigationPath = NavigationPath()
    @FocusState private var isCurrentPasswordFocused: Bool
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 30) {
                if !isCurrentPasswordVerified {
                    currentPasswordSection
                } else {
                    newAuthSelectionSection
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Change Authentication")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { dismiss() }) {
                        Text("Cancel")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .navigationDestination(for: AuthenticationType.self) { authType in
                if authType.isPasscode {
                    PasscodeSetupView(authType: authType, onPasscodeSet: {
                        onAuthChanged()
                        dismiss()
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                } else {
                    PasswordSetupView(onPasswordSet: {
                        onAuthChanged()
                        dismiss()
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var currentPasswordSection: some View {
        VStack(spacing: 20) {
            headerSection
            currentPasswordInput
            errorView
            verifyButton
        }
    }
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.blue)
            
            Text("Verify Current Authentication")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Enter your current \(currentAuthType.isPasscode ? "passcode" : "password") to continue")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var currentPasswordInput: some View {
        VStack(spacing: 12) {
            if currentAuthType.isPasscode, let digitCount = currentAuthType.digitCount {
                // OTP-style input for passcodes
                Text("Enter your \(digitCount)-digit passcode")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                OTPStylePasscodeView(digitCount: digitCount, passcode: $currentPassword)
            } else {
                // Password input
                HStack {
                    Group {
                        if showCurrentPassword {
                            TextField("Current Password", text: $currentPassword)
                        } else {
                            SecureField("Current Password", text: $currentPassword)
                        }
                    }
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .focused($isCurrentPasswordFocused)
                    .onSubmit {
                        verifyCurrentPassword()
                    }
                    
                    Button(action: { showCurrentPassword.toggle() }) {
                        Image(systemName: showCurrentPassword ? "eye.slash" : "eye")
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            if !currentAuthType.isPasscode {
                isCurrentPasswordFocused = true
            }
        }
        .onChange(of: currentPassword) { _, newValue in
            // Auto-verify for passcodes when complete
            if currentAuthType.isPasscode, let digitCount = currentAuthType.digitCount {
                if newValue.count == digitCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        verifyCurrentPassword()
                    }
                }
            }
        }
    }
    
    private var verifyButton: some View {
        Button(action: verifyCurrentPassword) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.shield")
                    .font(.system(size: 16, weight: .semibold))
                Text("Verify")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isVerifyButtonEnabled ? Color.blue : Color.gray)
            )
        }
        .disabled(!isVerifyButtonEnabled)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isVerifyButtonEnabled: Bool {
        if currentAuthType.isPasscode, let digitCount = currentAuthType.digitCount {
            return currentPassword.count == digitCount
        } else {
            return !currentPassword.isEmpty
        }
    }
    
    private var newAuthSelectionSection: some View {
        VStack(spacing: 20) {
            newAuthHeaderSection
            authTypeSelection
            proceedButton
        }
    }
    
    private var newAuthHeaderSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.shield.fill")
                .font(.system(size: 50))
                .foregroundColor(.green)
            
            Text("Choose New Authentication")
                .font(.title2)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)
            
            Text("Select your new authentication method")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var authTypeSelection: some View {
        VStack(spacing: 16) {
            ForEach(AuthenticationType.allCases, id: \.self) { type in
                AuthTypeCard(
                    type: type,
                    isSelected: newAuthType == type,
                    onTap: { newAuthType = type }
                )
                .disabled(type == currentAuthType)
                .opacity(type == currentAuthType ? 0.5 : 1.0)
            }
            
            if newAuthType == currentAuthType {
                Text("This is your current authentication method")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var proceedButton: some View {
        Button(action: proceedToNewAuth) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill")
                    .font(.system(size: 16, weight: .semibold))
                Text("Set New Authentication")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(newAuthType != currentAuthType ? Color.blue : Color.gray)
            )
        }
        .disabled(newAuthType == currentAuthType)
        .buttonStyle(PlainButtonStyle())
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
    
    // MARK: - Actions
    
    private func verifyCurrentPassword() {
        do {
            let savedPassword = try KeychainManager.shared.getPassword()
            let cleanCurrentPassword = currentPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanSavedPassword = savedPassword.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if cleanCurrentPassword == cleanSavedPassword {
                withAnimation(.easeInOut(duration: 0.3)) {
                    isCurrentPasswordVerified = true
                }
            } else {
                let type = currentAuthType.isPasscode ? "passcode" : "password"
                showError(message: "Incorrect \(type)")
                currentPassword = ""
            }
        } catch {
            let type = currentAuthType.isPasscode ? "passcode" : "password"
            showError(message: "Failed to verify \(type)")
        }
    }
    
    private func proceedToNewAuth() {
        // Navigate to setup view using native navigation
        navigationPath.append(newAuthType)
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
}

#Preview {
    ChangeAuthenticationView(
        currentAuthType: .passcode4,
        onAuthChanged: { print("Auth changed") }
    )
} 