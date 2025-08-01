//
//  SearchableView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Reusable search view component that can be applied to any content
struct SearchableView<Content: View>: View {
    @Binding private var searchText: String
    private let configuration: SearchConfiguration
    private let content: () -> Content
    
    init(
        searchText: Binding<String>,
        configuration: SearchConfiguration = SearchConfiguration(),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self._searchText = searchText
        self.configuration = configuration
        self.content = content
    }
    
    var body: some View {
        content()
            .searchable(
                text: $searchText,
                placement: .navigationBarDrawer(displayMode: .always),
                prompt: configuration.placeholder
            )
    }
}

/// Standalone search bar component
struct SearchBar: View {
    @Binding var text: String
    let configuration: SearchConfiguration
    @FocusState private var isSearchFieldFocused: Bool
    
    init(text: Binding<String>, configuration: SearchConfiguration = SearchConfiguration()) {
        self._text = text
        self.configuration = configuration
    }
    
    var body: some View {
        HStack {
            Image(systemName: configuration.searchIcon)
                .foregroundColor(.secondary)
            
            TextField(configuration.placeholder, text: $text)
                .focused($isSearchFieldFocused)
                .textFieldStyle(PlainTextFieldStyle())
                .autocorrectionDisabled()
                .onSubmit {
                    isSearchFieldFocused = false
                }
            
            if !text.isEmpty {
                Button(action: {
                    text = ""
                    isSearchFieldFocused = false
                }) {
                    Image(systemName: configuration.clearIcon)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(.systemGray6))
        .cornerRadius(10)
    }
}

/// Advanced search bar with filtering options
struct AdvancedSearchBar: View {
    @Binding var searchText: String
    @Binding var selectedFilter: String?
    
    let configuration: SearchConfiguration
    let filters: [SearchFilter]
    @FocusState private var isSearchFieldFocused: Bool
    @State private var showFilters = false
    
    init(
        searchText: Binding<String>,
        selectedFilter: Binding<String?> = .constant(nil),
        configuration: SearchConfiguration = SearchConfiguration(),
        filters: [SearchFilter] = []
    ) {
        self._searchText = searchText
        self._selectedFilter = selectedFilter
        self.configuration = configuration
        self.filters = filters
    }
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: configuration.searchIcon)
                    .foregroundColor(.secondary)
                
                TextField(configuration.placeholder, text: $searchText)
                    .focused($isSearchFieldFocused)
                    .textFieldStyle(PlainTextFieldStyle())
                    .autocorrectionDisabled()
                    .onSubmit {
                        isSearchFieldFocused = false
                    }
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        isSearchFieldFocused = false
                    }) {
                        Image(systemName: configuration.clearIcon)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                if !filters.isEmpty {
                    Button(action: {
                        showFilters.toggle()
                    }) {
                        Image(systemName: "line.horizontal.3.decrease.circle")
                            .foregroundColor(selectedFilter != nil ? .blue : .secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .cornerRadius(10)
            
            if showFilters && !filters.isEmpty {
                FilterChipsView(
                    filters: filters,
                    selectedFilter: $selectedFilter
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

/// Search filter chip view
struct FilterChipsView: View {
    let filters: [SearchFilter]
    @Binding var selectedFilter: String?
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(filters, id: \.id) { filter in
                    FilterChip(
                        filter: filter,
                        isSelected: selectedFilter == filter.id,
                        onTap: {
                            if selectedFilter == filter.id {
                                selectedFilter = nil
                            } else {
                                selectedFilter = filter.id
                            }
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Individual filter chip
struct FilterChip: View {
    let filter: SearchFilter
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                if let icon = filter.icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                Text(filter.title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.blue : Color(.systemGray5))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// Search result with highlighting
struct HighlightedText: View {
    let text: String
    let searchText: String
    let highlightColor: Color
    
    init(text: String, searchText: String, highlightColor: Color = .yellow) {
        self.text = text
        self.searchText = searchText
        self.highlightColor = highlightColor
    }
    
    var body: some View {
        if searchText.isEmpty {
            Text(text)
        } else {
            let highlight = SearchHighlight.highlight(in: text, searchText: searchText)
            highlightedText(highlight)
        }
    }
    
    private func highlightedText(_ highlight: SearchHighlight) -> some View {
        var result = Text("")
        var lastIndex = highlight.text.startIndex
        
        for range in highlight.ranges {
            // Add text before highlight
            if lastIndex < range.lowerBound {
                result = result + Text(String(highlight.text[lastIndex..<range.lowerBound]))
            }
            
            // Add highlighted text
            result = result + Text(String(highlight.text[range]))
            
            lastIndex = range.upperBound
        }
        
        // Add remaining text
        if lastIndex < highlight.text.endIndex {
            result = result + Text(String(highlight.text[lastIndex...]))
        }
        
        return result
    }
}

/// Search suggestion item
struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let icon: String?
    let category: String?
    
    init(text: String, icon: String? = nil, category: String? = nil) {
        self.text = text
        self.icon = icon
        self.category = category
    }
}

/// Search suggestions view
struct SearchSuggestionsView: View {
    let suggestions: [SearchSuggestion]
    let onSuggestionTap: (SearchSuggestion) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(suggestions) { suggestion in
                Button(action: {
                    onSuggestionTap(suggestion)
                }) {
                    HStack {
                        if let icon = suggestion.icon {
                            Image(systemName: icon)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                        }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.text)
                                .foregroundColor(.primary)
                            
                            if let category = suggestion.category {
                                Text(category)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.id != suggestions.last?.id {
                    Divider()
                        .padding(.leading)
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(radius: 4)
    }
}

/// Search filter definition
struct SearchFilter: Identifiable {
    let id: String
    let title: String
    let icon: String?
    let predicate: (Any) -> Bool
    
    init(id: String, title: String, icon: String? = nil, predicate: @escaping (Any) -> Bool) {
        self.id = id
        self.title = title
        self.icon = icon
        self.predicate = predicate
    }
}

// MARK: - Common Search Filters

extension SearchFilter {
    static let images = SearchFilter(
        id: "images",
        title: "Images",
        icon: "photo"
    ) { item in
        // Implementation would depend on the item type
        true
    }
    
    static let videos = SearchFilter(
        id: "videos",
        title: "Videos",
        icon: "video"
    ) { item in
        true
    }
    
    static let documents = SearchFilter(
        id: "documents",
        title: "Documents",
        icon: "doc"
    ) { item in
        true
    }
    
    static let folders = SearchFilter(
        id: "folders",
        title: "Folders",
        icon: "folder"
    ) { item in
        true
    }
}

// MARK: - View Extensions

extension View {
    /// Applies searchable functionality with configuration
    func searchable(
        text: Binding<String>,
        configuration: SearchConfiguration = SearchConfiguration()
    ) -> some View {
        SearchableView(searchText: text, configuration: configuration) {
            self
        }
    }
}