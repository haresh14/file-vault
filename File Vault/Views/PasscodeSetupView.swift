//
//  PasscodeSetupView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct PasscodeSetupView: View {
    let authType: AuthenticationType
    let onPasscodeSet: () -> Void
    let onCancel: (() -> Void)?
    
    @State private var passcode: String = ""
    @State private var confirmPasscode: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isConfirming: Bool = false
    
    private var digitCount: Int {
        authType.digitCount ?? 4
    }
    
    private var isPasscodeValid: Bool {
        passcode.count == digitCount && passcode.allSatisfy { $0.isNumber }
    }
    
    private var isConfirmPasscodeValid: Bool {
        confirmPasscode.count == digitCount && confirmPasscode.allSatisfy { $0.isNumber }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 40) {
                headerSection
                passcodeInputSection
                
                Spacer()
                
                bottomSection
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isConfirming {
                        Button("Back") {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                isConfirming = false
                                confirmPasscode = ""
                                showError = false
                            }
                        }
                    } else if let onCancel = onCancel {
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
            Image(systemName: "lock.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text(isConfirming ? "Re-enter your \(digitCount)-digit passcode" : "Create a \(digitCount)-digit passcode to protect your vault")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var passcodeInputSection: some View {
        VStack(spacing: 20) {
            if isConfirming {
                OTPStylePasscodeView(digitCount: digitCount, passcode: $confirmPasscode)
            } else {
                OTPStylePasscodeView(digitCount: digitCount, passcode: $passcode)
            }
            
            errorView
        }
        .onChange(of: passcode) { _, newValue in
            if newValue.count == digitCount && !isConfirming {
                // Auto-advance to confirmation
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        isConfirming = true
                    }
                }
            }
        }
        .onChange(of: confirmPasscode) { _, newValue in
            if newValue.count == digitCount && isConfirming {
                // Auto-validate when complete
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    handlePasscodeConfirmation()
                }
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
    
    private var bottomSection: some View {
        VStack(spacing: 16) {
            // Empty for now since navigation is handled by toolbar
        }
    }
    
    // MARK: - Actions
    
    private func handlePasscodeConfirmation() {
        guard passcode == confirmPasscode else {
            showError(message: "Passcodes don't match")
            confirmPasscode = ""
            return
        }
        
        guard isPasscodeValid else {
            showError(message: "Invalid passcode")
            return
        }
        
        // Save passcode and auth type
        do {
            try KeychainManager.shared.savePassword(passcode)
            KeychainManager.shared.setAuthenticationType(authType)
            onPasscodeSet()
        } catch {
            print("ERROR: Failed to save passcode: \(error)")
            showError(message: "Failed to save passcode")
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

#Preview {
    PasscodeSetupView(
        authType: .passcode4,
        onPasscodeSet: { print("Passcode set") },
        onCancel: { print("Cancelled") }
    )
} 