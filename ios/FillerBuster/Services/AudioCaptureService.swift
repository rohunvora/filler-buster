import AVFoundation
import Combine

/// Captures audio from the microphone and streams PCM data
class AudioCaptureService: ObservableObject {
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?

    // Deepgram optimal settings: 16kHz, mono, linear PCM
    private let sampleRate: Double = 16000
    private let bufferSize: AVAudioFrameCount = 1024

    /// Publisher that emits raw PCM audio data chunks
    let audioDataPublisher = PassthroughSubject<Data, Never>()

    @Published var isCapturing = false
    @Published var error: Error?

    /// Request microphone permission
    func requestPermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    /// Start capturing audio from the microphone
    func startCapture() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try audioSession.setActive(true)

        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw AudioCaptureError.engineInitFailed
        }

        inputNode = audioEngine.inputNode
        guard let inputNode = inputNode else {
            throw AudioCaptureError.inputNodeUnavailable
        }

        // Get the native format and create a converter to 16kHz mono
        let inputFormat = inputNode.outputFormat(forBus: 0)
        guard let outputFormat = AVAudioFormat(
            commonFormat: .pcmFormatInt16,
            sampleRate: sampleRate,
            channels: 1,
            interleaved: true
        ) else {
            throw AudioCaptureError.formatCreationFailed
        }

        guard let converter = AVAudioConverter(from: inputFormat, to: outputFormat) else {
            throw AudioCaptureError.converterCreationFailed
        }

        inputNode.installTap(onBus: 0, bufferSize: bufferSize, format: inputFormat) { [weak self] buffer, _ in
            self?.processAudioBuffer(buffer, converter: converter, outputFormat: outputFormat)
        }

        audioEngine.prepare()
        try audioEngine.start()

        isCapturing = true
    }

    /// Stop capturing audio
    func stopCapture() {
        inputNode?.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        inputNode = nil
        isCapturing = false

        try? AVAudioSession.sharedInstance().setActive(false)
    }

    /// Convert audio buffer to 16kHz mono PCM and publish
    private func processAudioBuffer(
        _ buffer: AVAudioPCMBuffer,
        converter: AVAudioConverter,
        outputFormat: AVAudioFormat
    ) {
        // Calculate output buffer size based on sample rate ratio
        let ratio = sampleRate / buffer.format.sampleRate
        let outputFrameCapacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio)

        guard let outputBuffer = AVAudioPCMBuffer(
            pcmFormat: outputFormat,
            frameCapacity: outputFrameCapacity
        ) else { return }

        var error: NSError?
        let status = converter.convert(to: outputBuffer, error: &error) { inNumPackets, outStatus in
            outStatus.pointee = .haveData
            return buffer
        }

        guard status != .error, error == nil else { return }

        // Convert to Data
        if let channelData = outputBuffer.int16ChannelData {
            let data = Data(
                bytes: channelData[0],
                count: Int(outputBuffer.frameLength) * MemoryLayout<Int16>.size
            )
            audioDataPublisher.send(data)
        }
    }
}

enum AudioCaptureError: LocalizedError {
    case engineInitFailed
    case inputNodeUnavailable
    case formatCreationFailed
    case converterCreationFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .engineInitFailed:
            return "Failed to initialize audio engine"
        case .inputNodeUnavailable:
            return "Microphone input not available"
        case .formatCreationFailed:
            return "Failed to create audio format"
        case .converterCreationFailed:
            return "Failed to create audio converter"
        case .permissionDenied:
            return "Microphone permission denied"
        }
    }
}
