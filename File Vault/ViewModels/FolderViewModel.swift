import Foundation
import Combine
import SwiftUI
import Photos
import PhotosUI
import UniformTypeIdentifiers

/// View-model backing FolderContentView, responsible for loading folders & files,
/// sorting, selection, CRUD, and import operations.
final class FolderViewModel: ObservableObject, SelectionManageable, ImportManageable, MediaViewerManageable, AlertManageable {
    // MARK: - Published State
    @Published private(set) var folders: [Folder] = []
    @Published private(set) var files: [VaultItem] = []

    // Sorting
    @Published var sortOption: FolderSortOption = .userDefault
    @Published var sortAscending: Bool = true
    
    // Selection Management (SelectionManageable Implementation)
    @Published var isSelectionMode: Bool = false
    @Published var selectedFolders: Set<Folder> = []
    @Published var selectedFiles: Set<VaultItem> = []
    
    // Import Management (ImportManageable Implementation)
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0
    @Published var showPhotoPicker = false
    @Published var showDocumentPicker = false
    
    // Media Viewer Management (MediaViewerManageable Implementation)
    @Published var showUnifiedMediaViewer = false
    @Published var mediaViewerIndex = -1
    
    // File Preview Management
    @Published var showFilePreview = false
    @Published var filePreviewItem: VaultItem?
    
    // Sheet/Alert Presentation
    @Published var showCreateFolder = false
    @Published var showRenameFolder = false
    @Published var showSortActionSheet = false
    @Published var showAddActionSheet = false
    @Published var showDeleteAlert = false
    @Published var showSwipeDeleteAlert = false
    @Published var showMoveSheet = false
    
    // Text Input State
    @Published var newFolderName = ""
    @Published var renameText = ""
    
    // Current Item State
    @Published var folderToRename: Folder? = nil
    @Published var itemsToDelete: [Any] = []
    
    // Alert Management (AlertManageable Implementation)
    @Published var currentAlert: AlertType?
    @Published var isShowingAlert: Bool = false

    // MARK: - Dependencies
    private let folder: Folder?
    private let loginStateManager: any LoginStateManaging
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Total number of selected items
    var selectionCount: Int {
        selectedFolders.count + selectedFiles.count
    }
    
    /// Whether there are any selected items
    var hasSelectedItems: Bool {
        !selectedFolders.isEmpty || !selectedFiles.isEmpty
    }
    
    /// Binding for media viewer presentation
    var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { [weak self] in 
                guard let self = self else { return false }
                return self.showUnifiedMediaViewer && self.mediaViewerIndex > -1 
            },
            set: { [weak self] newValue in
                guard let self = self else { return }
                if !newValue {
                    self.showUnifiedMediaViewer = false
                    self.mediaViewerIndex = -1
                }
            }
        )
    }

    init(folder: Folder?, loginStateManager: any LoginStateManaging = LoginStateManager.shared) {
        self.folder = folder
        self.loginStateManager = loginStateManager
        loadContent()

        // reload when Core Data saves
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in self?.loadContent() }
            .store(in: &cancellables)
        
        // Reset selection mode when tab changes
        NotificationCenter.default.publisher(for: Notification.Name("TabDidChange"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    if self?.isSelectionMode == true {
                        self?.exitSelectionMode()
                    }
                }
            }
            .store(in: &cancellables)
    }

    deinit { cancellables.forEach { $0.cancel() } }

    // MARK: - Derived Collections
    var sortedFolders: [Folder] {
        sort(folders: folders)
    }
    var sortedFiles: [VaultItem] {
        sort(files: files)
    }

    // MARK: - Public API
    func toggleFolderSelection(_ folder: Folder) {
        if selectedFolders.contains(folder) {
            selectedFolders.remove(folder)
        } else {
            selectedFolders.insert(folder)
        }
    }

    func toggleFileSelection(_ file: VaultItem) {
        if selectedFiles.contains(file) {
            selectedFiles.remove(file)
        } else {
            selectedFiles.insert(file)
        }
    }

    func enterSelectionMode() {
        isSelectionMode = true
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedFolders.removeAll()
        selectedFiles.removeAll()
    }

    func selectAll() {
        selectedFolders = Set(folders)
        selectedFiles = Set(files)
    }

    func moveSelectedItems(to destination: Folder?) {
        for folder in selectedFolders {
            CoreDataManager.shared.moveFolder(folder, to: destination)
        }
        for file in selectedFiles {
            CoreDataManager.shared.moveVaultItem(file, to: destination)
        }
        exitSelectionMode()
        notifyRefresh()
    }

    func deleteSelectedItems() {
        for folder in selectedFolders {
            CoreDataManager.shared.deleteFolderCompletely(folder)
        }
        for file in selectedFiles {
            try? FileStorageManager.shared.deleteFile(vaultItem: file)
        }
        exitSelectionMode()
        notifyRefresh()
    }

    func createFolder(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showError(message: "Folder name cannot be empty", recovery: nil)
            return
        }
        
        // Check for duplicate names
        let existingNames = folders.compactMap { $0.name?.lowercased() }
        if existingNames.contains(trimmedName.lowercased()) {
            showError(message: "A folder with this name already exists", recovery: nil)
            return
        }
        
        do {
            _ = CoreDataManager.shared.createFolder(name: trimmedName, parent: folder)
            loadContent()
            newFolderName = "" // Clear input
        } catch {
            showError(message: "Failed to create folder: \(error.localizedDescription)", recovery: nil)
        }
    }

    func renameFolder(_ folder: Folder, to newName: String) {
        let trimmedName = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            showError(message: "Folder name cannot be empty", recovery: nil)
            return
        }
        
        // Check for duplicate names (excluding current folder)
        let existingNames = folders.compactMap { $0.name?.lowercased() }.filter { $0 != folder.name?.lowercased() }
        if existingNames.contains(trimmedName.lowercased()) {
            showError(message: "A folder with this name already exists", recovery: nil)
            return
        }
        
        do {
            CoreDataManager.shared.updateFolder(folder, name: trimmedName)
            loadContent()
            renameText = "" // Clear input
            folderToRename = nil
        } catch {
            showError(message: "Failed to rename folder: \(error.localizedDescription)", recovery: nil)
        }
    }

    // MARK: - Imports
    func importDocuments(_ dataArray: [(Data, String)]) {
        guard !dataArray.isEmpty else { return }
        isImporting = true; importProgress = 0
        let total = Double(dataArray.count)
        var processed = 0.0
        for (data, fileName) in dataArray {
            do {
                let fileType = FileStorageManager.shared.determineFileType(from: fileName)
                _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: fileType, targetFolder: folder)
                print("Successfully imported file: \(fileName)")
            } catch FileStorageError.duplicateFile {
                print("Skipped duplicate file: \(fileName)")
            } catch {
                print("Error importing file \(fileName): \(error)")
            }
            processed += 1
            importProgress = processed / total
        }
        isImporting = false
        loadContent()
    }

    func importAssets(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }
        isImporting = true
        importProgress = 0
        let total = Double(results.count)
        var processed = 0.0
        for result in results {
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { image, _ in
                    guard let uiImage = image as? UIImage else { updateProgress(); return }
                    guard let data = uiImage.jpegData(compressionQuality: 1.0) ?? uiImage.pngData() else { updateProgress(); return }
                    let fileName = "Photo.jpg" // Will be resolved to unique name by FileStorageManager
                    do {
                        _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: "image/jpeg", targetFolder: self.folder)
                    } catch { print("Error saving image: \(error)") }
                    updateProgress()
                }
            } else if result.itemProvider.hasItemConformingToTypeIdentifier(UTType.movie.identifier) {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: UTType.movie.identifier) { url, _ in
                    guard let url = url else { updateProgress(); return }
                    do {
                        let data = try Data(contentsOf: url)
                        let fileName = "Video.mov" // Will be resolved to unique name by FileStorageManager
                        _ = try FileStorageManager.shared.saveFile(data: data, fileName: fileName, fileType: "video/quicktime", targetFolder: self.folder)
                    } catch { print("Error saving video: \(error)") }
                    updateProgress()
                }
            } else { updateProgress() }
        }
        func updateProgress() {
            DispatchQueue.main.async {
                processed += 1
                self.importProgress = processed / total
                if processed == total { self.isImporting = false; self.loadContent() }
            }
        }
    }

    // Remove or adjust finishImportingAssets if no longer needed
    func finishImportingAssets() {
        isImporting = false
        loadContent()
    }

    // MARK: - Helpers
    private func notifyRefresh() {
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        loadContent()
    }

    private func loadContent() {
        // Show empty folder content during fake login for security
        guard !loginStateManager.shouldShowEmptyVault else {
            folders = []
            files = []
            return
        }
        
        if let folder = folder {
            folders = folder.subfoldersArray
            files = folder.itemsArray
        } else {
            folders = CoreDataManager.shared.fetchRootFolders()
            files = CoreDataManager.shared.fetchVaultItems(in: nil)
        }
    }

    private func sort(folders: [Folder]) -> [Folder] {
        let sorted: [Folder]
        switch sortOption {
        case .userDefault:
            sorted = folders.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .name:
            sorted = folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        case .date:
            sorted = folders.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .size:
            sorted = folders.sorted { $0.totalItemCount < $1.totalItemCount }
        case .kind:
            sorted = folders.sorted { ($0.name ?? "") < ($1.name ?? "") }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    private func sort(files: [VaultItem]) -> [VaultItem] {
        let sorted: [VaultItem]
        switch sortOption {
        case .userDefault:
            sorted = files.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .name:
            sorted = files.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .date:
            sorted = files.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .size:
            sorted = files.sorted { $0.fileSize < $1.fileSize }
        case .kind:
            sorted = files.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        return sortAscending ? sorted : sorted.reversed()
    }
    
    // MARK: - Protocol Implementations
    
    // MARK: SelectionManageable Protocol Support
    var selectedItems: Set<AnyHashable> {
        get {
            let folderSet = Set(selectedFolders.map { AnyHashable($0) })
            let fileSet = Set(selectedFiles.map { AnyHashable($0) })
            return folderSet.union(fileSet)
        }
        set {
            // Extract folders and files from the set
            selectedFolders = Set(newValue.compactMap { $0.base as? Folder })
            selectedFiles = Set(newValue.compactMap { $0.base as? VaultItem })
        }
    }
    
    func toggleSelection(for item: AnyHashable) {
        if let folder = item.base as? Folder {
            if selectedFolders.contains(folder) {
                selectedFolders.remove(folder)
            } else {
                selectedFolders.insert(folder)
            }
        } else if let file = item.base as? VaultItem {
            if selectedFiles.contains(file) {
                selectedFiles.remove(file)
            } else {
                selectedFiles.insert(file)
            }
        }
    }
    
    func selectAll(from items: [AnyHashable]) {
        for item in items {
            if let folder = item.base as? Folder {
                selectedFolders.insert(folder)
            } else if let file = item.base as? VaultItem {
                selectedFiles.insert(file)
            }
        }
    }
    
    func isSelected(_ item: AnyHashable) -> Bool {
        if let folder = item.base as? Folder {
            return selectedFolders.contains(folder)
        } else if let file = item.base as? VaultItem {
            return selectedFiles.contains(file)
        }
        return false
    }
    
    // MARK: ImportManageable Protocol Support
    func startImport() {
        isImporting = true
        importProgress = 0.0
    }
    
    func finishImport() {
        isImporting = false
        importProgress = 0.0
    }
    
    func updateProgress(completed: Double, total: Double) {
        importProgress = completed / total
    }
    
    // MARK: MediaViewerManageable Protocol Support
    func showMediaViewer(at index: Int) {
        mediaViewerIndex = index
        showUnifiedMediaViewer = true
    }
    
    func hideMediaViewer() {
        showUnifiedMediaViewer = false
        mediaViewerIndex = -1
    }
    
    func shouldPresentMediaViewer() -> Bool {
        return showUnifiedMediaViewer && mediaViewerIndex > -1
    }
    
    // MARK: - Enhanced Action Methods
    
    /// Start renaming a folder with pre-filled text
    func startRenaming(_ folder: Folder) {
        folderToRename = folder
        renameText = folder.displayName
        showRenameFolder = true
    }
    
    /// Prepare deletion alert for selected items
    func prepareDeleteAlert() {
        let totalCount = selectionCount
        let itemType = totalCount == 1 ? 
            (selectedFolders.isEmpty ? "file" : "folder") : "items"
        
        showDeleteConfirmation(
            itemCount: totalCount,
            itemType: itemType,
            onConfirm: { [weak self] in
                self?.deleteSelectedItems()
            }
        )
    }
    
    /// Prepare swipe delete alert for specific items
    func prepareSwipeDeleteAlert(for items: [Any]) {
        itemsToDelete = items
        
        // Check if trash is enabled
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            // If trash is enabled, delete directly without confirmation
            performSwipeDelete()
        } else {
            // If trash is disabled, show confirmation alert
            showSwipeDeleteAlert = true
        }
    }
    
    /// Perform swipe delete operation
    func performSwipeDelete() {
        for item in itemsToDelete {
            if let folder = item as? Folder {
                CoreDataManager.shared.deleteFolderCompletely(folder)
            } else if let file = item as? VaultItem {
                try? FileStorageManager.shared.deleteFile(vaultItem: file)
            }
        }
        itemsToDelete.removeAll()
        notifyRefresh()
    }
    
    /// Toggle sort direction
    func toggleSortDirection() {
        sortAscending.toggle()
    }
    
    /// Update sort option and reset direction to ascending
    func updateSortOption(_ option: FolderSortOption) {
        sortOption = option
        sortAscending = true
    }
    
    /// Get files suitable for media viewer (using sorted files to match UI order)
    func getMediaFiles() -> [VaultItem] {
        sortedFiles.filter { item in
            item.isImage || item.isVideo
        }
    }
    
    /// Show media viewer for a specific file
    func showMediaViewerForFile(_ file: VaultItem) {
        let mediaFiles = getMediaFiles()
        if let index = mediaFiles.firstIndex(where: { $0.objectID == file.objectID }) {
            showMediaViewer(at: index)
        }
    }
    
    /// View a file - show media viewer for images/videos, file preview for others
    func viewFile(_ file: VaultItem) {
        if file.isImage || file.isVideo {
            showMediaViewerForFile(file)
        } else {
            showFilePreview(for: file)
        }
    }
    
    /// Show file preview for non-media files
    func showFilePreview(for item: VaultItem) {
        filePreviewItem = item
        showFilePreview = true
    }
    
    /// Get current folder path for navigation
    var folderPath: String {
        folder?.breadcrumbPath.map { $0.displayName }.joined(separator: " > ") ?? "Root"
    }
    
    /// Check if current folder is root
    var isRootFolder: Bool {
        folder == nil
    }
    
    /// Get folder breadcrumbs for navigation
    var breadcrumbs: [Folder] {
        folder?.breadcrumbPath ?? []
    }
    
    // MARK: - Helper Methods
} 