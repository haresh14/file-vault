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
    @State private var compactNavigationPath = NavigationPath()
    @State private var selectedFolder: Folder?
    @State private var previewItem: VaultItem?
    @State private var previewMediaItems: [VaultItem] = []
    @StateObject private var loginStateManager = LoginStateManager.shared
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.managedObjectContext) var context
    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Folder.createdAt, ascending: true)],
        predicate: NSPredicate(format: "parent == nil")
    ) private var rootFolders: FetchedResults<Folder>

    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                List {
                    Button {
                        select(nil)
                    } label: {
                        Label("All Folders", systemImage: "folder")
                    }
                    .accessibilityValue(selectedFolder == nil ? "Selected" : "")

                    if !loginStateManager.shouldShowEmptyVault {
                        ForEach(sidebarItems) { item in
                            Button {
                                select(item.folder)
                            } label: {
                                Label(
                                    item.folder.displayName,
                                    systemImage: selectedFolder == item.folder ? "folder.fill" : "folder"
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.leading, CGFloat(item.depth) * 16)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(
                                selectedFolder == item.folder ? Color.accentColor : Color.primary
                            )
                            .accessibilityValue(selectedFolder == item.folder ? "Selected" : "")
                        }
                    }
                }
                .navigationTitle("Folders")
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
                } content: {
                FolderContentView(
                    folder: selectedFolder,
                    navigationPath: $navigationPath,
                    onNavigateToFolder: select,
                    onPreviewFile: showPreview
                )
                .id(selectedFolder?.objectID)
                .navigationSplitViewColumnWidth(min: 360, ideal: 500)
                } detail: {
                VaultPreviewDetail(
                    item: previewItem,
                    mediaItems: previewMediaItems,
                    onClose: clearPreview
                )
                }
            } else {
                NavigationStack(path: $compactNavigationPath) {
                // FolderContentView already titles itself ("Folders" at the root, the
                // folder name when pushed). Setting a second title here competes with
                // it, which drops the title on first layout and flashes the root title
                // over each pushed folder.
                FolderContentView(
                    folder: nil,
                    navigationPath: $compactNavigationPath
                )
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .refreshVaultItems)) { _ in
            if selectedFolder?.isDeleted == true {
                select(nil)
            }
        }
    }

    private func select(_ folder: Folder?) {
        selectedFolder = folder
        navigationPath = NavigationPath()
        clearPreview()
    }

    private func showPreview(_ item: VaultItem, mediaItems: [VaultItem]) {
        previewItem = item
        previewMediaItems = mediaItems
    }

    private func clearPreview() {
        previewItem = nil
        previewMediaItems = []
    }

    private var sidebarItems: [FolderSidebarItem] {
        rootFolders.flatMap { flatten($0, depth: 0) }
    }

    private func flatten(_ folder: Folder, depth: Int) -> [FolderSidebarItem] {
        let item = FolderSidebarItem(folder: folder, depth: depth)
        let children = folder.subfoldersArray.sorted {
            $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
        return [item] + children.flatMap { flatten($0, depth: depth + 1) }
    }
}

private struct FolderSidebarItem: Identifiable {
    let folder: Folder
    let depth: Int
    var id: NSManagedObjectID { folder.objectID }
}

#Preview {
    FolderView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 