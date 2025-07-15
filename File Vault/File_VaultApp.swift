//
//  File_VaultApp.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI
import BackgroundTasks

@main
struct File_VaultApp: App {
    // Initialize Core Data
    let coreDataManager = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.context)
                .onAppear {
                    // Check for first launch and perform cleanup if needed
                    handleFirstLaunchCleanup()
                    
                    // Initialize WebServerManager to register background tasks
                    _ = WebServerManager.shared
                }
        }
    }
    
    private func handleFirstLaunchCleanup() {
        let appDataManager = AppDataManager.shared
        
        if appDataManager.isFirstLaunch {
            print("DEBUG: 🚀 First app launch detected - performing cleanup...")
            appDataManager.performFirstLaunchCleanup()
        } else {
            print("DEBUG: ✅ Not first launch - no cleanup needed")
        }
    }
}
