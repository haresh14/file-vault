import Foundation

final class TemporarySharingService {
    static let directoryName = "keepshire-share"

    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func shareRoot() -> URL {
        fileManager.temporaryDirectory.appendingPathComponent(Self.directoryName, isDirectory: true)
    }

    func prepare(data: Data, fileName: String) throws -> URL {
        let session = shareRoot().appendingPathComponent(UUID().uuidString, isDirectory: true)
        try fileManager.createDirectory(at: session, withIntermediateDirectories: true)
        let safeName = (fileName as NSString).lastPathComponent
        let url = session.appendingPathComponent(safeName.isEmpty ? "file" : safeName)
        try data.write(to: url)
        return url
    }

    func cleanup(at url: URL) {
        let session = url.deletingLastPathComponent()
        if session.lastPathComponent != Self.directoryName,
           session.path.hasPrefix(shareRoot().path) {
            try? fileManager.removeItem(at: session)
        } else {
            try? fileManager.removeItem(at: url)
        }
    }

    func sweepAll() {
        try? fileManager.removeItem(at: shareRoot())
    }
}
