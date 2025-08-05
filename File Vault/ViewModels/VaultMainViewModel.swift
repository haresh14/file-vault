//
//  VaultMainViewModel.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine
import PhotosUI
import CoreData

/// ViewModel for VaultMainView following MVVM architecture and protocol-oriented design
final class VaultMainViewModel: ObservableObject, SelectionManageable, ImportManageable, MediaViewerManageable, SearchManageable {
    // MARK: - Published Properties
    
    // Data
    @Published private(set) var vaultItems: [VaultItem] = []
    @Published var searchText: String = ""
    @Published var sortOption: SortOption = .userDefault
    @Published var sortAscending: Bool = true
    
    // Selection Management (from SelectionManageable)
    @Published var isSelectionMode: Bool = false
    @Published var selectedItems: Set<VaultItem> = []
    @Published private(set) var hasTriggeredSelectionHaptic: Bool = false
    
    // Import Management (from ImportManageable)
    @Published var isImporting: Bool = false
    @Published var importProgress: Double = 0
    
    // Media Viewer Management (from MediaViewerManageable)
    @Published var showUnifiedMediaViewer: Bool = false
    @Published var mediaViewerIndex: Int = -1
    
    // File Preview Management
    @Published var showFilePreview: Bool = false
    @Published var filePreviewItem: VaultItem?
    
    // Sheet and Alert States
    @Published var showPhotoPicker: Bool = false
    @Published var showDocumentPicker: Bool = false
    @Published var showDeleteAlert: Bool = false
    @Published var showMoveSheet: Bool = false
    @Published var showWebUpload: Bool = false
    @Published var showSortActionSheet: Bool = false
    @Published var showAddActionSheet: Bool = false
    
    // MARK: - Dependencies
    private let coreDataManager: CoreDataManaging
    private let fileStorageManager: FileStorageManaging
    private let loginStateManager: any LoginStateManaging
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    
    /// Filtered and sorted vault items based on search and sort criteria
    var filteredItems: [VaultItem] {
        let items = searchText.isEmpty ? vaultItems : vaultItems.filter { item in
            item.fileName?.localizedCaseInsensitiveContains(searchText) ?? false
        }
        return sortItems(items)
    }
    
    /// Filtered images for media viewer
    var filteredImages: [VaultItem] {
        if loginStateManager.shouldShowEmptyVault {
            return []
        }
        return filteredItems.filter { $0.isImage }
    }
    
    /// Selection count for UI display
    var selectionCount: Int {
        selectedItems.count
    }
    
    /// Whether any items are selected
    var hasSelection: Bool {
        !selectedItems.isEmpty
    }
    
    // MARK: - Initialization
    
    init(
        coreDataManager: CoreDataManaging = CoreDataManager.shared,
        fileStorageManager: FileStorageManaging = FileStorageManager.shared,
        loginStateManager: any LoginStateManaging = LoginStateManager.shared
    ) {
        self.coreDataManager = coreDataManager
        self.fileStorageManager = fileStorageManager
        self.loginStateManager = loginStateManager
        
        setupBindings()
        loadVaultItems()
    }
    
    /// Convenience initializer using dependency container
    convenience init(dependencies: DependencyContainer) {
        self.init(
            coreDataManager: dependencies.coreDataManager,
            fileStorageManager: dependencies.fileStorageManager,
            loginStateManager: dependencies.loginStateManager
        )
    }
    
    deinit {
        cancellables.forEach { $0.cancel() }
    }
    
    // MARK: - Setup
    
    private func setupBindings() {
        // Reload when Core Data saves
        NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.loadVaultItems()
                }
            }
            .store(in: &cancellables)
        
        // Reload when refresh notification is posted
        NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.loadVaultItems()
                }
            }
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
    
    // MARK: - Data Management
    
    /// Load vault items from Core Data
    func loadVaultItems() {
        // Show empty gallery during fake login for security
        guard !loginStateManager.shouldShowEmptyVault else {
            vaultItems = []
            return
        }
        
        let allItems = coreDataManager.fetchVaultItemsFromAllFolders()
        // Filter to only show photos and videos in the Gallery
        vaultItems = allItems.filter { $0.isImage || $0.isVideo }
    }
    
    /// Sort items based on current sort option and direction
    private func sortItems(_ items: [VaultItem]) -> [VaultItem] {
        let sorted: [VaultItem]
        
        switch sortOption {
        case .userDefault:
            sorted = items.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .name:
            sorted = items.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .size:
            sorted = items.sorted { $0.fileSize < $1.fileSize }
        case .date:
            sorted = items.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .favorites:
            sorted = items.sorted { ($0.isFavorite && !$1.isFavorite) || ($0.isFavorite == $1.isFavorite && ($0.fileName ?? "") < ($1.fileName ?? "")) }
        case .kind:
            sorted = items.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        
        return sortAscending ? sorted : sorted.reversed()
    }
    
    // MARK: - Selection Management (SelectionManageable Implementation)
    
    typealias SelectableItem = VaultItem
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
        hasTriggeredSelectionHaptic = false
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
        hasTriggeredSelectionHaptic = false
    }
    
    func selectAll(from items: [VaultItem]) {
        selectedItems = Set(items)
    }
    
    func triggerSelectionHaptic() {
        if !hasTriggeredSelectionHaptic {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            hasTriggeredSelectionHaptic = true
        }
    }
    
    // MARK: - Import Management (ImportManageable Implementation)
    
    func importAssets(_ results: [PHPickerResult]) {
        guard !results.isEmpty else { return }
        
        showPhotoPicker = false
        startImport()
        
        let totalItems = Double(results.count)
        let processedItemsQueue = DispatchQueue(label: "importProgress", attributes: .concurrent)
        let processedItemsGroup = DispatchGroup()
        var processedCount = 0.0
        
        for result in results {
            processedItemsGroup.enter()
            
            // Handle images
            if result.itemProvider.canLoadObject(ofClass: UIImage.self) {
                result.itemProvider.loadObject(ofClass: UIImage.self) { [weak self] image, error in
                    defer { processedItemsGroup.leave() }
                    
                    self?.processImageImport(image: image) { success in
                        processedItemsQueue.async(flags: .barrier) {
                            processedCount += 1
                            DispatchQueue.main.async { [weak self] in
                                self?.updateProgress(completed: processedCount, total: totalItems)
                            }
                        }
                    }
                }
            }
            // Handle videos
            else if result.itemProvider.hasItemConformingToTypeIdentifier("public.movie") {
                result.itemProvider.loadFileRepresentation(forTypeIdentifier: "public.movie") { [weak self] url, error in
                    defer { processedItemsGroup.leave() }
                    
                    self?.processVideoImport(url: url) { success in
                        processedItemsQueue.async(flags: .barrier) {
                            processedCount += 1
                            DispatchQueue.main.async { [weak self] in
                                self?.updateProgress(completed: processedCount, total: totalItems)
                            }
                        }
                    }
                }
            } else {
                processedItemsQueue.async(flags: .barrier) {
                    processedCount += 1
                    DispatchQueue.main.async { [weak self] in
                        self?.updateProgress(completed: processedCount, total: totalItems)
                    }
                }
                processedItemsGroup.leave()
            }
        }
        
        processedItemsGroup.notify(queue: .main) { [weak self] in
            self?.finishImportWithDataReload()
        }
    }
    
    func importDocuments(_ dataArray: [(Data, String)]) {
        guard !dataArray.isEmpty else { return }
        
        showDocumentPicker = false
        startImport()
        
        let totalItems = Double(dataArray.count)
        var processedItems = 0.0
        
        for (data, fileName) in dataArray {
            do {
                let fileType = fileStorageManager.determineFileType(from: fileName)
                _ = try fileStorageManager.saveFile(
                    data: data,
                    fileName: fileName,
                    fileType: fileType,
                    targetFolder: nil
                )
                
                print("Successfully imported file: \(fileName)")
            } catch FileStorageError.duplicateFile {
                print("Skipped duplicate file: \(fileName)")
            } catch {
                print("Error importing file \(fileName): \(error)")
            }
            
            DispatchQueue.main.async { [weak self] in
                processedItems += 1
                self?.updateProgress(completed: processedItems, total: totalItems)
                
                if processedItems == totalItems {
                    self?.finishImportWithDataReload()
                }
            }
        }
    }
    
    // MARK: - Import Helper Methods
    
    private func processImageImport(image: Any?, completion: @escaping (Bool) -> Void) {
        guard let uiImage = image as? UIImage else {
            completion(false)
            return
        }
        
        guard let imageData = uiImage.jpegData(compressionQuality: 1.0) ?? uiImage.pngData() else {
            completion(false)
            return
        }
        
        let fileName = "Photo.jpg" // Will be resolved to unique name by FileStorageManager
        let fileType = "image/jpeg"
        
        do {
            _ = try fileStorageManager.saveFile(
                data: imageData,
                fileName: fileName,
                fileType: fileType,
                targetFolder: nil
            )
            completion(true)
        } catch FileStorageError.duplicateFile {
            print("Skipped duplicate image")
            completion(true) // Count as successful since we're skipping duplicates
        } catch {
            print("Error saving image: \(error)")
            completion(false)
        }
    }
    
    private func processVideoImport(url: URL?, completion: @escaping (Bool) -> Void) {
        guard let url = url else {
            completion(false)
            return
        }
        
        do {
            let data = try Data(contentsOf: url)
            let fileName = "Video.mov" // Will be resolved to unique name by FileStorageManager
            
            _ = try fileStorageManager.saveFile(
                data: data,
                fileName: fileName,
                fileType: "video/quicktime",
                targetFolder: nil
            )
            completion(true)
        } catch FileStorageError.duplicateFile {
            print("Skipped duplicate video")
            completion(true) // Count as successful since we're skipping duplicates
        } catch {
            print("Error saving video: \(error)")
            completion(false)
        }
    }
    
    func finishImportWithDataReload() {
        finishImport()
        loadVaultItems()
    }
    
    // MARK: - Item Actions
    
    /// View a specific item (show in media viewer or file preview)
    func viewItem(_ item: VaultItem) {
        if item.isImage || item.isVideo {
            // Show unified viewer for images and videos only
            showMediaViewerForItem(item)
        } else {
            // Show file preview for documents, audio, and other files
            showFilePreview(for: item)
        }
    }
    
    /// Get media files (images and videos only) from filtered items
    func getMediaFiles() -> [VaultItem] {
        return filteredItems.filter { item in
            item.isImage || item.isVideo
        }
    }
    
    /// Show media viewer for a specific media item
    func showMediaViewerForItem(_ item: VaultItem) {
        let mediaFiles = getMediaFiles()
        if let index = mediaFiles.firstIndex(where: { $0.objectID == item.objectID }) {
            showMediaViewer(at: index)
        }
    }
    
    /// Show file preview for non-media files
    func showFilePreview(for item: VaultItem) {
        filePreviewItem = item
        showFilePreview = true
    }
    
    /// Move selected items to destination folder
    func moveSelectedItems(to destinationFolder: Folder?) {
        for item in selectedItems {
            coreDataManager.moveVaultItem(item, to: destinationFolder)
        }
        
        exitSelectionMode()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
        loadVaultItems()
    }
    
    /// Delete selected items
    func deleteSelectedItems() {
        for item in selectedItems {
            do {
                try fileStorageManager.deleteFile(vaultItem: item)
            } catch {
                print("Error deleting item: \(error)")
            }
        }
        
        exitSelectionMode()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
        loadVaultItems()
    }
    
    // MARK: - Sort Management
    
    /// Handle sort option selection with direction toggle
    func handleSortSelection(_ option: SortOption) {
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
    
    // MARK: - Sheet Management
    
    /// Show add action sheet
    func showAddActions() {
        showAddActionSheet = true
    }
    
    /// Handle add photos action
    func handleAddPhotos() {
        showAddActionSheet = false
        showPhotoPicker = true
    }
    
    /// Handle add files action
    func handleAddFiles() {
        showAddActionSheet = false
        showDocumentPicker = true
    }
    
    /// Handle web upload action
    func handleWebUpload() {
        showAddActionSheet = false
        showWebUpload = true
    }
    
    // MARK: - SearchManageable Implementation
    
    typealias SearchableItem = VaultItem
    
    var allItems: [VaultItem] { vaultItems }
    
    func matches(item: VaultItem, searchText: String) -> Bool {
        item.fileName?.localizedCaseInsensitiveContains(searchText) ?? false
    }
    
    // MARK: - Favorites Management
    
    func toggleFavorite(for item: VaultItem) {
        fileStorageManager.toggleFavorite(for: item)
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        
        loadVaultItems()
    }
    
    // MARK: - Share Management
    
    func shareItem(_ item: VaultItem) {
        ShareManager.shared.shareVaultItem(item)
    }
    
    func toggleFavoriteSelectedItems() {
        for item in selectedItems {
            FileStorageManager.shared.toggleFavorite(for: item)
        }
        exitSelectionMode()
        loadVaultItems()
    }
    
    func shareSelectedItems() {
        // Share all selected items at once
        ShareManager.shared.shareVaultItems(Array(selectedItems)) { [weak self] in
            DispatchQueue.main.async {
                self?.exitSelectionMode()
            }
        }
    }
    
    // MARK: - Single Item Move
    
    func moveItem(_ item: VaultItem) {
        // Clear selection and add only this item
        selectedItems.removeAll()
        selectedItems.insert(item)
        showMoveSheet = true
    }
    
    // MARK: - Single Item Delete
    
    func deleteItem(_ item: VaultItem) {
        // Check if trash is enabled
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            // Move to trash without confirmation
            try? fileStorageManager.deleteFile(vaultItem: item)
            loadVaultItems()
        } else {
            // Show confirmation alert (implement via delegate pattern or notifications)
            selectedItems = [item]
            showDeleteAlert = true
        }
    }

    // MARK: - Helper Methods
}