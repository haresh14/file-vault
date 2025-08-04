//
//  TrashView.swift
//  File Vault
//
//  Created on 10/07/25.
//

import SwiftUI
import CoreData

struct TrashView: View {
    @StateObject private var viewModel = TrashViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.deletedItems.isEmpty {
                emptyTrashView
            } else {
                // Use the existing VaultGridView for consistency
                VaultGridView(
                    items: viewModel.deletedItems,
                    searchText: "",
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedItems: viewModel.selectedItems,
                    isImporting: false,
                    emptyStateConfig: .emptyTrash(),
                    onItemTap: { item in
                        if viewModel.isSelectionMode {
                            viewModel.toggleSelection(item)
                        } else {
                            viewModel.viewFile(item)
                        }
                    },
                    onItemLongPress: { item in
                        if !viewModel.isSelectionMode {
                            viewModel.enterSelectionMode()
                            viewModel.toggleSelection(item)
                        }
                    }
                )
                
                // Bottom action bar (when items are selected)
                if viewModel.isSelectionMode && !viewModel.selectedItems.isEmpty {
                    bottomActionBar
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !viewModel.deletedItems.isEmpty {
                        if viewModel.isSelectionMode {
                            Button("Select All") {
                                viewModel.selectAllItems()
                            }
                            Button("Cancel") {
                                viewModel.exitSelectionMode()
                            }
                        } else {
                            // Empty Trash button (only show when not in selection mode)
                            Button("Empty Trash") {
                                viewModel.showEmptyTrashAlert = true
                            }
                            .foregroundColor(.red)
                            
                            Button("Select") {
                                viewModel.enterSelectionMode()
                            }
                        }
                    }
                }
            }
        }
        .alert("Permanently Delete", isPresented: $viewModel.showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                viewModel.permanentlyDeleteSelected()
            }
        } message: {
            Text("Are you sure you want to permanently delete \(viewModel.selectedItems.count) item(s)? This action cannot be undone.")
        }
        .alert("Restore Items", isPresented: $viewModel.showRestoreAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Restore") {
                viewModel.restoreSelected()
            }
        } message: {
            Text("Restore \(viewModel.selectedItems.count) item(s) to their original location?")
        }
        .alert("Empty Trash", isPresented: $viewModel.showEmptyTrashAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Empty Trash", role: .destructive) {
                viewModel.emptyAllTrash()
            }
        } message: {
            Text("Are you sure you want to permanently delete all \(viewModel.deletedItems.count) items in trash? This action cannot be undone.")
        }
        .fullScreenCover(isPresented: viewModel.isMediaViewerPresented) {
            UnifiedMediaViewerView(
                mediaItems: viewModel.getMediaFiles(),
                initialIndex: viewModel.mediaViewerIndex
            )
        }
        .fullScreenCover(isPresented: $viewModel.showFilePreview) {
            if let filePreviewItem = viewModel.filePreviewItem {
                FilePreviewView(vaultItem: filePreviewItem)
            }
        }
        .onAppear {
            viewModel.loadDeletedItems()
        }
    }
    

    
    private var emptyTrashView: some View {
        VStack(spacing: 32) {
            VStack(spacing: 20) {
                Image(systemName: "trash")
                    .font(.system(size: 80))
                    .foregroundColor(.green)
                
                Text("Trash is Empty")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                Text("When you delete files with trash enabled, they'll appear here as a gallery. You can restore them or permanently delete them.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .foregroundColor(.blue)
                        .font(.title2)
                    Text("Select items and restore to their original location")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack(spacing: 12) {
                    Image(systemName: "trash.slash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                    Text("Permanently delete items you no longer need")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var bottomActionBar: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack(spacing: 0) {
                // Restore button
                Button(action: {
                    viewModel.showRestoreAlert = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.title2)
                        Text("Restore (\(viewModel.selectedItems.count))")
                            .font(.caption)
                    }
                    .foregroundColor(.blue)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                
                Divider()
                    .frame(height: 40)
                
                // Delete button
                Button(action: {
                    viewModel.showDeleteAlert = true
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Delete (\(viewModel.selectedItems.count))")
                            .font(.caption)
                    }
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
            }
            .padding(.horizontal)
            .background(Color(.systemGray6))
        }
    }
    
    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}



#Preview {
    TrashView()
}