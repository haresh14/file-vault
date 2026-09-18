//
//  KeepshireApp.swift
//  Keepshire
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

@main
struct KeepshireApp: App {
    // Initialize dependency container
    let dependencies = DependencyContainer.shared
    
    init() {
        configureUITestingStateIfNeeded()
        _ = DiagnosticsManager.shared
        // Handle background URLSession events
        setupBackgroundURLSessionHandling()
    }
    
    var body: some Scene {
        WindowGroup {
            KeepshireRootView(dependencies: dependencies)
        }
    }
    
    private func setupBackgroundURLSessionHandling() {
        // The background session handling is actually done in AppDelegate or SceneDelegate
        // For SwiftUI apps, we need to handle it differently
        // Initialize the BackgroundUploadManager to ensure it's ready
        _ = BackgroundUploadManager.shared
    }

    private func configureUITestingStateIfNeeded() {
        let arguments = ProcessInfo.processInfo.arguments
        guard arguments.contains("--ui-testing") else { return }

        AppDataManager.shared.clearAllAppData()

        if arguments.contains("--ui-testing-first-launch") {
            UserDefaults.standard.removeObject(forKey: "hasLaunchedBefore")
            return
        }

        try? KeychainManager.shared.savePassword("1234")
        KeychainManager.shared.setAuthenticationType(.passcode4)
        KeychainManager.shared.setBiometricEnabled(false)
        KeychainManager.shared.setLockTimeout(KeychainManager.LockTimeout.never.rawValue)
        if arguments.contains("--ui-testing-fake-login") {
            try? KeychainManager.shared.saveFakePassword("9876")
        }
        AppDataManager.shared.markAppAsLaunched()
    }
}

private struct KeepshireRootView: View {
    let dependencies: DependencyContainer

    var body: some View {
        ContentView()
            .dependencies(dependencies)
            .environment(\.managedObjectContext, dependencies.coreDataManager.context)
            .overlay {
                if let error = dependencies.coreDataManager.persistentStoreLoadError {
                    VStack(spacing: 12) {
                        Text("Keepshire could not open its database.")
                            .font(.headline)
                        Text(error.localizedDescription)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(uiColor: .systemBackground))
                }
            }
            .onAppear {
                if dependencies.appDataManager.isFirstLaunch {
                    VaultLog.debug("DEBUG: 🚀 First app launch detected - performing cleanup...")
                    dependencies.appDataManager.performFirstLaunchCleanup()
                } else {
                    VaultLog.debug("DEBUG: ✅ Not first launch - no cleanup needed")
                }
                _ = dependencies.webServerManager
                // Registers the notification delegate. This does not ask for permission.
                _ = NotificationManager.shared
                // Blanking attaches to the scene's window, so it also covers sheets and previews.
                SecurityManager.shared.refreshCaptureBlanking()
            }
    }
}
