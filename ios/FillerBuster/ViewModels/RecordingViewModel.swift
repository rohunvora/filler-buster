import SwiftUI
import Combine
import AVFoundation

/// Main view model connecting audio capture, Deepgram, transcript, and haptics
@MainActor
class RecordingViewModel: ObservableObject {
    // State
    @Published var isRecording = false
    @Published var showResults = false
    @Published var errorMessage: String?
    @Published var pulseScale: CGFloat = 1.0

    // Services
    private let audioService = AudioCaptureService()
    private var deepgramService: DeepgramService?
    private let transcriptManager = TranscriptManager()
    private let hapticService = HapticService()

    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?

    // Expose transcript data
    var words: [TranscriptWord] {
        transcriptManager.words
    }

    var fillerCounts: [String: Int] {
        transcriptManager.fillerCounts
    }

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Forward transcript updates
        transcriptManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        // Haptic on filler detection
        transcriptManager.fillerDetectedPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.hapticService.buzz()
            }
            .store(in: &cancellables)
    }

    /// Start recording and streaming to Deepgram
    func startRecording() async {
        errorMessage = nil

        // Check microphone permission
        let granted = await audioService.requestPermission()
        guard granted else {
            errorMessage = "Microphone access required. Enable in Settings."
            return
        }

        // Get API key
        guard let apiKey = getDeepgramAPIKey() else {
            errorMessage = "Deepgram API key not configured"
            return
        }

        // Reset state
        transcriptManager.reset()
        showResults = false

        // Initialize Deepgram
        deepgramService = DeepgramService(apiKey: apiKey)

        // Subscribe to Deepgram responses
        deepgramService?.responsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                self?.transcriptManager.processResponse(response)
            }
            .store(in: &cancellables)

        // Subscribe to Deepgram connection
        deepgramService?.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                if connected {
                    self?.startAudioCapture()
                }
            }
            .store(in: &cancellables)

        // Subscribe to audio data
        audioService.audioDataPublisher
            .sink { [weak self] data in
                self?.deepgramService?.sendAudio(data)
            }
            .store(in: &cancellables)

        // Connect to Deepgram
        deepgramService?.connect()

        // Prepare haptics
        hapticService.prepare()

        // Start pulse animation
        startPulseAnimation()

        isRecording = true
    }

    /// Stop recording
    func stopRecording() {
        isRecording = false

        // Stop pulse
        stopPulseAnimation()

        // Stop audio
        audioService.stopCapture()

        // Close Deepgram
        deepgramService?.finishStream()
        deepgramService?.disconnect()
        deepgramService = nil

        // Stop haptics
        hapticService.stop()

        // Clear subscriptions except transcript bindings
        cancellables.removeAll()
        setupBindings()

        // Show results
        showResults = true
    }

    /// Toggle recording state
    func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            Task {
                await startRecording()
            }
        }
    }

    /// Clear results and prepare for new recording
    func recordAgain() {
        showResults = false
        transcriptManager.reset()
    }

    /// Trigger haptic (called from view when filler animates)
    func triggerHaptic() {
        hapticService.buzz()
    }

    // MARK: - Private

    private func startAudioCapture() {
        do {
            try audioService.startCapture()
        } catch {
            errorMessage = error.localizedDescription
            stopRecording()
        }
    }

    private func getDeepgramAPIKey() -> String? {
        // Try environment variable first (for development)
        if let key = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"], !key.isEmpty {
            return key
        }

        // Hardcoded for testing - replace with your key or use Keychain in production
        let hardcodedKey = "96895ed8ed205c76c6360138dac0ccabb90ac31a"
        return hardcodedKey.isEmpty ? nil : hardcodedKey
    }

    private func startPulseAnimation() {
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.75, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                withAnimation(.easeInOut(duration: 0.75)) {
                    self.pulseScale = self.pulseScale == 1.0 ? 1.05 : 1.0
                }
            }
        }
    }

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulseScale = 1.0
    }
}
