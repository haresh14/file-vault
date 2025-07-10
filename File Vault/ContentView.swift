//
//  ContentView.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isAuthenticated = false
    @State private var isPasswordSet = false
    @State private var isInBackground = false
    
    var body: some View {
        ZStack {
            Group {
                if !isPasswordSet {
                    // First time setup - need to create passcode
                    PasscodeView(isSettingPasscode: true) {
                        // After setting passcode, update both states
                        print("DEBUG: Passcode set successfully, updating states")
                        isPasswordSet = true
                        isAuthenticated = true
                    }
                } else if !isAuthenticated {
                    // Show authentication screen
                    PasscodeView(isSettingPasscode: false) {
                        print("DEBUG: Authentication successful, setting isAuthenticated = true")
                        isAuthenticated = true
                    }
                } else {
                    // Main vault view
                    VaultMainView()
                }
            }
            
            // Privacy overlay when in background
            if isInBackground {
                Color.black
                    .ignoresSafeArea()
                    .overlay(
                        VStack {
                            Image(systemName: "lock.shield.fill")
                                .font(.system(size: 60))
                                .foregroundColor(.white)
                            Text("File Vault")
                                .font(.title)
                                .foregroundColor(.white)
                        }
                    )
            }
        }
        .onAppear {
            // Check if password is already set
            isPasswordSet = KeychainManager.shared.isPasswordSet()
            print("DEBUG: ContentView appeared")
            print("DEBUG: Is password set: \(isPasswordSet)")
            print("DEBUG: Is authenticated: \(isAuthenticated)")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            // App is going to background - show privacy overlay and record time
            isInBackground = true
            KeychainManager.shared.setLastBackgroundTime()
            print("DEBUG: App going to background, showing privacy overlay")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            // App became active - hide privacy overlay
            isInBackground = false
            print("DEBUG: App became active, hiding privacy overlay")
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            // App is coming to foreground - check if we need authentication
            if KeychainManager.shared.shouldRequireAuthentication() {
                isAuthenticated = false
                print("DEBUG: App coming to foreground, requires authentication")
            } else {
                print("DEBUG: App coming to foreground, within timeout period - no auth needed")
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

#Preview {
    ContentView()
}
