//
//  FilePreviewView.swift
//  File Vault
//
//  Universal file preview system supporting documents, audio, images, and videos
//

import SwiftUI
import QuickLook

/// Universal file preview view that supports all file types
/// - Note: Navigation only works for media files (images/videos), not documents
struct FilePreviewView: View {
    let vaultItem: VaultItem
    @Environment(\.dismiss) private var dismiss
    @State private var fileData: Data?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingQuickLook = false
    @State private var temporaryFileURL: URL?
    @State private var isFavorite = false
    // File info gesture handler (for non-media files)
    @StateObject private var gestureHandler = FileInfoGestureHandler()
    
    // Helper function to toggle favorite status
    private func toggleFavorite() {
        FileStorageManager.shared.toggleFavorite(for: vaultItem)
        isFavorite.toggle()
    }
    
    var body: some View {
        NavigationView {
            GeometryReader { geometry in
                ZStack {
                    Color.black
                        .ignoresSafeArea()
                    
                    // Main layout that adjusts for info panel
                    if vaultItem.isImage || vaultItem.isVideo {
                        // Media files - use existing layout (handled by UnifiedMediaViewerView)
                        if isLoading {
                            FilePreviewLoadingView(fileName: vaultItem.fileName)
                        } else if let errorMessage = errorMessage {
                            FilePreviewErrorView(
                                message: errorMessage,
                                onRetry: { loadFileData() }
                            )
                        } else {
                            previewContent
                        }
                    } else {
                        // Non-media files - use common FileInfoLayoutContainer
                        FileInfoLayoutContainer(
                            vaultItem: vaultItem,
                            gestureHandler: gestureHandler,
                            geometry: geometry,
                            onFavoriteToggle: toggleFavorite,
                            onDismiss: nil // No dismiss for non-media files in NavigationView
                        ) {
                            // Main content area
                            if isLoading {
                                FilePreviewLoadingView(fileName: vaultItem.fileName)
                            } else if let errorMessage = errorMessage {
                                FilePreviewErrorView(
                                    message: errorMessage,
                                    onRetry: { loadFileData() }
                                )
                            } else {
                                previewContent
                            }
                        }
                    }
                }
            }
            .navigationTitle(vaultItem.fileName ?? "File Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        cleanup()
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 20) {
                        // Favorite button
                        Button(action: toggleFavorite) {
                            Image(systemName: isFavorite ? "heart.fill" : "heart")
                                .foregroundColor(isFavorite ? .red : .white)
                        }
                        
                        // Share button
                        Button(action: {
                            ShareManager.shared.shareVaultItem(vaultItem)
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .foregroundColor(.white)
                        }
                    }
                }
            }
        }
        .onAppear {
            loadFileData()
            isFavorite = vaultItem.isFavorite
        }
        .onDisappear {
            cleanup()
        }
        .sheet(isPresented: $showingQuickLook) {
            if let url = temporaryFileURL {
                QuickLookPreview(url: url)
            }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var previewContent: some View {
        Group {
            if vaultItem.isImage || vaultItem.isVideo {
                // Use the existing media viewer for images/videos 
                // This supports navigation between media files
                UnifiedMediaViewerView(mediaItems: [vaultItem], initialIndex: 0)
            } else if vaultItem.isDocument {
                // Documents don't support navigation - single file preview only
                DocumentPreviewView(
                    vaultItem: vaultItem,
                    fileData: fileData,
                    showingQuickLook: $showingQuickLook,
                    temporaryFileURL: $temporaryFileURL
                )
            } else if vaultItem.isAudio {
                // Audio files don't support navigation - single file preview only
                AudioPreviewView(
                    fileData: fileData,
                    fileName: vaultItem.fileName,
                    fileType: vaultItem.fileType
                )
            } else {
                // Unsupported files use QuickLook fallback
                UnsupportedFilePreviewView(
                    vaultItem: vaultItem,
                    canShareFile: canShareFile,
                    onShareFile: shareFile,
                    onShowQuickLook: { showingQuickLook = true }
                )
            }
        }
    }
    
    // MARK: - Helper Properties
    
    private var canShareFile: Bool {
        fileData != nil
    }
    
    // MARK: - File Sharing
    
    private func shareFile() {
        FilePreviewSharingService.shareFile(
            fileData: fileData,
            fileName: vaultItem.fileName
        )
    }
    
    // MARK: - Data Loading
    
    private func loadFileData() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let data = try await FileStorageManager.shared.loadImage(for: vaultItem)
                await MainActor.run {
                    self.fileData = data
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to load file: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    private func cleanup() {
        // Clean up temporary files
        if let url = temporaryFileURL {
            try? FileManager.default.removeItem(at: url)
            temporaryFileURL = nil
        }
    }
}

// MARK: - Preview Support

#Preview {
    // Create a sample vault item for preview
    let context = CoreDataManager.shared.context
    let sampleItem = VaultItem(context: context)
    sampleItem.fileName = "sample.pdf"
    sampleItem.fileType = "application/pdf"
    sampleItem.fileSize = 1024000
    sampleItem.createdAt = Date()
    
    return FilePreviewView(vaultItem: sampleItem)
}