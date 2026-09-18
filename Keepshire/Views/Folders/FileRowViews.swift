import SwiftUI

// MARK: - File Row Views

struct SelectableFileRowView: View {
    let file: VaultItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onSelect: (() -> Void)?
    let onFavoriteToggle: (() -> Void)?
    let onRename: (() -> Void)?
    let onMove: (() -> Void)?
    let onShare: (() -> Void)?
    let onDelete: (() -> Void)?

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? KeepshireTheme.accent : .gray)
                    .font(.title2)
            }

            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Image(systemName: file.isImage ? "photo" : file.isVideo ? "video" : "doc")
                        .foregroundColor(file.isImage ? .blue : file.isVideo ? .purple : .orange)
                        .font(.title2)
                        .frame(width: 40, height: 40)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(formatFileSize(file.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if let createdAt = file.createdAt {
                        Text("• \(createdAt, style: .date)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()
            
            HStack(spacing: 8) {
                // Favorite indicator
                if file.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                // Video play icon
                if file.isVideo {
                    Image(systemName: "play.circle")
                        .foregroundColor(.secondary)
                        .font(.title3)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("file.\(file.id?.uuidString ?? file.fileName ?? "unknown")")
        .accessibilityLabel(file.fileName ?? "Unnamed file")
        .accessibilityValue(isSelected ? "Selected" : file.fileType ?? "File")
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            // Select option
            Button(action: {
                onSelect?()
            }) {
                Label("Select", systemImage: "checkmark.circle")
                    .labelStyle(.titleAndIcon)
            }
            
            Divider()
            
            // Favorite/Unfavorite option
            Button(action: {
                onFavoriteToggle?()
            }) {
                Label(
                    file.isFavorite ? "Unfavorite" : "Favorite",
                    systemImage: file.isFavorite ? "heart.slash" : "heart"
                )
                .labelStyle(.titleAndIcon)
            }
            
            // Rename option
            Button(action: {
                onRename?()
            }) {
                Label("Rename", systemImage: "pencil")
                    .labelStyle(.titleAndIcon)
            }
            
            // Move option
            Button(action: {
                onMove?()
            }) {
                Label("Move", systemImage: "folder")
                    .labelStyle(.titleAndIcon)
            }
            
            Divider()
            
            // Share option
            Button(action: {
                onShare?()
            }) {
                Label("Share", systemImage: "square.and.arrow.up")
                    .labelStyle(.titleAndIcon)
            }
            
            Divider()
            
            // Delete option (in red)
            Button(role: .destructive, action: {
                onDelete?()
            }) {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.titleAndIcon)
            }
        }
        .onAppear {
            loadThumbnail()
        }
    }

    private func loadThumbnail() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loadedThumbnail = FileStorageManager.shared.loadThumbnail(for: file)
            DispatchQueue.main.async {
                if let data = loadedThumbnail {
                    self.thumbnail = UIImage(data: data)
                } else {
                    self.thumbnail = nil
                }
            }
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
