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
            mainContent
            
            if isInBackground {
                PrivacyOverlay()
            }
        }
        .onAppear(perform: handleOnAppear)
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            handleWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            handleDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            handleWillEnterForeground()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if !isPasswordSet {
            PasscodeView(isSettingPasscode: true) {
                handlePasscodeSet()
            }
        } else if !isAuthenticated {
            PasscodeView(isSettingPasscode: false) {
                handleAuthentication()
            }
        } else {
            VaultMainView()
        }
    }
    
    private func handleOnAppear() {
        isPasswordSet = KeychainManager.shared.isPasswordSet()
        print("DEBUG: ContentView appeared")
        print("DEBUG: Is password set: \(isPasswordSet)")
        print("DEBUG: Is authenticated: \(isAuthenticated)")
    }
    
    private func handleWillResignActive() {
        isInBackground = true
        KeychainManager.shared.setLastBackgroundTime()
        print("DEBUG: App going to background, showing privacy overlay")
    }
    
    private func handleDidBecomeActive() {
        isInBackground = false
        print("DEBUG: App became active, hiding privacy overlay")
    }
    
    private func handleWillEnterForeground() {
        if KeychainManager.shared.shouldRequireAuthentication() {
            isAuthenticated = false
            print("DEBUG: App coming to foreground, requires authentication")
        } else {
            print("DEBUG: App coming to foreground, within timeout period - no auth needed")
        }
    }
    
    private func handlePasscodeSet() {
        print("DEBUG: Passcode set successfully, updating states")
        isPasswordSet = true
        isAuthenticated = true
    }
    
    private func handleAuthentication() {
        print("DEBUG: Authentication successful, setting isAuthenticated = true")
        isAuthenticated = true
    }
}

// Privacy overlay as a separate view
struct PrivacyOverlay: View {
    var body: some View {
        Color.black
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 10) {
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

// Main vault view
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
