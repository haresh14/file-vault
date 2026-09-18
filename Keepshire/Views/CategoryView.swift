//
//  CategoryView.swift
//  Keepshire
//
//  Created on 12/07/25.
//

import SwiftUI
import CoreData

// `CategoryType` has been moved to Models/CategoryType.swift
struct CategoryView: View {
    /// Owns the data-loading logic so that this view remains declarative.
    @StateObject private var viewModel = CategoryViewModel()
    @State private var selectedCategory: CategoryType?
    @State private var previewItem: VaultItem?
    @State private var previewMediaItems: [VaultItem] = []

    @Environment(\.managedObjectContext) var context
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // Item filtering is now handled by CategoryViewModel.
    
    private func getItemCount(for categoryType: CategoryType) -> Int {
        viewModel.itemCount(for: categoryType)
    }
    
    private func getItems(for categoryType: CategoryType) -> [VaultItem] {
        viewModel.items(for: categoryType)
    }
    
    var body: some View {
        if horizontalSizeClass == .regular {
            NavigationSplitView {
                List(CategoryType.allCases, id: \.self) { categoryType in
                    Button {
                        selectedCategory = categoryType
                        clearPreview()
                    } label: {
                        Label {
                            HStack {
                                Text(categoryType.rawValue)
                                Spacer()
                                Text("\(getItemCount(for: categoryType))")
                                    .foregroundStyle(.secondary)
                            }
                        } icon: {
                            Image(systemName: categoryType.systemImage)
                        }
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(selectedCategory == categoryType ? Color.accentColor : Color.primary)
                }
                .navigationTitle("Categories")
                .navigationSplitViewColumnWidth(min: 220, ideal: 260)
            } content: {
                if let selectedCategory {
                    CategoryFilesView(
                        categoryType: selectedCategory,
                        onPreviewFile: showPreview
                    )
                    .id(selectedCategory)
                    .navigationSplitViewColumnWidth(min: 360, ideal: 500)
                } else {
                    ContentUnavailableView(
                        "Select a Category",
                        systemImage: "square.grid.2x2",
                        description: Text("Choose a category from the sidebar.")
                    )
                }
            } detail: {
                VaultPreviewDetail(
                    item: previewItem,
                    mediaItems: previewMediaItems,
                    onClose: clearPreview
                )
            }
        } else {
            NavigationStack {
                categoryGrid
            }
        }
    }

    private var categoryGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 150), spacing: 16)
            ], spacing: 16) {
                ForEach(CategoryType.allCases, id: \.self) { categoryType in
                    NavigationLink(destination: CategoryFilesView(
                        categoryType: categoryType
                    )
                    .id(categoryType)) {
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
    }

    private func showPreview(_ item: VaultItem, mediaItems: [VaultItem]) {
        previewItem = item
        previewMediaItems = mediaItems
    }

    private func clearPreview() {
        previewItem = nil
        previewMediaItems = []
    }
    
    // loadVaultItems removed – logic now lives in CategoryViewModel.
}

// `CategoryCard` has been moved to Views/Categories/CategoryCard.swift

// `CategoryFilesView` and `CategoryFolderPickerView` have been moved to Views/Categories/CategoryFilesView.swift

#Preview {
    CategoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 