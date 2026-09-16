import Foundation
import CoreData
import CryptoKit

struct SealedVaultItemPayload: Codable, Equatable {
    var fileName: String
    var fileType: String
    var fileSize: Int64
    var thumbnailFileName: String?
}

struct SealedFolderPayload: Codable, Equatable {
    var name: String
}

/// Encrypts display names, MIME types, and sizes into `sealedMetadata` before a Core Data
/// save, then restores them in RAM so search and the gallery keep working after unlock.
///
/// `VaultItem` and `Folder` call `reveal` every time Core Data materializes them, so the
/// decrypted values survive faulting, refetching, and context merges.
final class VaultMetadataSealer {
    /// Managed objects cannot take injected dependencies, so each sealer registers itself
    /// against the coordinator of the stack it protects and objects look it up from there.
    private static let registry = NSMapTable<NSPersistentStoreCoordinator, VaultMetadataSealer>.weakToWeakObjects()
    private static let registryLock = NSLock()

    static func sealer(for object: NSManagedObject) -> VaultMetadataSealer? {
        guard let coordinator = object.managedObjectContext?.persistentStoreCoordinator else { return nil }
        registryLock.lock()
        defer { registryLock.unlock() }
        return registry.object(forKey: coordinator)
    }

    private weak var coordinator: NSPersistentStoreCoordinator?
    private let cryptoService: VaultCryptoService
    var key: SymmetricKey?

    init(cryptoService: VaultCryptoService) {
        self.cryptoService = cryptoService
    }

    /// Binds the sealer to one Core Data stack so saves and reveals never touch another store.
    func attach(to coordinator: NSPersistentStoreCoordinator?) {
        guard let coordinator else { return }
        self.coordinator = coordinator
        VaultMetadataSealer.registryLock.lock()
        VaultMetadataSealer.registry.setObject(self, forKey: coordinator)
        VaultMetadataSealer.registryLock.unlock()
    }

    private func owns(_ context: NSManagedObjectContext) -> Bool {
        context.persistentStoreCoordinator === coordinator
    }

    func reveal(_ item: VaultItem) {
        guard let key else { return }
        reveal(item, key: key, markDirty: false)
    }

    func reveal(_ folder: Folder) {
        guard let key else { return }
        reveal(folder, key: key, markDirty: false)
    }

    func prepareForSave(_ context: NSManagedObjectContext) {
        guard let key, owns(context) else { return }
        let objects = context.insertedObjects.union(context.updatedObjects)
        for case let item as VaultItem in objects {
            persist(item, key: key)
        }
        for case let folder as Folder in objects {
            persist(folder, key: key)
        }
    }

    func restoreAfterSave(from notification: Notification) {
        guard let key,
              let context = notification.object as? NSManagedObjectContext, owns(context),
              let userInfo = notification.userInfo else { return }
        let inserted = userInfo[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
        let updated = userInfo[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
        for case let item as VaultItem in inserted.union(updated) {
            reveal(item, key: key, markDirty: false)
        }
        for case let folder as Folder in inserted.union(updated) {
            reveal(folder, key: key, markDirty: false)
        }
    }

    /// Drops objects materialized before the key arrived back to faults, so each one decrypts
    /// on first access instead of decrypting the whole vault up front.
    func revealLazily(in context: NSManagedObjectContext) {
        guard key != nil, owns(context) else { return }
        context.refreshAllObjects()
    }

    /// Copies plaintext left by older builds into sealed blobs. The predicate keeps this a
    /// no-op lookup once a vault is fully sealed.
    func sealLegacyPlaintext(in context: NSManagedObjectContext) -> Bool {
        guard let key, owns(context) else { return false }
        var changed = false
        let items: [VaultItem] = fetchUnsealed(entity: "VaultItem", plaintextKey: "fileName", in: context)
        for item in items {
            persist(item, key: key)
            changed = true
        }
        let folders: [Folder] = fetchUnsealed(entity: "Folder", plaintextKey: "name", in: context)
        for folder in folders {
            persist(folder, key: key)
            changed = true
        }
        return changed
    }

    private func fetchUnsealed<T: NSManagedObject>(
        entity: String,
        plaintextKey: String,
        in context: NSManagedObjectContext
    ) -> [T] {
        let request = NSFetchRequest<T>(entityName: entity)
        request.predicate = NSPredicate(format: "sealedMetadata == nil AND %K != nil AND %K != ''", plaintextKey, plaintextKey)
        return (try? context.fetch(request)) ?? []
    }

    func reencryptAll(items: [VaultItem], folders: [Folder], oldKey: SymmetricKey, newKey: SymmetricKey) {
        for item in items {
            if !reveal(item, key: oldKey, markDirty: false) {
                reveal(item, key: newKey, markDirty: false)
            }
            persist(item, key: newKey)
        }
        for folder in folders {
            if !reveal(folder, key: oldKey, markDirty: false) {
                reveal(folder, key: newKey, markDirty: false)
            }
            persist(folder, key: newKey)
        }
        key = newKey
    }

    private func persist(_ item: VaultItem, key: SymmetricKey) {
        let name = item.fileName ?? ""
        if name.isEmpty {
            return
        }
        let payload = SealedVaultItemPayload(
            fileName: name,
            fileType: item.fileType ?? "application/octet-stream",
            fileSize: item.fileSize,
            thumbnailFileName: item.thumbnailFileName
        )
        guard let json = try? JSONEncoder().encode(payload),
              let sealed = try? cryptoService.encrypt(json, using: key) else { return }
        item.sealedMetadata = sealed
        item.fileName = nil
        item.fileType = nil
        item.fileSize = 0
        item.thumbnailFileName = nil
    }

    private func persist(_ folder: Folder, key: SymmetricKey) {
        let name = folder.name ?? ""
        if name.isEmpty { return }
        let payload = SealedFolderPayload(name: name)
        guard let json = try? JSONEncoder().encode(payload),
              let sealed = try? cryptoService.encrypt(json, using: key) else { return }
        folder.sealedMetadata = sealed
        folder.name = nil
    }

    @discardableResult
    private func reveal(_ item: VaultItem, key: SymmetricKey, markDirty: Bool) -> Bool {
        guard let blob = item.sealedMetadata,
              let json = try? cryptoService.decrypt(blob, using: key),
              let payload = try? JSONDecoder().decode(SealedVaultItemPayload.self, from: json) else {
            return false
        }
        assign(item, fileName: payload.fileName, fileType: payload.fileType, fileSize: payload.fileSize, thumbnailFileName: payload.thumbnailFileName, markDirty: markDirty)
        return true
    }

    @discardableResult
    private func reveal(_ folder: Folder, key: SymmetricKey, markDirty: Bool) -> Bool {
        guard let blob = folder.sealedMetadata,
              let json = try? cryptoService.decrypt(blob, using: key),
              let payload = try? JSONDecoder().decode(SealedFolderPayload.self, from: json) else {
            return false
        }
        assign(folder, name: payload.name, markDirty: markDirty)
        return true
    }

    private func assign(
        _ item: VaultItem,
        fileName: String,
        fileType: String,
        fileSize: Int64,
        thumbnailFileName: String?,
        markDirty: Bool
    ) {
        if markDirty {
            item.fileName = fileName
            item.fileType = fileType
            item.fileSize = fileSize
            item.thumbnailFileName = thumbnailFileName
            return
        }
        item.setPrimitiveValue(fileName, forKey: "fileName")
        item.setPrimitiveValue(fileType, forKey: "fileType")
        item.setPrimitiveValue(NSNumber(value: fileSize), forKey: "fileSize")
        item.setPrimitiveValue(thumbnailFileName, forKey: "thumbnailFileName")
    }

    private func assign(_ folder: Folder, name: String, markDirty: Bool) {
        if markDirty {
            folder.name = name
            return
        }
        folder.setPrimitiveValue(name, forKey: "name")
    }
}

enum BackupExclusion {
    static func excludeFromBackup(_ url: URL) {
        var fileURL = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? fileURL.setResourceValues(values)
    }
}
