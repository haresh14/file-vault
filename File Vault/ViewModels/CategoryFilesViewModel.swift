import Foundation
import Combine
import SwiftUI

/// View model that powers `CategoryFilesView`, encapsulating loading, sorting,
/// selection, move and delete logic so the SwiftUI view can remain purely
/// declarative.
final class CategoryFilesViewModel: ObservableObject {
    // MARK: - Published State
    @Published private(set) var items: [VaultItem] = []
    @Published var sortOption: SortOption = .date
    @Published var sortAscending: Bool = false
    @Published var isSelectionMode: Bool = false
    
    // MARK: - Haptic Feedback State
    private var hasTriggeredSelectionHaptic: Bool = false
    @Published var selectedItems: Set<VaultItem> = []
    
    // Media Viewer Management
    @Published var showUnifiedMediaViewer = false
    @Published var mediaViewerIndex = -1
    
    // File Preview Management
    @Published var showFilePreview = false
    @Published var filePreviewItem: VaultItem?

    // MARK: - Computed
    /// Items sorted according to the currently chosen sort option and order.
    var sortedItems: [VaultItem] {
        let sorted: [VaultItem]
        switch sortOption {
        case .userDefault, .date:
            sorted = items.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) }
        case .name:
            sorted = items.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .size:
            sorted = items.sorted { $0.fileSize < $1.fileSize }
        case .favorites:
            sorted = items.sorted { ($0.isFavorite && !$1.isFavorite) || ($0.isFavorite == $1.isFavorite && ($0.fileName ?? "") < ($1.fileName ?? "")) }
        case .kind:
            sorted = items.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        return sortAscending ? sorted : sorted.reversed()
    }

    // MARK: - Private
    private let categoryType: CategoryType
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init
    init(categoryType: CategoryType) {
        self.categoryType = categoryType

        loadItems()

        NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))
            .merge(with: NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave))
            .sink { [weak self] _ in
                self?.loadItems()
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

    deinit { cancellables.forEach { $0.cancel() } }

    // MARK: - Public API

    func toggleSelection(_ item: VaultItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }

    func selectAll() {
        selectedItems = Set(items)
    }

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
    
    func triggerSelectionHaptic() {
        if !hasTriggeredSelectionHaptic {
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
            hasTriggeredSelectionHaptic = true
        }
    }

    func moveSelectedItems(to destinationFolder: Folder?) {
        for item in selectedItems {
            CoreDataManager.shared.moveVaultItem(item, to: destinationFolder)
        }
        exitSelectionMode()
        notifyGlobalRefresh()
    }

    func toggleFavoriteSelectedItems() {
        for item in selectedItems {
            FileStorageManager.shared.toggleFavorite(for: item)
        }
        exitSelectionMode()
        notifyGlobalRefresh()
    }
    
    func deleteSelectedItems() {
        for item in selectedItems {
            do {
                try FileStorageManager.shared.deleteFile(vaultItem: item)
            } catch {
                print("Error deleting item: \(error)")
            }
        }
        exitSelectionMode()
        notifyGlobalRefresh()
    }
    
    // MARK: - File Viewing
    
    /// View a file - show media viewer for images/videos, file preview for others
    func viewFile(_ item: VaultItem) {
        if item.isImage || item.isVideo {
            showMediaViewer(for: item)
        } else {
            showFilePreview(for: item)
        }
    }
    
    /// Get media files (images and videos only) from sorted items
    func getMediaFiles() -> [VaultItem] {
        return sortedItems.filter { item in
            item.isImage || item.isVideo
        }
    }
    
    /// Show media viewer for images and videos
    func showMediaViewer(for item: VaultItem) {
        let mediaFiles = getMediaFiles()
        if let index = mediaFiles.firstIndex(where: { $0.objectID == item.objectID }) {
            mediaViewerIndex = index
            showUnifiedMediaViewer = true
        }
    }
    
    /// Show file preview for non-media files
    func showFilePreview(for item: VaultItem) {
        filePreviewItem = item
        showFilePreview = true
    }
    
    // MARK: - Favorites Management
    
    func toggleFavorite(for item: VaultItem) {
        FileStorageManager.shared.toggleFavorite(for: item)
        // Refresh the view to reflect the change
        notifyGlobalRefresh()
    }
    
    // MARK: - Share Management
    
    func shareItem(_ item: VaultItem) {
        ShareManager.shared.shareVaultItem(item)
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
    
    func moveItem(_ item: VaultItem, showMoveSheet: @escaping () -> Void) {
        // Clear selection and add only this item
        selectedItems.removeAll()
        selectedItems.insert(item)
        showMoveSheet()
    }
    
    // MARK: - Single Item Delete
    
    func deleteItem(_ item: VaultItem) {
        // Check if trash is enabled
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            // Move to trash without confirmation
            try? FileStorageManager.shared.deleteFile(vaultItem: item)
            notifyGlobalRefresh()
        } else {
            // Show confirmation alert
            selectedItems = [item]
            enterSelectionMode()
            // Trigger the alert via delegate or notification pattern
            // For now, we'll handle this in the view level
        }
    }

    // MARK: - Private helpers
    private func notifyGlobalRefresh() {
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }

    private func loadItems() {
        let allItems = CoreDataManager.shared.fetchVaultItemsFromAllFolders()
        switch categoryType {
        case .favorites:
            items = allItems.filter { $0.isFavorite }
        case .photos:
            items = allItems.filter { $0.isImage }
        case .videos:
            items = allItems.filter { $0.isVideo }
        case .audio:
            items = allItems.filter { $0.isAudio }
        case .documents:
            items = allItems.filter { $0.isDocument }
        case .other:
            items = allItems.filter { $0.isOther }
        case .allFiles:
            items = allItems
        }
    }
} 