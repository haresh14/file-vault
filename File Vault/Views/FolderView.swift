//
//  FolderView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI
import Photos

enum FolderSortOption: String, CaseIterable {
    case name = "Name"
    case date = "Date"
    case size = "Size"
    case kind = "Kind"
    
    var systemImage: String {
        switch self {
        case .name:
            return "textformat.abc"
        case .date:
            return "calendar"
        case .size:
            return "arrow.up.arrow.down"
        case .kind:
            return "folder"
        }
    }
}

struct FolderView: View {
    @State private var folders: [Folder] = []
    @State private var files: [VaultItem] = []
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var currentFolder: Folder? = nil
    @State private var showRenameFolder = false
    @State private var folderToRename: Folder? = nil
    @State private var renameText = ""
    @State private var showUnifiedMediaViewer = false
    @State private var mediaViewerIndex = 0
    @State private var showPhotoPicker = false
    @State private var isImporting = false
    @State private var importProgress: Double = 0
    @State private var showSortActionSheet = false
    @State private var showAddActionSheet = false
    @State private var showSettings = false
    @State private var sortOption: FolderSortOption = .name
    @State private var sortAscending: Bool = true
    @State private var isSelectionMode = false
    @State private var selectedFolders: Set<Folder> = []
    @State private var selectedFiles: Set<VaultItem> = []
    @State private var showDeleteAlert = false
    @State private var showSwipeDeleteAlert = false
    @State private var showMoveSheet = false
    @State private var itemsToDelete: [Any] = []
    
    @Environment(\.managedObjectContext) var context
    
    var sortedFolders: [Folder] {
        let sorted: [Folder]
        
        switch sortOption {
        case .name:
            sorted = folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .date:
            sorted = folders.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .size:
            sorted = folders.sorted { $0.totalItemCount < $1.totalItemCount }
        case .kind:
            // For folders, kind sorting is same as name since they're all folders
            sorted = folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
        
        return sortAscending ? sorted : sorted.reversed()
    }
    
    var sortedFiles: [VaultItem] {
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
        NavigationView {
            ZStack {
                VStack(spacing: 0) {
                    // Breadcrumb navigation
                    if currentFolder != nil {
                        breadcrumbView
                            .padding(.horizontal)
                            .padding(.vertical, 8)
                            .background(Color(.systemGray6))
                    }
                    
                    // Content
                    if folders.isEmpty && files.isEmpty {
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
            .navigationTitle(currentFolder?.displayName ?? "Folders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isSelectionMode {
                        Button("Select All") {
                            selectAllItems()
                        }
                    } else if currentFolder != nil {
                        Button(action: { navigateBack() }) {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("Back")
                            }
                        }
                    } else {
                        Button(action: { showSettings = true }) {
                            Image(systemName: "gear")
                        }
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
                        Button(action: { showAddActionSheet = true }) {
                            Image(systemName: "plus")
                        }
                        
                        Button(action: { showSortActionSheet = true }) {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        
                        if !folders.isEmpty || !files.isEmpty {
                            Button("Select") {
                                enterSelectionMode()
                            }
                        }
                    }
                }
            }
            .onAppear {
                loadFolders()
            }
            .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
                DispatchQueue.main.async {
                    loadFolders()
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
                PhotoPickerView { assets in
                    importAssets(assets)
                }
            }
            .sheet(isPresented: $showSortActionSheet) {
                FolderSortPopupView(
                    currentSortOption: sortOption,
                    sortAscending: sortAscending,
                    onSortSelected: { option in
                        if option == sortOption {
                            // Toggle sort direction if same option is selected
                            sortAscending.toggle()
                        } else {
                            // Set new sort option and default to ascending
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
                    onCreateFolder: {
                        showAddActionSheet = false
                        showCreateFolder = true
                    }
                )
                .presentationDetents([.fraction(0.3)])
                .presentationDragIndicator(.visible)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showMoveSheet) {
                FolderPickerView(
                    selectedFolders: selectedFolders,
                    selectedFiles: selectedFiles,
                    currentFolder: currentFolder,
                    onMove: { destinationFolder in
                        moveSelectedItems(to: destinationFolder)
                        showMoveSheet = false
                    }
                )
            }
            .fullScreenCover(isPresented: $showUnifiedMediaViewer) {
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
    }
    
    // MARK: - Views
    
    private var breadcrumbView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                // Home button
                Button(action: {
                    currentFolder = nil
                    loadFolders()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "house.fill")
                            .font(.caption)
                        Text("Home")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                }
                
                if let currentFolder = currentFolder {
                    let breadcrumbs = currentFolder.breadcrumbPath
                    
                    ForEach(Array(breadcrumbs.enumerated()), id: \.offset) { index, folder in
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Button(action: {
                                navigateToFolder(folder, fromBreadcrumb: true)
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
            Image(systemName: currentFolder == nil ? "folder.badge.plus" : "folder")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text(currentFolder == nil ? "No Folders Yet" : "Empty Folder")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(currentFolder == nil ? "Create folders to organize your files" : "Add files or create subfolders to organize your content")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
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
    
    private var folderContentView: some View {
        List {
            // Folders section
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
                                    navigateToFolder(folder)
                                }
                            },
                            onRename: {
                                startRenaming(folder)
                            }
                        )
                    }
                    .onDelete(perform: isSelectionMode ? nil : deleteFolders)
                }
            }
            
            // Files section
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
    }
    
    // MARK: - Functions
    
    private func loadFolders() {
        if let currentFolder = currentFolder {
            folders = currentFolder.subfoldersArray
            files = currentFolder.itemsArray
        } else {
            folders = CoreDataManager.shared.fetchRootFolders()
            files = CoreDataManager.shared.fetchVaultItems(in: nil)
        }
    }
    
    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            newFolderName = ""
            return
        }
        
        let _ = CoreDataManager.shared.createFolder(name: newFolderName, parent: currentFolder)
        newFolderName = ""
        loadFolders()
    }
    
    private func navigateToFolder(_ folder: Folder, fromBreadcrumb: Bool = false) {
        if fromBreadcrumb {
            // For breadcrumb navigation, always navigate to the clicked folder
            currentFolder = folder
        } else {
            currentFolder = folder
        }
        loadFolders()
    }
    
    private func navigateBack() {
        currentFolder = currentFolder?.parent
        loadFolders()
    }
    
    private func startRenaming(_ folder: Folder) {
        folderToRename = folder
        renameText = folder.displayName
        showRenameFolder = true
    }
    
    private func renameFolder() {
        guard let folder = folderToRename,
              !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            renameText = ""
            folderToRename = nil
            return
        }
        
        CoreDataManager.shared.updateFolder(folder, name: renameText)
        renameText = ""
        folderToRename = nil
        loadFolders()
    }
    
    private func deleteFolders(offsets: IndexSet) {
        itemsToDelete.removeAll()
        for index in offsets {
            let folder = sortedFolders[index]
            itemsToDelete.append(folder)
        }
        showSwipeDeleteAlert = true
    }
    
    private func deleteFiles(offsets: IndexSet) {
        itemsToDelete.removeAll()
        for index in offsets {
            let file = sortedFiles[index]
            itemsToDelete.append(file)
        }
        showSwipeDeleteAlert = true
    }
    
    private func performSwipeDelete() {
        for item in itemsToDelete {
            if let folder = item as? Folder {
                CoreDataManager.shared.deleteFolder(folder)
            } else if let file = item as? VaultItem {
                do {
                    try FileStorageManager.shared.deleteFile(vaultItem: file)
                } catch {
                    print("Error deleting file: \(error)")
                }
            }
        }
        itemsToDelete.removeAll()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
        loadFolders()
    }
    
    private func enterSelectionMode() {
        isSelectionMode = true
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }
    
    private func toggleFolderSelection(_ folder: Folder) {
        if selectedFolders.contains(folder) {
            selectedFolders.remove(folder)
        } else {
            selectedFolders.insert(folder)
        }
    }
    
    private func toggleFileSelection(_ file: VaultItem) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }
    
    private func selectAllItems() {
        selectedFolders = Set(folders)
        selectedFiles = Set(files)
    }
    
    private func moveSelectedItems(to destinationFolder: Folder?) {
        // Move selected folders
        for folder in selectedFolders {
            CoreDataManager.shared.moveFolder(folder, to: destinationFolder)
        }
        
        // Move selected files
        for file in selectedFiles {
            CoreDataManager.shared.moveVaultItem(file, to: destinationFolder)
        }
        
        exitSelectionMode()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
        loadFolders()
    }
    
    private func deleteSelectedItems() {
        // Delete selected folders
        for folder in selectedFolders {
            CoreDataManager.shared.deleteFolder(folder)
        }
        
        // Delete selected files
        for file in selectedFiles {
            do {
                try FileStorageManager.shared.deleteFile(vaultItem: file)
            } catch {
                print("Error deleting file: \(error)")
            }
        }
        
        exitSelectionMode()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
        loadFolders()
    }
    
    private func viewFile(_ file: VaultItem) {
        if let index = sortedFiles.firstIndex(where: { $0.objectID == file.objectID }) {
            mediaViewerIndex = index
            showUnifiedMediaViewer = true
        }
    }
    
    private func importAssets(_ assets: [PHAsset]) {
        guard !assets.isEmpty else { return }
        
        showPhotoPicker = false
        isImporting = true
        importProgress = 0
        
        let totalItems = Double(assets.count)
        var processedItems = 0.0
        
        for asset in assets {
            FileStorageManager.shared.importFromPhotoLibrary(asset: asset, targetFolder: currentFolder) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        // Asset imported successfully
                        break
                    case .failure(let error):
                        print("Error importing asset: \(error)")
                    }
                    
                    processedItems += 1
                    importProgress = processedItems / totalItems
                    
                    if processedItems == totalItems {
                        isImporting = false
                        loadFolders()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct FolderRowView: View {
    let folder: Folder
    let onTap: () -> Void
    let onRename: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.headline)
                
                Text("\(folder.totalItemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
        }
    }
}

struct SelectableFolderRowView: View {
    let folder: Folder
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.headline)
                
                Text("\(folder.totalItemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            if !isSelectionMode {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            if !isSelectionMode {
                Button(action: onRename) {
                    Label("Rename", systemImage: "pencil")
                }
            }
        }
    }
}

struct FileRowView: View {
    let file: VaultItem
    let onTap: () -> Void
    
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            Image(systemName: file.isVideo ? "video.fill" : "photo.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(file.fileType?.uppercased() ?? "FILE")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(file.isVideo ? Color.red : Color.blue)
                        .cornerRadius(4)
                    
                    Text(formatFileSize(file.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            if file.isVideo {
                Image(systemName: "play.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = FileStorageManager.shared.loadThumbnail(for: file)
            
            DispatchQueue.main.async {
                self.thumbnail = loadedThumbnail
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct SelectableFileRowView: View {
    let file: VaultItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    @State private var thumbnail: UIImage?
    
    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }
            
            // Thumbnail or icon
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Image(systemName: file.isImage ? "photo" : file.isVideo ? "video" : "doc")
                        .foregroundColor(file.isImage ? .blue : file.isVideo ? .purple : .orange)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)
                
                HStack {
                    Text(formatFileSize(file.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let createdAt = file.createdAt {
                        Text("• \(createdAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
            
            if file.isVideo {
                Image(systemName: "play.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onAppear {
            loadThumbnail()
        }
    }
    
    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = FileStorageManager.shared.loadThumbnail(for: file)
            
            DispatchQueue.main.async {
                self.thumbnail = loadedThumbnail
            }
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Folder Add Action Sheet

struct FolderAddActionSheet: View {
    let onAddPhotos: () -> Void
    let onCreateFolder: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Button(action: onAddPhotos) {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)
                            
                            Text("Add from Photos")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                    
                    Divider()
                        .padding(.leading, 60)
                    
                    Button(action: onCreateFolder) {
                        HStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)
                            
                            Text("Create Folder")
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.top, 4)
            }
            .navigationTitle("Add Content")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Folder Sort Popup View

struct FolderSortPopupView: View {
    let currentSortOption: FolderSortOption
    let sortAscending: Bool
    let onSortSelected: (FolderSortOption) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort options
                VStack(spacing: 0) {
                    ForEach(FolderSortOption.allCases, id: \.self) { option in
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)
                            
                            Text(option.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            if option == currentSortOption {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSortSelected(option)
                        }
                        
                        if option != FolderSortOption.allCases.last {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .navigationTitle("Sort by")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Folder Picker View

struct FolderPickerView: View {
    let selectedFolders: Set<Folder>
    let selectedFiles: Set<VaultItem>
    let currentFolder: Folder?
    let onMove: (Folder?) -> Void
    
    @State private var navigationPath: [Folder] = []
    @State private var currentLevelFolders: [Folder] = []
    @Environment(\.dismiss) private var dismiss
    
    var currentNavigationFolder: Folder? {
        navigationPath.last
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Breadcrumb navigation
                if !navigationPath.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            Button("Root") {
                                navigationPath.removeAll()
                                loadCurrentLevelFolders()
                            }
                            .foregroundColor(.blue)
                            
                            ForEach(Array(navigationPath.enumerated()), id: \.element.objectID) { index, folder in
                                HStack(spacing: 4) {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Button(folder.displayName) {
                                        navigationPath = Array(navigationPath.prefix(index + 1))
                                        loadCurrentLevelFolders()
                                    }
                                    .foregroundColor(.blue)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical, 8)
                    .background(Color(.systemGray6))
                }
                
                List {
                    // Move here button
                    Button(action: {
                        onMove(currentNavigationFolder)
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "arrow.down.doc.fill")
                                .foregroundColor(.white)
                                .font(.title3)
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Move Here")
                                    .foregroundColor(.white)
                                    .fontWeight(.semibold)
                                    .font(.body)
                                
                                Text(currentNavigationFolder?.displayName ?? "Root Folder")
                                    .foregroundColor(.white.opacity(0.8))
                                    .font(.caption)
                            }
                            
                            Spacer()
                            
                            if currentNavigationFolder == currentFolder {
                                Text("Current")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.white.opacity(0.2))
                                    .cornerRadius(6)
                            }
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(currentNavigationFolder == currentFolder ? Color.gray : Color.green)
                        .cornerRadius(12)
                    }
                    .disabled(currentNavigationFolder == currentFolder)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    
                    // Folders in current level
                    ForEach(currentLevelFolders, id: \.objectID) { folder in
                        Button(action: {
                            // Always navigate into folder, never move directly
                            navigationPath.append(folder)
                            loadCurrentLevelFolders()
                        }) {
                            HStack {
                                Image(systemName: "folder.fill")
                                    .foregroundColor(.blue)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(folder.displayName)
                                        .foregroundColor(.primary)
                                        .font(.body)
                                    
                                    Text("\(folder.totalItemCount) items")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                Spacer()
                                
                                if folder == currentFolder {
                                    Text("Current")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .background(Color.secondary.opacity(0.2))
                                        .cornerRadius(6)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .disabled(selectedFolders.contains(folder) || isDescendantOfSelectedFolder(folder))
                        .contextMenu {
                            Button("Move Here") {
                                onMove(folder)
                                dismiss()
                            }
                            .disabled(folder == currentFolder || selectedFolders.contains(folder) || isDescendantOfSelectedFolder(folder))
                        }
                    }
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentLevelFolders()
            }
        }
    }
    
    private func loadCurrentLevelFolders() {
        if let currentNavFolder = currentNavigationFolder {
            currentLevelFolders = currentNavFolder.subfoldersArray.sorted { $0.displayName < $1.displayName }
        } else {
            currentLevelFolders = CoreDataManager.shared.fetchRootFolders().sorted { $0.displayName < $1.displayName }
        }
    }
    
    private func isDescendantOfSelectedFolder(_ folder: Folder) -> Bool {
        for selectedFolder in selectedFolders {
            if isFolder(selectedFolder, ancestorOf: folder) {
                return true
            }
        }
        return false
    }
    
    private func isFolder(_ potentialAncestor: Folder, ancestorOf folder: Folder) -> Bool {
        var current: Folder? = folder.parent
        while let currentFolder = current {
            if currentFolder == potentialAncestor {
                return true
            }
            current = currentFolder.parent
        }
        return false
    }
}

#Preview {
    FolderView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 