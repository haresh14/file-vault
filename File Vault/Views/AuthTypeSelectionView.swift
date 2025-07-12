//
//  AuthTypeSelectionView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

struct AuthTypeSelectionView: View {
    let onAuthTypeSelected: (AuthenticationType) -> Void
    @State private var selectedType: AuthenticationType = .passcode4
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 30) {
                headerSection
                
                VStack(spacing: 20) {
                    selectionCards
                    continueButton
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Security Setup")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: AuthenticationType.self) { authType in
                if authType.isPasscode {
                    PasscodeSetupView(authType: authType, onPasscodeSet: {
                        onAuthTypeSelected(authType)
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                } else {
                    PasswordSetupView(onPasswordSet: {
                        onAuthTypeSelected(authType)
                    }, onCancel: {
                        navigationPath.removeLast()
                    })
                }
            }
        }
    }
    
    // MARK: - View Components
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.blue)
            
            Text("Select how you'd like to secure your vault")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    private var selectionCards: some View {
        VStack(spacing: 16) {
            ForEach(AuthenticationType.allCases, id: \.self) { type in
                AuthTypeCard(
                    type: type,
                    isSelected: selectedType == type,
                    onTap: { selectedType = type }
                )
            }
        }
    }
    
    private var continueButton: some View {
        Button(action: { 
            navigationPath.append(selectedType)
        }) {
            HStack(spacing: 8) {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                Image(systemName: "arrow.right")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.blue)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
}

struct AuthTypeCard: View {
    let type: AuthenticationType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                iconView
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(type.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(descriptionText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                selectionIndicator
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var iconView: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundColor(.blue)
            .frame(width: 30, height: 30)
    }
    
    private var selectionIndicator: some View {
        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            .font(.title2)
            .foregroundColor(isSelected ? .blue : .secondary)
    }
    
    private var iconName: String {
        switch type {
        case .passcode4, .passcode6:
            return "number.circle.fill"
        case .password:
            return "textformat.abc"
        }
    }
    
    private var descriptionText: String {
        switch type {
        case .passcode4:
            return "Quick and simple 4-digit PIN"
        case .passcode6:
            return "More secure 6-digit PIN"
        case .password:
            return "Custom alphanumeric password"
        }
    }
}

#Preview {
    AuthTypeSelectionView { type in
        print("Selected: \(type.displayName)")
    }
} 