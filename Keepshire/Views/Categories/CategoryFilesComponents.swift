import SwiftUI

struct CategoryFilesEmptyState: View {
    let categoryType: CategoryType
    let isSearching: Bool
    let searchText: String

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isSearching ? "magnifyingglass" : categoryType.systemImage)
                .font(.system(size: 80))
                .foregroundColor(.gray)
            Text(isSearching ? "No Results" : "No \(categoryType.rawValue)")
                .font(.title2)
                .fontWeight(.semibold)
            Text(
                isSearching
                    ? "No \(categoryType.rawValue.lowercased()) match '\(searchText)'"
                    : "Files of this type will appear here when you add them to your vault"
            )
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct CategoryFilesGrid: View {
    private enum Layout {
        static let minimumCellWidth: CGFloat = 100
        static let maximumCellWidth: CGFloat = 150
        static let spacing: CGFloat = 2
    }

    let items: [VaultItem]
    let selectedItems: Set<VaultItem>
    let isSelectionMode: Bool
    let showFavoriteIndicator: Bool
    let open: (VaultItem) -> Void
    let select: (VaultItem) -> Void
    let longPress: (VaultItem) -> Void
    let favorite: (VaultItem) -> Void
    let rename: (VaultItem) -> Void
    let move: (VaultItem) -> Void
    let share: (VaultItem) -> Void
    let delete: (VaultItem) -> Void

    private var columns: [GridItem] {
        [GridItem(.adaptive(minimum: Layout.minimumCellWidth, maximum: Layout.maximumCellWidth), spacing: Layout.spacing)]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: Layout.spacing) {
                ForEach(items) { item in
                    VaultItemCell(
                        item: item,
                        isSelected: selectedItems.contains(item),
                        isSelectionMode: isSelectionMode,
                        showFavoriteIndicator: showFavoriteIndicator,
                        onTap: { isSelectionMode ? select(item) : open(item) },
                        onLongPress: { longPress(item) }
                    )
                    .contextMenu {
                        Button(action: { select(item) }) {
                            Label("Select", systemImage: "checkmark.circle")
                        }
                        Divider()
                        Button(action: { favorite(item) }) {
                            Label(
                                item.isFavorite ? "Unfavorite" : "Favorite",
                                systemImage: item.isFavorite ? "heart.slash" : "heart"
                            )
                        }
                        Button(action: { rename(item) }) {
                            Label("Rename", systemImage: "pencil")
                        }
                        Button(action: { move(item) }) {
                            Label("Move", systemImage: "folder")
                        }
                        Divider()
                        Button(action: { share(item) }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }
                        Divider()
                        Button(role: .destructive, action: { delete(item) }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(.horizontal, Layout.spacing)
        }
    }
}

struct CategoryFilesToolbar: ToolbarContent {
    let isSelectionMode: Bool
    let hasSelection: Bool
    let hasItems: Bool
    let selectAll: () -> Void
    let cancel: () -> Void
    let favorite: () -> Void
    let share: () -> Void
    let move: () -> Void
    let delete: () -> Void
    let sort: () -> Void
    let enterSelection: () -> Void

    var body: some ToolbarContent {
        ToolbarItem(placement: .navigationBarLeading) {
            if isSelectionMode {
                Button("Select All", action: selectAll)
            }
        }
        ToolbarItemGroup(placement: .navigationBarTrailing) {
            if isSelectionMode {
                Button("Cancel", action: cancel)
                if hasSelection {
                    Menu {
                        Button(action: favorite) { Label("Favorite", systemImage: "heart") }
                        Button(action: share) { Label("Share", systemImage: "square.and.arrow.up") }
                        Button(action: move) { Label("Move", systemImage: "arrow.up.doc.on.clipboard") }
                        Divider()
                        Button(role: .destructive, action: delete) { Label("Delete", systemImage: "trash") }
                    } label: {
                        Image(systemName: "ellipsis.circle").foregroundColor(.blue)
                    }
                }
            } else {
                Menu {
                    Button(action: sort) { Label("Sort", systemImage: "arrow.up.arrow.down") }
                    if hasItems {
                        Divider()
                        Button(action: enterSelection) { Label("Select Items", systemImage: "checkmark.circle") }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").foregroundColor(.blue)
                }
            }
        }
    }
}

struct CategoryFilesSortSheet: View {
    let currentSortOption: SortOption
    let sortAscending: Bool
    let select: (SortOption) -> Void

    var body: some View {
        CategorySortPopupView(
            currentSortOption: currentSortOption,
            sortAscending: sortAscending,
            onSortSelected: select
        )
        .presentationDetents([.fraction(0.5)])
        .presentationDragIndicator(.visible)
    }
}

struct CategoryFilesMoveSheet: View {
    let selectedFiles: Set<VaultItem>
    let move: (Folder?) -> Void

    var body: some View {
        UniversalFolderPickerView.forFiles(selectedFiles: selectedFiles, onMove: move)
    }
}

struct CategoryFilesAlertModifier: ViewModifier {
    @Binding var showDeleteAlert: Bool
    @Binding var showRenameAlert: Bool
    @Binding var renameText: String
    let selectedCount: Int
    let delete: () -> Void
    let cancelRename: () -> Void
    let rename: () -> Void

    func body(content: Content) -> some View {
        content
            .alert("Delete Items", isPresented: $showDeleteAlert) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive, action: delete)
            } message: {
                Text("Are you sure you want to delete \(selectedCount) item(s)? This action cannot be undone.")
            }
            .alert("Rename", isPresented: $showRenameAlert) {
                TextField("Name", text: $renameText)
                Button("Cancel", role: .cancel, action: cancelRename)
                Button("Rename", action: rename)
            } message: {
                Text("Enter a new name")
            }
    }
}
