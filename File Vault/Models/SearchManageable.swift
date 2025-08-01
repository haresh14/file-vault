//
//  SearchManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Protocol for managing search functionality in ViewModels
protocol SearchManageable: ObservableObject {
    associatedtype SearchableItem
    
    /// The current search text
    var searchText: String { get set }
    
    /// Whether search is currently active
    var isSearching: Bool { get }
    
    /// All available items to search through
    var allItems: [SearchableItem] { get }
    
    /// Filtered items based on search criteria
    var filteredItems: [SearchableItem] { get }
    
    /// Perform search on items
    func search(text: String, in items: [SearchableItem]) -> [SearchableItem]
    
    /// Clear search and reset to all items
    func clearSearch()
    
    /// Check if search text matches an item
    func matches(item: SearchableItem, searchText: String) -> Bool
}

/// Default implementation for SearchManageable protocol
extension SearchManageable {
    var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var filteredItems: [SearchableItem] {
        isSearching ? search(text: searchText, in: allItems) : allItems
    }
    
    func search(text: String, in items: [SearchableItem]) -> [SearchableItem] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return items }
        
        return items.filter { matches(item: $0, searchText: trimmedText) }
    }
    
    func clearSearch() {
        searchText = ""
    }
}

/// Configuration for search behavior
struct SearchConfiguration {
    /// Placeholder text for search field
    let placeholder: String
    
    /// Whether search should be case sensitive
    let caseSensitive: Bool
    
    /// Whether to search by word boundaries only
    let wholeWords: Bool
    
    /// Minimum characters required to trigger search
    let minimumCharacters: Int
    
    /// Debounce delay for search (in seconds)
    let debounceDelay: Double
    
    /// Whether to show search suggestions
    let showSuggestions: Bool
    
    /// Custom search icon
    let searchIcon: String
    
    /// Custom clear icon
    let clearIcon: String
    
    init(
        placeholder: String = "Search...",
        caseSensitive: Bool = false,
        wholeWords: Bool = false,
        minimumCharacters: Int = 1,
        debounceDelay: Double = 0.3,
        showSuggestions: Bool = false,
        searchIcon: String = "magnifyingglass",
        clearIcon: String = "xmark.circle.fill"
    ) {
        self.placeholder = placeholder
        self.caseSensitive = caseSensitive
        self.wholeWords = wholeWords
        self.minimumCharacters = minimumCharacters
        self.debounceDelay = debounceDelay
        self.showSuggestions = showSuggestions
        self.searchIcon = searchIcon
        self.clearIcon = clearIcon
    }
}

/// Enhanced search configuration for specific use cases
extension SearchConfiguration {
    static let fileSearch = SearchConfiguration(
        placeholder: "Search files",
        minimumCharacters: 1,
        debounceDelay: 0.2
    )
    
    static let folderSearch = SearchConfiguration(
        placeholder: "Search folders",
        minimumCharacters: 1,
        debounceDelay: 0.2
    )
    
    static let documentSearch = SearchConfiguration(
        placeholder: "Search documents",
        minimumCharacters: 2,
        debounceDelay: 0.3
    )
    
    static let mediaSearch = SearchConfiguration(
        placeholder: "Search photos & videos",
        minimumCharacters: 1,
        debounceDelay: 0.2
    )
    
    static let categorySearch = SearchConfiguration(
        placeholder: "Search categories",
        minimumCharacters: 1,
        debounceDelay: 0.1
    )
}

/// Search result highlighting for displaying matched text
struct SearchHighlight {
    let text: String
    let ranges: [Range<String.Index>]
    
    static func highlight(in text: String, searchText: String) -> SearchHighlight {
        let ranges = text.ranges(of: searchText, options: .caseInsensitive)
        return SearchHighlight(text: text, ranges: ranges)
    }
}

private extension String {
    func ranges(of searchString: String, options: CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = startIndex
        
        while searchStartIndex < endIndex,
              let range = range(of: searchString, options: options, range: searchStartIndex..<endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }
        
        return ranges
    }
}