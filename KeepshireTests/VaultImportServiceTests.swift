import Foundation
import Testing
@testable import Keepshire

@MainActor
struct VaultImportServiceTests {
    @Test func documentsUseTargetFolderAndReportEveryItem() {
        let coreData = TestCoreDataStore.reset()
        let storage = FakeFileStorageManager(coreDataManager: coreData)
        let service = VaultImportService(fileStorageManager: storage)
        let folder = coreData.createFolder(name: "Target", parent: nil)!
        var progress: [(Double, Double)] = []
        var completed = false

        service.importDocuments(
            [(Data("one".utf8), "one.pdf"), (Data("two".utf8), "two.txt")],
            targetFolder: folder,
            progress: { progress.append(($0, $1)) },
            completion: { completed = true }
        )

        #expect(storage.saves.count == 2)
        #expect(storage.saves.allSatisfy { $0.targetFolder == folder })
        #expect(progress.map(\.0) == [1, 2])
        #expect(progress.map(\.1) == [2, 2])
        #expect(completed)
    }

    @Test func duplicateDocumentsStillAdvanceProgressAndComplete() {
        let coreData = TestCoreDataStore.reset()
        let storage = FakeFileStorageManager(coreDataManager: coreData)
        storage.duplicateFileNames = ["duplicate.pdf"]
        let service = VaultImportService(fileStorageManager: storage)
        var progress = 0.0
        var completed = false

        service.importDocuments(
            [(Data(), "duplicate.pdf")],
            targetFolder: nil,
            progress: { progress = $0 / $1 },
            completion: { completed = true }
        )

        #expect(storage.saves.count == 1)
        #expect(progress == 1)
        #expect(completed)
    }
}
