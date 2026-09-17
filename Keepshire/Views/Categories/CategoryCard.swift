import SwiftUI

/// A reusable card representing a vault category.
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

#Preview {
    CategoryCard(categoryType: .photos, itemCount: 42)
} 