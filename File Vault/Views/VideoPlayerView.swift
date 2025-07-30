import SwiftUI
import AVKit
import AVFoundation

struct UnifiedMediaViewerView: View {
    let mediaItems: [VaultItem]
    let initialIndex: Int
    
    // The currentIndex needs to be optional for .scrollPosition
    @State private var currentIndex: Int?
    // Whether horizontal scrolling should be disabled (when zoomed)
    @State private var isScrollDisabled: Bool = false
    @Environment(\.dismiss) private var dismiss
    
    init(mediaItems: [VaultItem], initialIndex: Int) {
        self.mediaItems = mediaItems
        self.initialIndex = initialIndex
        // We set the initial value in onAppear
        self._currentIndex = State(initialValue: initialIndex)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if !mediaItems.isEmpty {
                // 1. Use a horizontal ScrollView
                ScrollView(.horizontal, showsIndicators: false) {
                    // 2. Use a LazyHStack for performance
                    LazyHStack(spacing: 0) {
                        ForEach(mediaItems.indices, id: \.self) { index in
                            let item = mediaItems[index]
                            let isActive = currentIndex == index
                            
                            Group {
                                if item.isVideo {
                                    AutoPlayVideoView(
                                        vaultItem: item,
                                        isActive: isActive,
                                        scrollDisabled: $isScrollDisabled
                                    )
                                } else {
                                    ZoomablePhotoView(
                                        vaultItem: item,
                                        isActive: isActive,
                                        scrollDisabled: $isScrollDisabled
                                    )
                                }
                            }
                            // 3. Make each item take the full container width
                            .containerRelativeFrame(.horizontal)
                            .id(index) // Set an ID for scrollPosition to track
                            // Allow horizontal scroll gesture to co-exist with item gestures
                        }
                    }
                    // 4. This is needed for the scroll target behavior to work correctly
                    .scrollTargetLayout()
                }
                // 5. This modifier enables the paging behavior
                .scrollTargetBehavior(.paging)
                // 6. This binds the scroll position to your state variable
                .scrollPosition(id: $currentIndex)
                // Disable scroll when an item is zoomed in
                .scrollDisabled(isScrollDisabled)
                .ignoresSafeArea()
            }
        }
        .statusBarHidden()
        .onAppear {
            // Set the initial page
            currentIndex = initialIndex
        }
        .gesture(
            // Swipe-down-to-close should only work when gestures are enabled (not zoomed)
            DragGesture()
                .onEnded { value in
                    guard !isScrollDisabled else { return } // Disable when zoomed
                    // Only trigger dismiss on vertical swipes
                    if value.translation.height > 100 && abs(value.translation.height) > abs(value.translation.width) {
                        dismiss()
                    }
                }
        )
    }
}

// Auto-playing video component
struct AutoPlayVideoView: View {
    let vaultItem: VaultItem
    let isActive: Bool
    @Binding var scrollDisabled: Bool
    @State private var player: AVPlayer?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var hasLoadedOnce = false
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var showControls = false
    @State private var isPlaying = false
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var playbackRate: Float = 1.0

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
                                            // Disable paging when zoomed in
                                            if isActive {
                                                scrollDisabled = scale > 1.0
                                            }
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
                                    DragGesture()
                                        .onChanged { value in
                                            if scale > 1.0 {
                                                let newOffset = CGSize(
                                                    width: lastOffset.width + value.translation.width,
                                                    height: lastOffset.height + value.translation.height
                                                )
                                                
                                                let maxOffsetX = (geometry.size.width * (scale - 1)) / 2
                                                let maxOffsetY = (geometry.size.height * (scale - 1)) / 2
                                                
                                                offset = CGSize(
                                                    width: min(max(newOffset.width, -maxOffsetX), maxOffsetX),
                                                    height: min(max(newOffset.height, -maxOffsetY), maxOffsetY)
                                                )
                                            }
                                        }
                                        .onEnded { _ in
                                            if scale > 1.0 {
                                                lastOffset = offset
                                            }
                                            if isActive {
                                                // Re-evaluate scroll disable
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
                                    } else {
                                        scale = 2.0
                                        lastScale = 2.0
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
            if player == nil {
                loadVideo()
            }
        }
        .onDisappear {
            player?.pause()
        }
    }
    
    private func loadVideo() {
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
}

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

// Player controls view
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

// Zoomable photo component
struct ZoomablePhotoView: View {
    let vaultItem: VaultItem
    let isActive: Bool
    @Binding var scrollDisabled: Bool
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    @State private var image: UIImage?
    @State private var isLoading = true
    @Environment(\.dismiss) private var dismiss

    // Reset zoom when the photo is no longer active
    @State private var lastIsActive: Bool = true
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Color.black.ignoresSafeArea()
                
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .scaleEffect(scale)
                        .offset(offset)
                        .simultaneousGesture(
                            SimultaneousGesture(
                                // Pinch to zoom
                                MagnificationGesture()
                                    .onChanged { value in
                                        let newScale = lastScale * value
                                        scale = max(newScale, 0.5) // Allow zoom out to 0.5x, no upper limit
                                        if isActive {
                                            scrollDisabled = scale > 1.0
                                        }
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
                                        if isActive {
                                            scrollDisabled = scale > 1.0
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
                                        }
                                    }
                                    .onEnded { _ in
                                        if scale > 1.0 {
                                            lastOffset = offset
                                        }
                                        if isActive {
                                            scrollDisabled = scale > 1.0
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
                                    if isActive { scrollDisabled = false }
                                } else {
                                    scale = 2.0
                                    lastScale = 2.0
                                    if isActive { scrollDisabled = true }
                                }
                            }
                        }
                } else if isLoading {
                    VStack(spacing: 20) {
                        ProgressView()
                            .scaleEffect(1.5)
                            .tint(.white)
                        
                        Text("Loading image...")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                } else {
                    VStack(spacing: 20) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                        
                        Text("Error loading image")
                            .font(.headline)
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .onAppear {
            loadImage()
            lastIsActive = isActive
            if isActive { scrollDisabled = false }
        }
        .onChange(of: isActive) { oldValue, newValue in
            if !newValue {
                // Reset zoom when switching away
                withAnimation(.spring()) {
                    scale = 1.0
                    lastScale = 1.0
                    offset = .zero
                    lastOffset = .zero
                }
                scrollDisabled = false
            }
            lastIsActive = newValue
        }
    }
    
    private func loadImage() {
        Task {
            do {
                let image = try await FileStorageManager.shared.loadImage(for: vaultItem)
                await MainActor.run {
                    self.image = image
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        }
    }
}

// Custom video player using UIViewRepresentable to have more control over the view
struct CustomVideoPlayerView: UIViewRepresentable {
    var player: AVPlayer

    func makeUIView(context: Context) -> PlayerUIView {
        return PlayerUIView(player: player)
    }

    func updateUIView(_ uiView: PlayerUIView, context: Context) {
        uiView.playerLayer.player = player
    }
}

class PlayerUIView: UIView {
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
    Text("Unified Media Viewer Preview")
} 
