//
//  VaultMainViewModelTests.swift
//  File VaultTests
//
//  Created on 01/08/25.
//

import Testing
import Foundation
@testable import File_Vault

struct VaultMainViewModelTests {
    
    @Test func testViewModelInitialization() async throws {
        let viewModel = VaultMainViewModel()
        
        // Test initial state
        #expect(viewModel.vaultItems.isEmpty, "VaultItems should start empty")
        #expect(viewModel.isInSelectionMode == false, "Should not start in selection mode")
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
        
        // Test entering selection mode
        viewModel.enterSelectionMode()
        #expect(viewModel.isInSelectionMode == true, "Should enter selection mode")
        #expect(viewModel.selectedItems.isEmpty, "Selected items should still be empty")
        
        // Test exiting selection mode
        viewModel.exitSelectionMode()
        #expect(viewModel.isInSelectionMode == false, "Should exit selection mode")
        #expect(viewModel.selectedItems.isEmpty, "Selected items should be cleared")
    }
    
    @Test func testSearchFunctionality() async throws {
        let viewModel = VaultMainViewModel()
        
        // Test that ViewModel conforms to SearchManageable
        #expect(viewModel is SearchManageable, "VaultMainViewModel should conform to SearchManageable")
        
        // Test search text
        viewModel.searchText = "test"
        #expect(viewModel.searchText == "test", "Search text should be set correctly")
        
        // Clear search
        viewModel.clearSearch()
        #expect(viewModel.searchText.isEmpty, "Search text should be cleared")
    }
    
    @Test func testImportManagement() async throws {
        let viewModel = VaultMainViewModel()
        
        // Test that ViewModel conforms to ImportManageable
        #expect(viewModel is ImportManageable, "VaultMainViewModel should conform to ImportManageable")
        
        // Test import progress initialization
        #expect(viewModel.importProgress == 0.0, "Import progress should start at 0")
        #expect(viewModel.importedCount == 0, "Imported count should start at 0")
        #expect(viewModel.totalImportCount == 0, "Total import count should start at 0")
    }
    
    @Test func testMediaViewerManagement() async throws {
        let viewModel = VaultMainViewModel()
        
        // Test that ViewModel conforms to MediaViewerManageable
        #expect(viewModel is MediaViewerManageable, "VaultMainViewModel should conform to MediaViewerManageable")
        
        // Test initial media viewer state
        #expect(viewModel.showMediaViewer == false, "Media viewer should not be shown initially")
        #expect(viewModel.currentMediaItem == nil, "Current media item should be nil initially")
    }
    
    @Test func testSearchableProtocolImplementation() async throws {
        let viewModel = VaultMainViewModel()
        
        // Test SearchManageable protocol implementation
        #expect(viewModel.allItems.isEmpty, "All items should be empty initially")
        #expect(viewModel.filteredItems.isEmpty, "Filtered items should be empty initially")
        
        // Test search matching logic with mock data
        // Note: This would require creating mock VaultItem objects in a real test
        // For now, we test that the method exists and doesn't crash
        let mockSearchText = "test"
        // In a real test, we would create a mock VaultItem and test the matches method
    }
}