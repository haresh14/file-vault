//  FolderContentView.swift
//  File Vault
//  Refactored folder content view with MVVM separation

import SwiftUI
import UIKit
import Photos
import PhotosUI
import UniformTypeIdentifiers

struct FolderContentView: View {
    let folder: Folder?
    @Binding var navigationPath: NavigationPath
    @StateObject private var viewModel: FolderViewModel
    @StateObject private var loginStateManager = LoginStateManager.shared
    @Environment(\.managedObjectContext) var context
    
    // MARK: - File Rename State
    @State private var showFileRenameAlert = false
    @State private var fileRenameText = ""
    @State private var fileToRename: VaultItem?

    // MARK: - Init
    init(folder: Folder?, navigationPath: Binding<NavigationPath>) {
        self.folder = folder
        self._navigationPath = navigationPath
        _viewModel = StateObject(wrappedValue: FolderViewModel(folder: folder))
    }

    private     var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { viewModel.showUnifiedMediaViewer && viewModel.mediaViewerIndex > -1 },
            set: { newValue in
                if !newValue {
                    viewModel.showUnifiedMediaViewer = false
                    viewModel.mediaViewerIndex = -1
                }
            }
        )
    }

    var sortedFolders: [Folder] {
        viewModel.sortedFolders
    }


    var folders: [Folder] { viewModel.folders }
    var files: [VaultItem] { viewModel.files }

    var sortedFiles: [VaultItem] {
        if loginStateManager.shouldShowEmptyVault {
            return []
        }
        let sorted: [VaultItem]
        switch viewModel.sortOption {
        case .userDefault:
            sorted = files.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .name:
            sorted = files.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .date:
            sorted = files.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .size:
            sorted = files.sorted { $0.fileSize < $1.fileSize }
        case .kind:
            sorted = files.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        return viewModel.sortAscending ? sorted : sorted.reversed()
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                breadcrumbView
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                if loginStateManager.shouldShowEmptyVault || (folders.isEmpty && files.isEmpty) {
                    VStack {
                        emptyStateView
                            .padding(.top, 80)
                        Spacer()
                    }
                } else {
                    folderContentView
                }
            }
        }
        .navigationTitle(folder?.displayName ?? "Folders")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if viewModel.isSelectionMode {
                    Button("Select All") {
                        selectAllItems()
                    }
                } else {
                    EmptyView()
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if viewModel.isSelectionMode {
                    if !viewModel.selectedFolders.isEmpty || !viewModel.selectedFiles.isEmpty {
                        Menu {
                            // Share button (only show for files, not folders)
                            if !viewModel.selectedFiles.isEmpty {
                                Button(action: { shareSelectedFiles() }) {
                                    Label("Share", systemImage: "square.and.arrow.up")
                                }
                            }
                            
                            Button(action: { viewModel.showMoveSheet = true }) {
                                Label("Move", systemImage: "arrow.up.doc.on.clipboard")
                            }
                            
                            Divider()
                            
                            Button(role: .destructive, action: { 
                                // Skip confirmation if trash is enabled
                                if UserDefaults.standard.bool(forKey: "trashEnabled") {
                                    deleteSelectedItems()
                                } else {
                                    viewModel.showDeleteAlert = true
                                }
                            }) {
                                Label("Delete", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .foregroundColor(.blue)
                        }
                    }
                    Button("Cancel") {
                        exitSelectionMode()
                    }
                } else {
                    Menu {
                        if loginStateManager.canAddFiles {
                            Button(action: { viewModel.showAddActionSheet = true }) {
                                Label("Add Files", systemImage: "plus")
                            }
                        }
                        
                        Button(action: { viewModel.showSortActionSheet = true }) {
                            Label("Sort", systemImage: "arrow.up.arrow.down")
                        }
                        
                        if !(folders.isEmpty && files.isEmpty) {
                            Divider()
                            
                            Button(action: { enterSelectionMode() }) {
                                Label("Select Items", systemImage: "checkmark.circle")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
            }
        }


        .alert("Create Folder", isPresented: $viewModel.showCreateFolder) {
            TextField("Folder Name", text: $viewModel.newFolderName)
            Button("Cancel", role: .cancel) {
                viewModel.newFolderName = ""
            }
            Button("Create") {
                createFolder()
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("Rename Folder", isPresented: $viewModel.showRenameFolder) {
            TextField("Folder Name", text: $viewModel.renameText)
            Button("Cancel", role: .cancel) {
                viewModel.renameText = ""
                viewModel.folderToRename = nil
            }
            Button("Rename") {
                renameFolder()
            }
        } message: {
            Text("Enter a new name for the folder")
        }
        .alert("Rename File", isPresented: $showFileRenameAlert) {
            TextField("File Name", text: $fileRenameText)
            Button("Cancel", role: .cancel) {
                cancelFileRename()
            }
            Button("Rename") {
                performFileRename()
            }
        } message: {
            Text("Enter a new name for the file")
        }
        .alert("Delete Items", isPresented: $viewModel.showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            let totalItems = viewModel.selectedFolders.count + viewModel.selectedFiles.count
            return Text("Are you sure you want to delete \(totalItems) item(s)? This action cannot be undone.")
        }
        .alert("Delete Items", isPresented: $viewModel.showSwipeDeleteAlert) {
            Button("Cancel", role: .cancel) {
                viewModel.itemsToDelete.removeAll()
            }
            Button("Delete", role: .destructive) {
                performSwipeDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(viewModel.itemsToDelete.count) item(s)? This action cannot be undone.")
        }

        .sheet(isPresented: $viewModel.showPhotoPicker) {
            PhotoPickerView { results in
                importAssets(results)
            }
        }
        .sheet(isPresented: $viewModel.showDocumentPicker) {
            DocumentPickerView { dataArray in
                importDocuments(dataArray)
            }
        }
        .sheet(isPresented: $viewModel.showSortActionSheet) {
            FolderSortPopupView(
                currentSortOption: viewModel.sortOption,
                sortAscending: viewModel.sortAscending,
                onSortSelected: { option in
                    if option == viewModel.sortOption {
                        viewModel.sortAscending.toggle()
                    } else {
                        viewModel.sortOption = option
                        viewModel.sortAscending = true
                    }
                    viewModel.showSortActionSheet = false
                }
            )
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showAddActionSheet) {
            UniversalAddContentView.forFolder(
                onAddPhotos: {
                    viewModel.showAddActionSheet = false
                    viewModel.showPhotoPicker = true
                },
                onAddFiles: {
                    viewModel.showAddActionSheet = false
                    viewModel.showDocumentPicker = true
                },
                onCreateFolder: {
                    viewModel.showAddActionSheet = false
                    viewModel.showCreateFolder = true
                }
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $viewModel.showMoveSheet) {
            FolderPickerView(
                selectedFolders: viewModel.selectedFolders,
                selectedFiles: viewModel.selectedFiles,
                currentFolder: folder,
                onMove: { destinationFolder in
                    moveSelectedItems(to: destinationFolder)
                    viewModel.showMoveSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: isMediaViewerPresented) {
            UnifiedMediaViewerView(
                mediaItems: viewModel.getMediaFiles(),
                initialIndex: viewModel.mediaViewerIndex
            )
        }
        .fullScreenCover(isPresented: $viewModel.showFilePreview) {
            if let filePreviewItem = viewModel.filePreviewItem {
                FilePreviewView(vaultItem: filePreviewItem)
            }
        }
        .overlay(
            Group {
                if viewModel.isImporting {
                    ImportProgressView(progress: viewModel.importProgress)
                }
            }
        )
    }

    // MARK: - Subviews & Helpers (identical to original)
    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button(action: {
                    navigationPath.removeLast(navigationPath.count)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.caption)
                        Text("Home")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                if let folder = folder {
                    let breadcrumbs = folder.breadcrumbPath
                    ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, folder in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Button(action: {
                                let countToRemove = breadcrumbs.count - (index + 1)
                                navigationPath.removeLast(countToRemove)
                            }) {
                                Text(folder.displayName)
                                    .font(.caption)
                                    .foregroundColor(index == breadcrumbs.count - 1 ? .primary : .blue)
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

    private var emptyStateView: some View {
        EmptyStateView(emptyStateConfiguration)
    }
    
    private var emptyStateConfiguration: EmptyStateConfiguration {
        if loginStateManager.shouldShowEmptyVault {
            return .noContent
        } else {
            // Both root folder and subfolders should have same capabilities
            return .emptyFolder(
                canCreateFolders: loginStateManager.canCreateFolders,
                canAddFiles: loginStateManager.canAddFiles,
                onCreateFolder: { viewModel.showCreateFolder = true },
                onAddFiles: { viewModel.showAddActionSheet = true }
            )
        }
    }

    private var folderContentView: some View {
        List {
            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(sortedFolders) { folder in
                        SelectableFolderRowView(
                            folder: folder,
                            isSelected: viewModel.selectedFolders.contains(folder),
                            isSelectionMode: viewModel.isSelectionMode,
                            onTap: {
                                if viewModel.isSelectionMode {
                                    toggleFolderSelection(folder)
                                } else {
                                    navigationPath.append(folder)
                                }
                            },
                            onRename: {
                                startRenaming(folder)
                            },
                            onSelect: {
                                if !viewModel.isSelectionMode {
                                    viewModel.enterSelectionMode()
                                }
                                toggleFolderSelection(folder)
                            },
                            onMove: {
                                moveFolder(folder)
                            },
                            onDelete: {
                                deleteFolder(folder)
                            }
                        )
                        .background(
                            NavigationLink(value: folder, label: { EmptyView() })
                                .opacity(0)
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: !UserDefaults.standard.bool(forKey: "trashEnabled")) {
                            if !viewModel.isSelectionMode {
                                Button(role: .destructive) {
                                    viewModel.prepareSwipeDeleteAlert(for: [folder])
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }

                    }
                }
            }
            if !files.isEmpty {
                Section("Files") {
                    ForEach(sortedFiles) { file in
                        SelectableFileRowView(
                            file: file,
                            isSelected: viewModel.selectedFiles.contains(file),
                            isSelectionMode: viewModel.isSelectionMode,
                            onTap: {
                                if viewModel.isSelectionMode {
                                    toggleFileSelection(file)
                                } else {
                                    viewFile(file)
                                }
                            },
                            onSelect: {
                                if !viewModel.isSelectionMode {
                                    viewModel.enterSelectionMode()
                                }
                                toggleFileSelection(file)
                            },
                            onFavoriteToggle: {
                                // Add favorite functionality to FolderViewModel
                                FileStorageManager.shared.toggleFavorite(for: file)
                            },
                            onRename: {
                                startFileRename(for: file)
                            },
                            onMove: {
                                moveFile(file)
                            },
                            onShare: {
                                ShareManager.shared.shareVaultItem(file)
                            },
                            onDelete: {
                                viewModel.prepareSwipeDeleteAlert(for: [file])
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: !UserDefaults.standard.bool(forKey: "trashEnabled")) {
                            if !viewModel.isSelectionMode {
                                Button(role: .destructive) {
                                    viewModel.prepareSwipeDeleteAlert(for: [file])
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationDestination(for: Folder.self) { folder in
            FolderContentView(folder: folder, navigationPath: $navigationPath)
        }
    }

    private func createFolder() {
        guard !viewModel.newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            viewModel.newFolderName = ""; return }
        viewModel.createFolder(named: viewModel.newFolderName)
        viewModel.newFolderName = ""
    }
    private func startRenaming(_ folder: Folder) {
        viewModel.folderToRename = folder; viewModel.renameText = folder.displayName; viewModel.showRenameFolder = true
    }
    private func renameFolder() {
        guard let folder = viewModel.folderToRename,
              !viewModel.renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { viewModel.renameText = ""; viewModel.folderToRename = nil; return }
        viewModel.renameFolder(folder, to: viewModel.renameText)
        viewModel.renameText = ""; viewModel.folderToRename = nil
    }
    private func deleteFolders(offsets: IndexSet) {
        viewModel.itemsToDelete = offsets.map { sortedFolders[$0] }
        
        // Skip confirmation if trash is enabled
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            performSwipeDelete()
        } else {
            viewModel.showSwipeDeleteAlert = true
        }
    }
    private func deleteFiles(offsets: IndexSet) {
        viewModel.itemsToDelete = offsets.map { sortedFiles[$0] }
        
        // Skip confirmation if trash is enabled
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            performSwipeDelete()
        } else {
            viewModel.showSwipeDeleteAlert = true
        }
    }
    private func performSwipeDelete() {
        viewModel.performSwipeDelete()
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
    private func toggleFolderSelection(_ folder: Folder) {
        viewModel.toggleFolderSelection(folder)
        viewModel.selectedFolders = viewModel.selectedFolders
    }
    private func toggleFileSelection(_ file: VaultItem) {
        viewModel.toggleFileSelection(file)
        viewModel.selectedFiles = viewModel.selectedFiles
    }
    private func selectAllItems() {
        viewModel.selectAll()
        viewModel.selectedFolders = viewModel.selectedFolders
        viewModel.selectedFiles = viewModel.selectedFiles
    }
    private func moveSelectedItems(to destinationFolder: Folder?) {
        viewModel.selectedFolders = viewModel.selectedFolders
        viewModel.selectedFiles = viewModel.selectedFiles
        viewModel.moveSelectedItems(to: destinationFolder)
        exitSelectionMode()
    }
    private func deleteSelectedItems() {
        viewModel.selectedFolders = viewModel.selectedFolders
        viewModel.selectedFiles = viewModel.selectedFiles
        viewModel.deleteSelectedItems()
        exitSelectionMode()
    }

    // MARK: - File viewing & imports (unchanged from original)
    private func viewFile(_ file: VaultItem) {
        viewModel.viewFile(file)
    }
    
    private func shareSelectedFiles() {
        ShareManager.shared.shareVaultItems(Array(viewModel.selectedFiles)) {
            DispatchQueue.main.async {
                exitSelectionMode()
            }
        }
    }
    
    private func moveFile(_ file: VaultItem) {
        // Clear selections and add only this file
        viewModel.selectedFiles.removeAll()
        viewModel.selectedFolders.removeAll()
        viewModel.selectedFiles.insert(file)
        viewModel.showMoveSheet = true
    }
    
    private func moveFolder(_ folder: Folder) {
        // Clear selections and add only this folder
        viewModel.selectedFiles.removeAll()
        viewModel.selectedFolders.removeAll()
        viewModel.selectedFolders.insert(folder)
        viewModel.showMoveSheet = true
    }
    
    private func deleteFolder(_ folder: Folder) {
        // Check if trash is enabled
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            // Move to trash without confirmation
            CoreDataManager.shared.deleteFolder(folder)
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        } else {
            // Show confirmation alert by entering selection mode and triggering delete alert
            if !viewModel.isSelectionMode {
                viewModel.enterSelectionMode()
            }
            viewModel.selectedFolders = [folder]
            viewModel.showDeleteAlert = true
        }
    }
    
    private func importAssets(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }
        viewModel.showPhotoPicker = false
        viewModel.isImporting = true
        viewModel.importProgress = 0
        let totalItems = Double(results.count)
        var processedItems = 0.0
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    guard let uiImage = image as? UIImage else { updateProgress(); return }
                    guard let imageData = uiImage.jpegData(compressionQuality: 1.0) ?? uiImage.pngData() else { updateProgress(); return }
                    let fileName = "IMG_\(Date().timeIntervalSince1970).jpg"
                    do {
                        _ = try FileStorageManager.shared.saveFile(data: imageData,
                                                                   fileName: fileName,
                                                                   fileType: "image/jpeg",
                                                                   targetFolder: self.folder)
                    } catch { print("Error saving image: \(error)") }
                    updateProgress()
                }
            } else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url = url else { updateProgress(); return }
                    do {
                        let data = try Data(contentsOf: url)
                        let fileName = "VID_\(Date().timeIntervalSince1970).mov"
                        _ = try FileStorageManager.shared.saveFile(data: data,
                                                                   fileName: fileName,
                                                                   fileType: "video/quicktime",
                                                                   targetFolder: self.folder)
                    } catch { print("Error saving video: \(error)") }
                    updateProgress()
                }
            } else { updateProgress() }
        }
        func updateProgress() {
            DispatchQueue.main.async {
                processedItems += 1; viewModel.importProgress = processedItems / totalItems
                if processedItems == totalItems { self.viewModel.isImporting = false; self.viewModel.finishImportingAssets() }
            }
        }
    }
    private func importDocuments(_ dataArray: [(Data, String)]) {
        guard !dataArray.isEmpty else { return }
        viewModel.showDocumentPicker = false
        viewModel.isImporting = true; viewModel.importProgress = 0
        let totalItems = Double(dataArray.count)
        var processedItems = 0.0
        for (data, fileName) in dataArray {
            do {
                let fileType = FileStorageManager.shared.determineFileType(from: fileName)
                _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: fileType, targetFolder: folder)
            } catch { print("Error importing file \(fileName): \(error)") }
            processedItems += 1; viewModel.importProgress = processedItems / totalItems
        }
        viewModel.isImporting = false; viewModel.finishImportingAssets()
    }
    
    // MARK: - File Rename Functions
    private func startFileRename(for file: VaultItem) {
        guard let fileName = file.fileName else { return }
        fileToRename = file
        fileRenameText = getFileNameWithoutExtension(fileName)
        showFileRenameAlert = true
    }
    
    private func performFileRename() {
        guard let file = fileToRename, !fileRenameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelFileRename()
            return
        }
        
        guard let oldFileName = file.fileName else {
            cancelFileRename()
            return
        }
        
        // Preserve the original file extension
        let url = URL(fileURLWithPath: oldFileName)
        let fileExtension = url.pathExtension
        let newFileName = fileExtension.isEmpty ? fileRenameText : "\(fileRenameText.trimmingCharacters(in: .whitespacesAndNewlines)).\(fileExtension)"
        
        do {
            // Rename the physical file first
            try FileStorageManager.shared.renameFile(vaultItem: file, newFileName: newFileName)
            
            // Refresh the view
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            
            cancelFileRename()
        } catch {
            print("Error renaming file: \(error)")
            // Show error to user - for now just cancel
            cancelFileRename()
        }
    }
    
    private func cancelFileRename() {
        showFileRenameAlert = false
        fileToRename = nil
        fileRenameText = ""
    }
    
    private func getFileNameWithoutExtension(_ fileName: String) -> String {
        let url = URL(fileURLWithPath: fileName)
        return url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Set helper extension
extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}
