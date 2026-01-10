import Foundation
import Combine

/// Streams audio to Deepgram and receives real-time transcriptions
class DeepgramService: NSObject, ObservableObject {
    // Using Nova-2 due to known filler word detection bugs in Nova-3
    // https://github.com/orgs/deepgram/discussions/1224
    private let baseURL = "wss://api.deepgram.com/v1/listen"
    private let apiKey: String

    private var webSocketTask: URLSessionWebSocketTask?
    private var urlSession: URLSession?

    /// Publisher that emits parsed Deepgram responses
    let responsePublisher = PassthroughSubject<DeepgramResponse, Never>()

    @Published var isConnected = false
    @Published var error: Error?

    init(apiKey: String) {
        self.apiKey = apiKey
        super.init()
    }

    /// Connect to Deepgram WebSocket
    func connect() {
        print("[Deepgram] Connecting...")

        // Build URL with query parameters
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "model", value: "nova-2"),
            URLQueryItem(name: "filler_words", value: "true"),
            URLQueryItem(name: "interim_results", value: "true"),
            URLQueryItem(name: "encoding", value: "linear16"),
            URLQueryItem(name: "sample_rate", value: "16000"),
            URLQueryItem(name: "channels", value: "1")
        ]

        guard let url = components.url else {
            print("[Deepgram] ERROR: Invalid URL")
            self.error = DeepgramError.invalidURL
            return
        }

        print("[Deepgram] URL: \(url.absoluteString.prefix(60))...")

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()
        print("[Deepgram] WebSocket task resumed, waiting for connection...")

        receiveMessage()
    }

    /// Send audio data to Deepgram
    private var audioPacketsSent = 0
    func sendAudio(_ data: Data) {
        guard isConnected else {
            // Uncomment for verbose debugging:
            // print("[Deepgram] sendAudio ignored - not connected")
            return
        }

        audioPacketsSent += 1
        if audioPacketsSent <= 3 || audioPacketsSent % 100 == 0 {
            print("[Deepgram] Sending audio packet #\(audioPacketsSent), size: \(data.count) bytes")
        }

        webSocketTask?.send(.data(data)) { [weak self] error in
            if let error = error {
                print("[Deepgram] Send audio ERROR: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self?.error = error
                }
            }
        }
    }

    /// Signal end of audio stream
    func finishStream() {
        // Send empty message to signal end of stream
        webSocketTask?.send(.string("")) { _ in }
    }

    /// Disconnect from Deepgram
    func disconnect() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        urlSession = nil
        isConnected = false
    }

    /// Continuously receive messages from WebSocket
    private var messagesReceived = 0
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.messagesReceived += 1
                if self.messagesReceived <= 5 || self.messagesReceived % 20 == 0 {
                    print("[Deepgram] Received message #\(self.messagesReceived)")
                }
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
                print("[Deepgram] Receive ERROR: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.error = error
                    self.isConnected = false
                }
            }
        }
    }

    /// Parse and publish received message
    private func handleMessage(_ message: URLSessionWebSocketTask.Message) {
        switch message {
        case .string(let text):
            guard let data = text.data(using: .utf8) else { return }
            parseResponse(data)

        case .data(let data):
            parseResponse(data)

        @unknown default:
            break
        }
    }

    /// Parse JSON response from Deepgram
    private func parseResponse(_ data: Data) {
        do {
            let response = try JSONDecoder().decode(DeepgramResponse.self, from: data)
            let transcript = response.channel?.alternatives.first?.transcript ?? ""
            let isFinal = response.isFinal ?? false
            if !transcript.isEmpty || isFinal {
                print("[Deepgram] Parsed response: final=\(isFinal), transcript='\(transcript.prefix(50))'")
            }
            DispatchQueue.main.async {
                self.responsePublisher.send(response)
            }
        } catch {
            // Log the raw message for debugging
            if let jsonStr = String(data: data, encoding: .utf8) {
                if jsonStr.count < 200 {
                    print("[Deepgram] Non-transcript message: \(jsonStr)")
                }
            }
        }
    }
}

extension DeepgramService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
        print("[Deepgram] WebSocket CONNECTED (protocol: \(`protocol` ?? "none"))")
        DispatchQueue.main.async {
            self.isConnected = true
        }
    }

    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didCloseWith closeCode: URLSessionWebSocketTask.CloseCode,
        reason: Data?
    ) {
        let reasonStr = reason.flatMap { String(data: $0, encoding: .utf8) } ?? "none"
        print("[Deepgram] WebSocket CLOSED (code: \(closeCode.rawValue), reason: \(reasonStr))")
        DispatchQueue.main.async {
            self.isConnected = false
        }
    }
}

enum DeepgramError: LocalizedError {
    case invalidURL
    case notConnected

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid Deepgram URL"
        case .notConnected:
            return "Not connected to Deepgram"
        }
    }
}
