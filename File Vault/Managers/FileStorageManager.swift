//
//  FileStorageManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CryptoKit
import UIKit
import AVFoundation
import Photos
import UniformTypeIdentifiers
import CoreData

class FileStorageManager {
    static let shared = FileStorageManager()
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let vaultDirectory: URL
    private let thumbnailsDirectory: URL
    
    // Encryption key derived from user's passcode
    private var encryptionKey: SymmetricKey?
    
    // MARK: - Helper Functions
    
    private func convertUTIToMimeType(_ uti: String) -> String {
        print("DEBUG: Converting UTI: \(uti)")
        
        // Handle common image UTIs
        switch uti {
        case "public.jpeg", "public.jpg":
            return "image/jpeg"
        case "public.png":
            return "image/png"
        case "public.heic", "public.heif":
            return "image/heic"
        case "public.tiff":
            return "image/tiff"
        case "public.gif":
            return "image/gif"
        case "public.mpeg-4", "public.mp4":
            return "video/mp4"
        case "public.quicktime-movie", "public.mov":
            return "video/quicktime"
        default:
            // Try to use UniformTypeIdentifiers if available
            if #available(iOS 14.0, *) {
                if let type = UTType(uti),
                   let mimeType = type.preferredMIMEType {
                    print("DEBUG: Converted to MIME type: \(mimeType)")
                    return mimeType
                }
            }
            
            // Fallback based on common patterns
            if uti.contains("image") {
                return "image/jpeg"
            } else if uti.contains("video") {
                return "video/quicktime"
            }
            
            return uti
        }
    }
    
    private init() {
        // Get documents directory
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        
        // Create vault directory
        vaultDirectory = documentsDirectory.appendingPathComponent("Vault", isDirectory: true)
        thumbnailsDirectory = documentsDirectory.appendingPathComponent("Thumbnails", isDirectory: true)
        
        print("DEBUG: Documents directory: \(documentsDirectory.path)")
        print("DEBUG: Vault directory: \(vaultDirectory.path)")
        print("DEBUG: Thumbnails directory: \(thumbnailsDirectory.path)")
        
        // Create directories if they don't exist
        do {
            try fileManager.createDirectory(at: vaultDirectory, withIntermediateDirectories: true, attributes: nil)
            print("DEBUG: Vault directory created/verified")
        } catch {
            print("DEBUG: Error creating vault directory: \(error)")
        }
        
        do {
            try fileManager.createDirectory(at: thumbnailsDirectory, withIntermediateDirectories: true, attributes: nil)
            print("DEBUG: Thumbnails directory created/verified")
        } catch {
            print("DEBUG: Error creating thumbnails directory: \(error)")
        }
        
        // Verify directories exist
        print("DEBUG: Vault directory exists: \(fileManager.fileExists(atPath: vaultDirectory.path))")
        print("DEBUG: Thumbnails directory exists: \(fileManager.fileExists(atPath: thumbnailsDirectory.path))")
        
        // Set file protection
        setFileProtection()
    }
    
    private func setFileProtection() {
        // Set complete protection for vault directory
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: vaultDirectory.path
        )
        try? fileManager.setAttributes(
            [.protectionKey: FileProtectionType.complete],
            ofItemAtPath: thumbnailsDirectory.path
        )
    }
    
    // MARK: - Encryption Key Management
    
    func setupEncryptionKey(from password: String) {
        // Derive encryption key from password using SHA256
        let passwordData = Data(password.utf8)
        let hashed = SHA256.hash(data: passwordData)
        encryptionKey = SymmetricKey(data: hashed)
    }
    
    // MARK: - File Operations
    
    func saveFile(data: Data, fileName: String, fileType: String, targetFolder: Folder? = nil) throws -> VaultItem {
        print("DEBUG: saveFile called - fileName: \(fileName), fileType: \(fileType), dataSize: \(data.count)")
        
        guard let key = encryptionKey else {
            print("DEBUG: No encryption key available")
            throw FileStorageError.noEncryptionKey
        }
        
        // Generate unique filename
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        let fileURL = vaultDirectory.appendingPathComponent(uniqueFileName)
        print("DEBUG: Will save file to: \(fileURL.path)")
        
        // Encrypt data
        let encryptedData = try encryptData(data, using: key)
        print("DEBUG: Data encrypted, size: \(encryptedData.count)")
        
        // Save encrypted file
        try encryptedData.write(to: fileURL)
        print("DEBUG: Encrypted file saved")
        
        // Generate thumbnail if it's an image or video
        var thumbnailFileName: String? = nil
        
        print("DEBUG: Checking fileType for thumbnail generation")
        print("DEBUG: fileType = '\(fileType)'")
        print("DEBUG: fileType.hasPrefix(\"image/\") = \(fileType.hasPrefix("image/"))")
        print("DEBUG: fileType.hasPrefix(\"video/\") = \(fileType.hasPrefix("video/"))")
        
        if fileType.hasPrefix("image/") {
            print("DEBUG: Generating image thumbnail...")
            thumbnailFileName = try generateImageThumbnail(from: data, originalFileName: uniqueFileName)
            print("DEBUG: Image thumbnail result: \(thumbnailFileName ?? "nil")")
        } else if fileType.hasPrefix("video/") {
            print("DEBUG: Generating video thumbnail...")
            thumbnailFileName = try generateVideoThumbnail(from: data, originalFileName: uniqueFileName)
            print("DEBUG: Video thumbnail result: \(thumbnailFileName ?? "nil")")
        } else {
            print("DEBUG: Skipping thumbnail generation for fileType: \(fileType)")
        }
        
        // Create Core Data entry using synchronous method for direct calls
        let vaultItem = CoreDataManager.shared.createVaultItem(
            fileName: uniqueFileName,
            fileType: fileType,
            fileSize: Int64(data.count),
            thumbnailFileName: thumbnailFileName,
            in: targetFolder
        )
        
        print("DEBUG: VaultItem created with thumbnailFileName: \(vaultItem.thumbnailFileName ?? "nil")")
        
        return vaultItem
    }
    
    // New method for background imports
    func saveFileInBackground(data: Data, fileName: String, fileType: String, targetFolder: Folder? = nil, completion: @escaping (Result<VaultItem, Error>) -> Void) {
        print("DEBUG: saveFileInBackground called - fileName: \(fileName), fileType: \(fileType), dataSize: \(data.count)")
        
        guard let key = encryptionKey else {
            print("DEBUG: No encryption key available")
            completion(.failure(FileStorageError.noEncryptionKey))
            return
        }
        
        // Generate unique filename
        let uniqueFileName = "\(UUID().uuidString)_\(fileName)"
        let fileURL = vaultDirectory.appendingPathComponent(uniqueFileName)
        print("DEBUG: Will save file to: \(fileURL.path)")
        
        do {
            // Encrypt data
            let encryptedData = try encryptData(data, using: key)
            print("DEBUG: Data encrypted, size: \(encryptedData.count)")
            
            // Save encrypted file
            try encryptedData.write(to: fileURL)
            print("DEBUG: Encrypted file saved")
            
            // Generate thumbnail if it's an image or video
            var thumbnailFileName: String? = nil
            
            print("DEBUG: Checking fileType for thumbnail generation")
            print("DEBUG: fileType = '\(fileType)'")
            print("DEBUG: fileType.hasPrefix(\"image/\") = \(fileType.hasPrefix("image/"))")
            print("DEBUG: fileType.hasPrefix(\"video/\") = \(fileType.hasPrefix("video/"))")
            
            if fileType.hasPrefix("image/") {
                print("DEBUG: Generating image thumbnail...")
                thumbnailFileName = try generateImageThumbnail(from: data, originalFileName: uniqueFileName)
                print("DEBUG: Image thumbnail result: \(thumbnailFileName ?? "nil")")
            } else if fileType.hasPrefix("video/") {
                print("DEBUG: Generating video thumbnail...")
                thumbnailFileName = try generateVideoThumbnail(from: data, originalFileName: uniqueFileName)
                print("DEBUG: Video thumbnail result: \(thumbnailFileName ?? "nil")")
            } else {
                print("DEBUG: Skipping thumbnail generation for fileType: \(fileType)")
            }
            
            // Create Core Data entry using background context
            CoreDataManager.shared.createVaultItemInBackground(
                fileName: uniqueFileName,
                fileType: fileType,
                fileSize: Int64(data.count),
                thumbnailFileName: thumbnailFileName,
                in: targetFolder
            ) { vaultItem in
                if let vaultItem = vaultItem {
                    print("DEBUG: VaultItem created with thumbnailFileName: \(vaultItem.thumbnailFileName ?? "nil")")
                    completion(.success(vaultItem))
                } else {
                    print("DEBUG: Failed to create VaultItem")
                    completion(.failure(FileStorageError.importFailed))
                }
            }
        } catch {
            print("DEBUG: Error in saveFileInBackground: \(error)")
            completion(.failure(error))
        }
    }
    
    func loadFile(vaultItem: VaultItem) throws -> Data {
        guard let key = encryptionKey else {
            throw FileStorageError.noEncryptionKey
        }
        
        guard let fileName = vaultItem.fileName else {
            throw FileStorageError.invalidFileName
        }
        
        let fileURL = vaultDirectory.appendingPathComponent(fileName)
        let encryptedData = try Data(contentsOf: fileURL)
        
        // Decrypt data
        return try decryptData(encryptedData, using: key)
    }
    
    func deleteFile(vaultItem: VaultItem) throws {
        // Delete main file
        if let fileName = vaultItem.fileName {
            let fileURL = vaultDirectory.appendingPathComponent(fileName)
            try? fileManager.removeItem(at: fileURL)
        }
        
        // Delete thumbnail
        if let thumbnailFileName = vaultItem.thumbnailFileName {
            let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
            try? fileManager.removeItem(at: thumbnailURL)
        }
        
        // Delete Core Data entry
        CoreDataManager.shared.deleteVaultItem(vaultItem)
    }
    
    // MARK: - Encryption/Decryption
    
    private func encryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let encryptedData = sealedBox.combined else {
            throw FileStorageError.encryptionFailed
        }
        return encryptedData
    }
    
    private func decryptData(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.SealedBox(combined: data)
        return try AES.GCM.open(sealedBox, using: key)
    }
    
    // MARK: - Thumbnail Generation
    
    private func generateImageThumbnail(from imageData: Data, originalFileName: String) throws -> String? {
        print("DEBUG: Generating image thumbnail for \(originalFileName)")
        guard let image = UIImage(data: imageData) else { 
            print("DEBUG: Failed to create UIImage from data")
            return nil 
        }
        
        let thumbnailSize = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        
        let thumbnail = renderer.image { context in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }
        
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            print("DEBUG: Failed to create JPEG data from thumbnail")
            return nil
        }
        
        let thumbnailFileName = "thumb_\(originalFileName).jpg"
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
        
        do {
            try thumbnailData.write(to: thumbnailURL)
            print("DEBUG: Thumbnail saved successfully at \(thumbnailURL.path)")
            print("DEBUG: Thumbnail file exists: \(fileManager.fileExists(atPath: thumbnailURL.path))")
            return thumbnailFileName
        } catch {
            print("DEBUG: Error saving thumbnail: \(error)")
            throw error
        }
    }
    
    private func generateVideoThumbnail(from videoData: Data, originalFileName: String) throws -> String? {
        print("DEBUG: Generating video thumbnail for \(originalFileName)")
        
        // Save video temporarily to generate thumbnail - use original extension
        let originalExtension = (originalFileName as NSString).pathExtension
        let tempFileName = UUID().uuidString + (originalExtension.isEmpty ? ".mov" : ".\(originalExtension)")
        let tempURL = fileManager.temporaryDirectory.appendingPathComponent(tempFileName)
        try videoData.write(to: tempURL)
        defer { try? fileManager.removeItem(at: tempURL) }
        
        let asset = AVURLAsset(url: tempURL)
        
        // First check if the asset is readable by AVFoundation
        let tracks = asset.tracks(withMediaType: .video)
        if tracks.isEmpty {
            print("DEBUG: No video tracks found in asset, format may not be supported by AVFoundation")
            return generateGenericVideoThumbnail(originalFileName: originalFileName)
        }
        
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 200, height: 200)
        
        // Try multiple time positions to find a good frame
        let times = [
            CMTime(seconds: 1, preferredTimescale: 60),
            CMTime(seconds: 0.5, preferredTimescale: 60),
            CMTime(seconds: 2, preferredTimescale: 60),
            CMTime.zero
        ]
        
        for time in times {
            do {
                let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
                let thumbnail = UIImage(cgImage: cgImage)
                
                guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
                    print("DEBUG: Failed to create JPEG data from video thumbnail")
                    continue
                }
                
                let thumbnailFileName = "thumb_\(originalFileName).jpg"
                let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                
                try thumbnailData.write(to: thumbnailURL)
                print("DEBUG: Video thumbnail saved successfully at \(thumbnailURL.path)")
                return thumbnailFileName
            } catch {
                print("DEBUG: Error generating video thumbnail at time \(time.seconds): \(error)")
                continue
            }
        }
        
        print("DEBUG: Failed to generate video thumbnail for all attempted times, creating generic video thumbnail")
        return generateGenericVideoThumbnail(originalFileName: originalFileName)
    }
    
    private func generateGenericVideoThumbnail(originalFileName: String) -> String? {
        print("DEBUG: Generating generic video thumbnail for \(originalFileName)")
        
        // Create a generic video icon thumbnail
        let thumbnailSize = CGSize(width: 200, height: 200)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)
        
        let thumbnail = renderer.image { context in
            let cgContext = context.cgContext
            
            // Set background color (dark gray)
            cgContext.setFillColor(UIColor.systemGray2.cgColor)
            cgContext.fill(CGRect(origin: .zero, size: thumbnailSize))
            
            // Draw play button in center
            let playButtonSize: CGFloat = 60
            let playButtonRect = CGRect(
                x: (thumbnailSize.width - playButtonSize) / 2,
                y: (thumbnailSize.height - playButtonSize) / 2,
                width: playButtonSize,
                height: playButtonSize
            )
            
            // Draw play button background circle
            cgContext.setFillColor(UIColor.white.withAlphaComponent(0.9).cgColor)
            cgContext.fillEllipse(in: playButtonRect)
            
            // Draw play triangle
            let triangleSize: CGFloat = 20
            let triangleRect = CGRect(
                x: playButtonRect.midX - triangleSize / 2 + 2, // Offset slightly to center visually
                y: playButtonRect.midY - triangleSize / 2,
                width: triangleSize,
                height: triangleSize
            )
            
            cgContext.setFillColor(UIColor.systemBlue.cgColor)
            cgContext.beginPath()
            cgContext.move(to: CGPoint(x: triangleRect.minX, y: triangleRect.minY))
            cgContext.addLine(to: CGPoint(x: triangleRect.maxX, y: triangleRect.midY))
            cgContext.addLine(to: CGPoint(x: triangleRect.minX, y: triangleRect.maxY))
            cgContext.closePath()
            cgContext.fillPath()
            
            // Add file extension text if available
            let fileExtension = (originalFileName as NSString).pathExtension.uppercased()
            if !fileExtension.isEmpty {
                let font = UIFont.systemFont(ofSize: 14, weight: .medium)
                let attributes: [NSAttributedString.Key: Any] = [
                    .font: font,
                    .foregroundColor: UIColor.white
                ]
                
                let text = fileExtension
                let textSize = text.size(withAttributes: attributes)
                let textRect = CGRect(
                    x: (thumbnailSize.width - textSize.width) / 2,
                    y: thumbnailSize.height - textSize.height - 10,
                    width: textSize.width,
                    height: textSize.height
                )
                
                text.draw(in: textRect, withAttributes: attributes)
            }
        }
        
        guard let thumbnailData = thumbnail.jpegData(compressionQuality: 0.7) else {
            print("DEBUG: Failed to create JPEG data from generic video thumbnail")
            return nil
        }
        
        let thumbnailFileName = "thumb_\(originalFileName).jpg"
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
        
        do {
            try thumbnailData.write(to: thumbnailURL)
            print("DEBUG: Generic video thumbnail saved successfully at \(thumbnailURL.path)")
            return thumbnailFileName
        } catch {
            print("DEBUG: Error saving generic video thumbnail: \(error)")
            return nil
        }
    }
    
    func loadThumbnail(for vaultItem: VaultItem) -> UIImage? {
        guard let thumbnailFileName = vaultItem.thumbnailFileName else { 
            print("DEBUG: No thumbnail filename for item \(vaultItem.fileName ?? "")")
            return nil 
        }
        
        let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
        print("DEBUG: Loading thumbnail from \(thumbnailURL.path)")
        print("DEBUG: Thumbnail exists: \(fileManager.fileExists(atPath: thumbnailURL.path))")
        
        guard let data = try? Data(contentsOf: thumbnailURL) else { 
            print("DEBUG: Failed to load thumbnail data")
            return nil 
        }
        
        let image = UIImage(data: data)
        print("DEBUG: Thumbnail loaded: \(image != nil)")
        return image
    }
    
    func loadImage(for vaultItem: VaultItem) async throws -> UIImage {
        return try await withCheckedThrowingContinuation { continuation in
            do {
                let fileData = try loadFile(vaultItem: vaultItem)
                guard let image = UIImage(data: fileData) else {
                    continuation.resume(throwing: FileStorageError.decryptionFailed)
                    return
                }
                continuation.resume(returning: image)
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }
    
    // MARK: - Storage Info
    
    func getStorageInfo() -> (fileCount: Int, usedSpace: Int64) {
        let context = CoreDataManager.shared.persistentContainer.viewContext
        
        let request: NSFetchRequest<VaultItem> = VaultItem.fetchRequest()
        
        do {
            let items = try context.fetch(request)
            let fileCount = items.count
            
            // Calculate used space by summing file sizes
            var usedSpace: Int64 = 0
            for item in items {
                if let fileName = item.fileName {
                    let fileURL = vaultDirectory.appendingPathComponent(fileName)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: fileURL.path),
                       let fileSize = attributes[FileAttributeKey.size] as? Int64 {
                        usedSpace += fileSize
                    }
                }
                
                // Also count thumbnail size
                if let thumbnailFileName = item.thumbnailFileName {
                    let thumbnailURL = thumbnailsDirectory.appendingPathComponent(thumbnailFileName)
                    if let attributes = try? FileManager.default.attributesOfItem(atPath: thumbnailURL.path),
                       let thumbnailSize = attributes[FileAttributeKey.size] as? Int64 {
                        usedSpace += thumbnailSize
                    }
                }
            }
            
            return (fileCount: fileCount, usedSpace: usedSpace)
            
        } catch {
            print("DEBUG: Error fetching storage info: \(error)")
            return (fileCount: 0, usedSpace: 0)
        }
    }
    
    // MARK: - Import from Photo Library
    
    func importFromPhotoLibrary(asset: PHAsset, targetFolder: Folder? = nil, completion: @escaping (Result<VaultItem, Error>) -> Void) {
        print("DEBUG: Starting import for asset: \(asset.localIdentifier)")
        
        if asset.mediaType == .image {
            let options = PHImageRequestOptions()
            options.version = .original
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, uti, _, info in
                print("DEBUG: Image data received: \(data?.count ?? 0) bytes")
                print("DEBUG: UTI: \(uti ?? "unknown")")
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("DEBUG: PHImageManager error: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let data = data else {
                    print("DEBUG: No image data received")
                    completion(.failure(FileStorageError.importFailed))
                    return
                }
                
                let fileName = asset.value(forKey: "filename") as? String ?? "IMG_\(Date().timeIntervalSince1970).jpg"
                let fileType = self.convertUTIToMimeType(uti ?? "image/jpeg")
                
                print("DEBUG: About to save image file")
                print("DEBUG: fileName: \(fileName)")
                print("DEBUG: fileType from UTI: \(uti ?? "nil")")
                print("DEBUG: fileType being used: \(fileType)")
                
                do {
                    let vaultItem = try self.saveFile(data: data, fileName: fileName, fileType: fileType, targetFolder: targetFolder)
                    print("DEBUG: Image saved successfully: \(vaultItem.fileName ?? "")")
                    completion(.success(vaultItem))
                } catch {
                    print("DEBUG: Error saving image: \(error)")
                    completion(.failure(error))
                }
            }
        } else if asset.mediaType == .video {
            let videoOptions = PHVideoRequestOptions()
            videoOptions.version = .original
            videoOptions.isNetworkAccessAllowed = true
            videoOptions.deliveryMode = .automatic
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: videoOptions) { avAsset, _, info in
                print("DEBUG: Video asset received: \(avAsset != nil)")
                
                if let error = info?[PHImageErrorKey] as? Error {
                    print("DEBUG: PHImageManager video error: \(error)")
                    completion(.failure(error))
                    return
                }
                
                guard let urlAsset = avAsset as? AVURLAsset else {
                    print("DEBUG: Could not get AVURLAsset")
                    completion(.failure(FileStorageError.importFailed))
                    return
                }
                
                do {
                    let data = try Data(contentsOf: urlAsset.url)
                    print("DEBUG: Video data loaded: \(data.count) bytes")
                    let fileName = asset.value(forKey: "filename") as? String ?? "VID_\(Date().timeIntervalSince1970).mov"
                    let fileType = "video/quicktime"
                    
                    // Use background save for videos to prevent Core Data recursive save errors
                    self.saveFileInBackground(data: data, fileName: fileName, fileType: fileType, targetFolder: targetFolder) { result in
                        switch result {
                        case .success(let vaultItem):
                            print("DEBUG: Video saved successfully: \(vaultItem.fileName ?? "")")
                            completion(.success(vaultItem))
                        case .failure(let error):
                            print("DEBUG: Error saving video: \(error)")
                            completion(.failure(error))
                        }
                    }
                } catch {
                    print("DEBUG: Error loading video data: \(error)")
                    completion(.failure(error))
                }
            }
        } else {
            print("DEBUG: Unsupported media type: \(asset.mediaType.rawValue)")
            completion(.failure(FileStorageError.importFailed))
        }
    }
}

// MARK: - Errors

enum FileStorageError: LocalizedError {
    case noEncryptionKey
    case encryptionFailed
    case decryptionFailed
    case invalidFileName
    case importFailed
    
    var errorDescription: String? {
        switch self {
        case .noEncryptionKey:
            return "Encryption key not set. Please authenticate first."
        case .encryptionFailed:
            return "Failed to encrypt file."
        case .decryptionFailed:
            return "Failed to decrypt file."
        case .invalidFileName:
            return "Invalid file name."
        case .importFailed:
            return "Failed to import file from photo library."
        }
    }
} 