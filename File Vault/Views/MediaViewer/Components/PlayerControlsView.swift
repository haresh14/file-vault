//
//  PlayerControlsView.swift
//  File Vault
//
//  Video player controls with scrubber and playback rate options
//

import SwiftUI
import AVKit
import AVFoundation

struct PlayerControlsView: View {
    let player: AVPlayer
    @Binding var isPlaying: Bool
    @Binding var showControls: Bool
    @Binding var playbackRate: Float
    @State private var hideControlsTimer: Timer?
    @State private var progress: Double = 0
    @State private var isScrubbing = false
    @Environment(\.verticalSizeClass) var verticalSizeClass
    private let availableRates: [Float] = [0.25, 0.5, 0.75, 1.0, 1.5, 2.0]

    var body: some View {
        ZStack {
            if showControls {
                // Centered controls
                HStack(spacing: 40) {
                    Button(action: {
                        seek(by: -15)
                        resetTimer()
                    }) {
                        Image(systemName: "gobackward.15")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        if isPlaying {
                            player.pause()
                        } else {
                            player.rate = playbackRate
                        }
                        isPlaying.toggle()
                        resetTimer()
                    }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 60, weight: .thin))
                            .foregroundColor(.white)
                    }

                    Button(action: {
                        seek(by: 15)
                        resetTimer()
                    }) {
                        Image(systemName: "goforward.15")
                            .font(.system(size: 30, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .transition(.opacity)
            }

            // Scrubber at the bottom
            VStack {
                Spacer()
                if showControls {
                    HStack(spacing: 16) {
                        Text(formatTime(player.currentTime().seconds))
                            .foregroundColor(.white)
                            .font(.caption)
                        
                        CustomScrubberView(
                            progress: $progress,
                            isScrubbing: $isScrubbing
                        ) { newProgress in
                            seek(to: newProgress)
                            resetTimer()
                        }
                        
                        Text(formatTime(player.currentItem?.duration.seconds ?? 0))
                            .foregroundColor(.white)
                            .font(.caption)

                        Menu {
                            ForEach(availableRates, id: \.self) { rate in
                                Button(action: {
                                    playbackRate = rate
                                    if isPlaying {
                                        player.rate = rate
                                    }
                                    resetTimer()
                                }) {
                                    HStack {
                                        if playbackRate == rate {
                                            Image(systemName: "checkmark")
                                        }
                                        Text("\(String(format: "%.2g", rate))x")
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "speedometer")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundColor(.white)
                                .frame(minWidth: 44, minHeight: 44)
                                .contentShape(Rectangle())
                        }
                    }
                    .padding()
                    .transition(.opacity)
                }
            }
            .padding(.bottom, verticalSizeClass == .compact ? 0 : 20)
        }
        .padding(.horizontal)
        .onAppear {
            setupTimer()
            addProgressObserver()
        }
        .onChange(of: showControls) { oldValue, newValue in
            if newValue {
                resetTimer()
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func addProgressObserver() {
        player.addPeriodicTimeObserver(forInterval: CMTime(seconds: 0.5, preferredTimescale: 600), queue: .main) { time in
            guard !isScrubbing else { return }
            let duration = player.currentItem?.duration.seconds ?? 1
            progress = time.seconds / duration
        }
    }

    private func seek(to progress: Double) {
        let duration = player.currentItem?.duration ?? .zero
        let newTime = CMTime(seconds: duration.seconds * progress, preferredTimescale: 600)
        player.seek(to: newTime)
    }

    private func seek(by seconds: Double) {
        let currentTime = player.currentTime()
        let newTime = CMTime(seconds: currentTime.seconds + seconds, preferredTimescale: 600)
        player.seek(to: newTime)
    }

    private func formatTime(_ seconds: Double) -> String {
        let date = Date(timeIntervalSince1970: seconds)
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        if seconds >= 3600 {
            formatter.dateFormat = "H:mm:ss"
        } else {
            formatter.dateFormat = "m:ss"
        }
        return formatter.string(from: date)
    }

    private func setupTimer() {
        if showControls {
            resetTimer()
        }
    }

    private func resetTimer() {
        hideControlsTimer?.invalidate()
        hideControlsTimer = Timer.scheduledTimer(withTimeInterval: 3.0, repeats: false) { _ in
            withAnimation {
                showControls = false
            }
        }
    }
}

// MARK: - Custom Scrubber

struct CustomScrubberView: View {
    @Binding var progress: Double
    @Binding var isScrubbing: Bool
    var onScrub: (Double) -> Void
    
    @State private var scrubberHeight: CGFloat = 7
    private let activeScrubberHeight: CGFloat = 14
    
    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let progressWidth = totalWidth * CGFloat(progress)
            
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.3))
                    .frame(height: scrubberHeight)
                
                Capsule()
                    .fill(Color.white)
                    .frame(width: progressWidth, height: scrubberHeight)
            }
            .frame(height: 44)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        if !isScrubbing {
                            isScrubbing = true
                        }
                        let newProgress = min(max(0, value.location.x / totalWidth), 1)
                        progress = newProgress
                        onScrub(newProgress)
                    }
                    .onEnded { value in
                        isScrubbing = false
                    }
            )
            .onChange(of: isScrubbing) { oldValue, newValue in
                withAnimation(.spring()) {
                    scrubberHeight = newValue ? activeScrubberHeight : 8
                }
            }
        }
        .frame(height: 44)
    }
}

#Preview {
    // Create a sample player for preview
    let url = URL(string: "https://sample-videos.com/zip/10/mp4/SampleVideo_1280x720_1mb.mp4")!
    let player = AVPlayer(url: url)
    
    PlayerControlsView(
        player: player,
        isPlaying: .constant(false),
        showControls: .constant(true),
        playbackRate: .constant(1.0)
    )
    .background(Color.black)
}