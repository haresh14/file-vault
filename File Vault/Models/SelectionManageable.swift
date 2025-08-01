//
//  SelectionManageable.swift
//  File Vault
//
//  Created on 10/07/25.
//

import Foundation
import SwiftUI

/// Protocol for managing selection state in views that support multi-selection
protocol SelectionManageable: ObservableObject {
    associatedtype SelectableItem: Hashable
    
    /// Whether the view is in selection mode
    var isSelectionMode: Bool { get set }
    
    /// Set of currently selected items
    var selectedItems: Set<SelectableItem> { get set }
    
    /// Toggle selection for a specific item
    func toggleSelection(for item: SelectableItem)
    
    /// Enter selection mode
    func enterSelectionMode()
    
    /// Exit selection mode and clear selections
    func exitSelectionMode()
    
    /// Select all available items
    func selectAll(from items: [SelectableItem])
    
    /// Check if an item is selected
    func isSelected(_ item: SelectableItem) -> Bool
    
    /// Get the count of selected items
    var selectionCount: Int { get }
    
    /// Check if any items are selected
    var hasSelection: Bool { get }
}

/// Default implementation for SelectionManageable
extension SelectionManageable {
    func toggleSelection(for item: SelectableItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
    }
    
    func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
    }
    
    func selectAll(from items: [SelectableItem]) {
        selectedItems = Set(items)
    }
    
    func isSelected(_ item: SelectableItem) -> Bool {
        selectedItems.contains(item)
    }
    
    var selectionCount: Int {
        selectedItems.count
    }
    
    var hasSelection: Bool {
        !selectedItems.isEmpty
    }
}