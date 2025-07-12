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
    
    var dateAdded: Date? {
        return createdAt
    }

}

extension VaultItem : Identifiable {
    var isPhoto: Bool {
        guard let fileType = fileType else { return false }
        let photoTypes = ["image/jpeg", "image/png", "image/heic", "image/heif", "image/gif", "image/webp"]
        return photoTypes.contains(fileType.lowercased())
    }
    
    var isImage: Bool {
        return fileType?.hasPrefix("image/") ?? false
    }
    
    var isVideo: Bool {
        guard let fileType = fileType else { return false }
        let videoTypes = [
            "video/mp4", 
            "video/quicktime", 
            "video/x-m4v", 
            "video/mpeg",
            "video/x-matroska",  // MKV
            "video/x-msvideo",   // AVI
            "video/webm",        // WebM
            "video/x-flv",       // FLV
            "video/x-ms-wmv",    // WMV
            "video/3gpp"         // 3GP
        ]
        return videoTypes.contains(fileType.lowercased())
    }
    
    var isDocument: Bool {
        guard let fileType = fileType else { return false }
        let documentTypes = [
            "application/pdf",
            "application/msword",
            "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
            "application/vnd.ms-excel",
            "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet",
            "application/vnd.ms-powerpoint",
            "application/vnd.openxmlformats-officedocument.presentationml.presentation",
            "text/plain",
            "text/rtf",
            "application/rtf",
            "application/zip",
            "application/x-zip-compressed",
            "application/x-rar-compressed",
            "application/x-7z-compressed"
        ]
        return documentTypes.contains(fileType.lowercased()) || 
               (!isImage && !isVideo && !isAudio)
    }
    
    var isAudio: Bool {
        guard let fileType = fileType else { return false }
        let audioTypes = [
            "audio/mpeg",        // MP3
            "audio/wav",         // WAV
            "audio/x-m4a",       // M4A
            "audio/aac",         // AAC
            "audio/ogg",         // OGG
            "audio/flac"         // FLAC
        ]
        return audioTypes.contains(fileType.lowercased())
    }
} 