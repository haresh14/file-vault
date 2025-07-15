//
//  RecoverySetupView.swift
//  File Vault
//
//  Created on 15/07/25.
//

import SwiftUI

struct RecoverySetupView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedMethods: Set<RecoveryMethod> = []
    @State private var currentStep = 0
    @State private var isLoading = false
    
    // Security Questions
    @State private var selectedQuestions: [String] = ["", "", ""]
    @State private var questionAnswers: [String] = ["", "", ""]
    
    // Recovery Phrase
    @State private var generatedPhrase: [String] = []
    @State private var confirmationPhrase: [String] = Array(repeating: "", count: 12)
    @State private var showPhraseConfirmation = false
    
    // Master Key
    @State private var generatedMasterKey = ""
    @State private var masterKeyConfirmation = ""
    @State private var showMasterKeyConfirmation = false
    
    // Error handling
    @State private var showError = false
    @State private var errorMessage = ""
    
    let onRecoverySetup: () -> Void
    let onSkip: (() -> Void)?
    
    private let minimumRequiredMethods = 1
    
    init(onRecoverySetup: @escaping () -> Void, onSkip: (() -> Void)? = nil) {
        self.onRecoverySetup = onRecoverySetup
        self.onSkip = onSkip
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
                            setupSteps
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 100) // Space for bottom buttons
                }
                
                Spacer()
                
                // Bottom actions
                bottomSection
            }
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var headerSection: some View {
        VStack(spacing: 16) {
            Text("Account Recovery")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            
            Text(currentStep == 0 ? 
                "Set up recovery options to regain access if you forget your password" :
                "Configure your selected recovery methods")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding(.top, 20)
        .padding(.bottom, 24)
    }
    
    @ViewBuilder
    private var methodSelectionStep: some View {
        VStack(spacing: 20) {
            ForEach(RecoveryMethod.allCases, id: \.self) { method in
                RecoveryMethodCard(
                    method: method,
                    isSelected: selectedMethods.contains(method)
                ) {
                    toggleMethod(method)
                }
            }
            
            if !selectedMethods.isEmpty {
                VStack(spacing: 12) {
                    Text("💡 Tip")
                        .font(.headline)
                        .foregroundColor(.blue)
                    
                    Text("We recommend setting up at least 2 recovery methods for better security.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
    }
    
    @ViewBuilder
    private var setupSteps: some View {
        VStack(spacing: 32) {
            if selectedMethods.contains(.securityQuestions) {
                securityQuestionsSetup
            }
            
            if selectedMethods.contains(.recoveryPhrase) {
                recoveryPhraseSetup
            }
            
            if selectedMethods.contains(.masterKey) {
                masterKeySetup
            }
        }
    }
    
    @ViewBuilder
    private var securityQuestionsSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Security Questions")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("Choose 3 questions and provide answers. Make sure your answers are memorable!")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 8) {
                    Text("Question \(index + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Menu {
                        ForEach(RecoveryManager.predefinedQuestions, id: \.self) { question in
                            Button(question) {
                                selectedQuestions[index] = question
                            }
                        }
                    } label: {
                        HStack {
                            Text(selectedQuestions[index].isEmpty ? "Select a question..." : selectedQuestions[index])
                                .foregroundColor(selectedQuestions[index].isEmpty ? .secondary : .primary)
                            Spacer()
                            Image(systemName: "chevron.down")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                    }
                    
                    if !selectedQuestions[index].isEmpty {
                        TextField("Your answer", text: $questionAnswers[index])
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var recoveryPhraseSetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recovery Phrase")
                .font(.headline)
                .foregroundColor(.primary)
            
            if generatedPhrase.isEmpty {
                VStack(spacing: 12) {
                    Text("A recovery phrase is 12 random words that can restore your account.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Generate Recovery Phrase") {
                        generateRecoveryPhrase()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Text("⚠️ Write this down and store it safely!")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .fontWeight(.medium)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(0..<generatedPhrase.count, id: \.self) { index in
                            Text("\(index + 1). \(generatedPhrase[index])")
                                .font(.caption)
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(6)
                        }
                    }
                    
                    if !showPhraseConfirmation {
                        Button("I've written this down") {
                            showPhraseConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(spacing: 8) {
                            Text("Confirm your phrase by entering it below:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                                ForEach(0..<12, id: \.self) { index in
                                    TextField("\(index + 1)", text: $confirmationPhrase[index])
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    @ViewBuilder
    private var masterKeySetup: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Master Recovery Key")
                .font(.headline)
                .foregroundColor(.primary)
            
            if generatedMasterKey.isEmpty {
                VStack(spacing: 12) {
                    Text("A master key is a unique code that can restore your account as a last resort.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Generate Master Key") {
                        generateMasterKey()
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                VStack(spacing: 12) {
                    Text("⚠️ Store this key securely - it cannot be recovered!")
                        .font(.caption)
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    
                    Text(generatedMasterKey)
                        .font(.system(.title3, design: .monospaced))
                        .fontWeight(.medium)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                        .overlay(
                            Button("Copy") {
                                UIPasteboard.general.string = generatedMasterKey
                            }
                            .font(.caption)
                            .padding(4)
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(4)
                            .offset(x: 0, y: -20),
                            alignment: .topTrailing
                        )
                    
                    if !showMasterKeyConfirmation {
                        Button("I've saved this key") {
                            showMasterKeyConfirmation = true
                        }
                        .buttonStyle(.bordered)
                    } else {
                        VStack(spacing: 8) {
                            Text("Confirm by entering your master key:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            TextField("Enter master key", text: $masterKeyConfirmation)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .font(.system(.body, design: .monospaced))
                        }
                    }
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
            if currentStep == 0 {
                // Method selection buttons
                HStack(spacing: 16) {
                    if let onSkip = onSkip {
                        Button("Skip for Now") {
                            onSkip()
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Continue") {
                        currentStep = 1
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(selectedMethods.count < minimumRequiredMethods)
                }
            } else {
                // Setup completion buttons
                HStack(spacing: 16) {
                    Button("Back") {
                        currentStep = 0
                    }
                    .buttonStyle(.bordered)
                    
                    Spacer()
                    
                    Button(isLoading ? "Setting up..." : "Complete Setup") {
                        completeRecoverySetup()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isLoading || !canCompleteSetup)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 34)
        .background(Color(.systemBackground))
    }
    
    private var canCompleteSetup: Bool {
        var isValid = true
        
        if selectedMethods.contains(.securityQuestions) {
            isValid = isValid && selectedQuestions.allSatisfy { !$0.isEmpty } && questionAnswers.allSatisfy { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
        
        if selectedMethods.contains(.recoveryPhrase) {
            isValid = isValid && !generatedPhrase.isEmpty && (showPhraseConfirmation ? confirmationPhrase == generatedPhrase : false)
        }
        
        if selectedMethods.contains(.masterKey) {
            isValid = isValid && !generatedMasterKey.isEmpty && (showMasterKeyConfirmation ? masterKeyConfirmation.replacingOccurrences(of: "-", with: "") == generatedMasterKey.replacingOccurrences(of: "-", with: "") : false)
        }
        
        return isValid
    }
    
    // MARK: - Actions
    
    private func toggleMethod(_ method: RecoveryMethod) {
        if selectedMethods.contains(method) {
            selectedMethods.remove(method)
        } else {
            selectedMethods.insert(method)
        }
    }
    
    private func generateRecoveryPhrase() {
        generatedPhrase = RecoveryManager.shared.generateRecoveryPhrase()
    }
    
    private func generateMasterKey() {
        generatedMasterKey = RecoveryManager.shared.generateMasterRecoveryKey()
    }
    
    private func completeRecoverySetup() {
        isLoading = true
        
        do {
            // Setup security questions
            if selectedMethods.contains(.securityQuestions) {
                let questions = zip(selectedQuestions, questionAnswers).enumerated().map { index, pair in
                    SecurityQuestion(id: "q\(index)", question: pair.0, answer: pair.1)
                }
                try RecoveryManager.shared.setupSecurityQuestions(questions)
            }
            
            // Setup recovery phrase
            if selectedMethods.contains(.recoveryPhrase) {
                try RecoveryManager.shared.setupRecoveryPhrase(generatedPhrase)
            }
            
            // Setup master key
            if selectedMethods.contains(.masterKey) {
                try RecoveryManager.shared.setupMasterRecoveryKey(generatedMasterKey)
            }
            
            // Success
            onRecoverySetup()
            
        } catch {
            showError(message: "Failed to set up recovery methods: \(error.localizedDescription)")
        }
        
        isLoading = false
    }
    
    private func showError(message: String) {
        errorMessage = message
        showError = true
    }
}

struct RecoveryMethodCard: View {
    let method: RecoveryMethod
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
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

#Preview {
    RecoverySetupView(
        onRecoverySetup: { print("Recovery setup completed") },
        onSkip: { print("Recovery setup skipped") }
    )
} 