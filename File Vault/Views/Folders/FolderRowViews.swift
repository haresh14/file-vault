import SwiftUI

// MARK: - Folder Row Views

struct FolderRowView: View {
    let folder: Folder
    let onTap: () -> Void
    let onRename: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.headline)

                Text("\(folder.totalItemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
                .font(.caption)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .contextMenu {
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
        }
    }
}

struct SelectableFolderRowView: View {
    let folder: Folder
    let isSelected: Bool
    let isSelectionMode: Bool
    let onTap: () -> Void
    let onRename: () -> Void
    let onSelect: (() -> Void)?
    let onMove: (() -> Void)?
    let onDelete: (() -> Void)?

    var body: some View {
        HStack {
            if isSelectionMode {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .gray)
                    .font(.title2)
            }

            Image(systemName: "folder.fill")
                .foregroundColor(.blue)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(folder.displayName)
                    .font(.headline)

                Text("\(folder.totalItemCount) items")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if !isSelectionMode {
                Image(systemName: "chevron.right")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
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
            }
            
            Divider()
            
            // Rename option
            Button(action: onRename) {
                Label("Rename", systemImage: "pencil")
            }
            
            // Move option
            Button(action: {
                onMove?()
            }) {
                Label("Move", systemImage: "folder")
            }
            
            if let onDelete = onDelete {
                Divider()
                
                // Delete option
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
    }
}
