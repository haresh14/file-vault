import Foundation
import CryptoKit

enum VaultBlobFormat {
    static let magic = Data("KSHC".utf8)
    static let version: UInt8 = 1
    static let headerByteCount = 12
    static let chunkPlaintextSize = 1_048_576
    static let inMemoryThreshold = 16 * 1_048_576
    static let hardCap: Int64 = 2 * 1024 * 1024 * 1024
}

final class EncryptedFileStore {
    private let fileManager: FileManager
    private let vaultDirectory: URL
    private let cryptoService: VaultCryptoService
    var plaintextChunkThreshold = VaultBlobFormat.inMemoryThreshold

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
        try rejectIfTooLarge(Int64(data.count))
        if data.count < plaintextChunkThreshold {
            try writeAtomically(cryptoService.encrypt(data, using: key), fileName: fileName)
            return
        }
        try writeChunked(from: data, fileName: fileName, key: key)
    }

    func write(fromFileURL source: URL, fileName: String, key: SymmetricKey) throws {
        let size = try fileSize(at: source)
        try rejectIfTooLarge(size)
        if size < Int64(plaintextChunkThreshold) {
            try write(Data(contentsOf: source, options: [.mappedIfSafe]), fileName: fileName, key: key)
            return
        }
        try writeChunked(fromFileURL: source, fileName: fileName, key: key)
    }

    func read(fileName: String, key: SymmetricKey) throws -> Data {
        let fileURL = url(for: fileName)
        let handle = try FileHandle(forReadingFrom: fileURL)
        defer { try? handle.close() }
        let prefix = try handle.read(upToCount: VaultBlobFormat.magic.count) ?? Data()
        try handle.seek(toOffset: 0)
        if prefix == VaultBlobFormat.magic {
            return try decryptChunked(handle: handle, key: key)
        }
        let encryptedData = try Data(contentsOf: fileURL)
        return try cryptoService.decrypt(encryptedData, using: key)
    }

    func reencrypt(fileName: String, oldKey: SymmetricKey, newKey: SymmetricKey) throws {
        let plaintext = try read(fileName: fileName, key: oldKey)
        try write(plaintext, fileName: fileName, key: newKey)
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

    private func rejectIfTooLarge(_ size: Int64) throws {
        if size > VaultBlobFormat.hardCap {
            throw FileStorageError.fileTooLarge
        }
    }

    private func fileSize(at url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        return Int64(values.fileSize ?? 0)
    }

    private func writeAtomically(_ data: Data, fileName: String) throws {
        let destination = url(for: fileName)
        let temporary = destination.appendingPathExtension("tmp")
        try data.write(to: temporary, options: .atomic)
        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    private func writeChunked(from data: Data, fileName: String, key: SymmetricKey) throws {
        try writeChunked(fileName: fileName, key: key) { bufferSize, consume in
            var offset = 0
            while offset < data.count {
                let end = min(offset + bufferSize, data.count)
                try consume(data.subdata(in: offset..<end))
                offset = end
            }
        }
    }

    private func writeChunked(fromFileURL source: URL, fileName: String, key: SymmetricKey) throws {
        try writeChunked(fileName: fileName, key: key) { bufferSize, consume in
            let handle = try FileHandle(forReadingFrom: source)
            defer { try? handle.close() }
            while true {
                let chunk = try handle.read(upToCount: bufferSize) ?? Data()
                if chunk.isEmpty { break }
                try consume(chunk)
            }
        }
    }

    private func writeChunked(
        fileName: String,
        key: SymmetricKey,
        readPlaintext: (Int, (Data) throws -> Void) throws -> Void
    ) throws {
        let destination = url(for: fileName)
        let temporary = destination.appendingPathExtension("tmp")
        if fileManager.fileExists(atPath: temporary.path) {
            try fileManager.removeItem(at: temporary)
        }
        fileManager.createFile(atPath: temporary.path, contents: nil)
        let handle = try FileHandle(forWritingTo: temporary)
        defer { try? handle.close() }

        var header = VaultBlobFormat.magic
        header.append(VaultBlobFormat.version)
        header.append(contentsOf: [0, 0, 0])
        header.append(contentsOf: UInt32(VaultBlobFormat.chunkPlaintextSize).bigEndianBytes)
        try handle.write(contentsOf: header)

        try readPlaintext(VaultBlobFormat.chunkPlaintextSize) { plaintext in
            let sealed = try cryptoService.encrypt(plaintext, using: key)
            try handle.write(contentsOf: UInt32(sealed.count).bigEndianBytes)
            try handle.write(contentsOf: sealed)
        }

        if fileManager.fileExists(atPath: destination.path) {
            _ = try fileManager.replaceItemAt(destination, withItemAt: temporary)
        } else {
            try fileManager.moveItem(at: temporary, to: destination)
        }
    }

    private func decryptChunked(handle: FileHandle, key: SymmetricKey) throws -> Data {
        let header = try handle.read(upToCount: VaultBlobFormat.headerByteCount) ?? Data()
        guard header.count == VaultBlobFormat.headerByteCount,
              header.prefix(4) == VaultBlobFormat.magic,
              header[4] == VaultBlobFormat.version else {
            throw FileStorageError.decryptionFailed
        }

        var plaintext = Data()
        while true {
            let lengthBytes = try handle.read(upToCount: 4) ?? Data()
            if lengthBytes.isEmpty { break }
            guard lengthBytes.count == 4 else { throw FileStorageError.decryptionFailed }
            let sealedLength = Int(lengthBytes.uint32BigEndian)
            guard sealedLength > 0 else { throw FileStorageError.decryptionFailed }
            let sealed = try handle.read(upToCount: sealedLength) ?? Data()
            guard sealed.count == sealedLength else { throw FileStorageError.decryptionFailed }
            plaintext.append(try cryptoService.decrypt(sealed, using: key))
        }
        return plaintext
    }
}

private extension UInt32 {
    var bigEndianBytes: Data {
        var value = bigEndian
        return Data(bytes: &value, count: MemoryLayout<UInt32>.size)
    }
}

private extension Data {
    var uint32BigEndian: UInt32 {
        reduce(UInt32(0)) { ($0 << 8) | UInt32($1) }
    }
}
