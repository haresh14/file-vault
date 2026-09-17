//
//  CoreDataManager.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import Foundation
import CoreData

class CoreDataManager: CoreDataManaging {
    static let shared = CoreDataManager()
    
    private let inMemory: Bool

    private init() {
        inMemory = false
    }

    /// Creates an isolated store for tests without changing the app's on-disk store.
    init(inMemory: Bool) {
        self.inMemory = inMemory
    }
    
    /// One model instance for every stack, so isolated stores never claim the same entity twice.
    private static let managedObjectModel: NSManagedObjectModel = {
        guard let url = Bundle(for: CoreDataManager.self).url(forResource: "Keepshire", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Unable to load the Keepshire managed object model")
        }
        return model
    }()

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "Keepshire", managedObjectModel: CoreDataManager.managedObjectModel)
        
        // Configure store description
        if let storeDescription = container.persistentStoreDescriptions.first {
            if inMemory {
                storeDescription.type = NSInMemoryStoreType
                storeDescription.url = URL(fileURLWithPath: "/dev/null")
            }

            storeDescription.shouldMigrateStoreAutomatically = true
            storeDescription.shouldInferMappingModelAutomatically = true

            // Use a less restrictive file protection level that allows Core Data to work properly
            storeDescription.setOption(FileProtectionType.completeUntilFirstUserAuthentication as NSObject, 
                                     forKey: NSPersistentStoreFileProtectionKey)
            
            // Set store URL to ensure it's in the correct location
            if !inMemory {
            let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let storeURL = documentsDirectory.appendingPathComponent("Keepshire.sqlite")
            storeDescription.url = storeURL
            }
            
            VaultLog.debug("DEBUG: Core Data store URL: \(storeDescription.url?.path ?? "in-memory")")
        }
        
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                VaultLog.debug("DEBUG: Core Data store loading failed: \(error), \(error.userInfo)")
                VaultLog.debug("DEBUG: Store description: \(storeDescription)")
                fatalError("Unresolved error \(error), \(error.userInfo)")
            } else {
                VaultLog.debug("DEBUG: Core Data store loaded successfully at: \(storeDescription.url?.path ?? "unknown")")
                if !self.inMemory, let url = storeDescription.url {
                    BackupExclusion.excludeFromBackup(url)
                    BackupExclusion.excludeFromBackup(URL(fileURLWithPath: url.path + "-wal"))
                    BackupExclusion.excludeFromBackup(URL(fileURLWithPath: url.path + "-shm"))
                }
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
            VaultLog.debug("CoreData save error: \(nsError), \(nsError.userInfo)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
    
    func saveContext(_ context: NSManagedObjectContext) {
        guard context.hasChanges else { return }
        
        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            VaultLog.debug("CoreData save error: \(nsError), \(nsError.userInfo)")
            fatalError("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }
} 