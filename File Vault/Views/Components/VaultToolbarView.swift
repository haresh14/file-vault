//
//  VaultToolbarView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Reusable toolbar component for vault-style views with selection and action capabilities
struct VaultToolbarView: ToolbarContent {
    // MARK: - Properties
    
    let isSelectionMode: Bool
    let selectedItemCount: Int
    let totalItemCount: Int
    let hasSelectedItems: Bool
    let canAddFiles: Bool
    let isEmpty: Bool
    
    // MARK: - Actions
    
    let onSelectAll: () -> Void
    let onMove: () -> Void
    let onDelete: () -> Void
    let onShare: (() -> Void)?
    let onFavorite: (() -> Void)?
    let onCancel: () -> Void
    let onAdd: () -> Void
    let onSort: () -> Void
    let onEnterSelection: () -> Void
    
    // MARK: - Initialization
    
    init(
        isSelectionMode: Bool,
        selectedItemCount: Int,
        totalItemCount: Int,
        hasSelectedItems: Bool,
        canAddFiles: Bool,
        isEmpty: Bool,
        onSelectAll: @escaping () -> Void,
        onMove: @escaping () -> Void,
        onDelete: @escaping () -> Void,
        onShare: (() -> Void)? = nil,
        onFavorite: (() -> Void)? = nil,
        onCancel: @escaping () -> Void,
        onAdd: @escaping () -> Void,
        onSort: @escaping () -> Void,
        onEnterSelection: @escaping () -> Void
    ) {
        self.isSelectionMode = isSelectionMode
        self.selectedItemCount = selectedItemCount
        self.totalItemCount = totalItemCount
        self.hasSelectedItems = hasSelectedItems
        self.canAddFiles = canAddFiles
        self.isEmpty = isEmpty
        self.onSelectAll = onSelectAll
        self.onMove = onMove
        self.onDelete = onDelete
        self.onShare = onShare
        self.onFavorite = onFavorite
        self.onCancel = onCancel
        self.onAdd = onAdd
        self.onSort = onSort
        self.onEnterSelection = onEnterSelection
    }
    
    // MARK: - Toolbar Content
    
    var body: some ToolbarContent {
        Group {
            // Leading toolbar items
            ToolbarItem(placement: .navigationBarLeading) {
                leadingContent
            }
            
            // Trailing toolbar items
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                trailingContent
            }
        }
    }
    
    // MARK: - Content Builders
    
    @ViewBuilder
    private var leadingContent: some View {
        if isSelectionMode {
            Button("Select All", action: onSelectAll)
        }
    }
    
    @ViewBuilder
    private var trailingContent: some View {
        if isSelectionMode {
            selectionModeActions
        } else {
            normalModeActions
        }
    }
    
    @ViewBuilder
    private var selectionModeActions: some View {
        Button("Cancel", action: onCancel)
        
        if hasSelectedItems {
            Menu {
                // Favorite option
                if let onFavorite = onFavorite {
                    Button(action: onFavorite) {
                        Label("Favorite", systemImage: "heart")
                    }
                }
                // Share option (if provided)
                if let onShare = onShare {
                    Button(action: onShare) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }
                }
                
                Button(action: onMove) {
                    Label("Move", systemImage: "arrow.up.doc.on.clipboard")
                }
                
                Divider()
                
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .foregroundColor(.blue)
            }
        }
    }
    
    @ViewBuilder
    private var normalModeActions: some View {
        Menu {
            if canAddFiles {
                Button(action: onAdd) {
                    Label("Add Files", systemImage: "plus")
                }
            }
            
            Button(action: onSort) {
                Label("Sort", systemImage: "arrow.up.arrow.down")
            }
            
            if !isEmpty && canAddFiles {
                Divider()
                
                Button(action: onEnterSelection) {
                    Label("Select Items", systemImage: "checkmark.circle")
                }
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundColor(.blue)
        }
    }
}

/// Helper view modifier for consistent navigation title in vault views
struct VaultNavigationTitle: ViewModifier {
    let isSelectionMode: Bool
    let selectedCount: Int
    let defaultTitle: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle(isSelectionMode ? "\(selectedCount) selected" : defaultTitle)
            .navigationBarTitleDisplayMode(.large)
    }
}

extension View {
    /// Apply vault-style navigation title
    func vaultNavigationTitle(
        isSelectionMode: Bool,
        selectedCount: Int,
        defaultTitle: String = "Gallery"
    ) -> some View {
        modifier(VaultNavigationTitle(
            isSelectionMode: isSelectionMode,
            selectedCount: selectedCount,
            defaultTitle: defaultTitle
        ))
    }
}