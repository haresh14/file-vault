//
//  FileVaultApp.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

@main
struct FileVaultApp: App {
    // Initialize dependency container
    let dependencies = DependencyContainer.shared
    
    init() {
        configureUITestingStateIfNeeded()
        // Handle background URLSession events
        setupBackgroundURLSessionHandling()
    }
    
    var body: some Scene {
        WindowGroup {
            FileVaultRootView(dependencies: dependencies)
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

private struct FileVaultRootView: View {
    let dependencies: DependencyContainer

    var body: some View {
        ContentView()
            .dependencies(dependencies)
            .environment(\.managedObjectContext, dependencies.coreDataManager.context)
            .onAppear {
                if dependencies.appDataManager.isFirstLaunch {
                    VaultLog.debug("DEBUG: 🚀 First app launch detected - performing cleanup...")
                    dependencies.appDataManager.performFirstLaunchCleanup()
                } else {
                    VaultLog.debug("DEBUG: ✅ Not first launch - no cleanup needed")
                }
                _ = dependencies.webServerManager
                // Blanking attaches to the scene's window, so it also covers sheets and previews.
                SecurityManager.shared.refreshCaptureBlanking()
            }
    }
}
