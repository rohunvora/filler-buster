import Foundation
import SwiftData

/// Handles saving, fetching, and deleting recording sessions
@MainActor
class SessionPersistenceService: ObservableObject {
    private let modelContext: ModelContext
    private let audioStorage = AudioStorageService.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Save a completed recording session
    func saveSession(
        words: [TranscriptWord],
        fillerCounts: [String: Int],
        wordsPerMinute: Double,
        longPauseCount: Int,
        sessionDuration: Double,
        promptUsed: String?,
        audioData: Data?
    ) throws -> RecordingSession {
        let sessionId = UUID()

        // Save audio file if present
        var audioFileName: String? = nil
        if let audio = audioData, !audio.isEmpty {
            audioFileName = try audioStorage.saveAudioAsWAV(audio, sessionId: sessionId)
        }

        // Generate preview text
        let previewText = generatePreview(words: words, prompt: promptUsed)

        // Encode filler counts
        let fillerData = try JSONEncoder().encode(fillerCounts)

        // Create session
        let session = RecordingSession(
            id: sessionId,
            createdAt: Date(),
            promptUsed: promptUsed,
            previewText: previewText,
            totalFillers: fillerCounts.values.reduce(0, +),
            wordsPerMinute: wordsPerMinute,
            longPauseCount: longPauseCount,
            sessionDuration: sessionDuration,
            totalWords: words.count,
            fillerCountsData: fillerData,
            audioFileName: audioFileName
        )

        // Create persisted words
        let persistedWords = words.enumerated().map { index, word in
            PersistedWord(
                index: index,
                text: word.text,
                isFiller: word.isFiller,
                startTime: word.startTime,
                endTime: word.endTime,
                confidence: word.confidence,
                pauseBefore: word.pauseBefore
            )
        }
        session.words = persistedWords

        modelContext.insert(session)
        try modelContext.save()

        return session
    }

    /// Delete a session and its audio file
    func deleteSession(_ session: RecordingSession) throws {
        if let audioFile = session.audioFileName {
            audioStorage.deleteAudio(fileName: audioFile)
        }
        modelContext.delete(session)
        try modelContext.save()
    }

    /// Fetch all sessions, newest first
    func fetchSessions() throws -> [RecordingSession] {
        let descriptor = FetchDescriptor<RecordingSession>(
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Get session count
    func sessionCount() throws -> Int {
        let descriptor = FetchDescriptor<RecordingSession>()
        return try modelContext.fetchCount(descriptor)
    }

    // MARK: - Private

    private func generatePreview(words: [TranscriptWord], prompt: String?) -> String {
        // Use prompt if available and not empty
        if let prompt = prompt, !prompt.trimmingCharacters(in: .whitespaces).isEmpty {
            // Truncate long prompts
            if prompt.count > 50 {
                return String(prompt.prefix(47)) + "..."
            }
            return prompt
        }

        // Otherwise, first ~8 words
        guard !words.isEmpty else { return "Empty recording" }

        let previewWords = words.prefix(8).map { $0.text }.joined(separator: " ")
        if words.count > 8 {
            return previewWords + "..."
        }
        return previewWords
    }
}
