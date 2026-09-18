//
//  ContentView.swift
//  Keepshire
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authenticationCoordinator = AuthenticationCoordinator()
    @StateObject private var securityManager = SecurityManager.shared
    @Environment(\.scenePhase) var scenePhase

    var body: some View {
        ZStack {
            mainContent
            
            // Only show privacy overlay if user is fully registered and authenticated
            if authenticationCoordinator.shouldShowPrivacyOverlay && authenticationCoordinator.isPasswordSet {
                EnhancedPrivacyOverlay()
            }
        }
        .onAppear(perform: authenticationCoordinator.handleOnAppear)
        .onChange(of: scenePhase) { _, newPhase in
            authenticationCoordinator.handleScenePhaseChange(to: newPhase)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willResignActiveNotification)) { _ in
            authenticationCoordinator.handleWillResignActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            authenticationCoordinator.handleDidBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            authenticationCoordinator.handleWillEnterForeground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            authenticationCoordinator.handleDidEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: .triggerSecurityLock)) { _ in
            authenticationCoordinator.handleSecurityLockTrigger()
        }
    }
    
    @ViewBuilder
    private var mainContent: some View {
        if !authenticationCoordinator.isAuthTypeSet {
            // First time setup - choose auth type with native navigation
            AuthTypeSelectionView { authType in
                authenticationCoordinator.handleAuthTypeSelected(authType)
            }
        } else if !authenticationCoordinator.isPasswordSet {
            // This should not happen with the new flow, but keeping as fallback
            PasscodeView(isSettingPasscode: true) {
                authenticationCoordinator.handlePasscodeSet()
            }
        } else if !authenticationCoordinator.isAuthenticated {
            if authenticationCoordinator.isCheckingBiometric {
                // Show loading state while checking biometric
                BiometricCheckView()
            } else if authenticationCoordinator.shouldShowPasscode {
                PasscodeView(isSettingPasscode: false) {
                    authenticationCoordinator.handleAuthentication()
                }
            }
        } else {
            ZStack {
                MainTabView()
                
                // Notification overlay
                NotificationOverlayView()
                
                // Upload progress overlay
                UploadProgressOverlayView()
            }
        }
    }
}

// Loading view while checking biometric
struct BiometricCheckView: View {
    var body: some View {
        ZStack {
            KeepshireTheme.brandWash
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "faceid")
                    .font(.system(size: 60))
                    .foregroundColor(KeepshireTheme.accent)
                
                Text("Checking Authentication...")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            }
        }
    }
}

// Enhanced privacy overlay with better visual design
struct EnhancedPrivacyOverlay: View {
    var body: some View {
        ZStack {
            // Opaque on purpose: this is the app-switcher cover, so nothing from
            // the vault may show through it.
            KeepshireTheme.brandScrim
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.white)
                
                Text(AppMetadata.displayName)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                
                Text("Your vault is protected by advanced security measures.")
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Spacer()
                
                Text("App is in background to ensure your privacy.")
                    .font(.caption)
                    .foregroundColor(.white)
                    .padding(.bottom)
    }
}
    }
}


#Preview {
    ContentView()
}
