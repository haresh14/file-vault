//
//  MainTabView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var webServer = WebServerManager.shared
    @State private var showSettings = false
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            FolderView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Folder")
                        .accessibilityIdentifier("tab.folder")
                }
                .tag(0)
            
            CategoryView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Category")
                        .accessibilityIdentifier("tab.category")
                }
                .tag(1)
            
            VaultMainView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Gallery")
                        .accessibilityIdentifier("tab.gallery")
                }
                .tag(2)
            
            WebUploadTabView()
                .tabItem {
                    Image(systemName: webServer.isRunning ? "globe.badge.chevron.backward" : "globe")
                    Text("Web Upload")
                        .accessibilityIdentifier("tab.webUpload")
                }
                .badge(webServer.isRunning ? "●" : nil)
                .tag(3)
            
            // Settings tab that opens as sheet
            SettingsView()
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                        .accessibilityIdentifier("tab.settings")
                }
                .tag(4)
        }
        .tint(.blue)
        .onChange(of: selectedTab) { _, _ in
            // Send notification to reset selection modes when tab changes
            NotificationCenter.default.post(name: .tabDidChange, object: nil)
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 