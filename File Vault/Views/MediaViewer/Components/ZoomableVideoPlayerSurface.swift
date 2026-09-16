import AVKit
import SwiftUI

struct ZoomableVideoPlayerSurface: View {
    let player: AVPlayer
    let videoSize: CGSize?
    let isActive: Bool
    @Binding var scrollDisabled: Bool
    @Binding var isPlaying: Bool
    @Binding var showControls: Bool
    @Binding var playbackRate: Float

    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    private var isZoomed: Bool { scale > 1.0 }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ZStack {
                    CustomVideoPlayerView(player: player)
                        .scaleEffect(scale)
                        .offset(offset)
                        .simultaneousGesture(
                            DragGesture()
                                .onChanged { value in
                                    guard isZoomed else { return }
                                    let raw = CGSize(
                                        width: lastOffset.width + value.translation.width,
                                        height: lastOffset.height + value.translation.height
                                    )
                                    offset = boundOffset(raw, in: geometry.size)
                                }
                                .onEnded { value in
                                    guard isZoomed else { return }
                                    let predictedRaw = CGSize(
                                        width: lastOffset.width + value.predictedEndTranslation.width,
                                        height: lastOffset.height + value.predictedEndTranslation.height
                                    )
                                    let momentum = hypot(
                                        value.predictedEndTranslation.width - value.translation.width,
                                        value.predictedEndTranslation.height - value.translation.height
                                    ) > 40
                                    let target = momentum
                                        ? boundOffset(predictedRaw, in: geometry.size)
                                        : offset
                                    withAnimation(.easeOut(duration: 0.45)) {
                                        offset = target
                                    }
                                    lastOffset = offset
                                    if isActive {
                                        scrollDisabled = scale > 1.0
                                    }
                                },
                            including: isZoomed ? .all : .subviews
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

                    VideoControlsIntegrationView(
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
            }
            .simultaneousGesture(
                MagnifyGesture()
                    .onChanged { value in
                        let newScale = max(lastScale * value.magnification, 0.5)
                        let anchored = anchoredOffset(
                            for: value.startAnchor,
                            newScale: newScale,
                            in: geometry.size
                        )
                        scale = newScale
                        offset = boundOffset(anchored, in: geometry.size)
                        if isActive {
                            scrollDisabled = scale > 1.0
                        }
                    }
                    .onEnded { _ in
                        lastScale = scale
                        offset = boundOffset(offset, in: geometry.size)
                        lastOffset = offset
                        if scale <= 1.0 {
                            withAnimation(.spring()) {
                                scale = 1.0
                                offset = .zero
                                lastScale = 1.0
                                lastOffset = .zero
                            }
                        }
                    }
            )
        }
    }

    private func anchoredOffset(
        for anchor: UnitPoint,
        newScale: CGFloat,
        in container: CGSize
    ) -> CGSize {
        guard lastScale > 0 else { return lastOffset }
        let focusX = (anchor.x - 0.5) * container.width
        let focusY = (anchor.y - 0.5) * container.height
        let ratio = newScale / lastScale
        return CGSize(
            width: focusX + (lastOffset.width - focusX) * ratio,
            height: focusY + (lastOffset.height - focusY) * ratio
        )
    }

    private func boundOffset(_ raw: CGSize, in container: CGSize) -> CGSize {
        var displayWidth = container.width
        var displayHeight = container.height
        if let videoSize = videoSize {
            let aspect = videoSize.width / videoSize.height
            let containerAspect = container.width / container.height
            if aspect > containerAspect {
                displayWidth = container.width
                displayHeight = container.width / aspect
            } else {
                displayHeight = container.height
                displayWidth = container.height * aspect
            }
        }
        let maxOffsetX = max((displayWidth * scale - container.width) / 2, 0)
        let maxOffsetY = max((displayHeight * scale - container.height) / 2, 0)
        return CGSize(
            width: min(max(raw.width, -maxOffsetX), maxOffsetX),
            height: min(max(raw.height, -maxOffsetY), maxOffsetY)
        )
    }
}

private struct VideoControlsIntegrationView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var showControls: Bool
    @Binding var playbackRate: Float

    var body: some View {
        PlayerControlsView(
            player: player,
            isPlaying: $isPlaying,
            showControls: $showControls,
            playbackRate: $playbackRate
        )
    }
}
