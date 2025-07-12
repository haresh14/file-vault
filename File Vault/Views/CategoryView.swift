//
//  CategoryView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

enum CategoryType: String, CaseIterable {
    case photos = "Photos"
    case videos = "Videos"
    case documents = "Documents"
    case allFiles = "All Files"
    
    var systemImage: String {
        switch self {
        case .photos:
            return "photo"
        case .videos:
            return "video"
        case .documents:
            return "doc"
        case .allFiles:
            return "folder"
        }
    }
    
    var color: Color {
        switch self {
        case .photos:
            return .blue
        case .videos:
            return .purple
        case .documents:
            return .orange
        case .allFiles:
            return .gray
        }
    }
}

struct CategoryView: View {
    @State private var allVaultItems: [VaultItem] = []

    @Environment(\.managedObjectContext) var context
    
    var photoItems: [VaultItem] {
        allVaultItems.filter { $0.isImage }
    }
    
    var videoItems: [VaultItem] {
        allVaultItems.filter { $0.isVideo }
    }
    
    var documentItems: [VaultItem] {
        allVaultItems.filter { $0.isDocument }
    }
    
    private func getItemCount(for categoryType: CategoryType) -> Int {
        switch categoryType {
        case .photos:
            return photoItems.count
        case .videos:
            return videoItems.count
        case .documents:
            return documentItems.count
        case .allFiles:
            return allVaultItems.count
        }
    }
    
    private func getItems(for categoryType: CategoryType) -> [VaultItem] {
        switch categoryType {
        case .photos:
            return photoItems
        case .videos:
            return videoItems
        case .documents:
            return documentItems
        case .allFiles:
            return allVaultItems
        }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(CategoryType.allCases, id: \.self) { categoryType in
                        NavigationLink(destination: CategoryFilesView(
                            categoryType: categoryType
                        )) {
                            CategoryCard(
                                categoryType: categoryType,
                                itemCount: getItemCount(for: categoryType)
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                .padding()
            }
                    .navigationTitle("Categories")
        .navigationBarTitleDisplayMode(.large)


        .onAppear {
            loadVaultItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))) { _ in
            DispatchQueue.main.async {
                loadVaultItems()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            DispatchQueue.main.async {
                loadVaultItems()
            }
        }
        }
    }
    
    private func loadVaultItems() {
        allVaultItems = CoreDataManager.shared.fetchVaultItemsFromAllFolders()
    }
}

struct CategoryCard: View {
    let categoryType: CategoryType
    let itemCount: Int
    
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: categoryType.systemImage)
                .font(.system(size: 40))
                .foregroundColor(categoryType.color)
            
            Text(categoryType.rawValue)
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("\(itemCount) items")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct CategoryFilesView: View {
    let categoryType: CategoryType
    @State private var items: [VaultItem] = []
    @State private var showUnifiedMediaViewer = false
    @State private var mediaViewerIndex = 0
    @State private var sortOption: SortOption = .date
    @State private var sortAscending: Bool = false
    @State private var showSortActionSheet = false
    @State private var isSelectionMode = false
    @State private var selectedItems: Set<VaultItem> = []
    @State private var showDeleteAlert = false
    @State private var showMoveSheet = false
    
    // Remove the items parameter and make it reactive
    init(categoryType: CategoryType) {
        self.categoryType = categoryType
    }
    
    var sortedItems: [VaultItem] {
        let sorted: [VaultItem]
        
        switch sortOption {
        case .userDefault, .date:
            sorted = items.sorted { ($0.createdAt ?? Date.distantPast) < ($1.createdAt ?? Date.distantPast) }
        case .name:
            sorted = items.sorted { ($0.fileName ?? "") < ($1.fileName ?? "") }
        case .size:
            sorted = items.sorted { $0.fileSize < $1.fileSize }
        case .kind:
            sorted = items.sorted { ($0.fileType ?? "") < ($1.fileType ?? "") }
        }
        
        return sortAscending ? sorted : sorted.reversed()
    }
    
    let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 150), spacing: 2)
    ]
    
    var body: some View {
        ZStack {
            Group {
                if items.isEmpty {
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
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 2) {
                            ForEach(Array(sortedItems.enumerated()), id: \.element.id) { index, item in
                                VaultItemCell(
                                    item: item,
                                    isSelected: selectedItems.contains(item),
                                    isSelectionMode: isSelectionMode,
                                    onTap: {
                                        if isSelectionMode {
                                            toggleSelection(item)
                                        } else {
                                            mediaViewerIndex = index
                                            showUnifiedMediaViewer = true
                                        }
                                    },
                                    onLongPress: {
                                        if !isSelectionMode {
                                            enterSelectionMode()
                                            selectedItems.insert(item)
                                        }
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 2)
                    }
                }
            }
            

        }
        .navigationTitle(categoryType.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .navigationBarBackButtonHidden(isSelectionMode)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                if isSelectionMode {
                    Button("Select All") {
                        selectAllItems()
                    }
                } else {
                    // Don't show settings button when inside a category view
                    EmptyView()
                }
            }
            
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isSelectionMode {
                    if !selectedItems.isEmpty {
                        Button(action: { showMoveSheet = true }) {
                            Image(systemName: "arrow.up.doc.on.clipboard")
                                .foregroundColor(.blue)
                        }
                        
                        Button(action: { showDeleteAlert = true }) {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                        }
                    }
                    
                    Button("Cancel") {
                        exitSelectionMode()
                    }
                } else {
                    Button(action: { showSortActionSheet = true }) {
                        Image(systemName: "arrow.up.arrow.down")
                    }
                    
                    if !items.isEmpty {
                        Button("Select") {
                            enterSelectionMode()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showSortActionSheet) {
            SortPopupView(
                currentSortOption: sortOption,
                sortAscending: sortAscending,
                onSortSelected: { option in
                    if option == sortOption {
                        sortAscending.toggle()
                    } else {
                        sortOption = option
                        sortAscending = true
                    }
                    showSortActionSheet = false
                }
            )
            .presentationDetents([.fraction(0.5)])
            .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showUnifiedMediaViewer) {
            UnifiedMediaViewerView(
                mediaItems: sortedItems,
                initialIndex: mediaViewerIndex
            )
        }
        .sheet(isPresented: $showMoveSheet) {
            CategoryFolderPickerView(
                selectedFiles: selectedItems,
                onMove: { destinationFolder in
                    moveSelectedItems(to: destinationFolder)
                    showMoveSheet = false
                }
            )
        }
        .alert("Delete Items", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteSelectedItems()
            }
        } message: {
            Text("Are you sure you want to delete \(selectedItems.count) item(s)? This action cannot be undone.")
        }
        .onAppear {
            loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("RefreshVaultItems"))) { _ in
            loadItems()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            loadItems()
        }
    }
    
    private func loadItems() {
        let allItems = CoreDataManager.shared.fetchVaultItemsFromAllFolders()
        
        switch categoryType {
        case .photos:
            items = allItems.filter { $0.isImage }
        case .videos:
            items = allItems.filter { $0.isVideo }
        case .documents:
            items = allItems.filter { $0.isDocument }
        case .allFiles:
            items = allItems
        }
        
        // Force a UI update
        DispatchQueue.main.async {
            // This ensures the view updates
        }
    }
    
    private func enterSelectionMode() {
        isSelectionMode = true
        selectedItems.removeAll()
    }
    
    private func exitSelectionMode() {
        isSelectionMode = false
        selectedItems.removeAll()
    }
    
    private func toggleSelection(_ item: VaultItem) {
        if selectedItems.contains(item) {
            selectedItems.remove(item)
        } else {
            selectedItems.insert(item)
        }
    }
    
    private func selectAllItems() {
        selectedItems = Set(items)
    }
    
    private func moveSelectedItems(to destinationFolder: Folder?) {
        for item in selectedItems {
            CoreDataManager.shared.moveVaultItem(item, to: destinationFolder)
        }
        
        exitSelectionMode()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }
    
    private func deleteSelectedItems() {
        for item in selectedItems {
            do {
                try FileStorageManager.shared.deleteFile(vaultItem: item)
            } catch {
                print("Error deleting item: \(error)")
            }
        }
        
        exitSelectionMode()
        
        // Post notification to refresh other views
        NotificationCenter.default.post(name: Notification.Name("RefreshVaultItems"), object: nil)
    }
}

// MARK: - Category Folder Picker View

struct CategoryFolderPickerView: View {
    let selectedFiles: Set<VaultItem>
    let onMove: (Folder?) -> Void
    
    @State private var navigationPath: [Folder] = []
    @State private var currentLevelFolders: [Folder] = []
    @Environment(\.dismiss) private var dismiss
    
    var currentNavigationFolder: Folder? {
        navigationPath.last
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Breadcrumb navigation
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
                
                List {
                    // Move here button
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
                    
                    // Folders in current level
                    ForEach(currentLevelFolders, id: \.objectID) { folder in
                        Button(action: {
                            // Always navigate into folder, never move directly
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
                }
            }
            .navigationTitle("Move to Folder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                loadCurrentLevelFolders()
            }
        }
    }
    
    private func loadCurrentLevelFolders() {
        if let currentNavFolder = currentNavigationFolder {
            currentLevelFolders = currentNavFolder.subfoldersArray.sorted { $0.displayName < $1.displayName }
        } else {
            currentLevelFolders = CoreDataManager.shared.fetchRootFolders().sorted { $0.displayName < $1.displayName }
        }
    }
}

#Preview {
    CategoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 