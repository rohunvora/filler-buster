import SwiftUI
import Combine
import AVFoundation

/// Main view model connecting audio capture, Deepgram, transcript, and haptics
@MainActor
class RecordingViewModel: ObservableObject {
    // State
    @Published var isRecording = false
    @Published var isConnecting = false  // New: shows connecting state
    @Published var showResults = false
    @Published var errorMessage: String?
    @Published var pulseScale: CGFloat = 1.0
    @Published var connectingRingScale: CGFloat = 1.0  // For ring animation

    // Prompt state
    @Published var showPrompt = false
    @Published private(set) var currentPrompt: String = ""

    // Last saved session (for post-recording actions)
    @Published private(set) var lastSavedSession: RecordingSession?

    // Prompts - designed to trigger natural, passionate speech
    private let prompts = [
        // The Rant
        "What's something that annoys you way more than it should?",
        "What do people do that makes absolutely no sense to you?",
        "What's a \"normal\" thing that you think is actually insane?",
        "What's something broken that everyone just accepts?",
        "What's a hill you'll die on that most people don't care about?",
        // The Hot Take
        "What's your most unpopular opinion?",
        "What does everyone get wrong about something you know well?",
        "What's something overhyped right now?",
        "What's a popular opinion you think is completely backwards?",
        "What's something people romanticize that actually sucks?",
        // The Defense
        "Defend something you love that people mock or dismiss.",
        "What's something \"lowbrow\" that's actually great?",
        "Make the case for something everyone thinks is outdated.",
        "What do you like that you have to defend constantly?",
        "What's underrated that deserves way more attention?",
        // The Story
        "What's the craziest thing you've ever witnessed?",
        "What happened to you that people don't believe?",
        "What's a story you always end up telling?",
        "What's the most unexpected thing that's happened to you?",
        "What's a moment that completely changed how you see something?",
        // The Expertise
        "Explain something you know way too much about.",
        "What rabbit hole have you gone down recently?",
        "What's something you understand that most people don't?",
        "What could you talk about for 30 minutes without notes?",
        "What do you wish someone had explained to you earlier?"
    ]

    // Services
    private let audioService = AudioCaptureService()
    private var deepgramService: DeepgramService?
    private let transcriptManager = TranscriptManager()
    private let hapticService = HapticService()
    private var persistenceService: SessionPersistenceService?

    private var cancellables = Set<AnyCancellable>()
    private var pulseTimer: Timer?
    private var connectingTimer: Timer?

    // Throttle UI updates to avoid overwhelming the render system
    private var lastUIUpdateTime: Date = .distantPast
    private let minUIUpdateInterval: TimeInterval = 0.15  // Max ~6-7 updates per second

    /// Inject persistence service from view (which has access to modelContext)
    func setPersistenceService(_ service: SessionPersistenceService) {
        self.persistenceService = service
    }

    // Expose transcript data
    var words: [TranscriptWord] {
        transcriptManager.words
    }

    var fillerCounts: [String: Int] {
        transcriptManager.fillerCounts
    }

    // Timing metrics
    var wordsPerMinute: Double {
        transcriptManager.wordsPerMinute
    }

    var longPauseCount: Int {
        transcriptManager.longPauseCount
    }

    var averagePause: Double {
        transcriptManager.averagePause
    }

    var sessionDuration: Double {
        transcriptManager.sessionDuration
    }

    init() {
        setupBindings()
    }

    private func setupBindings() {
        // Forward transcript updates with throttling
        // Only update UI 6-7 times per second max, not on every single packet
        transcriptManager.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                guard let self = self else { return }
                
                let now = Date()
                let timeSinceLastUpdate = now.timeIntervalSince(self.lastUIUpdateTime)
                
                // Always update immediately for final results, throttle interim updates
                if self.transcriptManager.hasRecentFinalUpdate || timeSinceLastUpdate >= self.minUIUpdateInterval {
                    self.lastUIUpdateTime = now
                    self.objectWillChange.send()
                }
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

        // Immediate feedback: light haptic + show connecting state
        hapticService.prepare()
        hapticService.lightTap()
        isConnecting = true
        startConnectingAnimation()

        // Check microphone permission
        let granted = await audioService.requestPermission()
        guard granted else {
            errorMessage = "Microphone access required. Enable in Settings."
            isConnecting = false
            stopConnectingAnimation()
            return
        }

        // Get API key
        guard let apiKey = getDeepgramAPIKey() else {
            errorMessage = "Deepgram API key not configured"
            isConnecting = false
            stopConnectingAnimation()
            return
        }

        // Reset state
        transcriptManager.reset()
        showResults = false
        lastSavedSession = nil

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
                    self?.onConnectionEstablished()
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
    }

    /// Called when Deepgram connection is established
    private func onConnectionEstablished() {
        // Stop connecting animation, start recording
        isConnecting = false
        stopConnectingAnimation()

        // Start audio capture
        startAudioCapture()

        // Confirm recording started with haptic
        hapticService.mediumTap()

        // Start pulse animation
        startPulseAnimation()

        isRecording = true
    }

    /// Stop recording
    func stopRecording() {
        isRecording = false

        // Haptic feedback for stop
        hapticService.mediumTap()

        // Stop pulse
        stopPulseAnimation()

        // Stop audio
        audioService.stopCapture()

        // Close Deepgram
        deepgramService?.finishStream()
        deepgramService?.disconnect()
        deepgramService = nil

        // Clear subscriptions except transcript bindings
        cancellables.removeAll()
        setupBindings()

        // Show results
        showResults = true

        // Save session to persistence
        saveCurrentSession()
    }

    /// Save current session to persistent storage
    private func saveCurrentSession() {
        guard let persistence = persistenceService else {
            print("Warning: No persistence service configured")
            return
        }

        // Only save if we have content
        guard !transcriptManager.words.isEmpty else {
            print("Skipping save: no words recorded")
            return
        }

        Task {
            do {
                let session = try persistence.saveSession(
                    words: transcriptManager.words,
                    fillerCounts: transcriptManager.fillerCounts,
                    wordsPerMinute: transcriptManager.wordsPerMinute,
                    longPauseCount: transcriptManager.longPauseCount,
                    sessionDuration: transcriptManager.sessionDuration,
                    promptUsed: currentPrompt.isEmpty ? nil : currentPrompt,
                    audioData: audioService.getRecordedAudio()
                )
                lastSavedSession = session
                print("Session saved successfully")
            } catch {
                print("Failed to save session: \(error)")
            }
        }
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
        showPrompt = false
        currentPrompt = ""
        transcriptManager.reset()
        audioService.clearAudioBuffer()
    }

    /// Reveal prompt card with a random prompt
    func revealPrompt() {
        if currentPrompt.isEmpty {
            shufflePrompt()
        }
        showPrompt = true
    }

    /// Get a new random prompt
    func shufflePrompt() {
        var newPrompt = prompts.randomElement() ?? prompts[0]
        // Avoid showing the same prompt twice in a row
        while newPrompt == currentPrompt && prompts.count > 1 {
            newPrompt = prompts.randomElement() ?? prompts[0]
        }
        currentPrompt = newPrompt
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
        pulseTimer = Timer.scheduledTimer(withTimeInterval: 0.9, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isRecording else { return }
                withAnimation(.spring(response: 0.45, dampingFraction: 0.5)) {
                    self.pulseScale = self.pulseScale == 1.0 ? 1.06 : 1.0
                }
            }
        }
    }

    private func stopPulseAnimation() {
        pulseTimer?.invalidate()
        pulseTimer = nil
        pulseScale = 1.0
    }

    private func startConnectingAnimation() {
        connectingRingScale = 1.0
        connectingTimer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, self.isConnecting else { return }
                self.connectingRingScale = 1.0
                withAnimation(.easeOut(duration: 1.1)) {
                    self.connectingRingScale = 2.0
                }
            }
        }
        // Trigger first animation immediately
        withAnimation(.easeOut(duration: 1.1)) {
            connectingRingScale = 2.0
        }
    }

    private func stopConnectingAnimation() {
        connectingTimer?.invalidate()
        connectingTimer = nil
        connectingRingScale = 1.0
    }
}
