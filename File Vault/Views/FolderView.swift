//
//  FolderView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct FolderView: View {
    @State private var folders: [Folder] = []
    @State private var showCreateFolder = false
    @State private var newFolderName = ""
    @State private var currentFolder: Folder? = nil
    @State private var showRenameFolder = false
    @State private var folderToRename: Folder? = nil
    @State private var renameText = ""
    
    @Environment(\.managedObjectContext) var context
    
    var body: some View {
        NavigationView {
            Group {
                if folders.isEmpty {
                    emptyStateView
                } else {
                    folderListView
                }
            }
            .navigationTitle(currentFolder?.displayName ?? "Folders")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showCreateFolder = true }) {
                        Image(systemName: "plus")
                    }
                }
                
                if currentFolder != nil {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Back") {
                            navigateBack()
                        }
                    }
                }
            }
            .onAppear {
                loadFolders()
            }
            .alert("Create Folder", isPresented: $showCreateFolder) {
                TextField("Folder Name", text: $newFolderName)
                Button("Cancel", role: .cancel) {
                    newFolderName = ""
                }
                Button("Create") {
                    createFolder()
                }
            } message: {
                Text("Enter a name for the new folder")
            }
            .alert("Rename Folder", isPresented: $showRenameFolder) {
                TextField("Folder Name", text: $renameText)
                Button("Cancel", role: .cancel) {
                    renameText = ""
                    folderToRename = nil
                }
                Button("Rename") {
                    renameFolder()
                }
            } message: {
                Text("Enter a new name for the folder")
            }
        }
    }
    
    // MARK: - Views
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 80))
                .foregroundColor(.gray)
            
            Text("No Folders Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Create folders to organize your files")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button(action: { showCreateFolder = true }) {
                Text("Create Folder")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: 200)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
    }
    
    private var folderListView: some View {
        List {
            ForEach(folders) { folder in
                FolderRowView(folder: folder) {
                    navigateToFolder(folder)
                } onRename: {
                    startRenaming(folder)
                }
            }
            .onDelete(perform: deleteFolders)
        }
    }
    
    // MARK: - Functions
    
    private func loadFolders() {
        if let currentFolder = currentFolder {
            folders = currentFolder.subfoldersArray
        } else {
            folders = CoreDataManager.shared.fetchRootFolders()
        }
    }
    
    private func createFolder() {
        guard !newFolderName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            newFolderName = ""
            return
        }
        
        let _ = CoreDataManager.shared.createFolder(name: newFolderName, parent: currentFolder)
        newFolderName = ""
        loadFolders()
    }
    
    private func navigateToFolder(_ folder: Folder) {
        currentFolder = folder
        loadFolders()
    }
    
    private func navigateBack() {
        currentFolder = currentFolder?.parent
        loadFolders()
    }
    
    private func startRenaming(_ folder: Folder) {
        folderToRename = folder
        renameText = folder.displayName
        showRenameFolder = true
    }
    
    private func renameFolder() {
        guard let folder = folderToRename,
              !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            renameText = ""
            folderToRename = nil
            return
        }
        
        CoreDataManager.shared.updateFolder(folder, name: renameText)
        renameText = ""
        folderToRename = nil
        loadFolders()
    }
    
    private func deleteFolders(offsets: IndexSet) {
        for index in offsets {
            let folder = folders[index]
            CoreDataManager.shared.deleteFolder(folder)
        }
        loadFolders()
    }
}

// MARK: - Supporting Views

struct FolderRowView: View {
    let folder: Folder
    let onTap: () -> Void
    let onRename: () -> Void
    
    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.headline)
                
                Text("\(folder.totalItemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
        }
    }
}

#Preview {
    FolderView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 