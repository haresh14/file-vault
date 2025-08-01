//
//  VaultMainView.swift
//  File Vault
//
//  Created on 10/07/25.
//  Refactored to use MVVM architecture and reusable components
//

import SwiftUI
import PhotosUI

/// Main gallery view displaying vault items with MVVM architecture
struct VaultMainView: View {
    // MARK: - ViewModels
    
    @StateObject private var viewModel = VaultMainViewModel()
    @StateObject private var importProgressViewModel = ImportProgressViewModel()
    @StateObject private var loginStateManager = LoginStateManager.shared
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) var context
    
    // MARK: - Body
    
    var body: some View {
        NavigationView {
            mainContent
                .vaultNavigationTitle(
                    isSelectionMode: viewModel.isSelectionMode,
                    selectedCount: viewModel.selectionCount,
                    defaultTitle: "Gallery"
                )
                .toolbar {
                    VaultToolbarView(
                        isSelectionMode: viewModel.isSelectionMode,
                        selectedItemCount: viewModel.selectionCount,
                        totalItemCount: viewModel.vaultItems.count,
                        hasSelectedItems: viewModel.hasSelection,
                        canAddFiles: loginStateManager.canAddFiles,
                        isEmpty: viewModel.vaultItems.isEmpty,
                        onSelectAll: { viewModel.selectAll(from: viewModel.vaultItems) },
                        onMove: { viewModel.showMoveSheet = true },
                        onDelete: { viewModel.showDeleteAlert = true },
                        onCancel: { viewModel.exitSelectionMode() },
                        onAdd: { viewModel.showAddActions() },
                        onSort: { viewModel.showSortActionSheet = true },
                        onEnterSelection: { viewModel.enterSelectionMode() }
                    )
                }
                .searchable(text: $viewModel.searchText, prompt: "Search files")
                .sheet(isPresented: $viewModel.showPhotoPicker) {
                    PhotoPickerView { results in
                        viewModel.importAssets(results)
                    }
                }
                .sheet(isPresented: $viewModel.showDocumentPicker) {
                    DocumentPickerView { dataArray in
                        viewModel.importDocuments(dataArray)
                    }
                }
                .sheet(isPresented: $viewModel.showWebUpload) {
                    WebUploadView()
                }
                .sheet(isPresented: $viewModel.showSortActionSheet) {
                GallerySortPopupView(
                        currentSortOption: viewModel.sortOption,
                        sortAscending: viewModel.sortAscending,
                        onSortSelected: viewModel.handleSortSelection
                )
                .presentationDetents([.fraction(0.5)])
                .presentationDragIndicator(.visible)
            }
                .sheet(isPresented: $viewModel.showAddActionSheet) {
                UniversalAddContentView.forGallery(
                        onAddPhotos: viewModel.handleAddPhotos,
                        onAddFiles: viewModel.handleAddFiles,
                        onWebUpload: viewModel.handleWebUpload
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
            }
                .fullScreenCover(isPresented: viewModel.isMediaViewerPresented) {
                    UnifiedMediaViewerView(
                        mediaItems: viewModel.filteredItems,
                        initialIndex: viewModel.mediaViewerIndex
                    )
                }
                .sheet(isPresented: $viewModel.showMoveSheet) {
                GalleryFolderPickerView(
                        selectedFiles: viewModel.selectedItems,
                    onMove: { destinationFolder in
                            viewModel.moveSelectedItems(to: destinationFolder)
                            viewModel.showMoveSheet = false
                        }
                    )
                }
                .alert("Delete Items", isPresented: $viewModel.showDeleteAlert) {
                    Button("Cancel", role: .cancel) { }
                    Button("Delete", role: .destructive) {
                        viewModel.deleteSelectedItems()
                    }
                } message: {
                    Text("Are you sure you want to delete \(viewModel.selectionCount) item(s)? This action cannot be undone.")
                }
                .importProgressOverlay(
                    isImporting: viewModel.isImporting,
                    progress: viewModel.importProgress,
                    message: "Importing media files..."
                )
                .onAppear {
                    viewModel.loadVaultItems()
                }
        }
    }
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var mainContent: some View {
        VaultGridView(
            items: viewModel.filteredItems,
            searchText: viewModel.searchText,
            isSelectionMode: viewModel.isSelectionMode,
            selectedItems: viewModel.selectedItems,
            isImporting: viewModel.isImporting,
            emptyStateConfig: .noPhotos(onAddPhotos: { viewModel.showPhotoPicker = true }),
            onItemTap: handleItemTap,
            onItemLongPress: handleItemLongPress
        )
    }
    
    // MARK: - Action Handlers
    
    private func handleItemTap(_ item: VaultItem) {
        if viewModel.isSelectionMode {
            viewModel.toggleSelection(for: item)
        } else {
            viewModel.viewItem(item)
        }
    }
    
    private func handleItemLongPress(_ item: VaultItem) {
        if !viewModel.isSelectionMode {
            viewModel.triggerSelectionHaptic()
            viewModel.enterSelectionMode()
            viewModel.selectedItems.insert(item)
        }
    }
}

// MARK: - Supporting Views



// MARK: - Preview Support

#Preview {
    VaultMainView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}