import Foundation

final class TemporarySharingService {
    private let fileManager: FileManager

    init(fileManager: FileManager) {
        self.fileManager = fileManager
    }

    func prepare(data: Data, fileName: String) throws -> URL {
        let url = fileManager.temporaryDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: url)
        try data.write(to: url)
        return url
    }

    func cleanup(at url: URL) {
        try? fileManager.removeItem(at: url)
    }
}
