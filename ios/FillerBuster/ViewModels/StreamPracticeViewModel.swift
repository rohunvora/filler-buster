import SwiftUI
import Combine

/// Manages the stream practice flow:
/// Voice input → Clarifying questions → Drills → Feedback
@MainActor
class StreamPracticeViewModel: ObservableObject {

    // MARK: - Flow State

    enum FlowState: Equatable {
        case initial              // "What are you making today?" + hold to record
        case processingIntent     // Analyzing voice input
        case clarifying           // Showing agent's questions
        case generatingSession    // Creating practice drills
        case sessionReady         // Show drills overview
        case drilling(index: Int) // Doing a specific drill
        case drillingFeedback(index: Int) // Showing feedback for drill
        case sessionComplete      // All drills done
    }

    @Published var flowState: FlowState = .initial

    // MARK: - Voice Input State

    @Published var isHoldingToRecord = false
    @Published var intentTranscript: String = ""

    // MARK: - Clarifying Q&A State

    @Published var questions: [ClarifyingQuestion] = []
    @Published var currentQuestionIndex: Int = 0
    @Published var answers: [ClarifyingAnswer] = []
    @Published var currentAnswerText: String = ""

    // MARK: - Session State

    @Published var intent: PracticeIntent?
    @Published var session: StreamPracticeSession?
    @Published var currentDrillFeedback: StreamDrillFeedback?

    // MARK: - Recording State (for drills)

    @Published var isRecording = false
    @Published var isConnecting = false
    @Published var isReadyToRecord = false  // True when Deepgram is connected
    @Published var words: [TranscriptWord] = []
    @Published var drillTranscript: String = ""
    @Published var drillDuration: TimeInterval = 0

    // MARK: - Error State

    @Published var errorMessage: String?

    // MARK: - Services

    private let coachingService = StreamCoachingService()
    private var transcriptManager = TranscriptManager()
    private var audioService = AudioCaptureService()
    private var deepgramService: DeepgramService?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Computed Properties

    var currentQuestion: ClarifyingQuestion? {
        guard currentQuestionIndex < questions.count else { return nil }
        return questions[currentQuestionIndex]
    }

    var currentDrill: StreamDrill? {
        guard case .drilling(let index) = flowState,
              let session = session,
              index < session.drills.count else { return nil }
        return session.drills[index]
    }

    var feedbackDrill: StreamDrill? {
        guard case .drillingFeedback(let index) = flowState,
              let session = session,
              index < session.drills.count else { return nil }
        return session.drills[index]
    }

    var progress: Double {
        guard let session = session else { return 0 }
        switch flowState {
        case .drilling(let index), .drillingFeedback(let index):
            return Double(index) / Double(session.drills.count)
        case .sessionComplete:
            return 1.0
        default:
            return 0
        }
    }

    // MARK: - Pre-connection

    /// Call this when view appears to pre-connect to Deepgram
    func prepareForRecording() {
        Task {
            await preConnect()
        }
    }

    private func preConnect() async {
        print("[StreamPractice] preConnect started")

        // Check microphone permission
        let granted = await audioService.requestPermission()
        guard granted else {
            errorMessage = "Microphone access required"
            print("[StreamPractice] ERROR: Microphone permission denied")
            return
        }
        print("[StreamPractice] Microphone permission granted")

        // Get API key
        guard let apiKey = getDeepgramAPIKey() else {
            errorMessage = "Deepgram API key not configured"
            print("[StreamPractice] ERROR: No Deepgram API key")
            return
        }
        print("[StreamPractice] Deepgram API key found: \(apiKey.prefix(8))...")

        // Initialize and connect Deepgram
        deepgramService = DeepgramService(apiKey: apiKey)
        print("[StreamPractice] DeepgramService created")

        setupSubscriptions()

        // Subscribe to Deepgram responses
        deepgramService?.responsePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] response in
                let transcript = response.channel?.alternatives.first?.transcript ?? "(no transcript)"
                let isFinal = response.isFinal ?? false
                let wordCount = response.channel?.alternatives.first?.words?.count ?? 0
                print("[StreamPractice] Deepgram response: final=\(isFinal), words=\(wordCount), text='\(transcript)'")
                self?.transcriptManager.processResponse(response)
                print("[StreamPractice] After processing: transcriptManager.words.count = \(self?.transcriptManager.words.count ?? -1)")
            }
            .store(in: &cancellables)

        // Subscribe to connection state
        deepgramService?.$isConnected
            .receive(on: DispatchQueue.main)
            .sink { [weak self] connected in
                print("[StreamPractice] Deepgram isConnected changed: \(connected)")
                if connected {
                    self?.isConnecting = false
                    self?.isReadyToRecord = true
                    print("[StreamPractice] Ready to record!")
                } else {
                    self?.isReadyToRecord = false
                }
            }
            .store(in: &cancellables)

        // Subscribe to Deepgram errors
        deepgramService?.$error
            .receive(on: DispatchQueue.main)
            .compactMap { $0 }
            .sink { error in
                print("[StreamPractice] Deepgram ERROR: \(error.localizedDescription)")
            }
            .store(in: &cancellables)

        // Subscribe to audio data - count packets sent
        var audioPacketCount = 0
        audioService.audioDataPublisher
            .sink { [weak self] data in
                audioPacketCount += 1
                if audioPacketCount <= 3 || audioPacketCount % 50 == 0 {
                    print("[StreamPractice] Sending audio packet #\(audioPacketCount), size: \(data.count) bytes")
                }
                self?.deepgramService?.sendAudio(data)
            }
            .store(in: &cancellables)

        // Connect
        isConnecting = true
        print("[StreamPractice] Connecting to Deepgram...")
        deepgramService?.connect()
    }

    // MARK: - Intent Recording

    func startRecordingIntent() {
        print("[StreamPractice] startRecordingIntent called")
        print("[StreamPractice]   isReadyToRecord: \(isReadyToRecord)")
        print("[StreamPractice]   isConnecting: \(isConnecting)")
        print("[StreamPractice]   deepgramService exists: \(deepgramService != nil)")
        print("[StreamPractice]   deepgramService.isConnected: \(deepgramService?.isConnected ?? false)")

        guard isReadyToRecord else {
            errorMessage = "Not connected yet - try again"
            print("[StreamPractice] ERROR: Not ready to record")
            return
        }

        isHoldingToRecord = true
        intentTranscript = ""
        words = []
        transcriptManager.reset()
        print("[StreamPractice] State reset, transcriptManager.words.count = \(transcriptManager.words.count)")

        // Start audio capture immediately (we're pre-connected)
        do {
            try audioService.startCapture()
            print("[StreamPractice] Audio capture started successfully")
            print("[StreamPractice]   audioService.isCapturing: \(audioService.isCapturing)")
        } catch {
            print("[StreamPractice] Audio capture FAILED: \(error)")
            errorMessage = "Failed to start recording"
            isHoldingToRecord = false
        }
    }

    func stopRecordingIntent() {
        print("[StreamPractice] stopRecordingIntent called")
        print("[StreamPractice]   words.count: \(words.count)")
        print("[StreamPractice]   transcriptManager.words.count: \(transcriptManager.words.count)")
        print("[StreamPractice]   audioService.isCapturing: \(audioService.isCapturing)")

        isHoldingToRecord = false
        audioService.stopCapture()
        print("[StreamPractice] Audio capture stopped")

        // Give a moment for final transcripts to arrive
        Task {
            print("[StreamPractice] Waiting 500ms for final transcripts...")
            try? await Task.sleep(nanoseconds: 500_000_000) // 500ms for more buffer

            await MainActor.run {
                // Collect transcript
                print("[StreamPractice] After wait:")
                print("[StreamPractice]   transcriptManager.words.count: \(transcriptManager.words.count)")
                for (i, word) in transcriptManager.words.enumerated() {
                    print("[StreamPractice]   word[\(i)]: '\(word.text)' (final=\(word.isFinal))")
                }

                intentTranscript = transcriptManager.words.map { $0.text }.joined(separator: " ")
                print("[StreamPractice] Final transcript: '\(intentTranscript)'")

                guard !intentTranscript.isEmpty else {
                    print("[StreamPractice] ERROR: Empty transcript, showing error")
                    errorMessage = "Didn't catch that - try again"
                    return
                }

                // Process intent
                print("[StreamPractice] Transcript captured, processing intent...")
                Task {
                    await processIntent()
                }
            }
        }
    }

    private func processIntent() async {
        flowState = .processingIntent

        do {
            let result = try await coachingService.parseIntent(transcript: intentTranscript)
            intent = result.intent
            questions = result.questions
            currentQuestionIndex = 0
            answers = []

            if questions.isEmpty {
                // No questions needed, go straight to session generation
                await generateSession()
            } else {
                flowState = .clarifying
            }
        } catch {
            errorMessage = "Couldn't understand that - try again"
            flowState = .initial
        }
    }

    // MARK: - Clarifying Q&A

    func answerWithOption(_ option: ClarifyingQuestion.QuickOption) {
        guard let question = currentQuestion else { return }

        let answer = ClarifyingAnswer(
            questionId: question.id,
            answer: option.value,
            wasVoiceInput: false
        )
        answers.append(answer)
        advanceQuestion()
    }

    func answerWithVoice(_ transcript: String) {
        guard let question = currentQuestion else { return }

        let answer = ClarifyingAnswer(
            questionId: question.id,
            answer: transcript,
            wasVoiceInput: true
        )
        answers.append(answer)
        advanceQuestion()
    }

    func answerWithText() {
        guard let question = currentQuestion, !currentAnswerText.isEmpty else { return }

        let answer = ClarifyingAnswer(
            questionId: question.id,
            answer: currentAnswerText,
            wasVoiceInput: false
        )
        answers.append(answer)
        currentAnswerText = ""
        advanceQuestion()
    }

    private func advanceQuestion() {
        currentQuestionIndex += 1
        if currentQuestionIndex >= questions.count {
            Task {
                await generateSession()
            }
        }
    }

    // MARK: - Session Generation

    private func generateSession() async {
        flowState = .generatingSession

        guard let intent = intent else {
            errorMessage = "Something went wrong"
            flowState = .initial
            return
        }

        do {
            session = try await coachingService.generateSession(intent: intent, answers: answers)
            flowState = .sessionReady
        } catch {
            errorMessage = "Couldn't create your practice session"
            flowState = .initial
        }
    }

    // MARK: - Drill Execution

    func startSession() {
        guard session != nil else { return }
        flowState = .drilling(index: 0)
    }

    func startDrill() {
        words = []
        drillTranscript = ""
        drillDuration = 0
        transcriptManager.reset()

        // Start audio capture (we're already connected from preConnect)
        do {
            try audioService.startCapture()
            isRecording = true
        } catch {
            errorMessage = "Failed to start recording"
        }
    }

    func stopDrill() {
        isRecording = false
        audioService.stopCapture()

        // Give a moment for final transcripts to arrive
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms

            await MainActor.run {
                drillTranscript = transcriptManager.words.map { $0.text }.joined(separator: " ")
                drillDuration = transcriptManager.sessionDuration

                Task {
                    await evaluateCurrentDrill()
                }
            }
        }
    }

    private func evaluateCurrentDrill() async {
        guard let drill = currentDrill else { return }

        do {
            let feedback = try await coachingService.evaluateDrill(
                drill: drill,
                transcript: drillTranscript,
                duration: drillDuration
            )
            currentDrillFeedback = feedback

            if case .drilling(let index) = flowState {
                flowState = .drillingFeedback(index: index)
            }
        } catch {
            // Show generic feedback on error
            currentDrillFeedback = StreamDrillFeedback(
                drillId: drill.id,
                passed: false,
                energyLevel: nil,
                clarityScore: nil,
                notes: "Couldn't analyze - but keep practicing!",
                suggestion: "Try again and focus on the instruction."
            )
            if case .drilling(let index) = flowState {
                flowState = .drillingFeedback(index: index)
            }
        }
    }

    func nextDrill() {
        guard let session = session else { return }

        if case .drillingFeedback(let index) = flowState {
            let nextIndex = index + 1
            if nextIndex < session.drills.count {
                flowState = .drilling(index: nextIndex)
            } else {
                flowState = .sessionComplete
            }
        }
    }

    func retryDrill() {
        if case .drillingFeedback(let index) = flowState {
            flowState = .drilling(index: index)
        }
    }

    // MARK: - Navigation

    func startOver() {
        flowState = .initial
        intentTranscript = ""
        questions = []
        answers = []
        intent = nil
        session = nil
        currentDrillFeedback = nil
        words = []
        errorMessage = nil
        disconnectAudio()
    }

    // MARK: - Audio Helpers

    private func setupSubscriptions() {
        // Subscribe to transcript manager words
        transcriptManager.$words
            .receive(on: DispatchQueue.main)
            .sink { [weak self] newWords in
                self?.words = newWords
            }
            .store(in: &cancellables)
    }

    private func disconnectAudio() {
        audioService.stopCapture()
        deepgramService?.disconnect()
        deepgramService = nil
    }

    private func getDeepgramAPIKey() -> String? {
        return APIKeys.deepgram
    }
}
