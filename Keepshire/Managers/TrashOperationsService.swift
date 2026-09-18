import Foundation

final class TrashOperationsService {
    private let fileManager: FileManager
    private let coreDataManager: CoreDataManager
    private let vaultDirectory: URL
    private let thumbnailsDirectory: URL

    init(
        fileManager: FileManager,
        coreDataManager: CoreDataManager,
        vaultDirectory: URL,
        thumbnailsDirectory: URL
    ) {
        self.fileManager = fileManager
        self.coreDataManager = coreDataManager
        self.vaultDirectory = vaultDirectory
        self.thumbnailsDirectory = thumbnailsDirectory
    }

    func moveToTrash(_ item: VaultItem) {
        item.isTrashed = true
        item.trashedAt = Date()
        coreDataManager.persistChanges()
    }

    func permanentlyDelete(_ item: VaultItem) {
        let blobNames = item.storedBlobCandidates
        let thumbNames = item.storedThumbnailCandidates

        coreDataManager.deleteVaultItem(item)

        for name in blobNames {
            try? fileManager.removeItem(at: vaultDirectory.appendingPathComponent(name))
        }
        for name in thumbNames {
            try? fileManager.removeItem(at: thumbnailsDirectory.appendingPathComponent(name))
        }
    }
}
