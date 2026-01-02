import Foundation
import SwiftData

/// Persisted transcript word with timing data for playback sync
@Model
final class PersistedWord {
    var index: Int
    var text: String
    var isFiller: Bool
    var startTime: Double
    var endTime: Double
    var confidence: Double
    var pauseBefore: Double?

    // Inverse relationship
    var session: RecordingSession?

    init(
        index: Int,
        text: String,
        isFiller: Bool,
        startTime: Double,
        endTime: Double,
        confidence: Double,
        pauseBefore: Double?
    ) {
        self.index = index
        self.text = text
        self.isFiller = isFiller
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
        self.pauseBefore = pauseBefore
    }

    /// Convert to in-memory TranscriptWord for UI compatibility
    func toTranscriptWord() -> TranscriptWord {
        TranscriptWord(
            id: index,
            text: text,
            isFiller: isFiller,
            isFinal: true,
            isNew: false,
            startTime: startTime,
            endTime: endTime,
            confidence: confidence,
            pauseBefore: pauseBefore
        )
    }
}
