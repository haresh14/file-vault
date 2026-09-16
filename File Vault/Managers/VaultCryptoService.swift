import Foundation
import CryptoKit
import CommonCrypto
import Security

struct VaultKeyDerivationRecord: Codable, Equatable {
    static let currentVersion = 1
    static let pbkdf2Algorithm = "pbkdf2-hmac-sha256"
    static let currentIterations = 210_000
    static let saltByteCount = 16
    static let keyByteCount = 32

    let version: Int
    let algorithm: String
    let iterations: Int
    let salt: Data

    static func makeCurrent(salt: Data? = nil) -> VaultKeyDerivationRecord {
        VaultKeyDerivationRecord(
            version: currentVersion,
            algorithm: pbkdf2Algorithm,
            iterations: currentIterations,
            salt: salt ?? randomSalt()
        )
    }

    private static func randomSalt() -> Data {
        var salt = Data(count: saltByteCount)
        let status = salt.withUnsafeMutableBytes { buffer in
            guard let pointer = buffer.baseAddress else { return errSecAllocate }
            return SecRandomCopyBytes(kSecRandomDefault, saltByteCount, pointer)
        }
        if status != errSecSuccess {
            return Data((0..<saltByteCount).map { _ in UInt8.random(in: 0...255) })
        }
        return salt
    }
}

enum VaultCryptoError: Error {
    case keyDerivationFailed
}

struct VaultCryptoService {
    func makeRecord() -> VaultKeyDerivationRecord {
        VaultKeyDerivationRecord.makeCurrent()
    }

    func key(from password: String, record: VaultKeyDerivationRecord) throws -> SymmetricKey {
        SymmetricKey(data: try pbkdf2(password: password, record: record))
    }

    /// Opens vault files that predate the Keychain derivation record.
    func legacySHA256Key(from password: String) -> SymmetricKey {
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

    private func pbkdf2(password: String, record: VaultKeyDerivationRecord) throws -> Data {
        var derived = Data(count: VaultKeyDerivationRecord.keyByteCount)
        let status: Int32 = password.withCString { passwordPointer in
            derived.withUnsafeMutableBytes { derivedBytes in
                record.salt.withUnsafeBytes { saltBytes in
                    CCKeyDerivationPBKDF(
                        CCPBKDFAlgorithm(kCCPBKDF2),
                        passwordPointer,
                        password.utf8.count,
                        saltBytes.bindMemory(to: UInt8.self).baseAddress,
                        record.salt.count,
                        CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
                        UInt32(record.iterations),
                        derivedBytes.bindMemory(to: UInt8.self).baseAddress,
                        VaultKeyDerivationRecord.keyByteCount
                    )
                }
            }
        }
        guard status == kCCSuccess else {
            throw VaultCryptoError.keyDerivationFailed
        }
        return derived
    }
}
