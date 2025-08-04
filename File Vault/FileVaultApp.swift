//
//  FileVaultApp.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI
import BackgroundTasks

@main
struct FileVaultApp: App {
    // Initialize dependency container
    let dependencies = DependencyContainer.shared
    
    init() {
        // Handle background URLSession events
        setupBackgroundURLSessionHandling()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .dependencies(dependencies)
                .environment(\.managedObjectContext, dependencies.coreDataManager.context)
                .onAppear {
                    // Check for first launch and perform cleanup if needed
                    handleFirstLaunchCleanup()
                    
                    // Initialize WebServerManager to register background tasks
                    _ = dependencies.webServerManager
                }
        }
    }
    
    private func handleFirstLaunchCleanup() {
        if dependencies.appDataManager.isFirstLaunch {
            print("DEBUG: 🚀 First app launch detected - performing cleanup...")
            dependencies.appDataManager.performFirstLaunchCleanup()
        } else {
            print("DEBUG: ✅ Not first launch - no cleanup needed")
        }
    }
    
    private func setupBackgroundURLSessionHandling() {
        // The background session handling is actually done in AppDelegate or SceneDelegate
        // For SwiftUI apps, we need to handle it differently
        // Initialize the BackgroundUploadManager to ensure it's ready
        _ = BackgroundUploadManager.shared
    }
}
