//
//  CategoryView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

// `CategoryType` has been moved to Models/CategoryType.swift
struct CategoryView: View {
    /// Owns the data-loading logic so that this view remains declarative.
    @StateObject private var viewModel = CategoryViewModel()

    @Environment(\.managedObjectContext) var context
    
    // Item filtering is now handled by CategoryViewModel.
    
    private func getItemCount(for categoryType: CategoryType) -> Int {
        viewModel.itemCount(for: categoryType)
    }
    
    private func getItems(for categoryType: CategoryType) -> [VaultItem] {
        viewModel.items(for: categoryType)
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
                        )
                        // Ensure a unique identity per category to avoid SwiftUI reuse issues
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


        // Data refresh handled inside CategoryViewModel, so no explicit observers here.
        }
    }
    
    // loadVaultItems removed – logic now lives in CategoryViewModel.
}

// `CategoryCard` has been moved to Views/Categories/CategoryCard.swift

// `CategoryFilesView` and `CategoryFolderPickerView` have been moved to Views/Categories/CategoryFilesView.swift

#Preview {
    CategoryView()
        .environment(\.managedObjectContext, CoreDataManager.shared.context)
} 