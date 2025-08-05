//
//  RenameManager.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Protocol for items that can be renamed
protocol RenameableItem {
    var id: UUID? { get }
    var currentName: String { get }
    func rename(to newName: String) throws
}

/// Manages file and folder renaming functionality across the app
class RenameManager: ObservableObject {
    static let shared = RenameManager()
    
    @Published var showRenameAlert = false
    @Published var renameText = ""
    @Published var currentItem: RenameableItem?
    
    private init() {}
    
    /// Present rename alert for a vault item
    func renameVaultItem(_ item: VaultItem) {
        guard let fileName = item.fileName else { return }
        
        let renameableItem = VaultItemWrapper(item: item)
        currentItem = renameableItem
        renameText = getFileNameWithoutExtension(fileName)
        showRenameAlert = true
    }
    
    /// Present rename alert for a folder
    func renameFolder(_ folder: Folder) {
        let renameableItem = FolderWrapper(folder: folder)
        currentItem = renameableItem
        renameText = folder.name ?? ""
        showRenameAlert = true
    }
    
    /// Perform the actual rename operation
    func performRename() {
        guard let item = currentItem, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            dismissRename()
            return
        }
        
        do {
            try item.rename(to: renameText.trimmingCharacters(in: .whitespacesAndNewlines))
            dismissRename()
        } catch {
            print("Error renaming item: \(error)")
            // Could show error alert here
            dismissRename()
        }
    }
    
    /// Dismiss the rename alert
    func dismissRename() {
        showRenameAlert = false
        currentItem = nil
        renameText = ""
    }
    
    /// Get filename without extension for editing
    private func getFileNameWithoutExtension(_ fileName: String) -> String {
        let url = URL(fileURLWithPath: fileName)
        return url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Wrapper Classes

extension RenameManager {
    
    /// Wrapper for VaultItem to conform to RenameableItem
    class VaultItemWrapper: RenameableItem {
        let item: VaultItem
        
        init(item: VaultItem) {
            self.item = item
        }
        
        var id: UUID? { item.id }
        
        var currentName: String {
            return item.fileName ?? "Unknown"
        }
        
        func rename(to newName: String) throws {
            guard let originalFileName = item.fileName else {
                throw RenameError.invalidItem
            }
            
            // Preserve the original file extension
            let url = URL(fileURLWithPath: originalFileName)
            let fileExtension = url.pathExtension
            let newFileName = fileExtension.isEmpty ? newName : "\(newName).\(fileExtension)"
            
            // Update the Core Data object
            item.fileName = newFileName
            
            // Save the context
            CoreDataManager.shared.save()
            
            // Post notification for UI refresh
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        }
    }
    
    /// Wrapper for Folder to conform to RenameableItem
    class FolderWrapper: RenameableItem {
        let folder: Folder
        
        init(folder: Folder) {
            self.folder = folder
        }
        
        var id: UUID? { folder.id }
        
        var currentName: String {
            return folder.name ?? "Unknown"
        }
        
        func rename(to newName: String) throws {
            // Update the folder name
            folder.name = newName
            
            // Save the context
            CoreDataManager.shared.save()
            
            // Post notification for UI refresh
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
        }
    }
}

// MARK: - Rename Error

enum RenameError: Error {
    case invalidItem
    case emptyName
    case saveFailed
}

// MARK: - SwiftUI View Extension

extension View {
    /// Add rename alert to any view
    func renameAlert() -> some View {
        self
            .alert("Rename", isPresented: Binding(
                get: { RenameManager.shared.showRenameAlert },
                set: { RenameManager.shared.showRenameAlert = $0 }
            )) {
                TextField("Name", text: Binding(
                    get: { RenameManager.shared.renameText },
                    set: { RenameManager.shared.renameText = $0 }
                ))
                Button("Cancel", role: .cancel) {
                    RenameManager.shared.dismissRename()
                }
                Button("Rename") {
                    RenameManager.shared.performRename()
                }
            } message: {
                Text("Enter a new name")
            }
    }
}