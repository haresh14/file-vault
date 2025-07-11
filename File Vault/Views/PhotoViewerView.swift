import SwiftUI

struct PhotoViewerView: View {
    let vaultItems: [VaultItem]
    let initialIndex: Int
    @State private var currentIndex: Int
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
    init(vaultItems: [VaultItem], initialIndex: Int) {
        self.vaultItems = vaultItems
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            TabView(selection: $currentIndex) {
                ForEach(vaultItems.indices, id: \.self) { index in
                    PhotoZoomView(vaultItem: vaultItems[index]) {
                        // Swipe down to close
                        dismiss()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            .animation(.easeInOut(duration: 0.3), value: currentIndex)
            .onAppear {
                currentIndex = initialIndex
            }
            
            VStack {
                HStack {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.leading)
                    
                    Spacer()
                    
                    Text("\(currentIndex + 1) of \(vaultItems.count)")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Capsule())
                    
                    Spacer()
                    
                    Button(action: {
                        // Share functionality can be added later
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.title2)
                            .foregroundColor(.white)
                            .padding()
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding(.trailing)
                }
                .padding(.top)
                
                Spacer()
                
                // Bottom info bar
                if let currentItem = vaultItems[safe: currentIndex] {
                    VStack(spacing: 4) {
                        Text(currentItem.fileName ?? "Unknown")
                            .font(.subheadline)
                            .foregroundColor(.white)
                        
                        if let dateAdded = currentItem.dateAdded {
                            Text(dateAdded, style: .date)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding()
                    .background(Color.black.opacity(0.5))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .padding(.bottom)
                }
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
    }
}

struct PhotoZoomView: View {
    let vaultItem: VaultItem
    let onSwipeDown: () -> Void
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var image: UIImage?
    @State private var dragOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(x: offset.width, y: offset.height + dragOffset.height)
                        .opacity(1.0 - abs(dragOffset.height) / 500.0)

                        .gesture(
                            SimultaneousGesture(
                                // Zoom gesture
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(newScale, 0.5) // Allow zoom out to 0.5x, no upper limit
                                    }
                                    .onEnded { _ in
                                        lastScale = scale
                                        if scale <= 1.0 {
                                            withAnimation(.spring()) {
                                                scale = 1.0
                                                offset = .zero
                                                lastScale = 1.0
                                                lastOffset = .zero
                                            }
                                        }
                                    },
                                // Pan/Swipe gesture
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            // Pan when zoomed
                                            let newOffset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            
                                            // Limit panning to image bounds
                                            let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                            let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                            
                                            offset = CGSize(
                                                width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                                height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                            )
                                                                } else {
                            // Swipe down to close when not zoomed
                            if abs(value.translation.height) > abs(value.translation.width) && abs(value.translation.height) > 20 {
                                dragOffset = CGSize(width: 0, height: value.translation.height)
                            }
                        }
                                    }
                                    .onEnded { value in
                                        if scale > 1.0 {
                                            lastOffset = offset
                                                                } else {
                            // Check if swipe down is significant enough to close
                            if dragOffset.height > 100 {
                                onSwipeDown()
                            } else {
                                // Animate back to original position
                                withAnimation(.spring()) {
                                    dragOffset = .zero
                                }
                            }
                        }
                                    }
                            )
                        )
                        .onTapGesture(count: 2) {
                            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                                if scale > 1.0 {
                                    scale = 1.0
                                    offset = .zero
                                    lastScale = 1.0
                                    lastOffset = .zero
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                } else {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onAppear {
                loadImage()
            }
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let loadedImage = try await FileStorageManager.shared.loadImage(for: vaultItem)
                await MainActor.run {
                    self.image = loadedImage
                }
            } catch {
                print("Failed to load image: \(error)")
            }
        }
    }
}

#Preview {
    Text("Photo Viewer Preview")
} 