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

    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var showRenameFolder = false
    @State private var folderToRename: Folder? = nil
    @State private var renameText = ""
    @State private var showUnifiedMediaViewer = false
    @State private var mediaViewerIndex = -1
    @State private var showPhotoPicker = false
    @State private var showDocumentPicker = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var showSortActionSheet = false
    @State private var showAddActionSheet = false
    @State private var sortOption: FolderSortOption = .name
    @State private var sortAscending: Bool = true
    @State private var isSelectionMode = false
    @State private var selectedFolders: Set<Folder> = []
    @State private var selectedFiles: Set<VaultItem> = []
    @State private var showDeleteAlert = false
    @State private var showSwipeDeleteAlert = false
    @State private var showMoveSheet = false
    @State private var itemsToDelete: [Any] = []
    @StateObject private var loginStateManager = LoginStateManager.shared
    @Environment(\.managedObjectContext) var context

    // MARK: - Init
    init(folder: Folder?, navigationPath: Binding<NavigationPath>) {
        self.folder = folder
        self._navigationPath = navigationPath
        _viewModel = StateObject(wrappedValue: FolderViewModel(folder: folder))
    }

    private var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { showUnifiedMediaViewer && mediaViewerIndex > -1 },
            set: { newValue in
                if !newValue {
                    showUnifiedMediaViewer = false
                    mediaViewerIndex = -1
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
        switch sortOption {
        case .name:
            sorted = files.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .date:
            sorted = files.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .size:
            sorted = files.sorted { $0.fileSize < $1.fileSize }
        case .kind:
            sorted = files.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                if folder != nil {
                    breadcrumbView
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                        .background(Color(.systemGray6))
                }
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
                if isSelectionMode {
                    Button("Select All") {
                        selectAllItems()
                    }
                } else {
                    EmptyView()
                }
            }
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isSelectionMode {
                    if !selectedFolders.isEmpty || !selectedFiles.isEmpty {
                        Button(action: { showMoveSheet = true }) {
                            Image(systemName: "arrow.up.doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                        Button(action: { showDeleteAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    Button("Cancel") {
                        exitSelectionMode()
                    }
                } else {
                    if loginStateManager.canAddFiles {
                        Button(action: { showAddActionSheet = true }) {
                            Image(systemName: "plus")
                        }
                    }
                    Button(action: { showSortActionSheet = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    Button("Select") {
                        enterSelectionMode()
                    }
                    .disabled(folders.isEmpty && files.isEmpty)
                }
            }
        }


        .alert("Create Folder", isPresented: $showCreateFolder) {
            TextField("Folder Name", text: $newFolderName)
            Button("Cancel", role: .cancel) {
                newFolderName = ""
            }
            Button("Create") {
                createFolder()
            }
        } message: {
            Text("Enter a name for the new folder")
        }
        .alert("Rename Folder", isPresented: $showRenameFolder) {
            TextField("Folder Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                renameText = ""
                folderToRename = nil
            }
            Button("Rename") {
                renameFolder()
            }
        } message: {
            Text("Enter a new name for the folder")
        }
        .alert("Delete Items", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            let totalItems = selectedFolders.count + selectedFiles.count
            return Text("Are you sure you want to delete \(totalItems) item(s)? This action cannot be undone.")
        }
        .alert("Delete Items", isPresented: $showSwipeDeleteAlert) {
            Button("Cancel", role: .cancel) {
                itemsToDelete.removeAll()
            }
            Button("Delete", role: .destructive) {
                performSwipeDelete()
            }
        } message: {
            Text("Are you sure you want to delete \(itemsToDelete.count) item(s)? This action cannot be undone.")
        }
        .sheet(isPresented: $showPhotoPicker) {
            PhotoPickerView { results in
                importAssets(results)
            }
        }
        .sheet(isPresented: $showDocumentPicker) {
            DocumentPickerView { dataArray in
                importDocuments(dataArray)
            }
        }
        .sheet(isPresented: $showSortActionSheet) {
            FolderSortPopupView(
                currentSortOption: sortOption,
                sortAscending: sortAscending,
                onSortSelected: { option in
                    if option == sortOption {
                        sortAscending.toggle()
                    } else {
                        sortOption = option
                        sortAscending = true
                    }
                    showSortActionSheet = false
                }
            )
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showAddActionSheet) {
            FolderAddActionSheet(
                onAddPhotos: {
                    showAddActionSheet = false
                    showPhotoPicker = true
                },
                onAddFiles: {
                    showAddActionSheet = false
                    showDocumentPicker = true
                },
                onCreateFolder: {
                    showAddActionSheet = false
                    showCreateFolder = true
                }
            )
            .presentationDetents([.fraction(0.4)])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showMoveSheet) {
            FolderPickerView(
                selectedFolders: selectedFolders,
                selectedFiles: selectedFiles,
                currentFolder: folder,
                onMove: { destinationFolder in
                    moveSelectedItems(to: destinationFolder)
                    showMoveSheet = false
                }
            )
        }
        .fullScreenCover(isPresented: isMediaViewerPresented) {
            UnifiedMediaViewerView(
                mediaItems: sortedFiles,
                initialIndex: mediaViewerIndex
            )
        }
        .overlay(
            Group {
                if isImporting {
                    ImportProgressView(progress: importProgress)
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
        VStack(spacing: 20) {
            if loginStateManager.shouldShowEmptyVault {
                Image(systemName: "folder.badge.questionmark")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                Text("No Content")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text("This vault appears to be empty")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            } else {
                Image(systemName: folder == nil ? "folder.badge.plus" : "folder")
                    .font(.system(size: 80))
                    .foregroundColor(.gray)
                Text(folder == nil ? "No Folders Yet" : "Empty Folder")
                    .font(.title2)
                    .fontWeight(.semibold)
                Text(folder == nil ? "Create folders to organize your files" : "Add files or create subfolders to organize your content")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                if loginStateManager.canCreateFolders {
                    Button(action: { showCreateFolder = true }) {
                        Text("Create Folder")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: 200)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
            }
        }
    }

    private var folderContentView: some View {
        List {
            if !folders.isEmpty {
                Section("Folders") {
                    ForEach(sortedFolders) { folder in
                        SelectableFolderRowView(
                            folder: folder,
                            isSelected: selectedFolders.contains(folder),
                            isSelectionMode: isSelectionMode,
                            onTap: {
                                if isSelectionMode {
                                    toggleFolderSelection(folder)
                                } else {
                                    navigationPath.append(folder)
                                }
                            },
                            onRename: {
                                startRenaming(folder)
                            }
                        )
                        .background(
                            NavigationLink(value: folder, label: { EmptyView() })
                                .opacity(0)
                        )
                    }
                    .onDelete(perform: isSelectionMode ? nil : deleteFolders)
                }
            }
            if !files.isEmpty {
                Section("Files") {
                    ForEach(sortedFiles) { file in
                        SelectableFileRowView(
                            file: file,
                            isSelected: selectedFiles.contains(file),
                            isSelectionMode: isSelectionMode,
                            onTap: {
                                if isSelectionMode {
                                    toggleFileSelection(file)
                                } else {
                                    viewFile(file)
                                }
                            }
                        )
                    }
                    .onDelete(perform: isSelectionMode ? nil : deleteFiles)
                }
            }
        }
        .navigationDestination(for: Folder.self) { folder in
            FolderContentView(folder: folder, navigationPath: $navigationPath)
        }
    }

    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            newFolderName = ""; return }
        viewModel.createFolder(named: newFolderName)
        newFolderName = ""
    }
    private func startRenaming(_ folder: Folder) {
        folderToRename = folder; renameText = folder.displayName; showRenameFolder = true
    }
    private func renameFolder() {
        guard let folder = folderToRename,
              !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { renameText = ""; folderToRename = nil; return }
        viewModel.renameFolder(folder, to: renameText)
        renameText = ""; folderToRename = nil
    }
    private func deleteFolders(offsets: IndexSet) {
        itemsToDelete = offsets.map { sortedFolders[$0] }; showSwipeDeleteAlert = true
    }
    private func deleteFiles(offsets: IndexSet) {
        itemsToDelete = offsets.map { sortedFiles[$0] }; showSwipeDeleteAlert = true
    }
    private func performSwipeDelete() {
        viewModel.selectedFolders = Set(itemsToDelete.compactMap { $0 as? Folder })
        viewModel.selectedFiles   = Set(itemsToDelete.compactMap { $0 as? VaultItem })
        viewModel.deleteSelectedItems()
        itemsToDelete.removeAll()
    }
    private func enterSelectionMode() {
        isSelectionMode = true
        viewModel.enterSelectionMode()
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }
    private func exitSelectionMode() {
        isSelectionMode = false
        viewModel.exitSelectionMode()
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }
    private func toggleFolderSelection(_ folder: Folder) {
        viewModel.toggleFolderSelection(folder)
        selectedFolders = viewModel.selectedFolders
    }
    private func toggleFileSelection(_ file: VaultItem) {
        viewModel.toggleFileSelection(file)
        selectedFiles = viewModel.selectedFiles
    }
    private func selectAllItems() {
        viewModel.selectAll()
        selectedFolders = viewModel.selectedFolders
        selectedFiles = viewModel.selectedFiles
    }
    private func moveSelectedItems(to destinationFolder: Folder?) {
        viewModel.selectedFolders = selectedFolders
        viewModel.selectedFiles = selectedFiles
        viewModel.moveSelectedItems(to: destinationFolder)
        exitSelectionMode()
    }
    private func deleteSelectedItems() {
        viewModel.selectedFolders = selectedFolders
        viewModel.selectedFiles = selectedFiles
        viewModel.deleteSelectedItems()
        exitSelectionMode()
    }

    // MARK: - File viewing & imports (unchanged from original)
    private func viewFile(_ file: VaultItem) {
        if let index = sortedFiles.firstIndex(where: { $0.objectID == file.objectID }) {
            mediaViewerIndex = index; showUnifiedMediaViewer = true
        }
    }
    private func importAssets(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }
        showPhotoPicker = false
        isImporting = true
        importProgress = 0
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
                processedItems += 1; importProgress = processedItems / totalItems
                if processedItems == totalItems { self.isImporting = false; self.viewModel.finishImportingAssets() }
            }
        }
    }
    private func importDocuments(_ dataArray: [(Data, String)]) {
        guard !dataArray.isEmpty else { return }
        showDocumentPicker = false
        isImporting = true; importProgress = 0
        let totalItems = Double(dataArray.count)
        var processedItems = 0.0
        for (data, fileName) in dataArray {
            do {
                let fileType = FileStorageManager.shared.determineFileType(from: fileName)
                _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: fileType, targetFolder: folder)
            } catch { print("Error importing file \(fileName): \(error)") }
            processedItems += 1; importProgress = processedItems / totalItems
        }
        isImporting = false; viewModel.finishImportingAssets()
    }
}

// MARK: - Set helper extension
extension Set {
    mutating func toggle(_ element: Element) {
        if contains(element) { remove(element) } else { insert(element) }
    }
}
