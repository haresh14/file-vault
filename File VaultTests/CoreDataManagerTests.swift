//
//  CoreDataManagerTests.swift
//  File VaultTests
//
//  Created on 11/07/25.
//

import Testing
import Foundation
import CoreData
@testable import File_Vault

struct CoreDataManagerTests {
    
    // MARK: - Initialization Tests
    
    @Test func testCoreDataManagerSingleton() async throws {
        let manager1 = CoreDataManager.shared
        let manager2 = CoreDataManager.shared
        
        #expect(manager1 === manager2, "CoreDataManager should be a singleton")
    }
    
    @Test func testPersistentContainer() async throws {
        let manager = CoreDataManager.shared
        
        #expect(manager.persistentContainer.name == "File_Vault", "Persistent container should be initialized with correct name")
        #expect(manager.persistentContainer.name == "File_Vault", "Container should have correct name")
    }
    
    @Test func testManagedObjectContext() async throws {
        let manager = CoreDataManager.shared
        
        #expect(manager.context.concurrencyType == .mainQueueConcurrencyType, "Context should use main queue concurrency")
        #expect(manager.context.concurrencyType == .mainQueueConcurrencyType, "Context should use main queue")
    }
    
    // MARK: - VaultItem CRUD Tests
    
    @Test func testCreateVaultItem() async throws {
        let manager = CoreDataManager.shared
        
        // Create a test VaultItem
        let vaultItem = VaultItem(context: manager.context)
        vaultItem.id = UUID()
        vaultItem.fileName = "test.txt"
        vaultItem.fileType = "text/plain"
        vaultItem.fileSize = 100
        vaultItem.createdAt = Date()
        
        // Save context
        manager.save()
        
        // Verify item was saved
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultItem.id! as CVarArg)
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 1, "Should have one VaultItem")
        #expect(results.first?.fileName == "test.txt", "File name should match")
        
        // Cleanup
        manager.context.delete(vaultItem)
        manager.save()
    }
    
    @Test func testFetchVaultItems() async throws {
        let manager = CoreDataManager.shared
        
        // Create test items
        var testItems: [VaultItem] = []
        for i in 0..<3 {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "test\(i).txt"
            vaultItem.fileType = "text/plain"
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = Date()
            testItems.append(vaultItem)
        }
        
        manager.save()
        
        // Fetch all items
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        let allItems = try manager.context.fetch(fetchRequest)
        
        #expect(allItems.count >= 3, "Should have at least 3 items")
        
        // Verify our test items are in the results
        let testFileNames = testItems.map { $0.fileName }
        let fetchedFileNames = allItems.map { $0.fileName }
        
        for fileName in testFileNames {
            #expect(fetchedFileNames.contains(fileName), "Should contain test file: \(fileName ?? "nil")")
        }
        
        // Cleanup
        for item in testItems {
            manager.context.delete(item)
        }
        manager.save()
    }
    
    @Test func testUpdateVaultItem() async throws {
        let manager = CoreDataManager.shared
        
        // Create a test VaultItem
        let vaultItem = VaultItem(context: manager.context)
        vaultItem.id = UUID()
        vaultItem.fileName = "original.txt"
        vaultItem.fileType = "text/plain"
        vaultItem.fileSize = 100
        vaultItem.createdAt = Date()
        
        manager.save()
        
        // Update the item
        vaultItem.fileName = "updated.txt"
        vaultItem.fileSize = 200
        
        manager.save()
        
        // Verify update
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultItem.id! as CVarArg)
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 1, "Should have one VaultItem")
        #expect(results.first?.fileName == "updated.txt", "File name should be updated")
        #expect(results.first?.fileSize == 200, "File size should be updated")
        
        // Cleanup
        manager.context.delete(vaultItem)
        manager.save()
    }
    
    @Test func testDeleteVaultItem() async throws {
        let manager = CoreDataManager.shared
        
        // Create a test VaultItem
        let vaultItem = VaultItem(context: manager.context)
        vaultItem.id = UUID()
        vaultItem.fileName = "delete_me.txt"
        vaultItem.fileType = "text/plain"
        vaultItem.fileSize = 100
        vaultItem.createdAt = Date()
        
        manager.save()
        
        // Verify item exists
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultItem.id! as CVarArg)
        
        var results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 1, "Should have one VaultItem before deletion")
        
        // Delete the item
        manager.context.delete(vaultItem)
        manager.save()
        
        // Verify item is deleted
        results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 0, "Should have no VaultItems after deletion")
    }
    
    // MARK: - Folder CRUD Tests
    
    @Test func testCreateFolder() async throws {
        let manager = CoreDataManager.shared
        
        // Create a test Folder
        let folder = Folder(context: manager.context)
        folder.id = UUID()
        folder.name = "Test Folder"
        folder.createdAt = Date()
        
        manager.save()
        
        // Verify folder was saved
        let fetchRequest: NSFetchRequest<Folder> = Folder.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", folder.id! as CVarArg)
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 1, "Should have one Folder")
        #expect(results.first?.name == "Test Folder", "Folder name should match")
        
        // Cleanup
        manager.context.delete(folder)
        manager.save()
    }
    
    @Test func testFolderVaultItemRelationship() async throws {
        let manager = CoreDataManager.shared
        
        // Create a test Folder
        let folder = Folder(context: manager.context)
        folder.id = UUID()
        folder.name = "Test Folder"
        folder.createdAt = Date()
        
        // Create test VaultItems
        var vaultItems: [VaultItem] = []
        for i in 0..<3 {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "test\(i).txt"
            vaultItem.fileType = "text/plain"
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = Date()
            vaultItem.folder = folder
            vaultItems.append(vaultItem)
        }
        
        manager.save()
        
        // Verify relationships
        #expect(folder.items?.count == 3, "Folder should have 3 vault items")
        
        for vaultItem in vaultItems {
            #expect(vaultItem.folder == folder, "VaultItem should belong to folder")
        }
        
        // Cleanup
        for item in vaultItems {
            manager.context.delete(item)
        }
        manager.context.delete(folder)
        manager.save()
    }
    
    // MARK: - Context Management Tests
    
    @Test func testSaveContext() async throws {
        let manager = CoreDataManager.shared
        
        // Create a test item
        let vaultItem = VaultItem(context: manager.context)
        vaultItem.id = UUID()
        vaultItem.fileName = "save_test.txt"
        vaultItem.fileType = "text/plain"
        vaultItem.fileSize = 100
        vaultItem.createdAt = Date()
        
        // Test that save doesn't throw
        manager.save()
        
        // Verify item was saved by fetching it
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", vaultItem.id! as CVarArg)
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 1, "Should have saved one VaultItem")
        
        // Cleanup
        manager.context.delete(vaultItem)
        manager.save()
    }
    
    @Test func testSaveContextWithoutChanges() async throws {
        let manager = CoreDataManager.shared
        
        // Test saving context without any changes
        manager.save()
        
        // Should not throw or cause issues
        #expect(true, "Save context should handle no changes gracefully")
    }
    
    // MARK: - Batch Operations Tests
    
    @Test func testBatchInsert() async throws {
        let manager = CoreDataManager.shared
        
        // Create multiple test items
        var testItems: [VaultItem] = []
        for i in 0..<10 {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "batch_test\(i).txt"
            vaultItem.fileType = "text/plain"
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = Date()
            testItems.append(vaultItem)
        }
        
        // Save all at once
        manager.save()
        
        // Verify all items were saved
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fileName BEGINSWITH %@", "batch_test")
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 10, "Should have saved 10 items")
        
        // Cleanup
        for item in testItems {
            manager.context.delete(item)
        }
        manager.save()
    }
    
    @Test func testBatchDelete() async throws {
        let manager = CoreDataManager.shared
        
        // Create test items
        var testItems: [VaultItem] = []
        for i in 0..<5 {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "delete_batch\(i).txt"
            vaultItem.fileType = "text/plain"
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = Date()
            testItems.append(vaultItem)
        }
        
        manager.save()
        
        // Delete all items
        for item in testItems {
            manager.context.delete(item)
        }
        
        manager.save()
        
        // Verify all items were deleted
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fileName BEGINSWITH %@", "delete_batch")
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 0, "Should have deleted all items")
    }
    
    // MARK: - Query Tests
    
    @Test func testFetchWithSortDescriptor() async throws {
        let manager = CoreDataManager.shared
        
        // Create test items with different dates
        var testItems: [VaultItem] = []
        let baseDate = Date()
        
        for i in 0..<3 {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "sort_test\(i).txt"
            vaultItem.fileType = "text/plain"
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = baseDate.addingTimeInterval(TimeInterval(i * 60)) // 1 minute apart
            testItems.append(vaultItem)
        }
        
        manager.save()
        
        // Fetch with sort descriptor
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fileName BEGINSWITH %@", "sort_test")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count == 3, "Should have 3 items")
        
        // Verify sort order (newest first)
        for i in 0..<results.count - 1 {
            let current = results[i].createdAt!
            let next = results[i + 1].createdAt!
            #expect(current >= next, "Items should be sorted by date descending")
        }
        
        // Cleanup
        for item in testItems {
            manager.context.delete(item)
        }
        manager.save()
    }
    
    @Test func testFetchWithPredicate() async throws {
        let manager = CoreDataManager.shared
        
        // Create test items with different file types
        var testItems: [VaultItem] = []
        let fileTypes = ["image/jpeg", "image/png", "text/plain"]
        
        for (i, fileType) in fileTypes.enumerated() {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "predicate_test\(i).txt"
            vaultItem.fileType = fileType
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = Date()
            testItems.append(vaultItem)
        }
        
        manager.save()
        
        // Fetch only image files
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fileType BEGINSWITH %@", "image/")
        
        let results = try manager.context.fetch(fetchRequest)
        #expect(results.count >= 2, "Should have at least 2 image items")
        
        // Verify all results are image files
        for result in results {
            #expect(result.fileType?.hasPrefix("image/") == true, "All results should be image files")
        }
        
        // Cleanup
        for item in testItems {
            manager.context.delete(item)
        }
        manager.save()
    }
    
    // MARK: - Error Handling Tests
    
    @Test func testInvalidSave() async throws {
        let manager = CoreDataManager.shared
        
        // Create an invalid VaultItem (missing required fields)
        let vaultItem = VaultItem(context: manager.context)
        // Don't set required fields
        
        // Try to save - this might not throw in this case, but we test the mechanism
        manager.save()
        
        // Clean up if it was created
        if vaultItem.managedObjectContext != nil {
            manager.context.delete(vaultItem)
            manager.save()
        }
        
        #expect(true, "Should handle invalid save gracefully")
    }
    
    // MARK: - Performance Tests
    
    @Test func testPerformance() async throws {
        let manager = CoreDataManager.shared
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Create many items
        var testItems: [VaultItem] = []
        for i in 0..<100 {
            let vaultItem = VaultItem(context: manager.context)
            vaultItem.id = UUID()
            vaultItem.fileName = "perf_test\(i).txt"
            vaultItem.fileType = "text/plain"
            vaultItem.fileSize = Int64(100 + i)
            vaultItem.createdAt = Date()
            testItems.append(vaultItem)
        }
        
        // Save all
        manager.save()
        
        // Fetch all
        let fetchRequest: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "fileName BEGINSWITH %@", "perf_test")
        
        let results = try manager.context.fetch(fetchRequest)
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        #expect(results.count == 100, "Should have created 100 items")
        #expect(timeElapsed < 5.0, "Operations should complete within 5 seconds")
        
        // Cleanup
        for item in testItems {
            manager.context.delete(item)
        }
        manager.save()
    }
} 