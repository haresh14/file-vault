//
//  VaultGridView.swift
//  Keepshire
//
//  Created on 10/07/25.
//

import SwiftUI

/// Reusable grid component for displaying vault items with search and empty state support
struct VaultGridView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
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
    let onFavoriteToggle: ((VaultItem) -> Void)?
    let onShare: ((VaultItem) -> Void)?
    let onRename: ((VaultItem) -> Void)?
    let onMove: ((VaultItem) -> Void)?
    let onDelete: ((VaultItem) -> Void)?
    let onSelect: ((VaultItem) -> Void)?
    let showFavoriteIndicator: Bool
    
    // MARK: - Grid Configuration
    
    private var gridSpacing: CGFloat {
        horizontalSizeClass == .regular ? 8 : 2
    }

    private var columns: [GridItem] {
        [
            GridItem(
                .adaptive(
                    minimum: horizontalSizeClass == .regular ? 140 : 100,
                    maximum: horizontalSizeClass == .regular ? 220 : 150
                ),
                spacing: gridSpacing
            )
        ]
    }
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            if items.isEmpty && !isImporting {
                EmptyStateView(emptyStateConfig)
            } else {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: gridSpacing) {
                        ForEach(items) { item in
                            VaultItemCell(
                                item: item,
                                isSelected: selectedItems.contains(item),
                                isSelectionMode: isSelectionMode,
                                showFavoriteIndicator: showFavoriteIndicator,
                                onTap: { onItemTap(item) },
                                onLongPress: { onItemLongPress(item) }
                            )
                            .contextMenu {
                                // Only show context menu if at least one action is available
                                if onSelect != nil || onFavoriteToggle != nil || onMove != nil || onShare != nil || onDelete != nil {
                                    // Select option
                                    if let onSelect = onSelect {
                                        Button(action: {
                                            onSelect(item)
                                        }) {
                                            Label("Select", systemImage: "checkmark.circle")
                                                .labelStyle(.titleAndIcon)
                                        }
                                        
                                        Divider()
                                    }
                                    
                                    // Favorite/Unfavorite option
                                    if let onFavoriteToggle = onFavoriteToggle {
                                        Button(action: {
                                            onFavoriteToggle(item)
                                        }) {
                                            Label(
                                                item.isFavorite ? "Unfavorite" : "Favorite",
                                                systemImage: item.isFavorite ? "heart.slash" : "heart"
                                            )
                                            .labelStyle(.titleAndIcon)
                                        }
                                    }
                                    
                                    // Rename option (available when other actions are present)
                                    if let onRename = onRename {
                                        Button(action: {
                                            onRename(item)
                                        }) {
                                            Label("Rename", systemImage: "pencil")
                                                .labelStyle(.titleAndIcon)
                                        }
                                    }
                                    
                                    // Move option
                                    if let onMove = onMove {
                                        Button(action: {
                                            onMove(item)   // Trigger move functionality directly
                                        }) {
                                            Label("Move", systemImage: "folder")
                                                .labelStyle(.titleAndIcon)
                                        }
                                    }
                                    
                                    if onShare != nil || onDelete != nil {
                                        Divider()
                                    }
                                    
                                    // Share option
                                    if let onShare = onShare {
                                        Button(action: {
                                            onShare(item)
                                        }) {
                                            Label("Share", systemImage: "square.and.arrow.up")
                                                .labelStyle(.titleAndIcon)
                                        }
                                    }
                                    
                                    // Delete option (in red)
                                    if let onDelete = onDelete {
                                        if onShare != nil {
                                            Divider()
                                        }
                                        Button(role: .destructive, action: {
                                            onDelete(item)
                                        }) {
                                            Label("Delete", systemImage: "trash")
                                                .labelStyle(.titleAndIcon)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, gridSpacing)
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
        onItemLongPress: { _ in },
        onFavoriteToggle: nil,
        onShare: nil,
        onRename: nil,
        onMove: nil,
        onDelete: nil,
        onSelect: nil,
        showFavoriteIndicator: true
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
        onItemLongPress: { _ in },
        onFavoriteToggle: nil,
        onShare: nil,
        onRename: nil,
        onMove: nil,
        onDelete: nil,
        onSelect: nil,
        showFavoriteIndicator: true
    )
}