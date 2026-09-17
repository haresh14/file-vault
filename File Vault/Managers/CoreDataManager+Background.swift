import Foundation
import CoreData

extension CoreDataManager {
    func createVaultItemInBackground(
        fileName: String,
        fileType: String,
        fileSize: Int64,
        thumbnailFileName: String? = nil,
        in folder: Folder? = nil,
        id: UUID? = nil,
        completion: @escaping (VaultItem?) -> Void
    ) {
        let backgroundContext = persistentContainer.newBackgroundContext()
        backgroundContext.perform {
            let item = NSEntityDescription.insertNewObject(
                forEntityName: "VaultItem",
                into: backgroundContext
            ) as! VaultItem
            item.id = id ?? UUID()
            item.fileName = fileName
            item.fileType = fileType
            item.fileSize = fileSize
            item.thumbnailFileName = thumbnailFileName
            item.createdAt = Date()
            item.updatedAt = Date()
            if let folder {
                item.folder = backgroundContext.object(with: folder.objectID) as? Folder
            }

            do {
                try backgroundContext.save()
                DispatchQueue.main.async {
                    do {
                        completion(try self.context.existingObject(with: item.objectID) as? VaultItem)
                    } catch {
                        VaultLog.debug("Error getting item in main context: \(error)")
                        completion(nil)
                    }
                }
            } catch {
                VaultLog.debug("Error saving in background context: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
