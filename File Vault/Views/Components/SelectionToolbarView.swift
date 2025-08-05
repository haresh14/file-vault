//
//  SelectionToolbarView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Specialized toolbar component for selection mode actions only
struct SelectionToolbarView: ToolbarContent {
    // MARK: - Properties
    
    let selectedItemCount: Int
    let totalItemCount: Int
    let hasSelectedItems: Bool
    let selectionTitle: String
    
    // MARK: - Actions
    
    let onSelectAll: () -> Void
    let onMove: (() -> Void)?
    let onDelete: (() -> Void)?
    let onShare: (() -> Void)?
    let onCancel: () -> Void
    
    // MARK: - Initialization
    
    init(
        selectedItemCount: Int,
        totalItemCount: Int,
        hasSelectedItems: Bool,
        selectionTitle: String = "selected",
        onSelectAll: @escaping () -> Void,
        onMove: (() -> Void)? = nil,
        onDelete: (() -> Void)? = nil,
        onShare: (() -> Void)? = nil,
        onCancel: @escaping () -> Void
    ) {
        self.selectedItemCount = selectedItemCount
        self.totalItemCount = totalItemCount
        self.hasSelectedItems = hasSelectedItems
        self.selectionTitle = selectionTitle
        self.onSelectAll = onSelectAll
        self.onMove = onMove
        self.onDelete = onDelete
        self.onShare = onShare
        self.onCancel = onCancel
    }
    
    // MARK: - Toolbar Content
    
    var body: some ToolbarContent {
        Group {
            // Leading toolbar items
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Select All", action: onSelectAll)
            }
            
            // Trailing toolbar items
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                selectionActions
            }
        }
    }
    
    // MARK: - Content Builders
    
    @ViewBuilder
    private var selectionActions: some View {
        if hasSelectedItems {
            HStack(spacing: 16) {
                // Share button (if provided)
                if let onShare = onShare {
                    Button(action: onShare) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.blue)
                    }
                }
                
                // Move button (if provided)
                if let onMove = onMove {
                    Button(action: onMove) {
                        Image(systemName: "arrow.up.doc.on.clipboard")
                            .foregroundColor(.blue)
                    }
                }
                
                // Delete button (if provided)
                if let onDelete = onDelete {
                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
        }
        
        Button("Cancel", action: onCancel)
    }
}

/// View modifier for selection mode navigation title
struct SelectionNavigationTitle: ViewModifier {
    let selectedCount: Int
    let selectionTitle: String
    let defaultTitle: String
    
    func body(content: Content) -> some View {
        content
            .navigationTitle("\(selectedCount) \(selectionTitle)")
            .navigationBarTitleDisplayMode(.large)
    }
}

extension View {
    /// Apply selection mode navigation title
    func selectionNavigationTitle(
        selectedCount: Int,
        selectionTitle: String = "selected",
        defaultTitle: String = "Items"
    ) -> some View {
        modifier(SelectionNavigationTitle(
            selectedCount: selectedCount,
            selectionTitle: selectionTitle,
            defaultTitle: defaultTitle
        ))
    }
}

/// Floating selection action bar for bottom of screen
struct FloatingSelectionBar: View {
    let selectedItemCount: Int
    let hasSelectedItems: Bool
    
    let onMove: (() -> Void)?
    let onDelete: (() -> Void)?
    let onShare: (() -> Void)?
    let onCancel: () -> Void
    
    var body: some View {
        if hasSelectedItems {
            VStack {
                Spacer()
                
                HStack {
                    Text("\(selectedItemCount) selected")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    HStack(spacing: 20) {
                        // Share button
                        if let onShare = onShare {
                            Button(action: onShare) {
                                VStack(spacing: 4) {
                                    Image(systemName: "square.and.arrow.up")
                                        .font(.title2)
                                    // Text("Share")
                                    //     .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Move button
                        if let onMove = onMove {
                            Button(action: onMove) {
                                VStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.title2)
                                    Text("Move")
                                        .font(.caption2)
                                }
                                .foregroundColor(.blue)
                            }
                        }
                        
                        // Delete button
                        if let onDelete = onDelete {
                            Button(action: onDelete) {
                                VStack(spacing: 4) {
                                    Image(systemName: "trash")
                                        .font(.title2)
                                    Text("Delete")
                                        .font(.caption2)
                                }
                                .foregroundColor(.red)
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Button("Cancel", action: onCancel)
                        .font(.caption)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(
                    Color(.systemBackground)
                        .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: -2)
                )
            }
            .transition(.move(edge: .bottom))
            .animation(.easeInOut, value: hasSelectedItems)
        }
    }
}