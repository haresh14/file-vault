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
                loadVaultItems()
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
        .navigationTitle(categoryType.rawValue)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItemGroup(placement: .navigationBarTrailing) {
                if isSelectionMode {
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
            
            if isSelectionMode && !selectedItems.isEmpty {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { showDeleteAlert = true }) {
                        Image(systemName: "trash")
                            .foregroundColor(.red)
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
        // Small delay to ensure Core Data changes are propagated
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
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

#Preview {
    CategoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 