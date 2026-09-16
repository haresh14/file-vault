//
//  VaultItem+CoreDataClass.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import CoreData

@objc(VaultItem)
public class VaultItem: NSManagedObject {

    public override func awakeFromFetch() {
        super.awakeFromFetch()
        VaultMetadataSealer.sealer(for: self)?.reveal(self)
    }

    public override func awake(fromSnapshotEvents flags: NSSnapshotEventType) {
        super.awake(fromSnapshotEvents: flags)
        VaultMetadataSealer.sealer(for: self)?.reveal(self)
    }
} 