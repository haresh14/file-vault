import Foundation
import SwiftUI

struct CategoryFilesView: View {
    private enum Constants {
        static let trashEnabledKey = "trashEnabled"
    }

    let categoryType: CategoryType
    let onPreviewFile: ((VaultItem, [VaultItem]) -> Void)?
    @StateObject private var viewModel: CategoryFilesViewModel
    @State private var showSortActionSheet = false
    @State private var showDeleteAlert = false
    @State private var showMoveSheet = false
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var itemToRename: VaultItem?

    init(
        categoryType: CategoryType,
        onPreviewFile: ((VaultItem, [VaultItem]) -> Void)? = nil,
        dependencies: DependencyContainer = .shared
    ) {
        self.categoryType = categoryType
        self.onPreviewFile = onPreviewFile
        _viewModel = StateObject(
            wrappedValue: CategoryFilesViewModel(categoryType: categoryType, dependencies: dependencies)
        )
    }

    var body: some View {
        Group {
            if viewModel.sortedItems.isEmpty {
                CategoryFilesEmptyState(
                    categoryType: categoryType,
                    isSearching: viewModel.isSearching,
                    searchText: viewModel.searchText
                )
            } else {
                itemsGrid
            }
        }
        .navigationTitle(categoryType.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(viewModel.isSelectionMode)
        .searchable(text: $viewModel.searchText, prompt: "Search \(categoryType.rawValue.lowercased())")
        .toolbar { toolbar }
        .sheet(isPresented: $showSortActionSheet) {
            CategoryFilesSortSheet(
                currentSortOption: viewModel.sortOption,
                sortAscending: viewModel.sortAscending,
                select: selectSortOption
            )
            .presentationSizing(.form)
        }
        .sheet(isPresented: $showMoveSheet) {
            CategoryFilesMoveSheet(selectedFiles: viewModel.selectedItems) { destination in
                viewModel.moveSelectedItems(to: destination)
                showMoveSheet = false
            }
            .presentationSizing(.form)
        }
        .fullScreenCover(isPresented: mediaViewerPresented) {
            UnifiedMediaViewerView(
                mediaItems: viewModel.getMediaFiles(),
                initialIndex: viewModel.mediaViewerIndex
            )
        }
        .fullScreenCover(isPresented: $viewModel.showFilePreview) {
            if let item = viewModel.filePreviewItem {
                FilePreviewView(vaultItem: item)
            }
        }
        .modifier(CategoryFilesAlertModifier(
            showDeleteAlert: $showDeleteAlert,
            showRenameAlert: $showRenameAlert,
            renameText: $renameText,
            selectedCount: viewModel.selectedItems.count,
            delete: viewModel.deleteSelectedItems,
            cancelRename: cancelRename,
            rename: performRename
        ))
    }

    private var itemsGrid: some View {
        CategoryFilesGrid(
            items: viewModel.sortedItems,
            selectedItems: viewModel.selectedItems,
            isSelectionMode: viewModel.isSelectionMode,
            showFavoriteIndicator: categoryType != .favorites,
            open: { item in
                if let onPreviewFile {
                    onPreviewFile(item, viewModel.getMediaFiles())
                } else {
                    viewModel.viewFile(item)
                }
            },
            select: viewModel.toggleSelection,
            longPress: { item in
                if !viewModel.isSelectionMode {
                    viewModel.enterSelectionMode()
                    viewModel.toggleSelection(item)
                }
            },
            favorite: viewModel.toggleFavorite,
            rename: startRename,
            move: { item in viewModel.moveItem(item, showMoveSheet: { showMoveSheet = true }) },
            share: viewModel.shareItem,
            delete: requestDelete
        )
    }

    private var toolbar: some ToolbarContent {
        CategoryFilesToolbar(
            isSelectionMode: viewModel.isSelectionMode,
            hasSelection: !viewModel.selectedItems.isEmpty,
            hasItems: !viewModel.sortedItems.isEmpty,
            selectAll: viewModel.selectAll,
            cancel: viewModel.exitSelectionMode,
            favorite: viewModel.toggleFavoriteSelectedItems,
            share: viewModel.shareSelectedItems,
            move: { showMoveSheet = true },
            delete: requestDeleteSelected,
            sort: { showSortActionSheet = true },
            enterSelection: viewModel.enterSelectionMode
        )
    }

    private var mediaViewerPresented: Binding<Bool> {
        Binding(
            get: { viewModel.showUnifiedMediaViewer && viewModel.mediaViewerIndex > -1 },
            set: { isPresented in
                if !isPresented {
                    viewModel.showUnifiedMediaViewer = false
                    viewModel.mediaViewerIndex = -1
                }
            }
        )
    }

    private func selectSortOption(_ option: SortOption) {
        if option == viewModel.sortOption {
            viewModel.sortAscending.toggle()
        } else {
            viewModel.sortOption = option
            viewModel.sortAscending = true
        }
        showSortActionSheet = false
    }

    private func requestDeleteSelected() {
        if UserDefaults.standard.bool(forKey: Constants.trashEnabledKey) {
            viewModel.deleteSelectedItems()
        } else {
            showDeleteAlert = true
        }
    }

    private func requestDelete(_ item: VaultItem) {
        if UserDefaults.standard.bool(forKey: Constants.trashEnabledKey) {
            viewModel.deleteItem(item)
        } else {
            if !viewModel.isSelectionMode {
                viewModel.enterSelectionMode()
            }
            viewModel.selectedItems = [item]
            showDeleteAlert = true
        }
    }

    private func startRename(for item: VaultItem) {
        guard let fileName = item.fileName else { return }
        itemToRename = item
        renameText = URL(fileURLWithPath: fileName).deletingPathExtension().lastPathComponent
        showRenameAlert = true
    }

    private func performRename() {
        let trimmedName = renameText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let item = itemToRename, !trimmedName.isEmpty, let oldFileName = item.fileName else {
            cancelRename()
            return
        }
        let fileExtension = URL(fileURLWithPath: oldFileName).pathExtension
        let newFileName = fileExtension.isEmpty ? renameText : "\(trimmedName).\(fileExtension)"
        do {
            try FileStorageManager.shared.renameFile(vaultItem: item, newFileName: newFileName)
            NotificationCenter.default.post(name: .refreshVaultItems, object: nil)
        } catch {
            VaultLog.debug("Error renaming file: \(error)")
        }
        cancelRename()
    }

    private func cancelRename() {
        showRenameAlert = false
        itemToRename = nil
        renameText = ""
    }
}

#Preview {
    CategoryFilesView(categoryType: .photos)
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
}
