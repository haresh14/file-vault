import SwiftUI
import AVKit
import AVFoundation

struct UnifiedMediaViewerView: View {
    let mediaItems: [VaultItem]
    let initialIndex: Int
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    init(mediaItems: [VaultItem], initialIndex: Int) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !mediaItems.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(mediaItems.enumerated()), id: \.element.id) { index, item in
                        Group {
                            if item.isVideo {
                                AutoPlayVideoView(vaultItem: item, isActive: currentIndex == index)
                                    .tag(index)
                            } else {
                                ZoomablePhotoView(vaultItem: item)
                                    .tag(index)
                            }
                        }
                        .clipped()
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                .onChange(of: currentIndex) { oldValue, newValue in
                    print("DEBUG: TabView index changed from \(oldValue) to \(newValue)")
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            currentIndex = initialIndex
            print("DEBUG: UnifiedMediaViewer appeared with \(mediaItems.count) items, initial index: \(initialIndex)")
        }
        .gesture(
            // Swipe down to close
            DragGesture()
                .onEnded { value in
                    if value.translation.height > 100 && abs(value.translation.height) > abs(value.translation.width) {
                        dismiss()
                    }
                }
        )
    }
}

// Auto-playing video component
struct AutoPlayVideoView: View {
    let vaultItem: VaultItem
    let isActive: Bool
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                    .onAppear {
                        print("DEBUG: VideoPlayer appeared for \(vaultItem.fileName ?? "unknown")")
                        if isActive && !hasLoadedOnce {
                            player.play()
                            hasLoadedOnce = true
                        }
                    }
                    .onChange(of: isActive) { oldValue, newValue in
                        print("DEBUG: Video \(vaultItem.fileName ?? "unknown") isActive changed: \(oldValue) -> \(newValue)")
                        if newValue {
                            // Only play if we haven't played before or if the video ended
                            if !hasLoadedOnce || player.currentTime() >= player.currentItem?.duration ?? CMTime.zero {
                                player.seek(to: .zero)
                                player.play()
                                hasLoadedOnce = true
                            } else {
                                player.play()
                            }
                        } else {
                            player.pause()
                        }
                    }
            } else if isLoading {
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    
                    Text("Loading video...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            } else if let errorMessage = errorMessage {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error loading video")
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
        }
        .onAppear {
            print("DEBUG: AutoPlayVideoView appeared for \(vaultItem.fileName ?? "unknown")")
            if player == nil {
                loadVideo()
            }
        }
        .onDisappear {
            print("DEBUG: AutoPlayVideoView disappeared for \(vaultItem.fileName ?? "unknown")")
            player?.pause()
        }
    }
    
    private func loadVideo() {
        print("DEBUG: Loading video for \(vaultItem.fileName ?? "unknown")")
        Task {
            do {
                let fileData = try FileStorageManager.shared.loadFile(vaultItem: vaultItem)
                
                // Create temporary file for AVPlayer
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(getFileExtension(from: vaultItem.fileType))
                
                try fileData.write(to: tempURL)
                
                await MainActor.run {
                    let playerItem = AVPlayerItem(url: tempURL)
                    
                    // Configure player item according to Apple best practices
                    playerItem.preferredForwardBufferDuration = 2.0
                    
                    // Add metadata
                    let metadata = AVMutableMetadataItem()
                    metadata.identifier = .commonIdentifierTitle
                    metadata.value = (vaultItem.fileName ?? "Video") as NSString
                    playerItem.externalMetadata = [metadata]
                    
                    // Create player
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.volume = 1.0
                    
                    self.player = newPlayer
                    self.isLoading = false
                    
                    print("DEBUG: Video player created for \(vaultItem.fileName ?? "unknown"), isActive: \(isActive)")
                    
                    // Auto-play if active
                    if isActive {
                        newPlayer.play()
                        hasLoadedOnce = true
                    }
                    
                    // Clean up temp file after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    print("DEBUG: Error loading video: \(error)")
                }
            }
        }
    }
    
    private func getFileExtension(from fileType: String?) -> String {
        guard let fileType = fileType else { return "mp4" }
        
        switch fileType {
        case "video/mp4":
            return "mp4"
        case "video/quicktime":
            return "mov"
        case "video/x-m4v":
            return "m4v"
        case "video/avi":
            return "avi"
        default:
            return "mp4"
        }
    }
}

// Zoomable photo component
struct ZoomablePhotoView: View {
    let vaultItem: VaultItem
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var image: UIImage?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss
    
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
                        .gesture(
                            SimultaneousGesture(
                                // Pinch to zoom
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
                                
                                // Pan gesture
                                DragGesture()
                                    .onChanged { value in
                                        if scale > 1.0 {
                                            // Pan when zoomed
                                            let newOffset = CGSize(
                                                width: lastOffset.width + value.translation.width,
                                                height: lastOffset.height + value.translation.height
                                            )
                                            
                                            // Limit panning to bounds
                                            let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                            let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                            
                                            offset = CGSize(
                                                width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                                height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                            )
                                        }
                                    }
                                    .onEnded { _ in
                                        if scale > 1.0 {
                                            lastOffset = offset
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
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                }
                            }
                        }
                } else if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Loading image...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
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
        }
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let image = try await FileStorageManager.shared.loadImage(for: vaultItem)
                await MainActor.run {
                    self.image = image
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

#Preview {
    Text("Unified Media Viewer Preview")
} 