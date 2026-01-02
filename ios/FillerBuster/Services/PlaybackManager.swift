import AVFoundation
import Combine

/// Manages audio playback with time tracking for transcript sync
@MainActor
class PlaybackManager: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: Double = 0
    @Published var duration: Double = 0
    @Published var isLoaded = false

    private var audioPlayer: AVAudioPlayer?
    private var displayLink: CADisplayLink?
    private var displayLinkTarget: DisplayLinkTarget?

    /// Load audio from file
    func loadAudio(fileName: String) {
        let url = AudioStorageService.shared.audioURL(fileName: fileName)

        guard AudioStorageService.shared.audioExists(fileName: fileName) else {
            print("Audio file not found: \(fileName)")
            return
        }

        do {
            // Configure audio session for playback
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            duration = audioPlayer?.duration ?? 0
            isLoaded = true
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    /// Start or resume playback
    func play() {
        guard let player = audioPlayer else { return }

        player.play()
        isPlaying = true
        startTimeUpdates()
    }

    /// Pause playback
    func pause() {
        audioPlayer?.pause()
        isPlaying = false
        stopTimeUpdates()
    }

    /// Stop playback and reset to beginning
    func stop() {
        audioPlayer?.stop()
        audioPlayer?.currentTime = 0
        isPlaying = false
        currentTime = 0
        stopTimeUpdates()
    }

    /// Seek to specific time
    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    /// Toggle play/pause
    func toggle() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    /// Skip forward by seconds
    func skipForward(_ seconds: Double = 5) {
        let newTime = min(currentTime + seconds, duration)
        seek(to: newTime)
    }

    /// Skip backward by seconds
    func skipBackward(_ seconds: Double = 5) {
        let newTime = max(currentTime - seconds, 0)
        seek(to: newTime)
    }

    // MARK: - Time Updates

    private func startTimeUpdates() {
        // Use CADisplayLink for smooth time updates
        displayLinkTarget = DisplayLinkTarget { [weak self] in
            Task { @MainActor in
                self?.updateTime()
            }
        }
        displayLink = CADisplayLink(target: displayLinkTarget!, selector: #selector(DisplayLinkTarget.tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 15, maximum: 30, preferred: 30)
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopTimeUpdates() {
        displayLink?.invalidate()
        displayLink = nil
        displayLinkTarget = nil
    }

    private func updateTime() {
        guard let player = audioPlayer else { return }
        currentTime = player.currentTime

        // Check if playback finished
        if !player.isPlaying && isPlaying {
            isPlaying = false
            stopTimeUpdates()
            // Reset to beginning when finished
            currentTime = 0
            player.currentTime = 0
        }
    }

    deinit {
        displayLink?.invalidate()
    }
}

// MARK: - DisplayLink Target (needed for CADisplayLink)

private class DisplayLinkTarget {
    let callback: () -> Void

    init(callback: @escaping () -> Void) {
        self.callback = callback
    }

    @objc func tick() {
        callback()
    }
}
