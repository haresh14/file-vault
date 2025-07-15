//
//  AccountRecoveryView.swift
//  File Vault
//
//  Created on 15/07/25.
//

import SwiftUI

struct AccountRecoveryView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethod: RecoveryMethod?
    @State private var currentStep = 0
    @State private var isLoading = false
    
    // Security Questions
    @State private var securityQuestions: [SecurityQuestion] = []
    @State private var questionAnswers: [String: String] = [:]
    
    // Recovery Phrase
    @State private var recoveryPhraseInput: [String] = Array(repeating: "", count: 12)
    
    // Master Key
    @State private var masterKeyInput = ""
    
    // New Password Setup
    @State private var newPassword = ""
    @State private var confirmNewPassword = ""
    
    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    
    let onRecoveryComplete: () -> Void
    
    private var availableMethods: Set<RecoveryMethod> {
        RecoveryManager.shared.getEnabledRecoveryMethods()
    }
    
    init(onRecoveryComplete: @escaping () -> Void) {
        self.onRecoveryComplete = onRecoveryComplete
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        if currentStep == 0 {
                            methodSelectionStep
                        } else if currentStep == 1 {
                            recoveryMethodStep
                        } else if currentStep == 2 {
                            newPasswordStep
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100)
                }
                
                Spacer()
                
                // Bottom actions
                bottomSection
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
            .alert("Recovery Successful", isPresented: $showSuccess) {
                Button("Continue") {
                    onRecoveryComplete()
                    dismiss()
                }
            } message: {
                Text("Your password has been reset successfully. You can now log in with your new password.")
            }
        }
        .onAppear {
            loadSecurityQuestions()
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "key.fill")
                .font(.system(size: 40))
                .foregroundColor(.blue)
            
            Text("Account Recovery")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(stepDescription)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    private var stepDescription: String {
        switch currentStep {
        case 0: return "Choose a recovery method to regain access to your account"
        case 1: return "Verify your identity using the selected recovery method"
        case 2: return "Set a new password for your account"
        default: return ""
        }
    }
    
    @ViewBuilder
    private var methodSelectionStep: some View {
        VStack(spacing: 20) {
            if availableMethods.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("No Recovery Methods Available")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("You haven't set up any recovery methods for your account. Please contact support if you need assistance.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
            } else {
                ForEach(Array(availableMethods), id: \.self) { method in
                    RecoveryMethodSelectionCard(
                        method: method,
                        isSelected: selectedMethod == method
                    ) {
                        selectedMethod = method
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private var recoveryMethodStep: some View {
        if let method = selectedMethod {
            switch method {
            case .securityQuestions:
                securityQuestionsRecovery
            case .recoveryPhrase:
                recoveryPhraseRecovery
            case .masterKey:
                masterKeyRecovery
            }
        }
    }
    
    @ViewBuilder
    private var securityQuestionsRecovery: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Security Questions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Answer the security questions you set up during account creation.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(securityQuestions, id: \.id) { question in
                VStack(alignment: .leading, spacing: 8) {
                    Text(question.question)
                        .font(.subheadline)
                        .foregroundColor(.primary)
                    
                    TextField("Your answer", text: Binding(
                        get: { questionAnswers[question.id] ?? "" },
                        set: { questionAnswers[question.id] = $0 }
                    ))
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var recoveryPhraseRecovery: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Recovery Phrase")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Enter your 12-word recovery phrase in the correct order.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                ForEach(0..<12, id: \.self) { index in
                    TextField("\(index + 1)", text: $recoveryPhraseInput[index])
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .font(.caption)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var masterKeyRecovery: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Master Recovery Key")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Enter your master recovery key. You can include or exclude the dashes.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            TextField("XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX-XXXX", text: $masterKeyInput)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .font(.system(.body, design: .monospaced))
                .autocapitalization(.allCharacters)
                .autocorrectionDisabled()
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var newPasswordStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Set New Password")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Choose a strong password for your account. This will replace your previous password.")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                SecureField("New Password", text: $newPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                SecureField("Confirm New Password", text: $confirmNewPassword)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                // Password strength indicator
                if !newPassword.isEmpty {
                    PasswordStrengthIndicator(password: newPassword)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var bottomSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
                
                Button(buttonTitle) {
                    handleNextStep()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canProceed || isLoading)
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(Color(.systemBackground))
    }
    
    private var buttonTitle: String {
        if isLoading { return "Processing..." }
        switch currentStep {
        case 0: return "Continue"
        case 1: return "Verify"
        case 2: return "Reset Password"
        default: return "Next"
        }
    }
    
    private var canProceed: Bool {
        switch currentStep {
        case 0: return selectedMethod != nil
        case 1: return canVerifyRecovery
        case 2: return isNewPasswordValid
        default: return false
        }
    }
    
    private var canVerifyRecovery: Bool {
        guard let method = selectedMethod else { return false }
        
        switch method {
        case .securityQuestions:
            return questionAnswers.count == securityQuestions.count && 
                   questionAnswers.values.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .recoveryPhrase:
            return recoveryPhraseInput.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        case .masterKey:
            return !masterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
    
    private var isNewPasswordValid: Bool {
        return newPassword.count >= 6 && 
               newPassword == confirmNewPassword &&
               !newPassword.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    // MARK: - Actions
    
    private func loadSecurityQuestions() {
        if let config = RecoveryManager.shared.getRecoveryConfiguration(),
           let questions = config.securityQuestions {
            securityQuestions = questions
        }
    }
    
    private func handleNextStep() {
        switch currentStep {
        case 0:
            currentStep = 1
        case 1:
            verifyRecoveryMethod()
        case 2:
            resetPassword()
        default:
            break
        }
    }
    
    private func verifyRecoveryMethod() {
        guard let method = selectedMethod else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let recoveryData: Any
            
            switch method {
            case .securityQuestions:
                recoveryData = questionAnswers
            case .recoveryPhrase:
                recoveryData = recoveryPhraseInput.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            case .masterKey:
                recoveryData = masterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            
            let isValid = RecoveryManager.shared.attemptRecovery(method: method, data: recoveryData)
            
            DispatchQueue.main.async {
                isLoading = false
                
                if isValid {
                    currentStep = 2
                } else {
                    showError(message: "Recovery verification failed. Please check your information and try again.")
                }
            }
        }
    }
    
    private func resetPassword() {
        guard let method = selectedMethod else { return }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                let recoveryData: Any
                
                switch method {
                case .securityQuestions:
                    recoveryData = questionAnswers
                case .recoveryPhrase:
                    recoveryData = recoveryPhraseInput.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                case .masterKey:
                    recoveryData = masterKeyInput.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                
                try RecoveryManager.shared.resetPassword(
                    to: newPassword,
                    using: method,
                    with: recoveryData
                )
                
                DispatchQueue.main.async {
                    isLoading = false
                    showSuccess = true
                }
            } catch {
                DispatchQueue.main.async {
                    isLoading = false
                    showError(message: "Failed to reset password: \(error.localizedDescription)")
                }
            }
        }
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

struct RecoveryMethodSelectionCard: View {
    let method: RecoveryMethod
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title2)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: methodIcon(for: method))
                    .foregroundColor(.secondary)
                    .font(.title2)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color(.systemGray4), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func methodIcon(for method: RecoveryMethod) -> String {
        switch method {
        case .securityQuestions: return "questionmark.circle"
        case .recoveryPhrase: return "text.word.spacing"
        case .masterKey: return "key"
        }
    }
}

struct PasswordStrengthIndicator: View {
    let password: String
    
    private var strength: RecoveryPasswordStrength {
        evaluatePasswordStrength(password)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Password Strength:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(strength.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(strength.color)
            }
            
            ProgressView(value: strength.value, total: 1.0)
                .progressViewStyle(LinearProgressViewStyle(tint: strength.color))
                .frame(height: 4)
        }
    }
    
    private func evaluatePasswordStrength(_ password: String) -> RecoveryPasswordStrength {
        var score = 0
        
        if password.count >= 8 { score += 1 }
        if password.count >= 12 { score += 1 }
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil { score += 1 }
        if password.rangeOfCharacter(from: .decimalDigits) != nil { score += 1 }
        if password.rangeOfCharacter(from: CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")) != nil { score += 1 }
        
        switch score {
        case 0...2: return RecoveryPasswordStrength(title: "Weak", color: .red, value: 0.33)
        case 3...4: return RecoveryPasswordStrength(title: "Medium", color: .orange, value: 0.66)
        case 5...6: return RecoveryPasswordStrength(title: "Strong", color: .green, value: 1.0)
        default: return RecoveryPasswordStrength(title: "Weak", color: .red, value: 0.33)
        }
    }
}

struct RecoveryPasswordStrength {
    let title: String
    let color: Color
    let value: Double
}

#Preview {
    AccountRecoveryView(
        onRecoveryComplete: { print("Recovery completed") }
    )
} 