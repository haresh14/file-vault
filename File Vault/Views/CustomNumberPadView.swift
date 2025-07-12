//
//  CustomNumberPadView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct CustomNumberPadView: View {
    let onNumberTapped: (String) -> Void
    let onBackspaceTapped: () -> Void
    let onHelpTapped: (() -> Void)?
    
    init(onNumberTapped: @escaping (String) -> Void, onBackspaceTapped: @escaping () -> Void, onHelpTapped: (() -> Void)? = nil) {
        self.onNumberTapped = onNumberTapped
        self.onBackspaceTapped = onBackspaceTapped
        self.onHelpTapped = onHelpTapped
    }
    
    private let numbers = [
        ["1", "2", "3"],
        ["4", "5", "6"],
        ["7", "8", "9"],
        ["?", "0", "⌫"]
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            ForEach(numbers, id: \.self) { row in
                HStack(spacing: 16) {
                    ForEach(row, id: \.self) { item in
                        NumberPadButton(
                            text: item,
                            action: {
                                if item == "⌫" {
                                    onBackspaceTapped()
                                } else if item == "?" {
                                    onHelpTapped?()
                                } else if !item.isEmpty {
                                    onNumberTapped(item)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding()
    }
}

struct NumberPadButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 80, height: 80)
                
                if text == "⌫" {
                    Image(systemName: "delete.left")
                        .font(.title3)
                        .foregroundColor(.primary)
                } else if text == "?" {
                    Image(systemName: "questionmark")
                        .font(.title2)
                        .foregroundColor(.primary)
                } else {
                    Text(text)
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .buttonStyle(NumberPadButtonStyle())
    }
}

struct NumberPadButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.7 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

#Preview {
    CustomNumberPadView(
        onNumberTapped: { number in
            print("Number tapped: \(number)")
        },
        onBackspaceTapped: {
            print("Backspace tapped")
        },
        onHelpTapped: {
            print("Help tapped")
        }
    )
} 