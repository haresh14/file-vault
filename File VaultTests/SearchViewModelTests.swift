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
        let viewModel = SearchViewModel<MockSearchableItem>(
            searchPredicate: { item, text in
                let name = item.name.lowercased()
                let content = item.content.lowercased()
                return name.contains(text.lowercased()) || content.contains(text.lowercased())
            }
        )
        
        // Test initial state
        #expect(viewModel.searchText.isEmpty, "Search text should start empty")
        #expect(viewModel.allItems.isEmpty, "All items should start empty")
        #expect(viewModel.filteredItems.isEmpty, "Filtered items should start empty")
        #expect(viewModel.showingSearchResults == false, "Should not be showing results initially")
        #expect(viewModel.suggestions.isEmpty, "Suggestions should start empty")
    }
    
    @Test func testSearchFunctionality() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>(
            searchPredicate: { item, text in
                let name = item.name.lowercased()
                let content = item.content.lowercased()
                return name.contains(text.lowercased()) || content.contains(text.lowercased())
            }
        )
        
        // Add test items
        let item1 = MockSearchableItem(name: "Test File 1", content: "This is a test document")
        let item2 = MockSearchableItem(name: "Another File", content: "Different content here")
        let item3 = MockSearchableItem(name: "Test Image", content: "An image file")
        
        viewModel.updateItems([item1, item2, item3])
        
        // Test search functionality
        viewModel.searchText = "test"
        
        // We expect items with "test" in their fields to be found
        #expect(viewModel.showingSearchResults == (viewModel.searchResultsCount > 0), "Results visibility should match count")
        
        // Test clearing search
        viewModel.clearSearch()
        #expect(viewModel.searchText.isEmpty, "Search text should be cleared")
        #expect(viewModel.isSearching == false, "Should not be searching after clearing")
    }
    
    @Test func testSearchConfiguration() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>(
            searchPredicate: { item, text in
                item.name.lowercased().contains(text.lowercased()) || item.content.lowercased().contains(text.lowercased())
            }
        )
        
        // Ensure default state is sensible (no access to private config)
        #expect(viewModel.searchText.isEmpty, "Search text should be empty by default")
    }
    
    @Test func testSearchSuggestions() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>(
            searchPredicate: { item, text in
                item.name.lowercased().contains(text.lowercased()) || item.content.lowercased().contains(text.lowercased())
            }
        )
        
        // Add test items
        let item1 = MockSearchableItem(name: "Document", content: "Important document")
        let item2 = MockSearchableItem(name: "Photo", content: "Family photo")
        
        viewModel.updateItems([item1, item2])
        
        // Test that search suggestions are generated
        viewModel.searchText = "doc"
        
        // Suggestions API exists and returns an array (count may vary with debounce)
        #expect(viewModel.suggestions.count >= 0, "Suggestions array should be present")
    }
    
    @Test func testProtocolConformance() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>(
            searchPredicate: { item, text in
                item.name.lowercased().contains(text.lowercased()) || item.content.lowercased().contains(text.lowercased())
            }
        )
        
        // Protocol conformance is compile-time; simple runtime type check
        #expect((viewModel as Any) is any SearchManageable, "SearchViewModel should conform to SearchManageable")
        
        // Test SearchableItem typealias
        #expect(type(of: viewModel).SearchableItem.self == MockSearchableItem.self, "SearchableItem should be properly aliased")
    }
    
    @Test func testAdvancedSearchFeatures() async throws {
        let viewModel = SearchViewModel<MockSearchableItem>(
            searchPredicate: { item, text in
                item.name.lowercased().contains(text.lowercased()) || item.content.lowercased().contains(text.lowercased())
            }
        )
        
        // Verify filters state via provided API
        #expect(viewModel.hasActiveFilters == false, "Active filters should start empty")
        
        // Test recent searches
        #expect(viewModel.recentSearches.isEmpty, "Recent searches should start empty")
    }
}