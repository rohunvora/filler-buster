import Foundation

/// A single word in the transcript with stable identity for SwiftUI diffing
struct TranscriptWord: Identifiable, Equatable {
    let id: Int          // Index in transcript, stable identity
    var text: String
    var isFiller: Bool
    var isFinal: Bool    // Interim words may update
    var isNew: Bool      // Just appeared, should animate

    // Timing data from Deepgram
    var startTime: Double    // When word began (seconds from start)
    var endTime: Double      // When word ended (seconds from start)
    var confidence: Double   // Recognition confidence (0-1)
    var pauseBefore: Double? // Gap from previous word's end (nil for first word)

    /// Duration of this word in seconds
    var duration: Double {
        endTime - startTime
    }

    /// Whether pause before this word is considered "long" (> 0.5s)
    var hasLongPauseBefore: Bool {
        guard let pause = pauseBefore else { return false }
        return pause > 0.5
    }

    static let fillerWords: Set<String> = [
        // Hesitation sounds
        "um", "uh", "er", "ah", "hmm", "eh",
        // Common fillers
        "like", "basically", "literally", "actually", "honestly",
        "right", "so", "well", "whatever",
        // Emphasis overuse
        "seriously", "really", "obviously", "clearly",
        "totally", "absolutely", "definitely",
        // Affirmation fillers
        "yeah", "okay",
        // Transitions
        "anyway", "anyways",
        // Phrases
        "you know", "y'know", "i mean", "kind of", "sort of",
        "kinda", "sorta", "i guess", "i feel like",
        // Hyphenated variations Deepgram produces
        "uh-oh", "uh-huh", "um-hum", "mm-hmm", "mm-mm"
    ]

    // Core fillers that should match even in hyphenated words
    private static let coreFillers: Set<String> = ["um", "uh"]

    /// Check if a word is a filler
    /// - Exact match: "um", "like", "basically"
    /// - Hyphenated: "uh-oh" contains "uh"
    static func isFiller(_ word: String) -> Bool {
        let lower = word.lowercased()

        // Exact match
        if fillerWords.contains(lower) {
            return true
        }

        // Check if word starts with core filler + hyphen (e.g., "uh-oh", "um-hm")
        for filler in coreFillers {
            if lower.hasPrefix("\(filler)-") {
                return true
            }
        }

        return false
    }
}
