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
    @Published var selectedItems: Set<VaultItem> = []

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
    }

    func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
    }

    func moveSelectedItems(to destinationFolder: Folder?) {
        for item in selectedItems {
            CoreDataManager.shared.moveVaultItem(item, to: destinationFolder)
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

    // MARK: - Private helpers
    private func notifyGlobalRefresh() {
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }

    private func loadItems() {
        let allItems = CoreDataManager.shared.fetchVaultItemsFromAllFolders()
        switch categoryType {
        case .photos:
            items = allItems.filter { $0.isImage }
        case .videos:
            items = allItems.filter { $0.isVideo }
        case .documents:
            items = allItems.filter { $0.isDocument }
        case .allFiles:
            items = allItems
        }
    }
} 