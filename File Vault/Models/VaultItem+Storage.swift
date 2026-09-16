import Foundation

extension VaultItem {
    /// On-disk ciphertext name. Display name stays in `fileName` for search and UI.
    var storedBlobName: String? {
        id?.uuidString
    }

    var storedThumbnailName: String? {
        storedBlobName.map { "\($0).thumb" }
    }

    /// Every ciphertext name this item can own on disk, including pre-UUID layouts.
    /// Read these before deleting the object: a deleted item reports no id or name.
    var storedBlobCandidates: Set<String> {
        Set([storedBlobName, fileName].compactMap { $0 })
    }

    var storedThumbnailCandidates: Set<String> {
        var names = Set([storedThumbnailName, thumbnailFileName].compactMap { $0 })
        if let fileName {
            names.insert("thumb_\(fileName).jpg")
        }
        return names
    }
}
