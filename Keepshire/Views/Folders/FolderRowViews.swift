import SwiftUI

// MARK: - Folder Row Views

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
                    .foregroundColor(isSelected ? KeepshireTheme.accent : .gray)
                    .font(.title2)
            }

            Image(systemName: "folder.fill")
                .foregroundColor(KeepshireTheme.accent)
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
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("folder.\(folder.id?.uuidString ?? folder.displayName)")
        .accessibilityLabel("\(folder.displayName), \(folder.totalItemCount) items")
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
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
            
            // Rename option
            Button(action: onRename) {
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
            
            if let onDelete = onDelete {
                Divider()
                
                // Delete option
                Button(role: .destructive, action: onDelete) {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}
