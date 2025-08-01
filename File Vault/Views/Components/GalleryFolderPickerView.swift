//
//  GalleryFolderPickerView.swift
//  File Vault
//
//  Created on 10/07/25.
//  Now using UniversalFolderPickerView for consistent UX
//

import SwiftUI

/// Folder picker for moving vault items to specific folders
struct GalleryFolderPickerView: View {
    let selectedFiles: Set<VaultItem>
    let onMove: (Folder?) -> Void
    
    var body: some View {
        UniversalFolderPickerView.forFiles(
            selectedFiles: selectedFiles,
            onMove: onMove
        )
    }
}