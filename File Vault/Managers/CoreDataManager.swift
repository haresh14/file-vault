//
//  CoreDataManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CoreData

class CoreDataManager {
    static let shared = CoreDataManager()
    
    private init() {}
    
    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "FileVault")
        
        // Configure store description
        if let storeDescription = container.persistentStoreDescriptions.first {
            // Use a less restrictive file protection level that allows Core Data to work properly
            storeDescription.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, 
                                     forKey: NSPersistentStoreFileProtectionKey)
            
            // Set store URL to ensure it's in the correct location
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let storeURL = documentsDirectory.appendingPathComponent("FileVault.sqlite")
            storeDescription.url = storeURL
            
            print("DEBUG: Core Data store URL: \(storeURL.path)")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                print("DEBUG: Core Data store loading failed: \(error), \(error.userInfo)")
                print("DEBUG: Store description: \(storeDescription)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                print("DEBUG: Core Data store loaded successfully at: \(storeDescription.url?.path ?? "unknown")")
            }
        }
        
        container.viewContext.automaticallyMergesChangesFromParent = true
        return container
    }()
    
    var context: NSManagedObjectContext {
        return persistentContainer.viewContext
    }
    
    func save() {
        let context = persistentContainer.viewContext
        
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("CoreData save error: \(nsError), \(nsError.userInfo)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            print("CoreData save error: \(nsError), \(nsError.userInfo)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    // MARK: - VaultItem Operations
    
    func createVaultItem(fileName: String, fileType: String, fileSize: Int64, thumbnailFileName: String? = nil, in folder: Folder? = nil) -> VaultItem {
        let item = VaultItem(context: context)
        item.id = UUID()
        item.fileName = fileName
        item.fileType = fileType
        item.fileSize = fileSize
        item.thumbnailFileName = thumbnailFileName
        item.createdAt = Date()
        item.updatedAt = Date()
        item.folder = folder
        
        if let folder = folder {
            print("DEBUG: ✅ VaultItem created and assigned to folder: \(folder.displayName) (ID: \(folder.id?.uuidString ?? "nil"))")
        } else {
            print("DEBUG: ❌ VaultItem created without folder assignment (root level)")
        }
        
        save()
        return item
    }
    
    // Thread-safe version for background imports
    func createVaultItemInBackground(fileName: String, fileType: String, fileSize: Int64, thumbnailFileName: String? = nil, in folder: Folder? = nil, completion: @escaping (VaultItem?) -> Void) {
        let backgroundContext = persistentContainer.newBackgroundContext()
        
        backgroundContext.perform {
            let item = VaultItem(context: backgroundContext)
            item.id = UUID()
            item.fileName = fileName
            item.fileType = fileType
            item.fileSize = fileSize
            item.thumbnailFileName = thumbnailFileName
            item.createdAt = Date()
            item.updatedAt = Date()
            
            // Handle folder relationship if needed
            if let folder = folder {
                // Get the folder in background context
                if let folderInBgContext = backgroundContext.object(with: folder.objectID) as? Folder {
                    item.folder = folderInBgContext
                }
            }
            
            do {
                try backgroundContext.save()
                
                // Return to main context
                DispatchQueue.main.async {
                    do {
                        let mainContextItem = try self.context.existingObject(with: item.objectID) as? VaultItem
                        completion(mainContextItem)
                    } catch {
                        print("Error getting item in main context: \(error)")
                        completion(nil)
                    }
                }
            } catch {
                print("Error saving in background context: \(error)")
                DispatchQueue.main.async {
                    completion(nil)
                }
            }
        }
    }
    
    func deleteVaultItem(_ item: VaultItem) {
        context.delete(item)
        save()
    }
    
    func fetchAllVaultItems() -> [VaultItem] {
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching vault items: \(error)")
            return []
        }
    }
    
    // MARK: - Folder Operations
    
    func createFolder(name: String, parent: Folder? = nil) -> Folder {
        let folder = Folder(context: context)
        folder.id = UUID()
        folder.name = name
        folder.createdAt = Date()
        folder.updatedAt = Date()
        folder.parent = parent
        
        save()
        return folder
    }
    
    func deleteFolder(_ folder: Folder) {
        context.delete(folder)
        save()
    }
    
    func deleteFolderCompletely(_ folder: Folder) {
        // First, clean up file storage for all files in this folder and subfolders
        cleanupFolderFileStorage(folder)
        
        // Then delete the folder (Core Data cascade deletion will handle VaultItems and subfolders)
        context.delete(folder)
        save()
    }
    
    private func cleanupFolderFileStorage(_ folder: Folder) {
        // Clean up file storage for all files in this folder
        for item in folder.itemsArray {
            FileStorageManager.shared.cleanupFileStorage(vaultItem: item)
        }
        
        // Recursively clean up storage for all subfolders
        for subfolder in folder.subfoldersArray {
            cleanupFolderFileStorage(subfolder)
        }
    }
    
    func fetchRootFolders() -> [Folder] {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "parent == nil")
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching folders: \(error)")
            return []
        }
    }
    
    func fetchAllFolders() -> [Folder] {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all folders: \(error)")
            return []
        }
    }
    
    func fetchFolder(by id: UUID) -> Folder? {
        let request: NSFetchRequest<Folder> = Folder.fetchRequest()
        request.predicate = NSPredicate(format: "id == %@", id as CVarArg)
        request.fetchLimit = 1
        
        do {
            return try context.fetch(request).first
        } catch {
            print("Error fetching folder by ID: \(error)")
            return nil
        }
    }

    func fetchVaultItems(in folder: Folder?) -> [VaultItem] {
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        
        if let folder = folder {
            request.predicate = NSPredicate(format: "folder == %@", folder)
        } else {
            // Fetch items not in any folder (root level)
            request.predicate = NSPredicate(format: "folder == nil")
        }
        
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching vault items in folder: \(error)")
            return []
        }
    }
    
    func fetchVaultItemsFromAllFolders() -> [VaultItem] {
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        do {
            return try context.fetch(request)
        } catch {
            print("Error fetching all vault items: \(error)")
            return []
        }
    }
    
    // MARK: - Data Cleanup
    
    func clearAllCoreData() {
        print("DEBUG: Clearing all Core Data...")
        
        // Delete all VaultItems
        let vaultItemRequest: NSFetchRequest<NSFetchRequestResult> = VaultItem.fetchRequest()
        let vaultItemDeleteRequest = NSBatchDeleteRequest(fetchRequest: vaultItemRequest)
        
        do {
            try context.execute(vaultItemDeleteRequest)
            print("DEBUG: All VaultItems deleted")
        } catch {
            print("ERROR: Failed to delete VaultItems: \(error)")
        }
        
        // Delete all Folders
        let folderRequest: NSFetchRequest<NSFetchRequestResult> = Folder.fetchRequest()
        let folderDeleteRequest = NSBatchDeleteRequest(fetchRequest: folderRequest)
        
        do {
            try context.execute(folderDeleteRequest)
            print("DEBUG: All Folders deleted")
        } catch {
            print("ERROR: Failed to delete Folders: \(error)")
        }
        
        // Save the context to persist deletions
        save()
        
        // Reset the context to ensure it's clean
        context.reset()
        
        print("DEBUG: Core Data cleared and context reset")
    }
    
    func deleteCoreDataStore() {
        print("DEBUG: Deleting Core Data store files...")
        
        guard let storeURL = persistentContainer.persistentStoreDescriptions.first?.url else {
            print("ERROR: Could not get store URL")
            return
        }
        
        let coordinator = persistentContainer.persistentStoreCoordinator
        
        do {
            // Remove the persistent store
            if let store = coordinator.persistentStores.first {
                try coordinator.remove(store)
                print("DEBUG: Persistent store removed")
            }
            
            // Delete all Core Data files
            let fileManager = FileManager.default
            let storeFiles = [
                storeURL,
                storeURL.appendingPathExtension("wal"),
                storeURL.appendingPathExtension("shm")
            ]
            
            for fileURL in storeFiles {
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                    print("DEBUG: Deleted Core Data file: \(fileURL.lastPathComponent)")
                }
            }
            
            print("DEBUG: Core Data store files deleted")
        } catch {
            print("ERROR: Failed to delete Core Data store: \(error)")
        }
    }
    
    func moveVaultItem(_ item: VaultItem, to folder: Folder?) {
        item.folder = folder
        item.updatedAt = Date()
        save()
    }
    
    func moveFolder(_ folder: Folder, to parent: Folder?) {
        // Prevent moving a folder into itself or its descendants
        if let parent = parent, isFolder(folder, ancestorOf: parent) {
            print("Cannot move folder into itself or its descendants")
            return
        }
        
        folder.parent = parent
        folder.updatedAt = Date()
        save()
    }
    
    private func isFolder(_ folder: Folder, ancestorOf potentialDescendant: Folder) -> Bool {
        var current: Folder? = potentialDescendant
        while let currentFolder = current {
            if currentFolder == folder {
                return true
            }
            current = currentFolder.parent
        }
        return false
    }
    
    func updateFolder(_ folder: Folder, name: String) {
        folder.name = name
        folder.updatedAt = Date()
        save()
    }
} 