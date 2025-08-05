//
//  FileInfoPanel.swift
//  File Vault
//
//  Common reusable file information panel component
//

import SwiftUI

// MARK: - File Info Panel View

struct FileInfoPanel: View {
    let vaultItem: VaultItem
    let isVisible: Bool
    let panelOffset: CGFloat
    let onFavoriteToggle: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Handle bar
            HStack {
                Spacer()
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.gray.opacity(0.6))
                    .frame(width: 40, height: 6)
                Spacer()
            }
            .padding(.top, 12)
            
            // File information
            VStack(alignment: .leading, spacing: 12) {
                // File name
                HStack {
                    Image(systemName: FileInfoHelpers.getFileIcon(for: vaultItem))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text(vaultItem.fileName ?? "Unknown")
                        .font(.headline)
                        .foregroundColor(.white)
                        .lineLimit(2)
                }
                
                // File type
                HStack {
                    Image(systemName: "doc.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text(vaultItem.fileType ?? "Unknown")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // File size
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text(FileInfoHelpers.formatFileSize(vaultItem.fileSize))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Folder location
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text(FileInfoHelpers.getFolderPath(for: vaultItem))
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                        .lineLimit(2)
                }
                
                // Date created
                HStack {
                    Image(systemName: "calendar")
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 20)
                    Text("Created: \(FileInfoHelpers.formatDate(vaultItem.createdAt))")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                // Date modified (if different from created)
                if let updatedAt = vaultItem.updatedAt,
                   let createdAt = vaultItem.createdAt,
                   !Calendar.current.isDate(updatedAt, inSameDayAs: createdAt) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 20)
                        Text("Modified: \(FileInfoHelpers.formatDate(updatedAt))")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                    }
                }
                
                // Favorite status (interactive)
                Button(action: onFavoriteToggle) {
                    HStack {
                        Image(systemName: vaultItem.isFavorite ? "heart.fill" : "heart")
                            .foregroundColor(vaultItem.isFavorite ? .red : .white.opacity(0.7))
                            .frame(width: 20)
                        Text(vaultItem.isFavorite ? "Favorite" : "Not favorited")
                            .font(.body)
                            .foregroundColor(.white.opacity(0.8))
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .frame(height: 350)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.9))
                .ignoresSafeArea(edges: .bottom)
        )
        .offset(y: panelOffset)
        .transition(.move(edge: .bottom))
        .animation(.interactiveSpring(), value: panelOffset)
    }
}

// MARK: - File Info Helpers

struct FileInfoHelpers {
    
    // Helper function to format file size
    static func formatFileSize(_ size: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useBytes, .useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: size)
    }
    
    // Helper function to get folder path
    static func getFolderPath(for item: VaultItem) -> String {
        guard let folder = item.folder else { return "Root" }
        
        var path: [String] = []
        var currentFolder: Folder? = folder
        
        while let folder = currentFolder {
            if let name = folder.name {
                path.insert(name, at: 0)
            }
            currentFolder = folder.parent
        }
        
        return path.isEmpty ? "Root" : path.joined(separator: " > ")
    }
    
    // Helper function to format date
    static func formatDate(_ date: Date?) -> String {
        guard let date = date else { return "Unknown" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    // Helper function to get file icon
    static func getFileIcon(for item: VaultItem) -> String {
        if item.isVideo {
            return "video.fill"
        } else if item.isImage {
            return "photo.fill"
        } else if item.isDocument {
            return "doc.fill"
        } else if item.isAudio {
            return "music.note"
        } else {
            return "questionmark.circle"
        }
    }
}

// MARK: - File Info Gesture Handler

class FileInfoGestureHandler: ObservableObject {
    @Published var showInfoPanel: Bool = false
    @Published var infoPanelOffset: CGFloat = 0
    @Published var isVerticalGesture: Bool = false
    
    func handleGestureChanged(value: DragGesture.Value, isScrollDisabled: Bool) {
        guard !isScrollDisabled else { return }
        
        // Determine gesture direction early to prevent conflicts
        let horizontalMovement = abs(value.translation.width)
        let verticalMovement = abs(value.translation.height)
        
        // If movement is more than 20 points, determine direction
        if horizontalMovement > 20 || verticalMovement > 20 {
            if !isVerticalGesture && verticalMovement > horizontalMovement * 1.5 {
                // This is clearly a vertical gesture
                isVerticalGesture = true
            } else if !isVerticalGesture && horizontalMovement > verticalMovement * 1.5 {
                // This is clearly a horizontal gesture - don't interfere
                return
            }
        }
        
        // Only handle if this is determined to be a vertical gesture
        if isVerticalGesture && showInfoPanel {
            // When info panel is shown, allow dragging it down
            let translation = max(0, value.translation.height)
            infoPanelOffset = translation
        }
    }
    
    func handleGestureEnded(value: DragGesture.Value, isScrollDisabled: Bool, onDismiss: (() -> Void)? = nil) {
        guard !isScrollDisabled else { return }
        
        let verticalMovement = abs(value.translation.height)
        let horizontalMovement = abs(value.translation.width)
        let isVerticalSwipe = verticalMovement > horizontalMovement && verticalMovement > 50
        
        if isVerticalGesture || isVerticalSwipe {
            if showInfoPanel {
                // Info panel is shown
                if value.translation.height > 100 {
                    // Swipe down to hide info panel
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showInfoPanel = false
                        infoPanelOffset = 0
                    }
                } else {
                    // Snap back to position
                    withAnimation(.easeInOut(duration: 0.2)) {
                        infoPanelOffset = 0
                    }
                }
            } else {
                // Info panel is hidden
                if value.translation.height < -100 {
                    // Swipe up to show info panel
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showInfoPanel = true
                        infoPanelOffset = 0
                    }
                } else if value.translation.height > 100, let onDismiss = onDismiss {
                    // Swipe down to dismiss the viewer (only for media files)
                    onDismiss()
                }
            }
        }
        
        // Reset gesture tracking
        isVerticalGesture = false
    }
    
    var shouldDisableHorizontalScroll: Bool {
        return isVerticalGesture
    }
}

// MARK: - File Info Layout Container

struct FileInfoLayoutContainer<Content: View>: View {
    let content: Content
    let vaultItem: VaultItem
    let gestureHandler: FileInfoGestureHandler
    let geometry: GeometryProxy
    let onFavoriteToggle: () -> Void
    let onDismiss: (() -> Void)?
    let isScrollDisabled: Bool
    
    init(
        vaultItem: VaultItem,
        gestureHandler: FileInfoGestureHandler,
        geometry: GeometryProxy,
        onFavoriteToggle: @escaping () -> Void,
        onDismiss: (() -> Void)? = nil,
        isScrollDisabled: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.vaultItem = vaultItem
        self.gestureHandler = gestureHandler
        self.geometry = geometry
        self.onFavoriteToggle = onFavoriteToggle
        self.onDismiss = onDismiss
        self.isScrollDisabled = isScrollDisabled
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Main content area - gets pushed up when info panel is shown
            content
                .frame(height: gestureHandler.showInfoPanel ? geometry.size.height - 350 : geometry.size.height)
                .clipped()
                .animation(.easeInOut(duration: 0.3), value: gestureHandler.showInfoPanel)
            
            // Info panel content - slides up from bottom
            if gestureHandler.showInfoPanel {
                FileInfoPanel(
                    vaultItem: vaultItem,
                    isVisible: gestureHandler.showInfoPanel,
                    panelOffset: gestureHandler.infoPanelOffset,
                    onFavoriteToggle: onFavoriteToggle
                )
            }
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    gestureHandler.handleGestureChanged(value: value, isScrollDisabled: isScrollDisabled)
                }
                .onEnded { value in
                    gestureHandler.handleGestureEnded(value: value, isScrollDisabled: isScrollDisabled, onDismiss: onDismiss)
                }
        )
    }
}

#Preview {
    // Create sample vault item for preview
    let context = CoreDataManager.shared.context
    let sampleItem = VaultItem(context: context)
    sampleItem.fileName = "sample.pdf"
    sampleItem.fileType = "application/pdf"
    sampleItem.fileSize = 1024000
    sampleItem.createdAt = Date()
    
    return GeometryReader { geometry in
        ZStack {
            Color.black.ignoresSafeArea()
            
            FileInfoLayoutContainer(
                vaultItem: sampleItem,
                gestureHandler: FileInfoGestureHandler(),
                geometry: geometry,
                onFavoriteToggle: {},
                onDismiss: {}
            ) {
                Text("Sample Content")
                    .foregroundColor(.white)
                    .font(.title)
            }
        }
    }
}