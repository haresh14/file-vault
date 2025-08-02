//
//  AudioPreviewView.swift
//  File Vault
//
//  Audio preview component with playback controls
//

import SwiftUI
import AVKit
import AVFoundation
import MediaPlayer

struct AudioPreviewView: View {
    let fileData: Data?
    let fileName: String?
    let fileType: String?
    
    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var currentTime: Double = 0
    @State private var duration: Double = 0
    @State private var timer: Timer?
    @State private var temporaryURL: URL?
    @State private var loadingError: String?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 40) {
            if isLoading {
                // Loading state
                VStack(spacing: 20) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                    Text("Loading audio...")
                        .font(.headline)
                        .foregroundColor(.white)
                }
            } else if let error = loadingError {
                // Error state
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 60))
                        .foregroundColor(.red)
                    Text("Failed to load audio")
                        .font(.headline)
                        .foregroundColor(.white)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
            } else {
                // Audio player content
                VStack(spacing: 40) {
                    // Audio icon and info
                    VStack(spacing: 20) {
                        Image(systemName: "music.note")
                            .font(.system(size: 100))
                            .foregroundColor(.white)
                        
                        VStack(spacing: 8) {
                            Text(fileName ?? "Audio File")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                            
                            if let fileType = fileType {
                                Text(getDisplayFileType(fileType))
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 4)
                                    .background(Color.gray.opacity(0.3))
                                    .cornerRadius(8)
                            }
                        }
                    }
                    
                    // Progress bar
                    VStack(spacing: 10) {
                        Slider(value: $currentTime, in: 0...max(duration, 1)) { editing in
                            if !editing && player != nil {
                                let time = CMTime(seconds: currentTime, preferredTimescale: 1000)
                                player?.seek(to: time)
                            }
                        }
                        .accentColor(.white)
                        
                        HStack {
                            Text(formatTime(currentTime))
                                .font(.caption)
                                .foregroundColor(.gray)
                            
                            Spacer()
                            
                            Text(formatTime(duration))
                                .font(.caption)
                                .foregroundColor(.gray)
                        }
                    }
                    .padding(.horizontal, 40)
                    
                    // Play/Pause button
                    Button(action: togglePlayback) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.white)
                    }
                    .disabled(player == nil)
                }
            }
        }
        .padding()
        .onAppear {
            setupAudioPlayer()
        }
        .onDisappear {
            cleanup()
        }
    }
    
    // MARK: - Audio Player Setup
    
    private func setupAudioPlayer() {
        guard let fileData = fileData else {
            loadingError = "No audio data available"
            isLoading = false
            return
        }
        
        Task {
            do {
                // Configure audio session for playback
                try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                try AVAudioSession.sharedInstance().setActive(true)
                
                // Create temporary file with correct extension
                let tempDir = FileManager.default.temporaryDirectory
                let fileExtension = getFileExtension(from: fileType)
                let tempURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
                
                try fileData.write(to: tempURL)
                
                await MainActor.run {
                    self.temporaryURL = tempURL
                    
                    let playerItem = AVPlayerItem(url: tempURL)
                    self.player = AVPlayer(playerItem: playerItem)
                    
                    // Start timer for progress updates
                    startTimer()
                }
                
                // Get duration asynchronously
                let asset = AVURLAsset(url: tempURL)
                let duration = try await asset.load(.duration)
                
                await MainActor.run {
                    self.duration = duration.seconds
                    self.isLoading = false
                }
                
            } catch {
                await MainActor.run {
                    self.loadingError = error.localizedDescription
                    self.isLoading = false
                }
                print("Failed to setup audio player: \(error)")
            }
        }
    }
    
    // MARK: - Playback Controls
    
    private func togglePlayback() {
        guard let player = player else { return }
        
        if isPlaying {
            player.pause()
            isPlaying = false
        } else {
            // Reset to beginning if playback finished
            if currentTime >= duration && duration > 0 {
                player.seek(to: .zero)
                currentTime = 0
            }
            player.play()
            isPlaying = true
        }
    }
    
    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            guard let player = player else { return }
            
            currentTime = player.currentTime().seconds
            
            // Check if playback finished
            if currentTime >= duration && duration > 0 {
                isPlaying = false
                currentTime = 0
                player.seek(to: .zero)
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && !seconds.isNaN else { return "0:00" }
        
        let totalSeconds = Int(seconds)
        let minutes = totalSeconds / 60
        let seconds = totalSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    private func cleanup() {
        timer?.invalidate()
        timer = nil
        player?.pause()
        player = nil
        
        // Deactivate audio session
        try? AVAudioSession.sharedInstance().setActive(false)
        
        if let url = temporaryURL {
            try? FileManager.default.removeItem(at: url)
            temporaryURL = nil
        }
    }
    
    // MARK: - Helper Methods
    
    private func getFileExtension(from mimeType: String?) -> String {
        guard let mimeType = mimeType else { return "mp3" }
        
        switch mimeType.lowercased() {
        case "audio/mpeg", "audio/mp3":
            return "mp3"
        case "audio/mp4", "audio/m4a":
            return "m4a"
        case "audio/wav", "audio/wave":
            return "wav"
        case "audio/aac":
            return "aac"
        case "audio/flac":
            return "flac"
        case "audio/ogg":
            return "ogg"
        case "audio/webm":
            return "webm"
        default:
            return "mp3" // Default fallback
        }
    }
    
    private func getDisplayFileType(_ mimeType: String) -> String {
        switch mimeType.lowercased() {
        case "audio/mpeg", "audio/mp3":
            return "MP3"
        case "audio/mp4", "audio/m4a":
            return "M4A"
        case "audio/wav", "audio/wave":
            return "WAV"
        case "audio/aac":
            return "AAC"
        case "audio/flac":
            return "FLAC"
        case "audio/ogg":
            return "OGG"
        case "audio/webm":
            return "WEBM"
        default:
            return mimeType.uppercased()
        }
    }
}

#Preview {
    AudioPreviewView(
        fileData: Data(),
        fileName: "sample.mp3",
        fileType: "audio/mpeg"
    )
    .background(Color.black)
}