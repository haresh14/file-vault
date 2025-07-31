import SwiftUI

/// Displays the items within a given `CategoryType` and allows sorting,
/// multi-select, move, and delete actions.
struct CategoryFilesView: View {
    let categoryType: CategoryType
    @StateObject private var viewModel: CategoryFilesViewModel

    @State private var showUnifiedMediaViewer = false
    @State private var mediaViewerIndex = -1
    @State private var showSortActionSheet = false
    @State private var showDeleteAlert = false
    @State private var showMoveSheet = false

    private var isMediaViewerPresented: Binding<Bool> {
        Binding(
            get: { showUnifiedMediaViewer && mediaViewerIndex > -1 },
            set: { newValue in
                if !newValue {
                    showUnifiedMediaViewer = false
                    mediaViewerIndex = -1
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
                                mediaViewerIndex = index
                                showUnifiedMediaViewer = true
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
                    Button(action: { showDeleteAlert = true }) {
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
        SortPopupView(
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
            mediaItems: sortedItems,
            initialIndex: mediaViewerIndex
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

    @State private var navigationPath: [Folder] = []
    @State private var currentLevelFolders: [Folder] = []
    @Environment(\.dismiss) private var dismiss

    private var currentNavigationFolder: Folder? { navigationPath.last }

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                breadcrumb
                foldersList
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear { loadCurrentLevelFolders() }
        }
    }

    // MARK: - Subviews
    private var breadcrumb: some View {
        Group {
            if !navigationPath.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        Button("Root") {
                            navigationPath.removeAll()
                            loadCurrentLevelFolders()
                        }
                        .foregroundColor(.blue)

                        ForEach(Array(navigationPath.enumerated()), id: \.element.objectID) { index, folder in
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Button(folder.displayName) {
                                    navigationPath = Array(navigationPath.prefix(index + 1))
                                    loadCurrentLevelFolders()
                                }
                                .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
            }
        }
    }

    private var foldersList: some View {
        List {
            moveHereButton
            ForEach(currentLevelFolders, id: \.objectID) { folder in
                folderRow(folder)
            }
        }
    }

    private var moveHereButton: some View {
        Button(action: {
            onMove(currentNavigationFolder)
            dismiss()
        }) {
            HStack {
                Image(systemName: "arrow.down.doc.fill")
                    .foregroundColor(.white)
                    .font(.title3)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Move Here")
                        .foregroundColor(.white)
                        .fontWeight(.semibold)
                        .font(.body)
                    Text(currentNavigationFolder?.displayName ?? "Root Folder")
                        .foregroundColor(.white.opacity(0.8))
                        .font(.caption)
                }
                Spacer()
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 16)
            .background(Color.green)
            .cornerRadius(12)
        }
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
        .listRowBackground(Color.clear)
    }

    private func folderRow(_ folder: Folder) -> some View {
        Button(action: {
            navigationPath.append(folder)
            loadCurrentLevelFolders()
        }) {
            HStack {
                Image(systemName: "folder.fill")
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text(folder.displayName)
                        .foregroundColor(.primary)
                        .font(.body)
                    Text("\(folder.totalItemCount) items")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
        }
        .contextMenu {
            Button("Move Here") {
                onMove(folder)
                dismiss()
            }
        }
    }

    // MARK: - Helpers
    private func loadCurrentLevelFolders() {
        if let currentNavFolder = currentNavigationFolder {
            currentLevelFolders = currentNavFolder.subfoldersArray.sorted { $0.displayName < $1.displayName }
        } else {
            currentLevelFolders = CoreDataManager.shared.fetchRootFolders().sorted { $0.displayName < $1.displayName }
        }
    }
}

#Preview {
    CategoryFilesView(categoryType: .photos)
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 