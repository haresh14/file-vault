//
//  OTPStylePasscodeView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct OTPStylePasscodeView: View {
    let digitCount: Int
    @Binding var passcode: String
    @State private var digits: [String]
    @State private var currentIndex: Int = 0
    let onHelpTapped: (() -> Void)?
    
    init(digitCount: Int, passcode: Binding<String>, onHelpTapped: (() -> Void)? = nil) {
        self.digitCount = digitCount
        self._passcode = passcode
        self._digits = State(initialValue: Array(repeating: "", count: digitCount))
        self.onHelpTapped = onHelpTapped
    }
    
    var body: some View {
        VStack(spacing: 30) {
            // Digit display
            HStack(spacing: 12) {
                ForEach(0..<digitCount, id: \.self) { index in
                    DigitDisplay(
                        digit: digits[index],
                        isActive: index == currentIndex,
                        onTap: {
                            currentIndex = index
                        }
                    )
                }
            }
            
            // Custom number pad
            CustomNumberPadView(
                onNumberTapped: { number in
                    handleNumberInput(number)
                },
                onBackspaceTapped: {
                    handleBackspace()
                },
                onHelpTapped: onHelpTapped
            )
        }
        .onAppear {
            currentIndex = 0
        }
        .onChange(of: passcode) { _, newValue in
            // Update digits when passcode changes externally
            if newValue.isEmpty {
                digits = Array(repeating: "", count: digitCount)
                currentIndex = 0
            }
        }
    }
    
    private func handleNumberInput(_ number: String) {
        guard currentIndex < digitCount else { return }
        
        // Set the digit at current position
        digits[currentIndex] = number
        
        // Update the bound passcode
        passcode = digits.joined()
        
        // Move to next position if not at the end
        if currentIndex < digitCount - 1 {
            currentIndex += 1
        }
    }
    
    private func handleBackspace() {
        // If current position has a digit, clear it
        if currentIndex < digitCount && !digits[currentIndex].isEmpty {
            digits[currentIndex] = ""
        } else if currentIndex > 0 {
            // Move back and clear the previous digit
            currentIndex -= 1
            digits[currentIndex] = ""
        }
        
        // Update the bound passcode
        passcode = digits.joined()
    }
}

struct DigitDisplay: View {
    let digit: String
    let isActive: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isActive ? Color.blue : Color.clear, lineWidth: 2)
                    )
                    .frame(width: 50, height: 60)
                
                // Visual indicator - smaller dots
                Text(digit.isEmpty ? "" : "●")
                    .font(.body)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    VStack(spacing: 30) {
        Text("4-Digit Passcode")
            .font(.title2)
        
        OTPStylePasscodeView(digitCount: 4, passcode: .constant(""))
        
        Text("6-Digit Passcode")
            .font(.title2)
        
        OTPStylePasscodeView(digitCount: 6, passcode: .constant(""))
    }
    .padding()
} 