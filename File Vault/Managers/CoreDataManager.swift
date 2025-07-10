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
        
        // Enable encryption for Core Data
        let storeDescription = container.persistentStoreDescriptions.first
        storeDescription?.setOption(FileProtectionType.complete as NSObject, forKey: NSPersistentStoreFileProtectionKey)
        
        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
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
        
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                let nsError = error as NSError
                fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
            }
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
        
        save()
        return item
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
} 