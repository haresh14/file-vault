import SwiftUI

// MARK: - File Row Views

struct FileRowView: View {
    let file: VaultItem
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack {
            // Thumbnail
            Group {
                if let thumbnail = thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 40, height: 40)
                        .clipped()
                        .cornerRadius(6)
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 40, height: 40)
                        .cornerRadius(6)
                        .overlay(
                            Image(systemName: file.isVideo ? "video.fill" : "photo.fill")
                                .foregroundColor(.gray)
                                .font(.caption)
                        )
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(file.fileName ?? "Unknown")
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    Text(file.fileType?.uppercased() ?? "FILE")
                        .font(.caption2)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(file.isVideo ? Color.red : Color.blue)
                        .cornerRadius(4)

                    Text(formatFileSize(file.fileSize))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if file.isVideo {
                Image(systemName: "play.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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

struct SelectableFileRowView: View {
    let file: VaultItem
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void

    @State private var thumbnail: UIImage?

    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
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

            if file.isVideo {
                Image(systemName: "play.circle")
                    .foregroundColor(.secondary)
                    .font(.title3)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
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
