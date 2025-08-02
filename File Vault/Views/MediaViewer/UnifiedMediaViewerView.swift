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
    @Environment(\.dismiss) private var dismiss
    
    init(mediaItems: [VaultItem], initialIndex: Int) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        // We set the initial value in onAppear
        self._currentIndex = State(initialValue: initialIndex)
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
        }
        .statusBarHidden()
        .onAppear {
            // Set the initial page
            currentIndex = initialIndex
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