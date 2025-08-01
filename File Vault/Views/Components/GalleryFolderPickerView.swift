//
//  GalleryFolderPickerView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI

/// Folder picker for moving vault items to specific folders
struct GalleryFolderPickerView: View {
    let selectedFiles: Set<VaultItem>
    let onMove: (Folder?) -> Void
    
    @State private var navigationPath: [Folder] = []
    @State private var currentLevelFolders: [Folder] = []
    @Environment(\.dismiss) private var dismiss
    
    var currentNavigationFolder: Folder? {
        navigationPath.last
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Breadcrumb navigation
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
                
                List {
                    // Move here button
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
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 12)
                        .padding(.horizontal, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowBackground(Color.clear)
                    
                    // Folders in current level
                    ForEach(currentLevelFolders, id: \.objectID) { folder in
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
                                
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .contentShape(Rectangle())
                        }
                        .contextMenu {
                            Button("Move Here") {
                                onMove(folder)
                                dismiss()
                            }
                        }
                    }
                }
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
    
    private func loadCurrentLevelFolders() {
        if let currentNavFolder = currentNavigationFolder {
            currentLevelFolders = currentNavFolder.subfoldersArray.sorted { $0.displayName < $1.displayName }
        } else {
            currentLevelFolders = CoreDataManager.shared.fetchRootFolders().sorted { $0.displayName < $1.displayName }
        }
    }
}