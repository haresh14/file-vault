//
//  PasswordSetupView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct PasswordSetupView: View {
    let onPasswordSet: () -> Void
    let onCancel: (() -> Void)?
    
    @State private var password: String = ""
    @State private var confirmPassword: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var showPassword: Bool = false
    @State private var showConfirmPassword: Bool = false
    @FocusState private var isPasswordFocused: Bool
    @FocusState private var isConfirmPasswordFocused: Bool
    
    private var isPasswordValid: Bool {
        password.count >= 6
    }
    
    private var passwordStrength: PasswordStrength {
        getPasswordStrength(password)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                headerSection
                passwordInputSection
                
                Spacer()
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if let onCancel = onCancel {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Create a strong password to protect your vault")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var passwordInputSection: some View {
        VStack(spacing: 20) {
            passwordField
            confirmPasswordField
            passwordStrengthIndicator
            errorView
            setPasswordButton
        }
    }
    
    private var passwordField: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Group {
                    if showPassword {
                        TextField("Password", text: $password)
                    } else {
                        SecureField("Password", text: $password)
                    }
                }
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .focused($isPasswordFocused)
                .onSubmit {
                    isConfirmPasswordFocused = true
                }
                
                Button(action: { showPassword.toggle() }) {
                    Image(systemName: showPassword ? "eye.slash" : "eye")
                        .foregroundColor(.secondary)
                }
            }
            
            Text("Minimum 6 characters")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    private var confirmPasswordField: some View {
        HStack {
            Group {
                if showConfirmPassword {
                    TextField("Confirm Password", text: $confirmPassword)
                } else {
                    SecureField("Confirm Password", text: $confirmPassword)
                }
            }
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .focused($isConfirmPasswordFocused)
            .onSubmit {
                handlePasswordSetup()
            }
            
            Button(action: { showConfirmPassword.toggle() }) {
                Image(systemName: showConfirmPassword ? "eye.slash" : "eye")
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var passwordStrengthIndicator: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !password.isEmpty {
                HStack {
                    Text("Password Strength:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(passwordStrength.description)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(passwordStrength.color)
                }
                
                ProgressView(value: passwordStrength.value, total: 1.0)
                    .tint(passwordStrength.color)
                    .scaleEffect(y: 0.5)
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
    
    private var setPasswordButton: some View {
        Button(action: handlePasswordSetup) {
            HStack(spacing: 8) {
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .semibold))
                Text("Set Password")
                    .font(.system(size: 17, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isButtonEnabled ? Color.blue : Color.gray)
            )
        }
        .disabled(!isButtonEnabled)
        .buttonStyle(PlainButtonStyle())
    }
    
    private var isButtonEnabled: Bool {
        isPasswordValid && !confirmPassword.isEmpty
    }
    
    // MARK: - Actions
    
    private func handlePasswordSetup() {
        // Trim whitespace and ensure clean strings
        let cleanPassword = password.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanConfirmPassword = confirmPassword.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard cleanPassword.count >= 6 else {
            showError(message: "Password must be at least 6 characters")
            return
        }
        
        guard cleanPassword == cleanConfirmPassword else {
            showError(message: "Passwords don't match")
            confirmPassword = ""
            return
        }
        
        // Additional validation: ensure password is not all the same character
        let uniqueCharacters = Set(cleanPassword)
        guard uniqueCharacters.count > 1 else {
            showError(message: "Password cannot be all the same character")
            password = ""
            confirmPassword = ""
            return
        }
        
        // Save password and auth type
        do {
            try KeychainManager.shared.savePassword(cleanPassword)
            KeychainManager.shared.setAuthenticationType(.password)
            onPasswordSet()
        } catch {
            print("ERROR: Failed to save password: \(error)")
            showError(message: "Failed to save password")
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            showError = false
        }
    }
    
    // MARK: - Password Strength
    
    private func getPasswordStrength(_ password: String) -> PasswordStrength {
        let length = password.count
        let hasUppercase = password.rangeOfCharacter(from: .uppercaseLetters) != nil
        let hasLowercase = password.rangeOfCharacter(from: .lowercaseLetters) != nil
        let hasNumbers = password.rangeOfCharacter(from: .decimalDigits) != nil
        let hasSpecialChars = password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil
        
        var score = 0
        
        if length >= 6 { score += 1 }
        if length >= 10 { score += 1 }
        if hasUppercase { score += 1 }
        if hasLowercase { score += 1 }
        if hasNumbers { score += 1 }
        if hasSpecialChars { score += 1 }
        
        switch score {
        case 0...2: return .weak
        case 3...4: return .medium
        case 5...6: return .strong
        default: return .weak
        }
    }
}

enum PasswordStrength {
    case weak
    case medium
    case strong
    
    var description: String {
        switch self {
        case .weak: return "Weak"
        case .medium: return "Medium"
        case .strong: return "Strong"
        }
    }
    
    var color: Color {
        switch self {
        case .weak: return .red
        case .medium: return .orange
        case .strong: return .green
        }
    }
    
    var value: Double {
        switch self {
        case .weak: return 0.33
        case .medium: return 0.66
        case .strong: return 1.0
        }
    }
}

#Preview {
    PasswordSetupView(
        onPasswordSet: { print("Password set") },
        onCancel: { print("Cancelled") }
    )
} 