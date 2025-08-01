//
//  VaultGridView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Reusable grid component for displaying vault items with search and empty state support
struct VaultGridView: View {
    // MARK: - Properties
    
    let items: [VaultItem]
    let searchText: String
    let isSelectionMode: Bool
    let selectedItems: Set<VaultItem>
    let isImporting: Bool
    let emptyStateConfig: EmptyStateConfiguration
    
    // MARK: - Actions
    
    let onItemTap: (VaultItem) -> Void
    let onItemLongPress: (VaultItem) -> Void
    
    // MARK: - Grid Configuration
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if items.isEmpty && !isImporting {
                EmptyStateView(emptyStateConfig)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 2) {
                        ForEach(items) { item in
                            VaultItemCell(
                                item: item,
                                isSelected: selectedItems.contains(item),
                                isSelectionMode: isSelectionMode,
                                onTap: { onItemTap(item) },
                                onLongPress: { onItemLongPress(item) }
                            )
                        }
                    }
                    .padding(.horizontal, 2)
                    .searchable(text: .constant(searchText), prompt: "Search files")
                }
            }
        }
    }
}



// MARK: - Preview Support

#Preview("Gallery Empty State") {
    VaultGridView(
        items: [],
        searchText: "",
        isSelectionMode: false,
        selectedItems: [],
        isImporting: false,
        emptyStateConfig: .noPhotos(onAddPhotos: {}),
        onItemTap: { _ in },
        onItemLongPress: { _ in }
    )
}

#Preview("Folder Empty State") {
    VaultGridView(
        items: [],
        searchText: "",
        isSelectionMode: false,
        selectedItems: [],
        isImporting: false,
        emptyStateConfig: .emptyFolder(onCreateFolder: {}, onAddFiles: {}),
        onItemTap: { _ in },
        onItemLongPress: { _ in }
    )
}