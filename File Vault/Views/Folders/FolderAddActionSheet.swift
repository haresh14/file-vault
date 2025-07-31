import SwiftUI

// MARK: - Folder Add Action Sheet (extracted)

struct FolderAddActionSheet: View {
    let onAddPhotos: () -> Void
    let onAddFiles: () -> Void
    let onCreateFolder: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                VStack(spacing: 0) {
                    Button(action: onAddPhotos) {
                        HStack(spacing: 16) {
                            Image(systemName: "photo.badge.plus")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)

                            Text("Add from Photos")
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }

                    Divider()
                        .padding(.leading, 60)

                    Button(action: onAddFiles) {
                        HStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)

                            Text("Add from Files")
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }

                    Divider()
                        .padding(.leading, 60)

                    Button(action: onCreateFolder) {
                        HStack(spacing: 16) {
                            Image(systemName: "folder.badge.plus")
                                .font(.body)
                                .foregroundColor(.primary)
                                .frame(width: 20)

                            Text("Create Folder")
                                .font(.body)
                                .foregroundColor(.primary)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .background(Color.clear)
                        .contentShape(Rectangle())
                    }
                }
                .padding(.top, 4)
            }
            .navigationTitle("Add Content")
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
