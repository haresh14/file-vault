//
//  FolderPickerView.swift
//  File Vault
//  Folder picker for moving items between folders (now using UniversalFolderPickerView)
//

import SwiftUI

struct FolderPickerView: View {
    let selectedFolders: Set<Folder>
    let selectedFiles: Set<VaultItem>
    let currentFolder: Folder?
    let onMove: (Folder?) -> Void
    
    var body: some View {
        UniversalFolderPickerView(
            selectedFolders: selectedFolders,
            selectedFiles: selectedFiles,
            currentFolder: currentFolder,
            onMove: onMove
        )
    }
}