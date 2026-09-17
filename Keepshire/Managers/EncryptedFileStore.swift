import Foundation
import CryptoKit

final class EncryptedFileStore {
    private let fileManager: FileManager
    private let vaultDirectory: URL
    private let cryptoService: VaultCryptoService

    init(
        fileManager: FileManager,
        vaultDirectory: URL,
        cryptoService: VaultCryptoService = VaultCryptoService()
    ) {
        self.fileManager = fileManager
        self.vaultDirectory = vaultDirectory
        self.cryptoService = cryptoService
    }

    func write(_ data: Data, fileName: String, key: SymmetricKey) throws {
        let encryptedData = try cryptoService.encrypt(data, using: key)
        try encryptedData.write(to: url(for: fileName))
    }

    func read(fileName: String, key: SymmetricKey) throws -> Data {
        let encryptedData = try Data(contentsOf: url(for: fileName))
        return try cryptoService.decrypt(encryptedData, using: key)
    }

    func move(from oldFileName: String, to newFileName: String) throws {
        try fileManager.moveItem(at: url(for: oldFileName), to: url(for: newFileName))
    }

    func exists(fileName: String) -> Bool {
        fileManager.fileExists(atPath: url(for: fileName).path)
    }

    func url(for fileName: String) -> URL {
        vaultDirectory.appendingPathComponent(fileName)
    }
}
