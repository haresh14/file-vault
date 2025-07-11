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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                setupPlayer()
            }
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
                
                // Determine file extension
                let fileExtension: String
                if let fileType = vaultItem.fileType?.lowercased() {
                    switch fileType {
                    case "video/mp4":
                        fileExtension = "mp4"
                    case "video/quicktime":
                        fileExtension = "mov"
                    case "video/x-m4v":
                        fileExtension = "m4v"
                    default:
                        fileExtension = "mp4"
                    }
                } else {
                    fileExtension = "mp4"
                }
                
                addDebugInfo("Using file extension: .\(fileExtension)")
                
                // Create temporary file
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("video_\(UUID().uuidString)")
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
                    addDebugInfo("Creating AVPlayer...")
                    
                    // Create AVPlayer with proper configuration
                    let asset = AVURLAsset(url: tempURL)
                    let playerItem = AVPlayerItem(asset: asset)
                    
                    // Configure player item for better video quality
                    playerItem.preferredForwardBufferDuration = 1.0
                    
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    
                    // Configure player for better performance and quality
                    newPlayer.automaticallyWaitsToMinimizeStalling = false
                    newPlayer.actionAtItemEnd = .pause
                    
                    self.player = newPlayer
                    self.isLoading = false
                    
                    addDebugInfo("AVPlayer created successfully")
                    addDebugInfo("Player setup complete - should show video now")
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

// AVPlayerViewController wrapper for better video rendering
struct AVPlayerViewControllerRepresentable: UIViewControllerRepresentable {
    let player: AVPlayer
    let onDismiss: () -> Void
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let controller = AVPlayerViewController()
        controller.player = player
        controller.showsPlaybackControls = true
        controller.videoGravity = .resizeAspect
        
        // Configure for better video quality
        controller.allowsPictureInPicturePlayback = false
        
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