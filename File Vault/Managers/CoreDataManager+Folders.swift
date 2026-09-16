import Foundation
import CoreData

extension CoreDataManager {
    func createFolder(name: String, parent: Folder?) -> Folder? {
        let folder = NSEntityDescription.insertNewObject(
            forEntityName: "Folder",
            into: context
        ) as! Folder
        folder.id = UUID()
        folder.name = name
        folder.createdAt = Date()
        folder.updatedAt = Date()
        folder.parent = parent
        save()
        return folder
    }

    func fetchFolders(in parent: Folder?) -> [Folder] {
        fetchFolders(
            predicate: NSPredicate(format: "parent == %@", parent ?? NSNull())
        )
    }

    func fetchRootFolders() -> [Folder] {
        fetchFolders(predicate: NSPredicate(format: "parent == nil"))
    }

    func fetchAllFolders() -> [Folder] {
        fetchFolders(predicate: nil)
    }

    func fetchFolder(by id: UUID) -> Folder? {
        let request = NSFetchRequest<Folder>(entityName: "Folder")
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        return try? context.fetch(request).first
    }

    func deleteFolder(_ folder: Folder) {
        context.delete(folder)
        save()
    }

    func deleteFolderCompletely(_ folder: Folder) {
        if UserDefaults.standard.bool(forKey: "trashEnabled") {
            moveAllFolderFilesToTrash(folder)
            context.delete(folder)
        } else {
            cleanupFolderFileStorage(folder)
            context.delete(folder)
        }
        save()
    }

    func moveFolder(_ folder: Folder, to parent: Folder?) {
        if let parent, isFolder(folder, ancestorOf: parent) {
            print("Cannot move folder into itself or its descendants")
            return
        }
        folder.parent = parent
        folder.updatedAt = Date()
        save()
    }

    func updateFolder(_ folder: Folder, name: String) {
        folder.name = name
        folder.updatedAt = Date()
        save()
    }

    private func fetchFolders(predicate: NSPredicate?) -> [Folder] {
        let request = NSFetchRequest<Folder>(entityName: "Folder")
        request.predicate = predicate
        do {
            // Names are sealed in the store, so sort the decrypted values instead.
            return try context.fetch(request).sorted { $0.displayName.localizedCompare($1.displayName) == .orderedAscending }
        } catch {
            print("Error fetching folders: \(error)")
            return []
        }
    }

    private func moveAllFolderFilesToTrash(_ folder: Folder) {
        for item in folder.items as? Set<VaultItem> ?? [] where !item.isTrashed {
            FileStorageManager.shared.moveToTrash(vaultItem: item)
            item.folder = nil
        }
        folder.subfoldersArray.forEach(moveAllFolderFilesToTrash)
    }

    private func cleanupFolderFileStorage(_ folder: Folder) {
        for item in folder.itemsArray {
            try? FileStorageManager.shared.permanentlyDeleteFile(vaultItem: item)
        }
        folder.subfoldersArray.forEach(cleanupFolderFileStorage)
    }

    private func isFolder(_ folder: Folder, ancestorOf descendant: Folder) -> Bool {
        var current: Folder? = descendant
        while let candidate = current {
            if candidate == folder { return true }
            current = candidate.parent
        }
        return false
    }
}
