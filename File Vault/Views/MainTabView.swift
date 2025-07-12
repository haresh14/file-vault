//
//  MainTabView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct MainTabView: View {
    @StateObject private var webServer = WebServerManager.shared
    
    var body: some View {
        TabView {
            FolderView()
                .tabItem {
                    Image(systemName: "folder")
                    Text("Folder")
                }
            
            VaultMainView()
                .tabItem {
                    Image(systemName: "photo.on.rectangle")
                    Text("Gallery")
                }
            
            CategoryView()
                .tabItem {
                    Image(systemName: "square.grid.2x2")
                    Text("Category")
                }
            
            WebUploadTabView()
                .tabItem {
                    Image(systemName: webServer.isRunning ? "globe.badge.chevron.backward" : "globe")
                    Text("Web Upload")
                }
                .badge(webServer.isRunning ? "●" : nil)
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 