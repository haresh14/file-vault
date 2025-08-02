//
//  CustomVideoPlayerView.swift
//  File Vault
//
//  Custom video player using UIViewRepresentable for direct AVPlayerLayer control
//

import SwiftUI
import AVKit
import AVFoundation

struct CustomVideoPlayerView: UIViewRepresentable {
    var player: AVPlayer

    func makeUIView(context: Context) -> MediaPlayerUIView {
        return MediaPlayerUIView(player: player)
    }

    func updateUIView(_ uiView: MediaPlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

class MediaPlayerUIView: UIView {
    let playerLayer = AVPlayerLayer()

    init(player: AVPlayer) {
        super.init(frame: .zero)
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        layer.addSublayer(playerLayer)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        playerLayer.frame = bounds
    }
}

#Preview {
    // Create a sample player for preview
    let url = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
    let player = AVPlayer(url: url)
    
    CustomVideoPlayerView(player: player)
        .frame(width: 300, height: 200)
        .background(Color.black)
}