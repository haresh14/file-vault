import Foundation
import CryptoKit

struct VaultCryptoService {
    func key(from password: String) -> SymmetricKey {
        SymmetricKey(data: SHA256.hash(data: Data(password.utf8)))
    }

    func encrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        let sealedBox = try AES.GCM.seal(data, using: key)
        guard let combined = sealedBox.combined else {
            throw FileStorageError.encryptionFailed
        }
        return combined
    }

    func decrypt(_ data: Data, using key: SymmetricKey) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
    }
}
