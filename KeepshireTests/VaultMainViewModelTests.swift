//
//  VaultMainViewModelTests.swift
//  KeepshireTests
//
//  Created on 01/08/25.
//

import Testing
import Foundation
@testable import Keepshire

@MainActor
struct VaultMainViewModelTests {
    
    @Test func testViewModelInitialization() async throws {
        let viewModel = VaultMainViewModel()
        
        #expect(viewModel.vaultItems.isEmpty, "VaultItems should start empty")
        #expect(viewModel.isSelectionMode == false, "Should not start in selection mode")
        #expect(viewModel.selectedItems.isEmpty, "Selected items should start empty")
        #expect(viewModel.showPhotoPicker == false, "Photo picker should not be shown initially")
        #expect(viewModel.showDocumentPicker == false, "Document picker should not be shown initially")
        #expect(viewModel.isImporting == false, "Should not be importing initially")
    }
    
    @Test func testDependencyInjection() async throws {
        let container = DependencyContainer.createForTesting()
        let viewModel = VaultMainViewModel(dependencies: container)
        
        #expect(viewModel != nil, "ViewModel should initialize with dependency container")
    }
    
    @Test func testSelectionManagement() async throws {
        let viewModel = VaultMainViewModel()
        
        viewModel.enterSelectionMode()
        #expect(viewModel.isSelectionMode == true, "Should enter selection mode")
        #expect(viewModel.selectedItems.isEmpty, "Selected items should still be empty")
        
        viewModel.exitSelectionMode()
        #expect(viewModel.isSelectionMode == false, "Should exit selection mode")
        #expect(viewModel.selectedItems.isEmpty, "Selected items should be cleared")
    }
    
    @Test func testSearchFunctionality() async throws {
        let viewModel = VaultMainViewModel()
        
        viewModel.searchText = "test"
        #expect(viewModel.searchText == "test", "Search text should be set correctly")
        
        viewModel.clearSearch()
        #expect(viewModel.searchText.isEmpty, "Search text should be cleared")
    }
    
    @Test func testImportManagement() async throws {
        let viewModel = VaultMainViewModel()
        
        #expect(viewModel.importProgress == 0.0, "Import progress should start at 0")
        #expect(viewModel.isImporting == false, "Should not be importing initially")
    }
    
    @Test func testMediaViewerManagement() async throws {
        let viewModel = VaultMainViewModel()
        
        #expect(viewModel.showUnifiedMediaViewer == false, "Media viewer should not be shown initially")
        #expect(viewModel.mediaViewerIndex == -1, "Media viewer index should start at -1")
        #expect(viewModel.filePreviewItem == nil, "File preview item should be nil initially")
    }
    
    @Test func testSearchableProtocolImplementation() async throws {
        let viewModel = VaultMainViewModel()
        
        #expect(viewModel.allItems.isEmpty, "All items should be empty initially")
        #expect(viewModel.filteredItems.isEmpty, "Filtered items should be empty initially")
    }

    @Test func testOrderingSearchSelectionAndMediaIndexParity() {
        let coreData = TestCoreDataStore.reset()
        let storage = FakeFileStorageManager(coreDataManager: coreData)
        let login = FakeLoginStateManager()
        let first = coreData.createVaultItem(fileType: "image/jpeg", fileName: "Bravo.jpg", folder: nil)!
        first.createdAt = Date(timeIntervalSince1970: 1)
        let second = coreData.createVaultItem(fileType: "video/quicktime", fileName: "Alpha.mov", folder: nil)!
        second.createdAt = Date(timeIntervalSince1970: 2)
        _ = coreData.createVaultItem(fileType: "application/pdf", fileName: "Ignored.pdf", folder: nil)
        coreData.save()

        let viewModel = VaultMainViewModel(
            coreDataManager: coreData,
            fileStorageManager: storage,
            loginStateManager: login
        )
        viewModel.sortOption = .name
        #expect(viewModel.filteredItems.map(\.fileName) == ["Alpha.mov", "Bravo.jpg"])

        viewModel.searchText = "bravo"
        #expect(viewModel.filteredItems == [first])
        viewModel.selectAll(from: viewModel.filteredItems)
        #expect(viewModel.selectedItems == [first])

        viewModel.searchText = ""
        viewModel.showMediaViewerForItem(first)
        #expect(viewModel.mediaViewerIndex == 1)
    }

    @Test func testFakeVaultFilteringAndInjectedImport() async {
        let coreData = TestCoreDataStore.reset()
        _ = coreData.createVaultItem(fileType: "image/jpeg", fileName: "Hidden.jpg", folder: nil)
        let login = FakeLoginStateManager()
        login.setLoginState(isFakeLogin: true)
        let importer = FakeVaultImportService()
        let viewModel = VaultMainViewModel(
            coreDataManager: coreData,
            fileStorageManager: FakeFileStorageManager(coreDataManager: coreData),
            importService: importer,
            loginStateManager: login
        )

        #expect(viewModel.vaultItems.isEmpty)
        viewModel.showDocumentPicker = true
        viewModel.importDocuments([(Data(), "test.pdf")])
        await Task.yield()
        await Task.yield()

        #expect(importer.documentTargetFolder == nil)
        #expect(viewModel.showDocumentPicker == false)
        #expect(viewModel.isImporting == false)
    }
}
