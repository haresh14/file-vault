import SwiftUI

// MARK: - Folder Sort Popup View (extracted)

struct FolderSortPopupView: View {
    let currentSortOption: FolderSortOption
    let sortAscending: Bool
    let onSortSelected: (FolderSortOption) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort options
                VStack(spacing: 0) {
                    ForEach(FolderSortOption.allCases, id: \.self) { option in
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)

                            Text(option.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if option == currentSortOption {
                                Image(systemName: sortAscending ? "arrow.up" : "arrow.down")
                                    .font(.body)
                                    .foregroundColor(.blue)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            onSortSelected(option)
                        }

                        if option != FolderSortOption.allCases.last {
                            Divider()
                                .padding(.leading, 60)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .navigationTitle("Sort by")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
