//
//  Folder+CoreDataClass.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CoreData

@objc(Folder)
public class Folder: NSManagedObject {
    
    // MARK: - Computed Properties
    
    var subfoldersArray: [Folder] {
        let set = subfolders as? Set<Folder> ?? []
        return set.sorted { ($0.name ?? "") < ($1.name ?? "") }
    }
    
    var itemsArray: [VaultItem] {
        let set = items as? Set<VaultItem> ?? []
        return set.sorted { ($0.createdAt ?? Date()) > ($1.createdAt ?? Date()) }
    }
    
    var totalItemCount: Int {
        let directItems = itemsArray.count
        let subfolderItems = subfoldersArray.reduce(0) { $0 + $1.totalItemCount }
        return directItems + subfolderItems
    }
    
    var isRootFolder: Bool {
        return parent == nil
    }
    
    var breadcrumbPath: [Folder] {
        var path: [Folder] = []
        var current: Folder? = self
        
        while let folder = current {
            path.insert(folder, at: 0)
            current = folder.parent
        }
        
        return path
    }
    
    var displayName: String {
        return name ?? "Untitled Folder"
    }
} 