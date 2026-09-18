//
//  VaultMainView.swift
//  Keepshire
//
//  Created on 10/07/25.
//  Refactored to use MVVM architecture and reusable components
//

import SwiftUI
import PhotosUI
import CoreData

/// Main gallery view displaying vault items with MVVM architecture
struct VaultMainView: View {
    // MARK: - ViewModels
    
    @StateObject private var viewModel: VaultMainViewModel
    @StateObject private var importProgressViewModel = ImportProgressViewModel()
    @StateObject private var loginStateManager = LoginStateManager.shared
    
    // MARK: - Rename State
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var itemToRename: VaultItem?
    @State private var previewItem: VaultItem?
    
    // MARK: - Environment
    
    @Environment(\.managedObjectContext) var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    init(dependencies: DependencyContainer = .shared) {
        _viewModel = StateObject(wrappedValue: VaultMainViewModel(dependencies: dependencies))
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if horizontalSizeClass == .regular {
                NavigationSplitView {
                    galleryContent
                    .navigationSplitViewColumnWidth(min: 420, ideal: 620)
                } detail: {
                    VaultPreviewDetail(
                        item: previewItem,
                        mediaItems: viewModel.getMediaFiles(),
                        onClose: { previewItem = nil }
                    )
                }
            } else {
                NavigationStack {
                    galleryContent
                }
            }
        }
        .onChange(of: horizontalSizeClass) { _, sizeClass in
            if sizeClass == .regular {
                viewModel.showUnifiedMediaViewer = false
                viewModel.mediaViewerIndex = -1
                viewModel.showFilePreview = false
                viewModel.filePreviewItem = nil
            } else {
                previewItem = nil
            }
        }
    }

    private var galleryContent: some View {
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
                        onDelete: { 
                            // Skip confirmation if trash is enabled
                            if UserDefaults.standard.bool(forKey: "trashEnabled") {
                                viewModel.deleteSelectedItems()
                            } else {
                                viewModel.showDeleteAlert = true
                            }
                        },
                        onShare: { viewModel.shareSelectedItems() },
                        onFavorite: { viewModel.toggleFavoriteSelectedItems() },
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
                .presentationSizing(.form)
            }
                .sheet(isPresented: $viewModel.showAddActionSheet) {
                UniversalAddContentView.forGallery(
                        onAddPhotos: viewModel.handleAddPhotos,
                        onAddFiles: viewModel.handleAddFiles,
                        onWebUpload: viewModel.handleWebUpload
                )
                .presentationDetents([.fraction(0.4)])
                .presentationDragIndicator(.visible)
                .presentationSizing(.form)
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
                .sheet(isPresented: $viewModel.showMoveSheet) {
                GalleryFolderPickerView(
                        selectedFiles: viewModel.selectedItems,
                    onMove: { destinationFolder in
                            viewModel.moveSelectedItems(to: destinationFolder)
                            viewModel.showMoveSheet = false
                        }
                    )
                    .presentationSizing(.form)
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
    
    // MARK: - Content Views
    
    @ViewBuilder
    private var mainContent: some View {
        VaultGridView(
            items: viewModel.filteredItems,
            searchText: viewModel.searchText,
            isSelectionMode: viewModel.isSelectionMode,
            selectedItems: viewModel.selectedItems,
            isImporting: viewModel.isImporting,
            emptyStateConfig: emptyStateConfiguration,
            onItemTap: handleItemTap,
            onItemLongPress: handleItemLongPress,
            onFavoriteToggle: { item in
                viewModel.toggleFavorite(for: item)
            },
            onShare: { item in
                viewModel.shareItem(item)
            },
            onRename: { item in
                startRename(for: item)
            },
            onMove: { item in
                viewModel.moveItem(item)
            },
            onDelete: { item in
                viewModel.deleteItem(item)
            },
            onSelect: { item in
                if !viewModel.isSelectionMode {
                    viewModel.triggerSelectionHaptic()
                    viewModel.enterSelectionMode()
                }
                viewModel.selectedItems.insert(item)
            },
            showFavoriteIndicator: true
        )
        .alert("Rename", isPresented: $showRenameAlert) {
            TextField("Name", text: $renameText)
            Button("Cancel", role: .cancel) {
                cancelRename()
            }
            Button("Rename") {
                performRename()
            }
        } message: {
            Text("Enter a new name")
        }
    }
    
    /// Empty state configuration that respects fake login state
    private var emptyStateConfiguration: EmptyStateConfiguration {
        if loginStateManager.canAddFiles {
            return .noPhotos(onAddPhotos: { viewModel.showPhotoPicker = true })
        } else {
            // During fake login, show empty state without any actions
            return EmptyStateConfiguration(
                iconName: "photo.on.rectangle.angled",
                title: "No Photos or Videos", 
                subtitle: "Your photo gallery appears to be empty",
                primaryAction: nil,
                style: .default
            )
        }
    }
    
    // MARK: - Action Handlers
    
    private func handleItemTap(_ item: VaultItem) {
        if viewModel.isSelectionMode {
            viewModel.toggleSelection(for: item)
        } else if horizontalSizeClass == .regular {
            previewItem = item
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
    
    // MARK: - Rename Functions
    
    private func startRename(for item: VaultItem) {
        guard let fileName = item.fileName else { return }
        itemToRename = item
        renameText = getFileNameWithoutExtension(fileName)
        showRenameAlert = true
    }
    
    private func performRename() {
        guard let item = itemToRename, !renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            cancelRename()
            return
        }
        
        guard let oldFileName = item.fileName else {
            cancelRename()
            return
        }
        
        // Preserve the original file extension
        let url = URL(fileURLWithPath: oldFileName)
        let fileExtension = url.pathExtension
        let newFileName = fileExtension.isEmpty ? renameText : "\(renameText.trimmingCharacters(in: .whitespacesAndNewlines)).\(fileExtension)"
        
        do {
            // Rename the physical file first
            try FileStorageManager.shared.renameFile(vaultItem: item, newFileName: newFileName)
            
            // Refresh the view
            viewModel.loadVaultItems()
            
            cancelRename()
        } catch {
            VaultLog.debug("Error renaming file: \(error)")
            // Show error to user - for now just cancel
            cancelRename()
        }
    }
    
    private func cancelRename() {
        showRenameAlert = false
        itemToRename = nil
        renameText = ""
    }
    
    private func getFileNameWithoutExtension(_ fileName: String) -> String {
        let url = URL(fileURLWithPath: fileName)
        return url.deletingPathExtension().lastPathComponent
    }
}

// MARK: - Supporting Views



// MARK: - Preview Support

#Preview {
    VaultMainView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}