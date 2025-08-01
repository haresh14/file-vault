import Foundation
import Combine
import SwiftUI

/// View model responsible for providing category data to `CategoryView`.
///
/// Moves all business logic out of the SwiftUI view so that the UI stays
/// declarative and side-effect free. This aligns with Apple’s
/// MVVM-style recommendations for SwiftUI.
final class CategoryViewModel: ObservableObject {
    // MARK: - Published Properties

    /// All vault items fetched from Core Data. Updating this property will
    /// automatically refresh any views that depend on the derived collections
    /// below.
    @Published private(set) var allVaultItems: [VaultItem] = []

    // MARK: - Private

    private var cancellables = Set<AnyCancellable>()
    private let loginStateManager = LoginStateManager.shared

    // MARK: - Lifecycle

    init() {
        // Load initial data.
        loadVaultItems()

        // Observe refresh notifications so that data stays in sync with the
        // rest of the app.
        NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))
            .merge(with: NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave))
            .sink { [weak self] _ in
                self?.loadVaultItems()
            }
            .store(in: &cancellables)
    }

    deinit {
        cancellables.forEach { $0.cancel() }
    }

    // MARK: - Public Helpers

    /// Returns the number of items for the provided category type.
    func itemCount(for category: CategoryType) -> Int {
        guard !loginStateManager.shouldShowEmptyVault else { return 0 }
        return items(for: category).count
    }

    /// Returns the filtered items for a given category.
    func items(for category: CategoryType) -> [VaultItem] {
        guard !loginStateManager.shouldShowEmptyVault else { return [] }

        switch category {
        case .photos:
            return photoItems
        case .videos:
            return videoItems
        case .documents:
            return documentItems
        case .allFiles:
            return allVaultItems
        }
    }

    // MARK: - Private Helpers

    private var photoItems: [VaultItem] {
        allVaultItems.filter { $0.isImage }
    }

    private var videoItems: [VaultItem] {
        allVaultItems.filter { $0.isVideo }
    }

    private var documentItems: [VaultItem] {
        allVaultItems.filter { $0.isDocument }
    }

    private func loadVaultItems() {
        allVaultItems = CoreDataManager.shared.fetchVaultItemsFromAllFolders()
    }
} 