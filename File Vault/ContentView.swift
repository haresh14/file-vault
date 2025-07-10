//
//  ContentView.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var needsPasscodeSetup = false
    
    var body: some View {
        Group {
            if !KeychainManager.shared.isPasswordSet() {
                // First time setup - need to create passcode
                PasscodeView(isSettingPasscode: true) {
                    // After setting passcode, show biometric setup
                    isAuthenticated = true
                }
            } else if !isAuthenticated {
                // Show authentication screen
                PasscodeView(isSettingPasscode: false) {
                    isAuthenticated = true
                }
            } else {
                // Main vault view (placeholder for now)
                VaultMainView()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // App is going to background
            KeychainManager.shared.setLastBackgroundTime()
            isAuthenticated = false
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // App is coming to foreground
            if KeychainManager.shared.shouldRequireAuthentication() {
                isAuthenticated = false
            }
        }
    }
}

// Placeholder for main vault view
struct VaultMainView: View {
    @State private var showSettings = false
    
    var body: some View {
        NavigationView {
            VStack {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .padding()
                
                Text("Welcome to Your Vault")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Your photos and videos are secure")
                    .foregroundColor(.secondary)
                    .padding()
                
                Spacer()
            }
            .navigationTitle("File Vault")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gear")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }
}

// Basic settings view
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @State private var biometricEnabled = KeychainManager.shared.isBiometricEnabled()
    
    var body: some View {
        NavigationView {
            Form {
                Section("Security") {
                    Toggle("Enable Biometric Authentication", isOn: $biometricEnabled)
                        .onChange(of: biometricEnabled) { newValue in
                            KeychainManager.shared.setBiometricEnabled(newValue)
                        }
                        .disabled(!BiometricAuthManager.shared.canUseBiometrics())
                    
                    if BiometricAuthManager.shared.canUseBiometrics() {
                        HStack {
                            Image(systemName: BiometricAuthManager.shared.biometricType() == .faceID ? "faceid" : "touchid")
                            Text("\(BiometricAuthManager.shared.biometricType() == .faceID ? "Face ID" : "Touch ID") Available")
                                .foregroundColor(.secondary)
                        }
                    }
                }
                
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
}
