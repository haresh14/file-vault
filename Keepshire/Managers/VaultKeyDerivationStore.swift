import Foundation

protocol VaultKeyDerivationStoring {
    func loadRecord() -> VaultKeyDerivationRecord?
    func saveRecord(_ record: VaultKeyDerivationRecord) throws
    func deleteRecord()
}

final class InMemoryVaultKeyDerivationStore: VaultKeyDerivationStoring {
    private var record: VaultKeyDerivationRecord?

    func loadRecord() -> VaultKeyDerivationRecord? {
        record
    }

    func saveRecord(_ record: VaultKeyDerivationRecord) throws {
        self.record = record
    }

    func deleteRecord() {
        record = nil
    }
}

final class KeychainVaultKeyDerivationStore: VaultKeyDerivationStoring {
    private let keychain: KeychainManager

    init(keychain: KeychainManager) {
        self.keychain = keychain
    }

    func loadRecord() -> VaultKeyDerivationRecord? {
        keychain.loadKeyDerivationRecord()
    }

    func saveRecord(_ record: VaultKeyDerivationRecord) throws {
        try keychain.saveKeyDerivationRecord(record)
    }

    func deleteRecord() {
        keychain.deleteKeyDerivationRecord()
    }
}
