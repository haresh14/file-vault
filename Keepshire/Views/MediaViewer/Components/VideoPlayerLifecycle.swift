import AVFoundation
import AVKit
import Foundation

final class VideoPlayerLifecycle: ObservableObject {
    @Published private(set) var player: AVPlayer?
    @Published private(set) var isLoading = true
    @Published private(set) var errorMessage: String?
    @Published private(set) var videoSize: CGSize?
    @Published private(set) var isFormatUnsupported = false
    @Published var isPlaying = false

    private var hasLoadedOnce = false

    func load(vaultItem: VaultItem, isActive: Bool, playbackRate: Float) {
        guard player == nil else { return }

        Task {
            do {
                let fileData = try await FileStorageManager.shared.loadImage(for: vaultItem)
                let tempURL = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension(Self.fileExtension(from: vaultItem.fileType))
                try fileData.write(to: tempURL)

                let asset = AVURLAsset(url: tempURL)
                let videoTracks: [AVAssetTrack]
                do {
                    videoTracks = try await asset.loadTracks(withMediaType: .video)
                } catch {
                    await markUnsupported(fileType: vaultItem.fileType)
                    return
                }

                guard !videoTracks.isEmpty else {
                    await markUnsupported(fileType: vaultItem.fileType)
                    return
                }

                do {
                    guard try await asset.load(.isPlayable) else {
                        await markUnsupported(fileType: vaultItem.fileType)
                        return
                    }
                } catch {
                    await markUnsupported(fileType: vaultItem.fileType)
                    return
                }

                if let track = videoTracks.first {
                    do {
                        let natural = try await track.load(.naturalSize)
                        let transform = try await track.load(.preferredTransform)
                        let transformedSize = natural.applying(transform)
                        let corrected = CGSize(
                            width: abs(transformedSize.width),
                            height: abs(transformedSize.height)
                        )
                        await MainActor.run { self.videoSize = corrected }
                    } catch {
                        VaultLog.debug("Error loading track properties: \(error)")
                    }
                }

                await MainActor.run {
                    let playerItem = AVPlayerItem(url: tempURL)
                    playerItem.preferredForwardBufferDuration = 2.0
                    let newPlayer = AVPlayer(playerItem: playerItem)
                    newPlayer.volume = 1.0
                    self.player = newPlayer
                    self.isLoading = false

                    if isActive {
                        newPlayer.rate = playbackRate
                        self.isPlaying = true
                        self.hasLoadedOnce = true
                    }

                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        try? FileManager.default.removeItem(at: tempURL)
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    VaultLog.debug("Error loading video: \(error)")
                }
            }
        }
    }

    func surfaceAppeared(isActive: Bool, playbackRate: Float) {
        guard let player = player, isActive, !hasLoadedOnce else { return }
        player.rate = playbackRate
        isPlaying = true
        hasLoadedOnce = true
    }

    func activeStateChanged(from oldValue: Bool, to newValue: Bool, playbackRate: Float) -> Bool {
        guard let player = player else { return false }
        if newValue {
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
        }
        return !newValue && oldValue
    }

    func pause() {
        player?.pause()
    }

    static func fileExtension(from fileType: String?) -> String {
        guard let fileType = fileType else { return "mp4" }
        switch fileType {
        case "video/mp4": return "mp4"
        case "video/quicktime": return "mov"
        case "video/x-m4v": return "m4v"
        case "video/x-matroska": return "mkv"
        case "video/x-msvideo": return "avi"
        case "video/webm": return "webm"
        case "video/x-flv": return "flv"
        case "video/x-ms-wmv": return "wmv"
        case "video/3gpp": return "3gp"
        default: return "mp4"
        }
    }

    static func unsupportedFormatMessage(fileType: String?) -> String {
        let fileType = fileType ?? ""
        if fileType == "video/x-matroska" {
            return "This MKV video contains codecs that are not supported by iOS. The video file is safely stored, but cannot be played on this device. Try converting to MP4 format for playback."
        }
        return "This video format (\(fileExtension(from: fileType).uppercased())) is not supported for playback on iOS. The file is safely stored but cannot be played."
    }

    private func markUnsupported(fileType: String?) async {
        await MainActor.run {
            isFormatUnsupported = true
            errorMessage = Self.unsupportedFormatMessage(fileType: fileType)
            isLoading = false
        }
    }
}
