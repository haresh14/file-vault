import Foundation
import PhotosUI
import SwiftUI

struct FolderContentView: View {
    private enum Constants {
        static let trashEnabledKey = "trashEnabled"
    }

    let folder: Folder?
    @Binding var navigationPath: NavigationPath
    @StateObject private var viewModel: FolderViewModel
    @StateObject private var loginStateManager = LoginStateManager.shared
    @State private var showFileRenameAlert = false
    @State private var fileRenameText = ""
    @State private var fileToRename: VaultItem?

    init(
        folder: Folder?,
        navigationPath: Binding<NavigationPath>,
        dependencies: DependencyContainer = .shared
    ) {
        self.folder = folder
        _navigationPath = navigationPath
        _viewModel = StateObject(wrappedValue: FolderViewModel(folder: folder, dependencies: dependencies))
    }

    var body: some View {
        // The list is always the view's content, even when empty, and the empty state
        // is layered on top. Swapping the list out for a plain stack made the
        // navigation bar re-bind its large title and search field on every change,
        // which is what made the title and search drawer come and go.
        contentList
        .overlay {
            if isShowingEmptyState {
                FolderContentEmptyState(configuration: emptyStateConfiguration)
            }
        }
        // The breadcrumb is a horizontal ScrollView. Stacking it above the list in a
        // VStack makes the navigation bar bind its large title and search drawer to
        // that strip instead of the list, which is why both went missing. As a safe
        // area inset it stays pinned without becoming the primary scroll view.
        .safeAreaInset(edge: .top, spacing: 0) {
            FolderBreadcrumbView(folder: folder, navigationPath: $navigationPath)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
        }
        .navigationTitle(folder?.displayName ?? "Folders")
        // Inline, unlike the other tabs. A large title is laid out from the list's
        // scroll offset, and the pinned breadcrumb inset sits in the space it expands
        // into, so the title landed above/below the breadcrumb or vanished depending
        // on scroll position. An inline title is drawn in the bar regardless.
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $viewModel.searchText, prompt: "Search this folder")
        // Belongs to the view, not to the rows: a destination declared inside the list
        // disappears whenever the list has no content to render it from.
        .navigationDestination(for: Folder.self) { destination in
            FolderContentView(folder: destination, navigationPath: $navigationPath)
        }
        .toolbar { toolbar }
        .modifier(FolderContentAlertsModifier(
            viewModel: viewModel,
            showFileRenameAlert: $showFileRenameAlert,
            fileRenameText: $fileRenameText,
            createFolder: createFolder,
            renameFolder: renameFolder,
            cancelFileRename: cancelFileRename,
            renameFile: performFileRename,
            deleteSelected: deleteSelectedItems,
            deleteSwiped: viewModel.performSwipeDelete
        ))
        .modifier(FolderContentSheetsModifier(
            viewModel: viewModel,
            folder: folder,
            mediaViewerPresented: mediaViewerPresented,
            importAssets: importAssets,
            importDocuments: importDocuments,
            selectSort: selectSortOption,
            addPhotos: {
                viewModel.showAddActionSheet = false
                viewModel.showPhotoPicker = true
            },
            addFiles: {
                viewModel.showAddActionSheet = false
                viewModel.showDocumentPicker = true
            },
            createFolder: {
                viewModel.showAddActionSheet = false
                viewModel.showCreateFolder = true
            },
            move: { destination in
                moveSelectedItems(to: destination)
                viewModel.showMoveSheet = false
            }
        ))
        .overlay {
            if viewModel.isImporting {
                ImportProgressView(progress: viewModel.importProgress)
            }
        }
    }

    private var isShowingEmptyState: Bool {
        loginStateManager.shouldShowEmptyVault
            || (viewModel.folders.isEmpty && viewModel.files.isEmpty)
            || viewModel.isShowingNoSearchResults
    }

    private var contentList: some View {
        FolderContentList(
            folders: isShowingEmptyState ? [] : viewModel.sortedFolders,
            files: isShowingEmptyState ? [] : viewModel.sortedFiles,
            selectedFolders: viewModel.selectedFolders,
            selectedFiles: viewModel.selectedFiles,
            isSelectionMode: viewModel.isSelectionMode,
            tapFolder: { item in
                viewModel.isSelectionMode ? toggleFolderSelection(item) : navigationPath.append(item)
            },
            renameFolder: startRenaming,
            selectFolder: { item in
                if !viewModel.isSelectionMode { viewModel.enterSelectionMode() }
                toggleFolderSelection(item)
            },
            moveFolder: moveFolder,
            deleteFolder: deleteFolder,
            swipeDeleteFolder: { viewModel.prepareSwipeDeleteAlert(for: [$0]) },
            tapFile: { item in
                viewModel.isSelectionMode ? toggleFileSelection(item) : viewModel.viewFile(item)
            },
            selectFile: { item in
                if !viewModel.isSelectionMode { viewModel.enterSelectionMode() }
                toggleFileSelection(item)
            },
            favoriteFile: { FileStorageManager.shared.toggleFavorite(for: $0) },
            renameFile: startFileRename,
            moveFile: moveFile,
            shareFile: { ShareManager.shared.shareVaultItem($0) },
            deleteFile: { viewModel.prepareSwipeDeleteAlert(for: [$0]) },
            swipeDeleteFile: { viewModel.prepareSwipeDeleteAlert(for: [$0]) }
        )
    }

    private var toolbar: some ToolbarContent {
        FolderContentToolbar(
            isSelectionMode: viewModel.isSelectionMode,
            hasSelection: !viewModel.selectedFolders.isEmpty || !viewModel.selectedFiles.isEmpty,
            hasSelectedFiles: !viewModel.selectedFiles.isEmpty,
            hasItems: !viewModel.folders.isEmpty || !viewModel.files.isEmpty,
            canAddFiles: loginStateManager.canAddFiles,
            selectAll: selectAllItems,
            cancel: exitSelectionMode,
            favorite: viewModel.toggleFavoriteSelectedFiles,
            share: shareSelectedFiles,
            move: { viewModel.showMoveSheet = true },
            delete: requestDeleteSelected,
            addFiles: { viewModel.showAddActionSheet = true },
            sort: { viewModel.showSortActionSheet = true },
            selectItems: enterSelectionMode
        )
    }

    private var emptyStateConfiguration: EmptyStateConfiguration {
        if loginStateManager.shouldShowEmptyVault {
            return .noContent
        }
        if viewModel.isShowingNoSearchResults {
            return EmptyStateConfiguration(
                iconName: "magnifyingglass",
                title: "No Results",
                subtitle: "No files or folders match “\(viewModel.searchText)”.",
                animation: .none
            )
        }
        return .emptyFolder(
            canCreateFolders: loginStateManager.canCreateFolders,
            canAddFiles: loginStateManager.canAddFiles,
            onCreateFolder: { viewModel.showCreateFolder = true },
            onAddFiles: { viewModel.showAddActionSheet = true }
        )
    }

    private var mediaViewerPresented: Binding<Bool> {
        Binding(
            get: { viewModel.showUnifiedMediaViewer && viewModel.mediaViewerIndex > -1 },
            set: { isPresented in
                if !isPresented {
                    viewModel.showUnifiedMediaViewer = false
                    viewModel.mediaViewerIndex = -1
                }
            }
        )
    }

    private func selectSortOption(_ option: FolderSortOption) {
        if option == viewModel.sortOption {
            viewModel.sortAscending.toggle()
        } else {
            viewModel.sortOption = option
            viewModel.sortAscending = true
        }
        viewModel.showSortActionSheet = false
    }

    private func createFolder() {
        let name = viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else {
            viewModel.newFolderName = ""
            return
        }
        viewModel.createFolder(named: viewModel.newFolderName)
        viewModel.newFolderName = ""
    }

    private func startRenaming(_ item: Folder) {
        viewModel.folderToRename = item
        viewModel.renameText = item.displayName
        viewModel.showRenameFolder = true
    }

    private func renameFolder() {
        let name = viewModel.renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = viewModel.folderToRename, !name.isEmpty else {
            viewModel.renameText = ""
            viewModel.folderToRename = nil
            return
        }
        viewModel.renameFolder(item, to: viewModel.renameText)
        viewModel.renameText = ""
        viewModel.folderToRename = nil
    }

    private func requestDeleteSelected() {
        if UserDefaults.standard.bool(forKey: Constants.trashEnabledKey) {
            deleteSelectedItems()
        } else {
            viewModel.showDeleteAlert = true
        }
    }

    private func enterSelectionMode() {
        viewModel.isSelectionMode = true
        viewModel.enterSelectionMode()
        viewModel.selectedFolders.removeAll()
        viewModel.selectedFiles.removeAll()
    }

    private func exitSelectionMode() {
        viewModel.isSelectionMode = false
        viewModel.exitSelectionMode()
        viewModel.selectedFolders.removeAll()
        viewModel.selectedFiles.removeAll()
    }

    private func toggleFolderSelection(_ item: Folder) {
        viewModel.toggleFolderSelection(item)
    }

    private func toggleFileSelection(_ item: VaultItem) {
        viewModel.toggleFileSelection(item)
    }

    private func selectAllItems() {
        viewModel.selectAll()
    }

    private func moveSelectedItems(to destination: Folder?) {
        viewModel.moveSelectedItems(to: destination)
        exitSelectionMode()
    }

    private func deleteSelectedItems() {
        viewModel.deleteSelectedItems()
        exitSelectionMode()
    }

    private func shareSelectedFiles() {
        ShareManager.shared.shareVaultItems(Array(viewModel.selectedFiles)) {
            DispatchQueue.main.async { exitSelectionMode() }
        }
    }

    private func moveFile(_ item: VaultItem) {
        viewModel.selectedFiles.removeAll()
        viewModel.selectedFolders.removeAll()
        viewModel.selectedFiles.insert(item)
        viewModel.showMoveSheet = true
    }

    private func moveFolder(_ item: Folder) {
        viewModel.selectedFiles.removeAll()
        viewModel.selectedFolders.removeAll()
        viewModel.selectedFolders.insert(item)
        viewModel.showMoveSheet = true
    }

    private func deleteFolder(_ item: Folder) {
        if UserDefaults.standard.bool(forKey: Constants.trashEnabledKey) {
            CoreDataManager.shared.deleteFolder(item)
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
        } else {
            if !viewModel.isSelectionMode {
                viewModel.enterSelectionMode()
            }
            viewModel.selectedFolders = [item]
            viewModel.showDeleteAlert = true
        }
    }

    private func importAssets(_ results: [PHPickerResult]) {
        viewModel.importAssets(results)
    }

    private func importDocuments(_ documents: [(Data, String)]) {
        viewModel.importDocuments(documents)
    }

    private func startFileRename(for item: VaultItem) {
        guard let fileName = item.fileName else { return }
        fileToRename = item
        fileRenameText = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        showFileRenameAlert = true
    }

    private func performFileRename() {
        let trimmedName = fileRenameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = fileToRename, !trimmedName.isEmpty, let oldFileName = item.fileName else {
            cancelFileRename()
            return
        }
        let fileExtension = URL(fileURLWithPath: oldFileName).pathExtension
        let newFileName = fileExtension.isEmpty ? fileRenameText : "\(trimmedName).\(fileExtension)"
        do {
            try FileStorageManager.shared.renameFile(vaultItem: item, newFileName: newFileName)
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
        } catch {
            VaultLog.debug("Error renaming file: \(error)")
        }
        cancelFileRename()
    }

    private func cancelFileRename() {
        showFileRenameAlert = false
        fileToRename = nil
        fileRenameText = ""
    }
}
