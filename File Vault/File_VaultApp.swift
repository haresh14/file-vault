//
//  File_VaultApp.swift
//  File Vault
//
//  Created by Thor on 10/07/25.
//

import SwiftUI

@main
struct File_VaultApp: App {
    // Initialize Core Data
    let coreDataManager = CoreDataManager.shared
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, coreDataManager.context)
        }
    }
}
