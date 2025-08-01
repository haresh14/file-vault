//
//  UniversalAddContentView.swift
//  File Vault
//
//  Universal add content component with superior visual design
//  Based on the Gallery view's AddActionSheet with optional folder creation
//

import SwiftUI

/// Universal add content view that works across all contexts
/// Features visually appealing card design with configurable options
struct UniversalAddContentView: View {
    let onAddPhotos: () -> Void
    let onAddFiles: () -> Void
    let onWebUpload: (() -> Void)?
    let onCreateFolder: (() -> Void)?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Add Content")
                .font(.headline)
                .padding(.top)
            
            VStack(spacing: 16) {
                // Photos & Videos
                UniversalActionButton(
                    icon: "photo.on.rectangle.angled",
                    title: "Photos & Videos",
                    subtitle: "From photo library",
                    color: .blue,
                    action: onAddPhotos
                )
                
                // Files
                UniversalActionButton(
                    icon: "doc.on.doc",
                    title: "Files",
                    subtitle: "Documents and other files",
                    color: .green,
                    action: onAddFiles
                )
                
                // Web Upload (optional)
                if let onWebUpload = onWebUpload {
                    UniversalActionButton(
                        icon: "wifi",
                        title: "Web Upload",
                        subtitle: "Upload via web browser",
                        color: .purple,
                        action: onWebUpload
                    )
                }
                
                // Create Folder (optional)
                if let onCreateFolder = onCreateFolder {
                    UniversalActionButton(
                        icon: "folder.badge.plus",
                        title: "Create Folder",
                        subtitle: "Organize your files",
                        color: .orange,
                        action: onCreateFolder
                    )
                }
            }
            
            Spacer()
        }
        .padding()
    }
}

/// Enhanced action button with superior visual design
struct UniversalActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                    .frame(width: 30)
                        
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Convenience Initializers

extension UniversalAddContentView {
    /// Initializer for Gallery view (Photos, Files, Web Upload)
    static func forGallery(
        onAddPhotos: @escaping () -> Void,
        onAddFiles: @escaping () -> Void,
        onWebUpload: @escaping () -> Void
    ) -> UniversalAddContentView {
        UniversalAddContentView(
            onAddPhotos: onAddPhotos,
            onAddFiles: onAddFiles,
            onWebUpload: onWebUpload,
            onCreateFolder: nil
        )
    }
    
    /// Initializer for Folder view (Photos, Files, Create Folder)
    static func forFolder(
        onAddPhotos: @escaping () -> Void,
        onAddFiles: @escaping () -> Void,
        onCreateFolder: @escaping () -> Void
    ) -> UniversalAddContentView {
        UniversalAddContentView(
            onAddPhotos: onAddPhotos,
            onAddFiles: onAddFiles,
            onWebUpload: nil,
            onCreateFolder: onCreateFolder
        )
    }
    
    /// Initializer for Category view (Photos, Files)
    static func forCategory(
        onAddPhotos: @escaping () -> Void,
        onAddFiles: @escaping () -> Void
    ) -> UniversalAddContentView {
        UniversalAddContentView(
            onAddPhotos: onAddPhotos,
            onAddFiles: onAddFiles,
            onWebUpload: nil,
            onCreateFolder: nil
        )
    }
    
    /// Initializer for full feature set (Photos, Files, Web Upload, Create Folder)
    static func withAllFeatures(
        onAddPhotos: @escaping () -> Void,
        onAddFiles: @escaping () -> Void,
        onWebUpload: @escaping () -> Void,
        onCreateFolder: @escaping () -> Void
    ) -> UniversalAddContentView {
        UniversalAddContentView(
            onAddPhotos: onAddPhotos,
            onAddFiles: onAddFiles,
            onWebUpload: onWebUpload,
            onCreateFolder: onCreateFolder
        )
    }
}

#Preview {
    UniversalAddContentView.forGallery(
        onAddPhotos: {},
        onAddFiles: {},
        onWebUpload: {}
    )
}