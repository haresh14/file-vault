import SwiftUI

struct FolderBreadcrumbView: View {
    let folder: Folder?
    @Binding var navigationPath: NavigationPath
    let onNavigateToFolder: ((Folder?) -> Void)?

    init(
        folder: Folder?,
        navigationPath: Binding<NavigationPath>,
        onNavigateToFolder: ((Folder?) -> Void)? = nil
    ) {
        self.folder = folder
        _navigationPath = navigationPath
        self.onNavigateToFolder = onNavigateToFolder
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    if let onNavigateToFolder {
                        onNavigateToFolder(nil)
                    } else {
                        navigationPath.removeLast(navigationPath.count)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill").font(.caption)
                        Text("Home").font(.caption)
                    }
                        .foregroundColor(KeepshireTheme.accent)
                }
                if let folder {
                    let breadcrumbs = folder.breadcrumbPath
                    ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, breadcrumb in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button {
                                if let onNavigateToFolder {
                                    onNavigateToFolder(breadcrumb)
                                } else {
                                    navigationPath.removeLast(breadcrumbs.count - (index + 1))
                                }
                            } label: {
                                Text(breadcrumb.displayName)
                                    .font(.caption)
                                    .foregroundColor(index == breadcrumbs.count - 1 ? .primary : KeepshireTheme.accent)
                                    .fontWeight(index == breadcrumbs.count - 1 ? .semibold : .regular)
                            }
                            .disabled(index == breadcrumbs.count - 1)
                        }
                    }
                }
            }
            .padding(.horizontal, 4)
        }
    }
}

struct FolderContentEmptyState: View {
    let configuration: EmptyStateConfiguration

    var body: some View {
        VStack {
            EmptyStateView(configuration)
                .padding(.top, 80)
            Spacer()
        }
    }
}

struct FolderContentList: View {
    let folders: [Folder]
    let files: [VaultItem]
    let selectedFolders: Set<Folder>
    let selectedFiles: Set<VaultItem>
    let isSelectionMode: Bool
    let tapFolder: (Folder) -> Void
    let renameFolder: (Folder) -> Void
    let selectFolder: (Folder) -> Void
    let moveFolder: (Folder) -> Void
    let deleteFolder: (Folder) -> Void
    let swipeDeleteFolder: (Folder) -> Void
    let tapFile: (VaultItem) -> Void
    let selectFile: (VaultItem) -> Void
    let favoriteFile: (VaultItem) -> Void
    let renameFile: (VaultItem) -> Void
    let moveFile: (VaultItem) -> Void
    let shareFile: (VaultItem) -> Void
    let deleteFile: (VaultItem) -> Void
    let swipeDeleteFile: (VaultItem) -> Void

    var body: some View {
        List {
            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(folders) { folder in
                        SelectableFolderRowView(
                            folder: folder,
                            isSelected: selectedFolders.contains(folder),
                            isSelectionMode: isSelectionMode,
                            onTap: { tapFolder(folder) },
                            onRename: { renameFolder(folder) },
                            onSelect: { selectFolder(folder) },
                            onMove: { moveFolder(folder) },
                            onDelete: { deleteFolder(folder) }
                        )
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: !UserDefaults.standard.bool(forKey: "trashEnabled")
                        ) {
                            if !isSelectionMode {
                                Button(role: .destructive) { swipeDeleteFolder(folder) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            if !files.isEmpty {
                Section("Files") {
                    ForEach(files) { file in
                        SelectableFileRowView(
                            file: file,
                            isSelected: selectedFiles.contains(file),
                            isSelectionMode: isSelectionMode,
                            onTap: { tapFile(file) },
                            onSelect: { selectFile(file) },
                            onFavoriteToggle: { favoriteFile(file) },
                            onRename: { renameFile(file) },
                            onMove: { moveFile(file) },
                            onShare: { shareFile(file) },
                            onDelete: { deleteFile(file) }
                        )
                        .swipeActions(
                            edge: .trailing,
                            allowsFullSwipe: !UserDefaults.standard.bool(forKey: "trashEnabled")
                        ) {
                            if !isSelectionMode {
                                Button(role: .destructive) { swipeDeleteFile(file) } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

struct FolderContentToolbar: ToolbarContent {
    let isSelectionMode: Bool
    let hasSelection: Bool
    let hasSelectedFiles: Bool
    let hasItems: Bool
    let canAddFiles: Bool
    let selectAll: () -> Void
    let cancel: () -> Void
    let favorite: () -> Void
    let share: () -> Void
    let move: () -> Void
    let delete: () -> Void
    let addFiles: () -> Void
    let sort: () -> Void
    let selectItems: () -> Void

    var body: some ToolbarContent {
        // Declared conditionally rather than always-present-but-empty: an empty leading
        // item still claims the slot that holds the back button and the large title.
        if isSelectionMode {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Select All", action: selectAll)
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isSelectionMode {
                Button("Cancel", action: cancel)
                if hasSelection {
                    Menu {
                        if hasSelectedFiles {
                            Button(action: favorite) { Label("Favorite", systemImage: "heart") }
                            Button(action: share) { Label("Share", systemImage: "square.and.arrow.up") }
                        }
                        Button(action: move) { Label("Move", systemImage: "arrow.up.doc.on.clipboard") }
                        Divider()
                        Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(KeepshireTheme.accent)
                    }
                }
            } else {
                Menu {
                    if canAddFiles {
                        Button(action: addFiles) { Label("Add Files", systemImage: "plus") }
                    }
                    Button(action: sort) { Label("Sort", systemImage: "arrow.up.arrow.down") }
                    if hasItems {
                        Divider()
                        Button(action: selectItems) { Label("Select Items", systemImage: "checkmark.circle") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(KeepshireTheme.accent)
                }
            }
        }
    }
}
