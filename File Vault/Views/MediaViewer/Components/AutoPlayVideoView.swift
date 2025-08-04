//
//  AutoPlayVideoView.swift
//  File Vault
//
//  Auto-playing video component with zoom and pan support
//

import SwiftUI
import AVKit
import AVFoundation

struct AutoPlayVideoView: View {
    let vaultItem: VaultItem
    let isActive: Bool
    @Binding var scrollDisabled: Bool
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false
    // Original video pixel size (corrected for orientation)
    @State private var videoSize: CGSize?
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showControls = false
    @State private var isPlaying = false
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var playbackRate: Float = 1.0
    @State private var isFormatUnsupported = false

    // Keep panning within the visible bounds given current scale and video aspect
    private func boundOffset(_ raw: CGSize, in container: CGSize) -> CGSize {
        // Determine displayed video size (aspect-fit)
        var displayWidth: CGFloat = container.width
        var displayHeight: CGFloat = container.height
        if let vSize = videoSize {
            let aspect = vSize.width / vSize.height
            let containerAspect = container.width / container.height
            if aspect > containerAspect {
                displayWidth = container.width
                displayHeight = container.width / aspect
            } else {
                displayHeight = container.height
                displayWidth = container.height * aspect
            }
        }
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
                
                if let player = player {
                    ZStack {
                        CustomVideoPlayerView(player: player)
                            .scaleEffect(scale)
                            .offset(offset)
                            .simultaneousGesture(
                                SimultaneousGesture(
                                    MagnificationGesture()
                                        .onChanged { value in
                                            let newScale = lastScale * value
                                            scale = max(newScale, 0.5)
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
                                        },
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
                        
                        PlayerControlsView(
                            player: player,
                            isPlaying: $isPlaying,
                            showControls: $showControls,
                            playbackRate: $playbackRate
                        )
                    }
                    .onTapGesture {
                        withAnimation {
                            showControls.toggle()
                        }
                    }
                    .ignoresSafeArea()
                    .onAppear {
                        if isActive && !hasLoadedOnce {
                            player.rate = playbackRate
                            isPlaying = true
                            hasLoadedOnce = true
                        }
                    }
                    .onChange(of: isActive) { oldValue, newValue in
                        if newValue {
                            // Only play if we haven't played before or if the video ended
                            if !hasLoadedOnce || player.currentTime() >= player.currentItem?.duration ?? CMTime.zero {
                                player.seek(to: .zero)
                                player.rate = playbackRate
                                hasLoadedOnce = true
                            } else {
                                player.rate = playbackRate
                            }
                            isPlaying = true
                        } else {
                            player.pause()
                            isPlaying = false
                            if oldValue {
                                // Reset when leaving
                                scrollDisabled = false
                            }
                        }
                    }
                } else if isLoading {
                    VideoLoadingView(fileName: vaultItem.fileName)
                } else if let errorMessage = errorMessage {
                    VideoErrorView(
                        errorMessage: errorMessage,
                        isFormatUnsupported: isFormatUnsupported,
                        fileName: vaultItem.fileName
                    )
                }
            }
        }
        .onAppear {
            if player == nil {
                loadVideo()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    // MARK: - Video Loading
    
    private func loadVideo() {
        Task {
            do {
                let fileData = try await FileStorageManager.shared.loadImage(for: vaultItem)
                
                // Create temporary file for AVPlayer
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(getFileExtension(from: vaultItem.fileType))
                
                try fileData.write(to: tempURL)
                
                // Create AVURLAsset to inspect video compatibility and dimensions
                let asset = AVURLAsset(url: tempURL)
                let videoTracks: [AVAssetTrack]
                do {
                    videoTracks = try await asset.loadTracks(withMediaType: .video)
                } catch {
                    await MainActor.run {
                        self.isFormatUnsupported = true
                        self.errorMessage = getUnsupportedFormatMessage()
                        self.isLoading = false
                    }
                    return
                }
                
                // Check if the video format is supported by AVFoundation
                if videoTracks.isEmpty {
                    await MainActor.run {
                        self.isFormatUnsupported = true
                        self.errorMessage = getUnsupportedFormatMessage()
                        self.isLoading = false
                    }
                    return
                }
                
                // Check if the video tracks are playable
                do {
                    let playable = try await asset.load(.isPlayable)
                    if !playable {
                        await MainActor.run {
                            self.isFormatUnsupported = true  
                            self.errorMessage = getUnsupportedFormatMessage()
                            self.isLoading = false
                        }
                        return
                    }
                } catch {
                    await MainActor.run {
                        self.isFormatUnsupported = true  
                        self.errorMessage = getUnsupportedFormatMessage()
                        self.isLoading = false
                    }
                    return
                }
                
                if let track = videoTracks.first {
                    do {
                        let natural = try await track.load(.naturalSize)
                        let transform = try await track.load(.preferredTransform)
                        let transformedSize = natural.applying(transform)
                        let corrected = CGSize(width: abs(transformedSize.width), height: abs(transformedSize.height))
                        await MainActor.run { self.videoSize = corrected }
                    } catch {
                        print("Error loading track properties: \(error)")
                        // Continue without video size information
                    }
                }

                await MainActor.run {
                    let playerItem = AVPlayerItem(url: tempURL)
                    
                    // Configure player item according to Apple best practices
                    playerItem.preferredForwardBufferDuration = 2.0
                    
                    // Create player
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.volume = 1.0
                    
                    self.player = newPlayer
                    self.isLoading = false
                    
                    // Auto-play if active
                    if isActive {
                        newPlayer.rate = playbackRate
                        isPlaying = true
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
                    print("Error loading video: \(error)")
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
        case "video/x-matroska":
            return "mkv"
        case "video/x-msvideo":
            return "avi"
        case "video/webm":
            return "webm"
        case "video/x-flv":
            return "flv"
        case "video/x-ms-wmv":
            return "wmv"
        case "video/3gpp":
            return "3gp"
        default:
            return "mp4"
        }
    }
    
    private func getUnsupportedFormatMessage() -> String {
        let fileType = vaultItem.fileType ?? ""
        
        if fileType == "video/x-matroska" {
            return "This MKV video contains codecs that are not supported by iOS. The video file is safely stored, but cannot be played on this device. Try converting to MP4 format for playback."
        } else {
            return "This video format (\(getFileExtension(from: fileType).uppercased())) is not supported for playback on iOS. The file is safely stored but cannot be played."
        }
    }
}

// MARK: - Supporting Views

struct VideoLoadingView: View {
    let fileName: String?
    
    var body: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
            
            Text("Loading \(fileName ?? "video")...")
                .font(.headline)
                .foregroundColor(.white)
        }
    }
}

struct VideoErrorView: View {
    let errorMessage: String
    let isFormatUnsupported: Bool
    let fileName: String?
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: isFormatUnsupported ? "play.slash" : "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(isFormatUnsupported ? .orange : .red)
            
            Text(isFormatUnsupported ? "Unsupported Video Format" : "Error loading video")
                .font(.headline)
                .foregroundColor(.white)
            
            if let fileName = fileName {
                Text(fileName)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
                    .padding(.horizontal, 40)
            }
            
            Text(errorMessage)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            if isFormatUnsupported {
                VStack(spacing: 8) {
                    Text("Supported formats:")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Text("MP4, MOV, M4V")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                .padding(.top, 10)
            }
        }
        .padding()
    }
}

#Preview {
    let sampleItem: VaultItem = {
        let context = CoreDataManager.shared.context
        let item = VaultItem(context: context)
        item.fileName = "sample.mp4"
        item.fileType = "video/mp4"
        item.fileSize = 5000000
        item.createdAt = Date()
        return item
    }()
    
    AutoPlayVideoView(
        vaultItem: sampleItem,
        isActive: true,
        scrollDisabled: .constant(false)
    )
    .background(Color.black)
}