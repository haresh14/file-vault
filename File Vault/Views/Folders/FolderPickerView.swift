//
//  FolderPickerView.swift
//  File Vault
//  Folder picker for moving items between folders
//

import SwiftUI

struct FolderPickerView: View {
    let selectedFolders: Set<Folder>
    let selectedFiles: Set<VaultItem>
    let currentFolder: Folder?
    let onMove: (Folder?) -> Void
    
    @State private var navigationPath: [Folder] = []
    @State private var currentLevelFolders: [Folder] = []
    @Environment(\.dismiss) private var dismiss
    
    private var currentNavigationFolder: Folder? { navigationPath.last }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                breadcrumb
                foldersList
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { loadCurrentLevelFolders() }
        }
    }
    
    // MARK: - Subviews
    private var breadcrumb: some View {
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
            // Root folder option
            if navigationPath.isEmpty {
                Button(action: {
                    onMove(nil)
                }) {
                    HStack {
                        Image(systemName: "house.fill")
                            .foregroundColor(.blue)
                        Text("Root Folder")
                            .foregroundColor(.primary)
                        Spacer()
                        if currentFolder == nil {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .disabled(currentFolder == nil)
            }
            
            // Folder list
            ForEach(currentLevelFolders) { folder in
                Button(action: {
                    if canMoveToFolder(folder) {
                        onMove(folder)
                    }
                }) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text(folder.displayName)
                            .foregroundColor(.primary)
                        Spacer()
                        
                        if folder.objectID == currentFolder?.objectID {
                            Image(systemName: "checkmark")
                                .foregroundColor(.blue)
                        } else if !canMoveToFolder(folder) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                        } else {
                            Button(action: {
                                navigationPath.append(folder)
                                loadCurrentLevelFolders()
                            }) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .disabled(!canMoveToFolder(folder) || folder.objectID == currentFolder?.objectID)
            }
        }
    }
    
    // MARK: - Helper Methods
    private func loadCurrentLevelFolders() {
        if let currentFolder = currentNavigationFolder {
            currentLevelFolders = currentFolder.subfoldersArray
        } else {
            currentLevelFolders = CoreDataManager.shared.fetchRootFolders()
        }
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