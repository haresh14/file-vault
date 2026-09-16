import Foundation
import CoreData

extension CoreDataManager {
    func clearAllCoreData() {
        print("DEBUG: Clearing all Core Data...")
        for entityName in ["VaultItem", "Folder"] {
            let request = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            do {
                try context.execute(NSBatchDeleteRequest(fetchRequest: request))
            } catch {
                print("ERROR: Failed to delete \(entityName): \(error)")
            }
        }
        save()
        context.reset()
        print("DEBUG: Core Data cleared and context reset")
    }

    func deleteCoreDataStore() {
        print("DEBUG: Deleting Core Data store files...")
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            print("ERROR: Could not get store URL")
            return
        }

        do {
            let coordinator = persistentContainer.persistentStoreCoordinator
            if let store = coordinator.persistentStores.first {
                try coordinator.remove(store)
            }
            for fileURL in [
                storeURL,
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm")
            ] where FileManager.default.fileExists(atPath: fileURL.path) {
                try FileManager.default.removeItem(at: fileURL)
            }
        } catch {
            print("ERROR: Failed to delete Core Data store: \(error)")
        }
    }
}
