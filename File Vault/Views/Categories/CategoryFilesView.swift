import SwiftUI

/// Displays the items within a given `CategoryType` and allows sorting,
/// multi-select, move, and delete actions.
struct CategoryFilesView: View {
    let categoryType: CategoryType
    @StateObject private var viewModel: CategoryFilesViewModel

    @State private var showSortActionSheet = false
    @State private var showDeleteAlert = false
    @State private var showMoveSheet = false

    private var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { viewModel.showUnifiedMediaViewer && viewModel.mediaViewerIndex > -1 },
            set: { newValue in
                if !newValue {
                    viewModel.showUnifiedMediaViewer = false
                    viewModel.mediaViewerIndex = -1
                }
            }
        )
    }

    init(categoryType: CategoryType) {
        self.categoryType = categoryType
        _viewModel = StateObject(wrappedValue: CategoryFilesViewModel(categoryType: categoryType))
    }

    var sortedItems: [VaultItem] { viewModel.sortedItems }

    private let columns = [GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)]

    var body: some View {
        ZStack {
            Group {
                if viewModel.items.isEmpty {
                    emptyState
                } else {
                    itemsGrid
                }
            }
        }
        .navigationTitle(categoryType.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(viewModel.isSelectionMode)
        .toolbar { toolbarContent }
        .sheet(isPresented: $showSortActionSheet) { sortSheet }
        .fullScreenCover(isPresented: isMediaViewerPresented) { mediaViewer }
        .fullScreenCover(isPresented: $viewModel.showFilePreview) {
            if let filePreviewItem = viewModel.filePreviewItem {
                FilePreviewView(vaultItem: filePreviewItem)
            }
        }
        .sheet(isPresented: $showMoveSheet) { moveSheet }
        .alert("Delete Items", isPresented: $showDeleteAlert) {
            alertButtons
        } message: {
            Text("Are you sure you want to delete \(viewModel.selectedItems.count) item(s)? This action cannot be undone.")
        }
    }

    // MARK: - Subviews
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: categoryType.systemImage)
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text("No \(categoryType.rawValue)")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Files of this type will appear here when you add them to your vault")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var itemsGrid: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                    VaultItemCell(
                        item: item,
                        isSelected: viewModel.selectedItems.contains(item),
                        isSelectionMode: viewModel.isSelectionMode,
                        onTap: {
                            if viewModel.isSelectionMode {
                                viewModel.toggleSelection(item)
                            } else {
                                viewModel.viewFile(item)
                            }
                        },
                        onLongPress: {
                            if !viewModel.isSelectionMode {
                                viewModel.enterSelectionMode()
                                viewModel.toggleSelection(item)
                            }
                        }
                    )
                }
            }
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Toolbar
    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if viewModel.isSelectionMode {
                Button("Select All") { viewModel.selectAll() }
            }
        }

        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if viewModel.isSelectionMode {
                if !viewModel.selectedItems.isEmpty {
                    Button(action: { showMoveSheet = true }) {
                        Image(systemName: "arrow.up.doc.on.clipboard")
                            .foregroundColor(.blue)
                    }
                    Button(action: { 
                        // Skip confirmation if trash is enabled
                        if UserDefaults.standard.bool(forKey: "trashEnabled") {
                            viewModel.deleteSelectedItems()
                        } else {
                            showDeleteAlert = true
                        }
                    }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
                    }
                }
                Button("Cancel") { viewModel.exitSelectionMode() }
            } else {
                Button(action: { showSortActionSheet = true }) {
                    Image(systemName: "arrow.up.arrow.down")
                }
                if !viewModel.items.isEmpty {
                    Button("Select") { viewModel.enterSelectionMode() }
                }
            }
        }
    }

    // MARK: - Sheets & Alerts
    private var sortSheet: some View {
        CategorySortPopupView(
            currentSortOption: viewModel.sortOption,
            sortAscending: viewModel.sortAscending,
            onSortSelected: { option in
                if option == viewModel.sortOption {
                    viewModel.sortAscending.toggle()
                } else {
                    viewModel.sortOption = option
                    viewModel.sortAscending = true
                }
                showSortActionSheet = false
            }
        )
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }

    private var mediaViewer: some View {
        UnifiedMediaViewerView(
            mediaItems: viewModel.getMediaFiles(),
            initialIndex: viewModel.mediaViewerIndex
        )
    }

    private var moveSheet: some View {
        CategoryFolderPickerView(
            selectedFiles: viewModel.selectedItems,
            onMove: { destination in
                viewModel.moveSelectedItems(to: destination)
                showMoveSheet = false
            }
        )
    }

    @ViewBuilder
    private var alertButtons: some View {
        Button("Cancel", role: .cancel) { }
        Button("Delete", role: .destructive) { viewModel.deleteSelectedItems() }
    }
}

// MARK: - Category Folder Picker View
struct CategoryFolderPickerView: View {
    let selectedFiles: Set<VaultItem>
    let onMove: (Folder?) -> Void

    var body: some View {
        UniversalFolderPickerView.forFiles(
            selectedFiles: selectedFiles,
            onMove: onMove
        )
    }
}

#Preview {
    CategoryFilesView(categoryType: .photos)
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 