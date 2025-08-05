//
//  UnifiedMediaViewerView.swift
//  File Vault
//
//  Unified media viewer for images and videos with navigation support
//

import SwiftUI
import AVKit
import AVFoundation

struct UnifiedMediaViewerView: View {
    let mediaItems: [VaultItem]
    let initialIndex: Int
    
    // The currentIndex needs to be optional for .scrollPosition
    @State private var currentIndex: Int?
    // Whether horizontal scrolling should be disabled (when zoomed)
    @State private var isScrollDisabled: Bool = false
    // Track favorite status for UI updates
    @State private var favoriteStatus: [UUID: Bool] = [:]
    @Environment(\.dismiss) private var dismiss
    
    init(mediaItems: [VaultItem], initialIndex: Int) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        // We set the initial value in onAppear
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    // Computed property to get the current media item
    private var currentMediaItem: VaultItem? {
        guard let currentIndex = currentIndex,
              currentIndex >= 0 && currentIndex < mediaItems.count else {
            return nil
        }
        return mediaItems[currentIndex]
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !mediaItems.isEmpty {
                // 1. Use a horizontal ScrollView
                ScrollView(.horizontal, showsIndicators: false) {
                    // 2. Use a LazyHStack for performance
                    LazyHStack(spacing: 0) {
                        ForEach(mediaItems.indices, id: \.self) { index in
                            let item = mediaItems[index]
                            let isActive = currentIndex == index
                            
                            Group {
                                if item.isVideo {
                                    AutoPlayVideoView(
                                        vaultItem: item,
                                        isActive: isActive,
                                        scrollDisabled: $isScrollDisabled
                                    )
                                } else {
                                    ZoomablePhotoView(
                                        vaultItem: item,
                                        isActive: isActive,
                                        scrollDisabled: $isScrollDisabled
                                    )
                                }
                            }
                            // 3. Make each item take the full container width
                            .containerRelativeFrame(.horizontal)
                            .id(index) // Set an ID for scrollPosition to track
                            // Allow horizontal scroll gesture to co-exist with item gestures
                        }
                    }
                    // 4. This is needed for the scroll target behavior to work correctly
                    .scrollTargetLayout()
                }
                // 5. This modifier enables the paging behavior
                .scrollTargetBehavior(.paging)
                // 6. This binds the scroll position to your state variable
                .scrollPosition(id: $currentIndex)
                // Disable scroll when an item is zoomed in
                .scrollDisabled(isScrollDisabled)
                .ignoresSafeArea()
            }
            
            // Favorite and Share buttons overlay (hidden during zoom)
            if !isScrollDisabled && !mediaItems.isEmpty {
                VStack {
                    HStack {
                        Spacer()
                        HStack(spacing: 20) {
                            // Favorite button
                            Button(action: {
                                if let currentItem = currentMediaItem, let itemId = currentItem.id {
                                    FileStorageManager.shared.toggleFavorite(for: currentItem)
                                    favoriteStatus[itemId] = !(favoriteStatus[itemId] ?? currentItem.isFavorite)
                                }
                            }) {
                                let isFavorite = currentMediaItem?.id.flatMap { favoriteStatus[$0] } ?? currentMediaItem?.isFavorite ?? false
                                Image(systemName: isFavorite ? "heart.fill" : "heart")
                                    .foregroundColor(isFavorite ? .red : .white)
                                    .font(.title2)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                            .frame(width: 44, height: 44)
                                    )
                            }
                            
                            // Share button
                            Button(action: {
                                if let currentItem = currentMediaItem {
                                    ShareManager.shared.shareVaultItem(currentItem)
                                }
                            }) {
                                Image(systemName: "square.and.arrow.up")
                                    .foregroundColor(.white)
                                    .font(.title2)
                                    .background(
                                        Circle()
                                            .fill(Color.black.opacity(0.5))
                                            .frame(width: 44, height: 44)
                                    )
                            }
                        }
                        .padding(.trailing, 20)
                    }
                    Spacer()
                }
                .padding(.top, 50) // Account for safe area
            }
        }
        .statusBarHidden()
        .onAppear {
            // Set the initial page
            currentIndex = initialIndex
            // Initialize favorite status for all items
            for item in mediaItems {
                if let itemId = item.id {
                    favoriteStatus[itemId] = item.isFavorite
                }
            }
        }
        .gesture(
            // Swipe-down-to-close should only work when gestures are enabled (not zoomed)
            DragGesture()
                .onEnded { value in
                    guard !isScrollDisabled else { return } // Disable when zoomed
                    // Only trigger dismiss on vertical swipes
                    if value.translation.height > 100 && abs(value.translation.height) > abs(value.translation.width) {
                        dismiss()
                    }
                }
        )
    }
}

#Preview {
    // Create sample vault items for preview
    let context = CoreDataManager.shared.context
    let sampleItems = (0..<3).map { index in
        let item = VaultItem(context: context)
        item.fileName = "sample\(index).jpg"
        item.fileType = "image/jpeg"
        item.fileSize = 1024000
        item.createdAt = Date()
        return item
    }
    
    UnifiedMediaViewerView(mediaItems: sampleItems, initialIndex: 0)
}