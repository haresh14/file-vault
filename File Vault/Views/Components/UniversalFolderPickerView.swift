//
//  UniversalFolderPickerView.swift
//  File Vault
//
//  Reusable folder picker component with clear UX
//  Based on the superior GalleryFolderPickerView design
//

import SwiftUI

/// Universal folder picker for moving items between folders
/// Features clear "Move Here" button and intuitive navigation
struct UniversalFolderPickerView: View {
    let selectedFolders: Set<Folder>
    let selectedFiles: Set<VaultItem>
    let currentFolder: Folder?
    let onMove: (Folder?) -> Void
    
    @State private var navigationPath: [Folder] = []
    @State private var currentLevelFolders: [Folder] = []
    @Environment(\.dismiss) private var dismiss
    
    private var currentNavigationFolder: Folder? {
        navigationPath.last
    }
    
    private var itemCountText: String {
        let folderCount = selectedFolders.count
        let fileCount = selectedFiles.count
        let totalCount = folderCount + fileCount
        
        if totalCount == 1 {
            return "1 item"
        } else {
            return "\(totalCount) items"
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                breadcrumbNavigation
                foldersList
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentLevelFolders()
            }
        }
    }
    
    // MARK: - Subviews
    
    private var breadcrumbNavigation: some View {
        Group {
            if !navigationPath.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("Root") {
                            navigationPath.removeAll()
                            loadCurrentLevelFolders()
                        }
                        .foregroundColor(.blue)
                        
                        ForEach(Array(navigationPath.enumerated()), id: \.element.objectID) { index, folder in
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                
                                Button(folder.displayName) {
                                    navigationPath = Array(navigationPath.prefix(index + 1))
                                    loadCurrentLevelFolders()
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
        }
    }
    
    private var foldersList: some View {
        List {
            moveHereButton
            
            // Folders in current level
            ForEach(currentLevelFolders, id: \.objectID) { folder in
                folderRow(folder)
            }
        }
    }
    
    private var moveHereButton: some View {
        Button(action: {
            onMove(currentNavigationFolder)
            dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move Here")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .font(.body)
                    
                    Text(currentNavigationFolder?.displayName ?? "Root Folder")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                    
                    Text("(\(itemCountText))")
                        .foregroundColor(.white.opacity(0.7))
                        .font(.caption2)
                }
                
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.green)
            .cornerRadius(12)
        }
        .disabled(!canMoveToCurrentFolder())
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }
    
    private func folderRow(_ folder: Folder) -> some View {
        Button(action: {
            // Always navigate into folder, never move directly
            navigationPath.append(folder)
            loadCurrentLevelFolders()
        }) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.displayName)
                        .foregroundColor(.primary)
                        .font(.body)
                    
                    Text("\(folder.totalItemCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if !canMoveToFolder(folder) {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundColor(.orange)
                        .font(.caption)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .disabled(!canMoveToFolder(folder))
        .contextMenu {
            if canMoveToFolder(folder) {
                Button("Move Here") {
                    onMove(folder)
                    dismiss()
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadCurrentLevelFolders() {
        if let currentNavFolder = currentNavigationFolder {
            currentLevelFolders = currentNavFolder.subfoldersArray.sorted { $0.displayName < $1.displayName }
        } else {
            currentLevelFolders = CoreDataManager.shared.fetchRootFolders().sorted { $0.displayName < $1.displayName }
        }
    }
    
    private func canMoveToCurrentFolder() -> Bool {
        // Can't move to the current folder
        if currentNavigationFolder?.objectID == currentFolder?.objectID {
            return false
        }
        
        // Can't move a folder into itself or its descendants
        if let currentNav = currentNavigationFolder {
            if selectedFolders.contains(currentNav) {
                return false
            }
            
            // Check if any selected folder is an ancestor of the current navigation folder
            for selectedFolder in selectedFolders {
                if currentNav.isDescendant(of: selectedFolder) {
                    return false
                }
            }
        }
        
        return true
    }
    
    private func canMoveToFolder(_ folder: Folder) -> Bool {
        // Can't move a folder into itself or its descendants
        if selectedFolders.contains(folder) {
            return false
        }
        
        // Check if any selected folder is an ancestor of the target folder
        for selectedFolder in selectedFolders {
            if folder.isDescendant(of: selectedFolder) {
                return false
            }
        }
        
        return true
    }
}

// MARK: - Convenience Initializers

extension UniversalFolderPickerView {
    /// Initializer for files only (like Gallery view)
    static func forFiles(selectedFiles: Set<VaultItem>, onMove: @escaping (Folder?) -> Void) -> UniversalFolderPickerView {
        return UniversalFolderPickerView(
            selectedFolders: [],
            selectedFiles: selectedFiles,
            currentFolder: nil,
            onMove: onMove
        )
    }
}