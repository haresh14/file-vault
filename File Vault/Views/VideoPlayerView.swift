import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let vaultItems: [VaultItem]
    let initialIndex: Int
    @State private var currentIndex: Int
    @Environment(\.dismiss) private var dismiss
    
    init(vaultItem: VaultItem) {
        // For backward compatibility - single video
        self.vaultItems = [vaultItem]
        self.initialIndex = 0
        self._currentIndex = State(initialValue: 0)
    }
    
    init(vaultItems: [VaultItem], initialIndex: Int) {
        // For multiple videos with navigation
        self.vaultItems = vaultItems
        self.initialIndex = initialIndex
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !vaultItems.isEmpty {
                TabView(selection: $currentIndex) {
                    ForEach(Array(vaultItems.enumerated()), id: \.element.objectID) { index, item in
                        ZoomableVideoPlayerView(vaultItem: item)
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .ignoresSafeArea()
                
                // Fixed overlay controls that don't get affected by zoom
                VStack {
                    // Top controls with proper spacing
                    HStack {
                        // Close button
                        Button(action: {
                            dismiss()
                        }) {
                            Image(systemName: "xmark")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.leading, 20)
                        
                        Spacer()
                        
                        // Counter
                        Text("\(currentIndex + 1) of \(vaultItems.count)")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.black.opacity(0.6))
                            .clipShape(Capsule())
                        
                        Spacer()
                        
                        // Share button
                        Button(action: {
                            // TODO: Implement share functionality
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                        .padding(.trailing, 20)
                    }
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom info
                    VStack(spacing: 8) {
                        if currentIndex < vaultItems.count {
                            let currentItem = vaultItems[currentIndex]
                            
                            // Filename
                            Text(currentItem.fileName ?? "Unknown")
                                .font(.headline)
                                .foregroundColor(.white)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 20)
                            
                            // Date
                            Text(currentItem.dateAdded ?? Date(), style: .date)
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                    .padding(.bottom, 30)
                }
            }
        }
        .statusBarHidden()
        .onAppear {
            currentIndex = initialIndex
        }
    }
}

// Separate zoomable video player component
struct ZoomableVideoPlayerView: View {
    let vaultItem: VaultItem
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var dragOffset: CGSize = .zero
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let player = player {
                    // Pure video player without any controls overlay
                    PureVideoPlayerView(player: player)
                        .scaleEffect(scale)
                        .offset(x: offset.width + dragOffset.width, y: offset.height + dragOffset.height)
                        .opacity(1.0 - abs(dragOffset.height) / 500.0)
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
                                                dismiss()
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
                        .clipped()
                        
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
        }
        .onAppear {
            loadVideo()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
    }
    
    private func loadVideo() {
        guard let fileName = vaultItem.fileName else {
            errorMessage = "Invalid file name"
            isLoading = false
            return
        }
        
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
                    metadata.value = fileName as NSString
                    playerItem.externalMetadata = [metadata]
                    
                    // Create player
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.volume = 1.0
                    
                    self.player = newPlayer
                    self.isLoading = false
                    
                    // Clean up temp file after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
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

// Pure video player without any overlay controls
struct PureVideoPlayerView: UIViewControllerRepresentable {
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        
        // Configure the player controller
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        controller.allowsPictureInPicturePlayback = false
        controller.updatesNowPlayingInfoCenter = true
        
        // Enable visual analysis (Live Text) - new iOS 16 feature from WWDC 2022
        if #available(iOS 16.0, *) {
            controller.allowsVideoFrameAnalysis = true
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update player if needed
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
}

// Extension to check if array is safe to access
extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}

#Preview {
    Text("Video Player Preview")
} 