import SwiftUI

/// Displays the items within a given `CategoryType` and allows sorting,
/// multi-select, move, and delete actions.
struct CategoryFilesView: View {
    let categoryType: CategoryType
    @StateObject private var viewModel: CategoryFilesViewModel

    @State private var showSortActionSheet = false
    @State private var showDeleteAlert = false
    @State private var showMoveSheet = false
    
    // MARK: - Rename State
    
    @State private var showRenameAlert = false
    @State private var renameText = ""
    @State private var itemToRename: VaultItem?

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
                        showFavoriteIndicator: categoryType != .favorites,
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
                    .contextMenu {
                        // Select option
                        Button(action: {
                            if !viewModel.isSelectionMode {
                                viewModel.enterSelectionMode()
                            }
                            viewModel.toggleSelection(item)
                        }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        
                        Divider()
                        
                        // Favorite/Unfavorite option
                        Button(action: {
                            viewModel.toggleFavorite(for: item)
                        }) {
                            Label(
                                item.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: item.isFavorite ? "heart.slash" : "heart"
                            )
                        }
                        
                        // Rename option
                        Button(action: {
                            startRename(for: item)
                        }) {
                            Label("Rename", systemImage: "pencil")
                        }
                        
                        // Move option
                        Button(action: {
                            viewModel.moveItem(item, showMoveSheet: { showMoveSheet = true })
                        }) {
                            Label("Move", systemImage: "folder")
                        }
                        
                        Divider()
                        
                        // Share option
                        Button(action: {
                            viewModel.shareItem(item)
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Divider()
                        
                        // Delete option (in red)
                        Button(role: .destructive, action: {
                            if UserDefaults.standard.bool(forKey: "trashEnabled") {
                                viewModel.deleteItem(item)
                            } else {
                                // Select the item and show delete alert
                                if !viewModel.isSelectionMode {
                                    viewModel.enterSelectionMode()
                                }
                                viewModel.selectedItems = [item]
                                showDeleteAlert = true
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
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
                    Menu {
                        Button(action: { viewModel.shareSelectedItems() }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        
                        Button(action: { showMoveSheet = true }) {
                            Label("Move", systemImage: "arrow.up.doc.on.clipboard")
                        }
                        
                        Divider()
                        
                        Button(role: .destructive, action: { 
                            // Skip confirmation if trash is enabled
                            if UserDefaults.standard.bool(forKey: "trashEnabled") {
                                viewModel.deleteSelectedItems()
                            } else {
                                showDeleteAlert = true
                            }
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(.blue)
                    }
                }
                Button("Cancel") { viewModel.exitSelectionMode() }
            } else {
                Menu {
                    Button(action: { showSortActionSheet = true }) {
                        Label("Sort", systemImage: "arrow.up.arrow.down")
                    }
                    
                    if !viewModel.items.isEmpty {
                        Divider()
                        
                        Button(action: { viewModel.enterSelectionMode() }) {
                            Label("Select Items", systemImage: "checkmark.circle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundColor(.blue)
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
            NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
            
            cancelRename()
        } catch {
            print("Error renaming file: \(error)")
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