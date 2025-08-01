//
//  SearchViewModel.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI
import Combine

/// Generic search ViewModel that can be used for different item types
class SearchViewModel<Item>: ObservableObject, SearchManageable {
    typealias SearchableItem = Item
    
    // MARK: - Published Properties
    @Published var searchText: String = ""
    @Published var selectedFilter: String?
    @Published var suggestions: [SearchSuggestion] = []
    @Published var recentSearches: [String] = []
    
    // MARK: - SearchManageable Properties
    var allItems: [Item] { _allItems }
    
    // MARK: - Private Properties
    private var _allItems: [Item] = []
    private let searchPredicate: (Item, String) -> Bool
    private let searchConfiguration: SearchConfiguration
    private let filters: [SearchFilter]
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Computed Properties
    var filteredItems: [Item] {
        let searchFiltered = isSearching ? search(text: searchText, in: allItems) : allItems
        
        guard let filterId = selectedFilter,
              let filter = filters.first(where: { $0.id == filterId }) else {
            return searchFiltered
        }
        
        return searchFiltered.filter { filter.predicate($0) }
    }
    
    var hasActiveFilters: Bool {
        selectedFilter != nil
    }
    
    var searchResultsCount: Int {
        filteredItems.count
    }
    
    var showingSearchResults: Bool {
        isSearching && searchResultsCount > 0
    }
    
    var showingNoResults: Bool {
        isSearching && searchResultsCount == 0
    }
    
    // MARK: - Initialization
    init(
        searchPredicate: @escaping (Item, String) -> Bool,
        configuration: SearchConfiguration = SearchConfiguration(),
        filters: [SearchFilter] = []
    ) {
        self.searchPredicate = searchPredicate
        self.searchConfiguration = configuration
        self.filters = filters
        
        setupBindings()
        loadRecentSearches()
    }
    
    // MARK: - Setup
    private func setupBindings() {
        // Debounce search text changes
        $searchText
            .debounce(for: .seconds(searchConfiguration.debounceDelay), scheduler: DispatchQueue.main)
            .removeDuplicates()
            .sink { [weak self] text in
                self?.handleSearchTextChange(text)
            }
            .store(in: &cancellables)
    }
    
    private func handleSearchTextChange(_ text: String) {
        // Update suggestions based on search text
        updateSuggestions(for: text)
        
        // Save to recent searches if minimum length is met
        if text.count >= searchConfiguration.minimumCharacters && !text.isEmpty {
            addToRecentSearches(text)
        }
    }
    
    // MARK: - SearchManageable Implementation
    func matches(item: Item, searchText: String) -> Bool {
        let text = searchConfiguration.caseSensitive ? searchText : searchText.lowercased()
        return searchPredicate(item, text)
    }
    
    func clearSearch() {
        searchText = ""
        selectedFilter = nil
    }
    
    // MARK: - Public Methods
    func updateItems(_ items: [Item]) {
        _allItems = items
    }
    
    func addFilter(_ filter: SearchFilter) {
        // This would typically be handled during initialization
        // but could be used for dynamic filter addition
    }
    
    func clearFilters() {
        selectedFilter = nil
    }
    
    func selectSuggestion(_ suggestion: SearchSuggestion) {
        searchText = suggestion.text
    }
    
    func clearRecentSearches() {
        recentSearches.removeAll()
        saveRecentSearches()
    }
    
    // MARK: - Suggestions
    private func updateSuggestions(for text: String) {
        guard !text.isEmpty else {
            suggestions = recentSearchesToSuggestions()
            return
        }
        
        // Generate suggestions based on search text and items
        let itemSuggestions = generateItemSuggestions(for: text)
        let recentSuggestions = recentSearchesToSuggestions().filter {
            $0.text.localizedCaseInsensitiveContains(text)
        }
        
        suggestions = (itemSuggestions + recentSuggestions).uniqued()
    }
    
    func generateItemSuggestions(for text: String) -> [SearchSuggestion] {
        // This would be implemented based on the specific item type
        // For example, for VaultItems, we might suggest file names, types, etc.
        return []
    }
    
    private func recentSearchesToSuggestions() -> [SearchSuggestion] {
        return recentSearches.prefix(5).map { searchText in
            SearchSuggestion(
                text: searchText,
                icon: "clock.arrow.circlepath",
                category: "Recent"
            )
        }
    }
    
    // MARK: - Recent Searches
    private func addToRecentSearches(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !recentSearches.contains(trimmed) else { return }
        
        recentSearches.insert(trimmed, at: 0)
        if recentSearches.count > 10 {
            recentSearches = Array(recentSearches.prefix(10))
        }
        
        saveRecentSearches()
    }
    
    private func loadRecentSearches() {
        recentSearches = UserDefaults.standard.stringArray(forKey: "RecentSearches") ?? []
    }
    
    private func saveRecentSearches() {
        UserDefaults.standard.set(recentSearches, forKey: "RecentSearches")
    }
}

// MARK: - Array Extension for Unique Elements
private extension Array where Element: Identifiable {
    func uniqued() -> [Element] {
        var seen = Set<Element.ID>()
        return filter { seen.insert($0.id).inserted }
    }
}

// MARK: - VaultItem Search ViewModel
final class VaultItemSearchViewModel: SearchViewModel<VaultItem> {
    init() {
        super.init(
            searchPredicate: { item, searchText in
                item.fileName?.localizedCaseInsensitiveContains(searchText) ?? false
            },
            configuration: .fileSearch,
            filters: [.images, .videos, .documents]
        )
    }
    
    override func generateItemSuggestions(for text: String) -> [SearchSuggestion] {
        let matchingItems = allItems.prefix(3).compactMap { item -> SearchSuggestion? in
            guard let fileName = item.fileName,
                  fileName.localizedCaseInsensitiveContains(text) else { return nil }
            
            let icon = item.fileType == "image" ? "photo" : 
                      item.fileType == "video" ? "video" :
                      "doc"
            
            return SearchSuggestion(
                text: fileName,
                icon: icon,
                category: item.fileType?.capitalized
            )
        }
        
        return Array(matchingItems)
    }
}

// MARK: - Folder Search ViewModel
final class FolderSearchViewModel: SearchViewModel<Folder> {
    init() {
        super.init(
            searchPredicate: { folder, searchText in
                folder.displayName.localizedCaseInsensitiveContains(searchText)
            },
            configuration: .folderSearch,
            filters: [.folders]
        )
    }
    
    override func generateItemSuggestions(for text: String) -> [SearchSuggestion] {
        let matchingFolders = allItems.prefix(3).compactMap { folder -> SearchSuggestion? in
            guard folder.displayName.localizedCaseInsensitiveContains(text) else { return nil }
            
            return SearchSuggestion(
                text: folder.displayName,
                icon: "folder",
                category: "Folder"
            )
        }
        
        return Array(matchingFolders)
    }
}