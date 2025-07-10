//
//  Folder+CoreDataProperties.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CoreData

extension Folder {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<Folder> {
        return NSFetchRequest<Folder>(entityName: "Folder")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var items: NSSet?
    @NSManaged public var parent: Folder?
    @NSManaged public var subfolders: NSSet?

}

// MARK: Generated accessors for items
extension Folder {

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: VaultItem)

    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: VaultItem)

    @objc(addItems:)
    @NSManaged public func addToItems(_ values: NSSet)

    @objc(removeItems:)
    @NSManaged public func removeFromItems(_ values: NSSet)

}

// MARK: Generated accessors for subfolders
extension Folder {

    @objc(addSubfoldersObject:)
    @NSManaged public func addToSubfolders(_ value: Folder)

    @objc(removeSubfoldersObject:)
    @NSManaged public func removeFromSubfolders(_ value: Folder)

    @objc(addSubfolders:)
    @NSManaged public func addToSubfolders(_ values: NSSet)

    @objc(removeSubfolders:)
    @NSManaged public func removeFromSubfolders(_ values: NSSet)

}

extension Folder : Identifiable {
    var itemsArray: [VaultItem] {
        let set = items as? Set<VaultItem> ?? []
        return set.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var subfoldersArray: [Folder] {
        let set = subfolders as? Set<Folder> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
} 