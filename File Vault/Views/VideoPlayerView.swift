import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: View {
    let vaultItem: VaultItem
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var debugInfo: String = ""
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let player = player {
                // Use AVPlayerViewController for better video rendering
                AVPlayerViewControllerRepresentable(player: player, onDismiss: {
                    dismiss()
                })
                .ignoresSafeArea()
            } else if isLoading {
                VStack(spacing: 15) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.5)
                    
                    Text("Loading video...")
                        .foregroundColor(.white)
                        .font(.headline)
                    
                    // Debug info - smaller and at bottom
                    VStack {
                        Spacer()
                        ScrollView {
                            Text(debugInfo)
                                .foregroundColor(.gray)
                                .font(.caption2)
                                .multilineTextAlignment(.leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 100)
                        .background(Color.black.opacity(0.3))
                        .cornerRadius(8)
                    }
                }
                .padding()
            } else if let errorMessage = errorMessage {
                VStack(spacing: 15) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.red)
                    
                    Text("Error Loading Video")
                        .font(.title2)
                        .foregroundColor(.white)
                    
                    Text(errorMessage)
                        .font(.body)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    
                    Button("Retry") {
                        setupPlayer()
                    }
                    .foregroundColor(.blue)
                    .padding()
                    
                    // Debug info
                    ScrollView {
                        Text(debugInfo)
                            .foregroundColor(.gray)
                            .font(.caption2)
                            .multilineTextAlignment(.leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 100)
                    .background(Color.black.opacity(0.3))
                    .cornerRadius(8)
                }
                .padding()
            }
        }
        .navigationBarHidden(true)
        .statusBarHidden()
        .onAppear {
            addDebugInfo("VideoPlayerView appeared")
            setupPlayer()
        }
        .onDisappear {
            addDebugInfo("VideoPlayerView disappeared")
            cleanupPlayer()
        }
    }
    
    private func addDebugInfo(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        debugInfo += "\n[\(timestamp)] \(message)"
        print("DEBUG VideoPlayer: \(message)")
    }
    
    private func setupPlayer() {
        addDebugInfo("=== Starting Video Player Setup ===")
        addDebugInfo("VaultItem ID: \(vaultItem.id?.uuidString ?? "nil")")
        addDebugInfo("VaultItem fileName: \(vaultItem.fileName ?? "nil")")
        addDebugInfo("VaultItem fileType: \(vaultItem.fileType ?? "nil")")
        addDebugInfo("VaultItem fileSize: \(vaultItem.fileSize)")
        addDebugInfo("VaultItem isVideo: \(vaultItem.isVideo)")
        
        // Reset states
        isLoading = true
        errorMessage = nil
        player = nil
        
        Task {
            do {
                addDebugInfo("Loading encrypted video file...")
                let videoData = try FileStorageManager.shared.loadFile(vaultItem: vaultItem)
                addDebugInfo("Video data loaded successfully: \(videoData.count) bytes")
                
                // Determine file extension based on MIME type
                let fileExtension: String
                if let fileType = vaultItem.fileType?.lowercased() {
                    switch fileType {
                    case "video/mp4":
                        fileExtension = "mp4"
                    case "video/quicktime":
                        fileExtension = "mov"
                    case "video/x-m4v":
                        fileExtension = "m4v"
                    case "video/avi":
                        fileExtension = "avi"
                    default:
                        fileExtension = "mp4"
                    }
                } else {
                    fileExtension = "mp4"
                }
                
                addDebugInfo("Using file extension: .\(fileExtension)")
                
                // Create temporary file with proper naming
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("vault_video_\(UUID().uuidString)")
                    .appendingPathExtension(fileExtension)
                
                addDebugInfo("Temp file path: \(tempURL.path)")
                
                // Write video data to temporary file
                try videoData.write(to: tempURL)
                addDebugInfo("Video data written to temp file")
                
                // Verify file exists and get size
                let fileExists = FileManager.default.fileExists(atPath: tempURL.path)
                addDebugInfo("Temp file exists: \(fileExists)")
                
                if fileExists {
                    let attributes = try FileManager.default.attributesOfItem(atPath: tempURL.path)
                    let fileSize = attributes[.size] as? Int64 ?? 0
                    addDebugInfo("Temp file size: \(fileSize) bytes")
                    
                    if fileSize == 0 {
                        throw NSError(domain: "VideoPlayerError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Temp file is empty"])
                    }
                } else {
                    throw NSError(domain: "VideoPlayerError", code: 2, userInfo: [NSLocalizedDescriptionKey: "Temp file was not created"])
                }
                
                await MainActor.run {
                    addDebugInfo("Creating AVPlayer with Apple best practices...")
                    
                    // Create AVURLAsset with proper configuration
                    let asset = AVURLAsset(url: tempURL)
                    
                    // Create AVPlayerItem with proper configuration
                    let playerItem = AVPlayerItem(asset: asset)
                    
                    // Configure player item according to Apple best practices
                    playerItem.preferredForwardBufferDuration = 2.0
                    
                    // Set up metadata for better player experience (from WWDC 2022)
                    if let fileName = vaultItem.fileName {
                        let titleItem = AVMutableMetadataItem()
                        titleItem.identifier = .commonIdentifierTitle
                        titleItem.value = fileName as NSString
                        titleItem.extendedLanguageTag = "und"
                        playerItem.externalMetadata = [titleItem]
                    }
                    
                    // Create AVPlayer with proper configuration
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    
                    // Configure player according to Apple best practices
                    newPlayer.automaticallyWaitsToMinimizeStalling = false
                    newPlayer.actionAtItemEnd = .pause
                    
                    // Set volume to ensure audio works properly
                    newPlayer.volume = 1.0
                    
                    self.player = newPlayer
                    self.isLoading = false
                    
                    addDebugInfo("AVPlayer created successfully with Apple best practices")
                    addDebugInfo("Player setup complete - should show video now")
                    
                    // Clean up temp file after a delay to ensure player has loaded it
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        try? FileManager.default.removeItem(at: tempURL)
                        addDebugInfo("Temp file cleaned up")
                    }
                }
                
            } catch {
                addDebugInfo("ERROR: \(error.localizedDescription)")
                await MainActor.run {
                    self.isLoading = false
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }
    
    private func cleanupPlayer() {
        addDebugInfo("Cleaning up player...")
        player?.pause()
        player = nil
    }
}

// AVPlayerViewController wrapper optimized according to Apple best practices
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        
        // Configure according to Apple best practices from WWDC 2022
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        
        // Disable features that might cause issues
        controller.allowsPictureInPicturePlayback = false
        
        // Configure for better video quality and performance
        controller.updatesNowPlayingInfoCenter = true
        
        // Enable visual analysis (Live Text) - new iOS 16 feature from WWDC 2022
        if #available(iOS 16.0, *) {
            controller.allowsVideoFrameAnalysis = true
        }
        
        // Set up the coordinator to handle dismissal
        context.coordinator.onDismiss = onDismiss
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        // Update player if needed
        if uiViewController.player != player {
            uiViewController.player = player
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject {
        var onDismiss: (() -> Void)?
        
        @objc func playerViewControllerDidDismiss() {
            onDismiss?()
        }
    }
}

#Preview {
    Text("Video Player Preview")
} 