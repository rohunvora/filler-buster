import Foundation
import SwiftData

/// Persisted recording session with transcript, stats, and audio reference
@Model
final class RecordingSession {
    // Identity
    var id: UUID
    var createdAt: Date

    // Context
    var promptUsed: String?

    // Preview for list display (first ~8 words or prompt)
    var previewText: String

    // Aggregate stats (denormalized for fast list rendering)
    var totalFillers: Int
    var wordsPerMinute: Double
    var longPauseCount: Int
    var sessionDuration: Double
    var totalWords: Int

    // Filler breakdown stored as JSON (Dictionary not directly supported by SwiftData)
    var fillerCountsData: Data

    // Audio file reference (stored in Documents/recordings/)
    var audioFileName: String?

    // Transcript words
    @Relationship(deleteRule: .cascade)
    var words: [PersistedWord] = []

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        promptUsed: String? = nil,
        previewText: String,
        totalFillers: Int,
        wordsPerMinute: Double,
        longPauseCount: Int,
        sessionDuration: Double,
        totalWords: Int,
        fillerCountsData: Data,
        audioFileName: String? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.promptUsed = promptUsed
        self.previewText = previewText
        self.totalFillers = totalFillers
        self.wordsPerMinute = wordsPerMinute
        self.longPauseCount = longPauseCount
        self.sessionDuration = sessionDuration
        self.totalWords = totalWords
        self.fillerCountsData = fillerCountsData
        self.audioFileName = audioFileName
    }

    // MARK: - Convenience accessors

    var fillerCounts: [String: Int] {
        get {
            (try? JSONDecoder().decode([String: Int].self, from: fillerCountsData)) ?? [:]
        }
        set {
            fillerCountsData = (try? JSONEncoder().encode(newValue)) ?? Data()
        }
    }

    /// Filler rate as percentage (fillers per word)
    var fillerRate: Double {
        guard totalWords > 0 else { return 0 }
        return Double(totalFillers) / Double(totalWords) * 100
    }

    /// Sorted words by index for display
    var sortedWords: [PersistedWord] {
        words.sorted { $0.index < $1.index }
    }

    /// Full transcript text
    var transcriptText: String {
        sortedWords.map { $0.text }.joined(separator: " ")
    }
}
