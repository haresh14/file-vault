//
//  VaultItem+CoreDataProperties.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CoreData

extension VaultItem {

    @nonobjc public class func fetchRequest() -> NSFetchRequest<VaultItem> {
        return NSFetchRequest<VaultItem>(entityName: "VaultItem")
    }

    @NSManaged public var createdAt: Date?
    @NSManaged public var fileName: String?
    @NSManaged public var fileSize: Int64
    @NSManaged public var fileType: String?
    @NSManaged public var id: UUID?
    @NSManaged public var thumbnailFileName: String?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var folder: Folder?

}

extension VaultItem : Identifiable {
    var isPhoto: Bool {
        guard let fileType = fileType else { return false }
        let photoTypes = ["image/jpeg", "image/png", "image/heic", "image/heif", "image/gif", "image/webp"]
        return photoTypes.contains(fileType.lowercased())
    }
    
    var isVideo: Bool {
        guard let fileType = fileType else { return false }
        let videoTypes = ["video/mp4", "video/quicktime", "video/x-m4v", "video/mpeg"]
        return videoTypes.contains(fileType.lowercased())
    }
} 