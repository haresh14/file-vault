//
//  FolderView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct FolderView: View {
    @State private var navigationPath = NavigationPath()
    @StateObject private var loginStateManager = LoginStateManager.shared
    @Environment(\.managedObjectContext) var context

    var body: some View {
        NavigationStack(path: $navigationPath) {
            FolderContentView(
                folder: nil,
                navigationPath: $navigationPath
            )
            .navigationTitle("Folders")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

#Preview {
    FolderView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 