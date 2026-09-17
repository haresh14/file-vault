import SwiftUI

struct AutoPlayVideoView: View {
    let vaultItem: VaultItem
    let isActive: Bool
    @Binding var scrollDisabled: Bool

    @StateObject private var lifecycle = VideoPlayerLifecycle()
    @State private var showControls = false
    @State private var playbackRate: Float = 1.0

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = lifecycle.player {
                ZoomableVideoPlayerSurface(
                    player: player,
                    videoSize: lifecycle.videoSize,
                    isActive: isActive,
                    scrollDisabled: $scrollDisabled,
                    isPlaying: $lifecycle.isPlaying,
                    showControls: $showControls,
                    playbackRate: $playbackRate
                )
                .onAppear {
                    lifecycle.surfaceAppeared(
                        isActive: isActive,
                        playbackRate: playbackRate
                    )
                }
                .onChange(of: isActive) { oldValue, newValue in
                    let shouldEnablePaging = lifecycle.activeStateChanged(
                        from: oldValue,
                        to: newValue,
                        playbackRate: playbackRate
                    )
                    if shouldEnablePaging {
                        scrollDisabled = false
                    }
                }
            } else if lifecycle.isLoading {
                VideoLoadingView(fileName: vaultItem.fileName)
            } else if let errorMessage = lifecycle.errorMessage {
                VideoErrorView(
                    errorMessage: errorMessage,
                    isFormatUnsupported: lifecycle.isFormatUnsupported,
                    fileName: vaultItem.fileName
                )
            }
        }
        .onAppear {
            lifecycle.load(
                vaultItem: vaultItem,
                isActive: isActive,
                playbackRate: playbackRate
            )
        }
        .onDisappear {
            lifecycle.pause()
        }
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
