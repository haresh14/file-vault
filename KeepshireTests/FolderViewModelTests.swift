import Foundation
import Testing
@testable import Keepshire

@MainActor
struct FolderViewModelTests {
    @Test func sortingSelectionAndMediaIndexMatchDisplayedOrder() throws {
        let coreData = TestCoreDataStore.reset()
        let login = FakeLoginStateManager()
        let storage = FakeFileStorageManager(coreDataManager: coreData)
        let older = coreData.createVaultItem(fileType: "image/jpeg", fileName: "Zulu.jpg", folder: nil)!
        older.createdAt = Date(timeIntervalSince1970: 1)
        let newer = coreData.createVaultItem(fileType: "video/quicktime", fileName: "Alpha.mov", folder: nil)!
        newer.createdAt = Date(timeIntervalSince1970: 2)
        try coreData.save()

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

    @Test func searchFiltersFolderAndFileNamesAndSelectAllUsesVisibleResults() {
        let coreData = TestCoreDataStore.reset()
        let trip = coreData.createFolder(name: "Summer Trip", parent: nil)!
        _ = coreData.createFolder(name: "Receipts", parent: nil)
        let beach = coreData.createVaultItem(
            fileType: "image/jpeg",
            fileName: "Beach.jpg",
            folder: nil
        )!
        _ = coreData.createVaultItem(
            fileType: "application/pdf",
            fileName: "Invoice.pdf",
            folder: nil
        )
        let viewModel = FolderViewModel(
            folder: nil,
            coreDataManager: coreData,
            fileStorageManager: FakeFileStorageManager(coreDataManager: coreData),
            loginStateManager: FakeLoginStateManager()
        )

        viewModel.searchText = "trip"
        #expect(viewModel.sortedFolders == [trip])
        #expect(viewModel.sortedFiles.isEmpty)

        viewModel.searchText = "beach"
        #expect(viewModel.sortedFolders.isEmpty)
        #expect(viewModel.sortedFiles == [beach])
        viewModel.selectAll()
        #expect(viewModel.selectedFolders.isEmpty)
        #expect(viewModel.selectedFiles == Set([beach]))

        viewModel.searchText = "missing"
        #expect(viewModel.isShowingNoSearchResults)
        viewModel.searchText = ""
        #expect(viewModel.sortedFolders.count == 2)
        #expect(viewModel.sortedFiles.count == 2)
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
