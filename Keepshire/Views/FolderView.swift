//
//  FolderView.swift
//  Keepshire
//
//  Created on 12/07/25.
//

import SwiftUI
import CoreData

struct FolderView: View {
    @State private var navigationPath = NavigationPath()
    @State private var selectedFolder: Folder?
    @StateObject private var loginStateManager = LoginStateManager.shared
    @Environment(\.managedObjectContext) var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        predicate: NSPredicate(format: "parent == nil")
    ) private var rootFolders: FetchedResults<Folder>

    var body: some View {
        if UIDevice.current.userInterfaceIdiom == .pad {
            NavigationSplitView {
                List {
                    Button {
                        select(nil)
                    } label: {
                        Label("All Folders", systemImage: "folder")
                    }
                    .accessibilityValue(selectedFolder == nil ? "Selected" : "")

                    if !loginStateManager.shouldShowEmptyVault {
                        ForEach(rootFolders) { folder in
                            Button {
                                select(folder)
                            } label: {
                                Label(folder.displayName, systemImage: "folder.fill")
                            }
                            .accessibilityValue(selectedFolder == folder ? "Selected" : "")
                        }
                    }
                }
                .navigationTitle("Folders")
            } detail: {
                NavigationStack(path: $navigationPath) {
                    FolderContentView(
                        folder: selectedFolder,
                        navigationPath: $navigationPath
                    )
                    .id(selectedFolder?.objectID)
                }
            }
        } else {
            NavigationStack(path: $navigationPath) {
                // FolderContentView already titles itself ("Folders" at the root, the
                // folder name when pushed). Setting a second title here competes with
                // it, which drops the title on first layout and flashes the root title
                // over each pushed folder.
                FolderContentView(
                    folder: nil,
                    navigationPath: $navigationPath
                )
            }
        }
    }

    private func select(_ folder: Folder?) {
        selectedFolder = folder
        navigationPath = NavigationPath()
    }
}

#Preview {
    FolderView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 