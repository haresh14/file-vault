//
//  CategoryView.swift
//  File Vault
//
//  Created on 12/07/25.
//

import SwiftUI

struct CategoryView: View {
    let categories = [
        Category(name: "Photos", systemImage: "photo", color: .blue),
        Category(name: "Videos", systemImage: "video", color: .purple),
        Category(name: "Documents", systemImage: "doc", color: .orange),
        Category(name: "All Files", systemImage: "folder", color: .gray)
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150), spacing: 16)
                ], spacing: 16) {
                    ForEach(categories) { category in
                        CategoryCard(category: category) {
                            // TODO: Navigate to category files
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Categories")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct Category: Identifiable {
    let id = UUID()
    let name: String
    let systemImage: String
    let color: Color
}

struct CategoryCard: View {
    let category: Category
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                Image(systemName: category.systemImage)
                    .font(.system(size: 40))
                    .foregroundColor(category.color)
                
                Text(category.name)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("0 items") // TODO: Show actual count
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    CategoryView()
} 