import Foundation
import Testing
@testable import File_Vault

@MainActor
struct FolderViewModelTests {
    @Test func sortingSelectionAndMediaIndexMatchDisplayedOrder() {
        let coreData = TestCoreDataStore.reset()
        let login = FakeLoginStateManager()
        let storage = FakeFileStorageManager(coreDataManager: coreData)
        let older = coreData.createVaultItem(fileType: "image/jpeg", fileName: "Zulu.jpg", folder: nil)!
        older.createdAt = Date(timeIntervalSince1970: 1)
        let newer = coreData.createVaultItem(fileType: "video/quicktime", fileName: "Alpha.mov", folder: nil)!
        newer.createdAt = Date(timeIntervalSince1970: 2)
        coreData.save()

        let viewModel = FolderViewModel(
            folder: nil,
            coreDataManager: coreData,
            fileStorageManager: storage,
            loginStateManager: login
        )

        viewModel.sortOption = .name
        viewModel.sortAscending = true
        #expect(viewModel.sortedFiles.map(\.fileName) == ["Alpha.mov", "Zulu.jpg"])

        viewModel.selectAll()
        #expect(viewModel.selectedFiles == Set([older, newer]))

        viewModel.showMediaViewerForFile(older)
        #expect(viewModel.mediaViewerIndex == 1)
        #expect(viewModel.showUnifiedMediaViewer)
    }

    @Test func fakeVaultFiltersContent() {
        let coreData = TestCoreDataStore.reset()
        _ = coreData.createVaultItem(fileType: "image/jpeg", fileName: "Hidden.jpg", folder: nil)
        let login = FakeLoginStateManager()
        login.setLoginState(isFakeLogin: true)

        let viewModel = FolderViewModel(
            folder: nil,
            coreDataManager: coreData,
            fileStorageManager: FakeFileStorageManager(coreDataManager: coreData),
            loginStateManager: login
        )

        #expect(viewModel.files.isEmpty)
        #expect(viewModel.sortedFiles.isEmpty)
    }

    @Test func importsPassCurrentFolderAndExposeProgress() {
        let coreData = TestCoreDataStore.reset()
        let folder = coreData.createFolder(name: "Imports", parent: nil)!
        let importService = FakeVaultImportService()
        let viewModel = FolderViewModel(
            folder: folder,
            coreDataManager: coreData,
            fileStorageManager: FakeFileStorageManager(coreDataManager: coreData),
            importService: importService,
            loginStateManager: FakeLoginStateManager()
        )

        viewModel.showDocumentPicker = true
        viewModel.importDocuments([(Data(), "document.pdf")])

        #expect(importService.documentTargetFolder == folder)
        #expect(importService.importedDocumentNames == ["document.pdf"])
        #expect(viewModel.showDocumentPicker == false)
        #expect(viewModel.isImporting == false)
    }
}
