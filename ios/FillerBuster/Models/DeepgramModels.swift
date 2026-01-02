import Foundation

// Deepgram WebSocket response models
struct DeepgramResponse: Codable {
    let type: String
    let channel: DeepgramChannel?
    let isFinal: Bool?

    enum CodingKeys: String, CodingKey {
        case type
        case channel
        case isFinal = "is_final"
    }
}

struct DeepgramChannel: Codable {
    let alternatives: [DeepgramAlternative]
}

struct DeepgramAlternative: Codable {
    let transcript: String
    let words: [DeepgramWord]?
}

struct DeepgramWord: Codable {
    let word: String
    let start: Double
    let end: Double
    let confidence: Double
}
