//
//  ZoomablePhotoView.swift
//  File Vault
//
//  Zoomable photo component with pan and zoom support
//

import SwiftUI

struct ZoomablePhotoView: View {
    let vaultItem: VaultItem
    let isActive: Bool
    @Binding var scrollDisabled: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var image: UIImage?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    // Reset zoom when the photo is no longer active
    @State private var lastIsActive: Bool = true
    
    // Keep panning within bounds for current scale
    private func boundOffset(_ raw: CGSize, in container: CGSize) -> CGSize {
        // Determine the photo's un-scaled display size (aspect-fit) within the container
        var displayWidth: CGFloat = container.width
        var displayHeight: CGFloat = container.height
        if let img = image {
            let imgAspect = img.size.width / img.size.height
            let containerAspect = container.width / container.height
            if imgAspect > containerAspect { // wider than container
                displayWidth = container.width
                displayHeight = container.width / imgAspect
            } else { // taller than container
                displayHeight = container.height
                displayWidth = container.height * imgAspect
            }
        }
        // Calculate bounds based on scaled content size
        let scaledW = displayWidth * scale
        let scaledH = displayHeight * scale
        let maxOffsetX = max((scaledW - container.width) / 2, 0)
        let maxOffsetY = max((scaledH - container.height) / 2, 0)
        return CGSize(
            width: min(max(raw.width, -maxOffsetX), maxOffsetX),
            height: min(max(raw.height, -maxOffsetY), maxOffsetY)
        )
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .simultaneousGesture(
                            SimultaneousGesture(
                                // Pinch to zoom
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(newScale, 0.5) // Allow zoom out to 0.5x, no upper limit
                                        // Clamp offset to new bounds so content never disappears
                                        offset = boundOffset(offset, in: geometry.size)
                                        if isActive {
                                            scrollDisabled = scale > 1.0
                                        }
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        // Ensure offset in range on gesture end
                                        offset = boundOffset(offset, in: geometry.size)
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                                lastScale = 1.0
                                                lastOffset = .zero
                                            }
                                        }
                                        if isActive {
                                            scrollDisabled = scale > 1.0
                                        }
                                    },
                                
                                // Pan gesture
                                DragGesture()
                                    .onChanged { value in
                                        guard scale > 1.0 else { return }
                                        // Follow the finger 1:1
                                        let raw = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                        let bounded = boundOffset(raw, in: geometry.size)
                                        offset = bounded
                                    }
                                    .onEnded { value in
                                        guard scale > 1.0 else { return }
                                        // Determine momentum using predicted end translation
                                        let predictedRaw = CGSize(
                                            width: lastOffset.width + value.predictedEndTranslation.width,
                                            height: lastOffset.height + value.predictedEndTranslation.height
                                        )
                                        let shouldUseMomentum = hypot(value.predictedEndTranslation.width - value.translation.width,
                                                                      value.predictedEndTranslation.height - value.translation.height) > 40
                                        let target = shouldUseMomentum ? boundOffset(predictedRaw, in: geometry.size) : offset
                                        withAnimation(.easeOut(duration: 0.45)) {
                                            offset = target
                                        }
                                        lastOffset = offset
                                        if isActive {
                                            scrollDisabled = scale > 1.0
                                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            // Double tap to zoom
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                    if isActive { scrollDisabled = false }
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                    if isActive { scrollDisabled = true }
                                }
                            }
                        }
                } else if isLoading {
                    PhotoLoadingView(fileName: vaultItem.fileName)
                } else {
                    PhotoErrorView()
                }
            }
        }
        .onAppear {
            loadImage()
            lastIsActive = isActive
            if isActive { scrollDisabled = false }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if !newValue {
                // Reset zoom when switching away
                withAnimation(.spring()) {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
                scrollDisabled = false
            }
            lastIsActive = newValue
        }
    }
    
    // MARK: - Image Loading
    
    private func loadImage() {
        Task {
            do {
                let imageData = try await FileStorageManager.shared.loadImage(for: vaultItem)
                await MainActor.run {
                    self.image = UIImage(data: imageData)
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
                print("Error loading image: \(error)")
            }
        }
    }
}

// MARK: - Supporting Views

struct PhotoLoadingView: View {
    let fileName: String?
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading \(fileName ?? "image")...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct PhotoErrorView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.red)
            
            Text("Error loading image")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    let sampleItem: VaultItem = {
        let context = CoreDataManager.shared.context
        let item = VaultItem(context: context)
        item.fileName = "sample.jpg"
        item.fileType = "image/jpeg"
        item.fileSize = 2000000
        item.createdAt = Date()
        return item
    }()
    
    ZoomablePhotoView(
        vaultItem: sampleItem,
        isActive: true,
        scrollDisabled: .constant(false)
    )
    .background(Color.black)
}