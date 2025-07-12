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
                }
                .tag(0)
            
            VaultMainView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Gallery")
                }
                .tag(1)
            
            CategoryView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Category")
                }
                .tag(2)
            
            WebUploadTabView()
                .tabItem {
                    Image(systemName: webServer.isRunning ? "globe.badge.chevron.backward" : "globe")
                    Text("Web Upload")
                }
                .badge(webServer.isRunning ? "●" : nil)
                .tag(3)
            
            // Settings tab that opens as sheet
            Color.clear
                .tabItem {
                    Image(systemName: "gear")
                    Text("Settings")
                }
                .tag(4)
        }
        .accentColor(.blue)
        .onChange(of: selectedTab) { oldValue, newValue in
            if newValue == 4 { // Settings tab
                showSettings = true
                // Reset to previous tab to prevent staying on empty settings tab
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    selectedTab = oldValue
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 