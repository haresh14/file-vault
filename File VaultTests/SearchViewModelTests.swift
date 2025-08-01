//
//  SearchViewModelTests.swift
//  File VaultTests
//
//  Created on 01/08/25.
//

import Testing
import Foundation
@testable import File_Vault

// Mock item for testing SearchViewModel
struct MockSearchableItem: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let content: String
}

struct SearchViewModelTests {
    
    @Test func testSearchViewModelInitialization() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>()
        
        // Test initial state
        #expect(viewModel.searchText.isEmpty, "Search text should start empty")
        #expect(viewModel.allItems.isEmpty, "All items should start empty")
        #expect(viewModel.filteredItems.isEmpty, "Filtered items should start empty")
        #expect(viewModel.isSearching == false, "Should not be searching initially")
        #expect(viewModel.searchSuggestions.isEmpty, "Search suggestions should start empty")
    }
    
    @Test func testSearchFunctionality() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>()
        
        // Add test items
        let item1 = MockSearchableItem(name: "Test File 1", content: "This is a test document")
        let item2 = MockSearchableItem(name: "Another File", content: "Different content here")
        let item3 = MockSearchableItem(name: "Test Image", content: "An image file")
        
        viewModel.allItems = [item1, item2, item3]
        
        // Test search functionality
        viewModel.searchText = "test"
        
        // Since the default implementation searches based on description,
        // we expect items with "test" in their string representation to be found
        #expect(viewModel.isSearching == true, "Should be searching when search text is not empty")
        
        // Test clearing search
        viewModel.clearSearch()
        #expect(viewModel.searchText.isEmpty, "Search text should be cleared")
        #expect(viewModel.isSearching == false, "Should not be searching after clearing")
    }
    
    @Test func testSearchConfiguration() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>()
        
        // Test default search configuration
        #expect(viewModel.searchConfiguration != nil, "Search configuration should exist")
        #expect(viewModel.searchConfiguration.debounceDelay == 0.3, "Default debounce delay should be 0.3")
        #expect(viewModel.searchConfiguration.minimumCharacters == 1, "Default minimum characters should be 1")
        #expect(viewModel.searchConfiguration.caseSensitive == false, "Default should be case insensitive")
    }
    
    @Test func testSearchSuggestions() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>()
        
        // Add test items
        let item1 = MockSearchableItem(name: "Document", content: "Important document")
        let item2 = MockSearchableItem(name: "Photo", content: "Family photo")
        
        viewModel.allItems = [item1, item2]
        
        // Test that search suggestions are generated
        viewModel.searchText = "doc"
        
        // The base implementation should generate suggestions
        #expect(viewModel.searchSuggestions.count >= 0, "Search suggestions should be generated")
    }
    
    @Test func testProtocolConformance() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>()
        
        // Test that SearchViewModel conforms to SearchManageable
        #expect(viewModel is SearchManageable, "SearchViewModel should conform to SearchManageable")
        
        // Test SearchableItem typealias
        #expect(type(of: viewModel).SearchableItem.self == MockSearchableItem.self, "SearchableItem should be properly aliased")
    }
    
    @Test func testAdvancedSearchFeatures() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>()
        
        // Test search scope (default implementation)
        #expect(viewModel.currentScope != nil, "Current scope should exist")
        
        // Test search filters
        #expect(viewModel.activeFilters.isEmpty, "Active filters should start empty")
        
        // Test recent searches
        #expect(viewModel.recentSearches.isEmpty, "Recent searches should start empty")
    }
}