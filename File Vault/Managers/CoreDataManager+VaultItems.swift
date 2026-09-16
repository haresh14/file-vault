import Foundation
import CoreData

extension CoreDataManager {
    func createVaultItem(fileType: String, fileName: String, folder: Folder?) -> VaultItem? {
        let item = NSEntityDescription.insertNewObject(
            forEntityName: "VaultItem",
            into: context
        ) as! VaultItem
        item.id = UUID()
        item.fileName = fileName
        item.fileType = fileType
        item.fileSize = 0
        item.createdAt = Date()
        item.updatedAt = Date()
        item.folder = folder
        save()
        return item
    }

    func createVaultItem(
        fileName: String,
        fileType: String,
        fileSize: Int64,
        thumbnailFileName: String? = nil,
        in folder: Folder? = nil
    ) -> VaultItem {
        let item = NSEntityDescription.insertNewObject(
            forEntityName: "VaultItem",
            into: context
        ) as! VaultItem
        item.id = UUID()
        item.fileName = fileName
        item.fileType = fileType
        item.fileSize = fileSize
        item.thumbnailFileName = thumbnailFileName
        item.createdAt = Date()
        item.updatedAt = Date()
        item.folder = folder
        save()
        return item
    }

    func deleteVaultItem(_ item: VaultItem) {
        context.delete(item)
        save()
    }

    func fetchAllVaultItems() -> [VaultItem] {
        fetchVaultItems(predicate: nil)
    }

    func fetchVaultItems(in folder: Folder?) -> [VaultItem] {
        let predicate = folder.map {
            NSPredicate(format: "folder == %@ AND isTrashed == false", $0)
        } ?? NSPredicate(format: "folder == nil AND isTrashed == false")
        return fetchVaultItems(predicate: predicate)
    }

    func fetchVaultItemsFromAllFolders() -> [VaultItem] {
        fetchVaultItems(predicate: NSPredicate(format: "isTrashed == false"))
    }

    func moveVaultItem(_ item: VaultItem, to folder: Folder?) {
        item.folder = folder
        item.updatedAt = Date()
        save()
    }

    func toggleFavorite(for item: VaultItem) {
        item.isFavorite.toggle()
        item.updatedAt = Date()
        save()
    }

    func fetchFavoriteVaultItems() -> [VaultItem] {
        fetchVaultItems(
            predicate: NSPredicate(format: "isFavorite == true AND isTrashed == false")
        )
    }

    private func fetchVaultItems(predicate: NSPredicate?) -> [VaultItem] {
        let request = NSFetchRequest<VaultItem>(entityName: "VaultItem")
        request.predicate = predicate
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching vault items: \(error)")
            return []
        }
    }
}
