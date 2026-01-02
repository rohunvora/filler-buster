import Foundation

/// A single word in the transcript with stable identity for SwiftUI diffing
struct TranscriptWord: Identifiable, Equatable {
    let id: Int          // Index in transcript, stable identity
    var text: String
    var isFiller: Bool
    var isFinal: Bool    // Interim words may update
    var isNew: Bool      // Just appeared, should animate

    static let fillerWords: Set<String> = [
        "um", "uh", "like", "you know", "basically", "literally",
        "actually", "honestly", "right", "so", "well", "i mean",
        "kind of", "sort of", "i guess", "i feel like", "whatever"
    ]

    /// Check if a word is a filler (handles multi-word fillers via phrase matching in manager)
    static func isFiller(_ word: String) -> Bool {
        fillerWords.contains(word.lowercased())
    }
}
