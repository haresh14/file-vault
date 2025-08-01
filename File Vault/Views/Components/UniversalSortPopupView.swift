//
//  UniversalSortPopupView.swift
//  File Vault
//
//  Universal sorting popup component with polished UX
//  Based on the superior FolderSortPopupView design
//

import SwiftUI

/// Universal sort popup that works with any sortable enum
/// Features proper navigation interface and consistent design
struct UniversalSortPopupView<SortType: RawRepresentable & CaseIterable & Hashable>: View 
where SortType.RawValue == String, SortType: SortOptionProtocol {
    let currentSortOption: SortType
    let sortAscending: Bool
    let onSortSelected: (SortType) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Sort options
                VStack(spacing: 0) {
                    ForEach(Array(SortType.allCases), id: \.self) { option in
                        HStack(spacing: 16) {
                            Image(systemName: option.systemImage)
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)

                            Text(option.rawValue)
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()

                            if option.hashValue == currentSortOption.hashValue {
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

                        if option.hashValue != Array(SortType.allCases).last?.hashValue {
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

/// Protocol that sort option enums must conform to
protocol SortOptionProtocol {
    var systemImage: String { get }
}

// MARK: - Conformances for existing enums

extension SortOption: SortOptionProtocol {}
extension FolderSortOption: SortOptionProtocol {}

// MARK: - Convenience type aliases

typealias GallerySortPopupView = UniversalSortPopupView<SortOption>
typealias CategorySortPopupView = UniversalSortPopupView<SortOption>
typealias FolderSortPopupView = UniversalSortPopupView<FolderSortOption>