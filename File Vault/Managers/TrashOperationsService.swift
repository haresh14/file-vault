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
        coreDataManager.save()
    }

    func permanentlyDelete(_ item: VaultItem) {
        let fileName = item.fileName
        let thumbnailFileName = item.thumbnailFileName
        let shouldDeleteFile = fileName.map { !hasOtherReference(to: $0, excluding: item) } ?? false
        let shouldDeleteThumbnail = thumbnailFileName.map {
            !hasOtherThumbnailReference(to: $0, excluding: item)
        } ?? false

        coreDataManager.deleteVaultItem(item)

        if shouldDeleteFile, let fileName {
            try? fileManager.removeItem(at: vaultDirectory.appendingPathComponent(fileName))
        }
        if shouldDeleteThumbnail, let thumbnailFileName {
            try? fileManager.removeItem(
                at: thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
            )
        }
    }

    private func hasOtherReference(to fileName: String, excluding item: VaultItem) -> Bool {
        coreDataManager.fetchAllVaultItems().contains {
            $0.objectID != item.objectID && $0.fileName == fileName
        }
    }

    private func hasOtherThumbnailReference(
        to thumbnailFileName: String,
        excluding item: VaultItem
    ) -> Bool {
        coreDataManager.fetchAllVaultItems().contains {
            $0.objectID != item.objectID && $0.thumbnailFileName == thumbnailFileName
        }
    }
}
