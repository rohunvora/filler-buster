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
            self.error = DeepgramError.invalidURL
            return
        }

        var request = URLRequest(url: url)
        request.setValue("Token \(apiKey)", forHTTPHeaderField: "Authorization")

        let config = URLSessionConfiguration.default
        urlSession = URLSession(configuration: config, delegate: self, delegateQueue: nil)
        webSocketTask = urlSession?.webSocketTask(with: request)
        webSocketTask?.resume()

        receiveMessage()
    }

    /// Send audio data to Deepgram
    func sendAudio(_ data: Data) {
        guard isConnected else { return }

        webSocketTask?.send(.data(data)) { [weak self] error in
            if let error = error {
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
    private func receiveMessage() {
        webSocketTask?.receive { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let message):
                self.handleMessage(message)
                // Continue receiving
                self.receiveMessage()

            case .failure(let error):
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
            DispatchQueue.main.async {
                self.responsePublisher.send(response)
            }
        } catch {
            // Silently ignore parse errors (metadata messages, etc.)
        }
    }
}

extension DeepgramService: URLSessionWebSocketDelegate {
    func urlSession(
        _ session: URLSession,
        webSocketTask: URLSessionWebSocketTask,
        didOpenWithProtocol protocol: String?
    ) {
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
