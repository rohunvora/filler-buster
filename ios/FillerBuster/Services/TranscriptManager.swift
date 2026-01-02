import Foundation
import Combine

/// Manages transcript state, handles interim/final results, detects fillers
class TranscriptManager: ObservableObject {
    @Published private(set) var words: [TranscriptWord] = []
    @Published private(set) var fillerCounts: [String: Int] = [:]

    /// Publisher that fires when a NEW filler word is detected
    let fillerDetectedPublisher = PassthroughSubject<String, Never>()

    private var finalizedCount: Int = 0
    private var detectedFillerIndices: Set<Int> = []
    private var lastFinalizedEndTime: Double = 0  // End time of last finalized word
    
    // Track when we last processed a final result for throttling
    private(set) var hasRecentFinalUpdate = false
    
    // Single timer for marking words as not new (avoid spam)
    private var markNotNewTimer: Timer?

    // Multi-word filler phrases to detect
    private let multiWordFillers = ["you know", "i mean", "kind of", "sort of", "i guess", "i feel like"]

    // MARK: - Session Timing Metrics

    /// Total time spent speaking (sum of word durations)
    var totalSpeakingTime: Double {
        words.filter { $0.isFinal }.reduce(0) { $0 + $1.duration }
    }

    /// Total pause time between words
    var totalPauseTime: Double {
        words.compactMap { $0.pauseBefore }.reduce(0, +)
    }

    /// Average pause duration between words
    var averagePause: Double {
        let pauses = words.compactMap { $0.pauseBefore }
        guard !pauses.isEmpty else { return 0 }
        return pauses.reduce(0, +) / Double(pauses.count)
    }

    /// Number of long pauses (> 0.5 seconds)
    var longPauseCount: Int {
        words.filter { $0.hasLongPauseBefore }.count
    }

    /// Speaking pace in words per minute
    var wordsPerMinute: Double {
        let totalTime = totalSpeakingTime + totalPauseTime
        guard totalTime > 0 else { return 0 }
        let finalWords = words.filter { $0.isFinal }.count
        return Double(finalWords) / totalTime * 60
    }

    /// Average word confidence from Deepgram
    var averageConfidence: Double {
        let finalWords = words.filter { $0.isFinal }
        guard !finalWords.isEmpty else { return 0 }
        return finalWords.reduce(0) { $0 + $1.confidence } / Double(finalWords.count)
    }

    /// Session duration from first word start to last word end
    var sessionDuration: Double {
        guard let first = words.first, let last = words.last else { return 0 }
        return last.endTime - first.startTime
    }

    /// Process a Deepgram response, updating words array
    func processResponse(_ response: DeepgramResponse) {
        guard let channel = response.channel,
              let alternative = channel.alternatives.first,
              let responseWords = alternative.words else {
            return
        }

        let isFinal = response.isFinal ?? false

        if isFinal {
            processFinalResponse(responseWords)
        } else {
            processInterimResponse(responseWords)
        }
    }

    /// Handle final (confirmed) words
    private func processFinalResponse(_ responseWords: [DeepgramWord]) {
        hasRecentFinalUpdate = true
        
        // Replace everything after finalizedCount with new final words
        var previousEndTime = lastFinalizedEndTime

        let newWords = responseWords.enumerated().map { index, dgWord -> TranscriptWord in
            let globalIndex = finalizedCount + index
            let isFiller = checkIfFiller(dgWord.word)
            let isNew = globalIndex >= words.count

            // Calculate pause before this word
            let pauseBefore: Double?
            if globalIndex == 0 {
                pauseBefore = nil  // First word has no pause before
            } else {
                pauseBefore = max(0, dgWord.start - previousEndTime)
            }

            previousEndTime = dgWord.end

            return TranscriptWord(
                id: globalIndex,
                text: dgWord.word,
                isFiller: isFiller,
                isFinal: true,
                isNew: isNew,
                startTime: dgWord.start,
                endTime: dgWord.end,
                confidence: dgWord.confidence,
                pauseBefore: pauseBefore
            )
        }

        // Update last finalized end time
        if let lastWord = responseWords.last {
            lastFinalizedEndTime = lastWord.end
        }

        // Check for new fillers before updating
        for word in newWords where word.isFiller && word.isNew {
            if !detectedFillerIndices.contains(word.id) {
                detectedFillerIndices.insert(word.id)
                fillerCounts[word.text.lowercased(), default: 0] += 1
                fillerDetectedPublisher.send(word.text)
            }
        }

        // Update words array
        if finalizedCount < words.count {
            words.removeSubrange(finalizedCount...)
        }
        words.append(contentsOf: newWords)

        // Update finalized count
        finalizedCount = words.count

        // Schedule a single delayed update to mark words as not new
        scheduleMarkAsNotNew()
        
        // Reset final update flag after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.hasRecentFinalUpdate = false
        }
    }

    /// Handle interim (partial) words - shown immediately but may change
    private func processInterimResponse(_ responseWords: [DeepgramWord]) {
        // Build new words starting from finalizedCount
        var previousEndTime = lastFinalizedEndTime

        let newWords = responseWords.enumerated().map { index, dgWord -> TranscriptWord in
            let globalIndex = finalizedCount + index
            let isFiller = checkIfFiller(dgWord.word)

            // Check if this word already exists
            let existingWord = words.first { $0.id == globalIndex }
            let isNew = existingWord == nil

            // Calculate pause before this word
            let pauseBefore: Double?
            if globalIndex == 0 {
                pauseBefore = nil
            } else {
                pauseBefore = max(0, dgWord.start - previousEndTime)
            }

            previousEndTime = dgWord.end

            return TranscriptWord(
                id: globalIndex,
                text: dgWord.word,
                isFiller: isFiller,
                isFinal: false,
                isNew: isNew,
                startTime: dgWord.start,
                endTime: dgWord.end,
                confidence: dgWord.confidence,
                pauseBefore: pauseBefore
            )
        }

        // Check for new fillers
        for word in newWords where word.isFiller && word.isNew {
            if !detectedFillerIndices.contains(word.id) {
                detectedFillerIndices.insert(word.id)
                fillerCounts[word.text.lowercased(), default: 0] += 1
                fillerDetectedPublisher.send(word.text)
            }
        }

        // Replace interim portion
        if finalizedCount < words.count {
            words.removeSubrange(finalizedCount...)
        }
        words.append(contentsOf: newWords)

        // Schedule a single delayed update to mark words as not new
        scheduleMarkAsNotNew()
    }

    /// Check if a word is a filler
    private func checkIfFiller(_ word: String) -> Bool {
        TranscriptWord.isFiller(word)
    }
    
    /// Schedule marking words as not new (coalesces multiple calls)
    private func scheduleMarkAsNotNew() {
        // Invalidate any existing timer
        markNotNewTimer?.invalidate()
        
        // Schedule a new timer
        markNotNewTimer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: false) { [weak self] _ in
            self?.markAllAsNotNew()
        }
    }

    /// Mark all words as not new (after animation completes)
    private func markAllAsNotNew() {
        for i in words.indices {
            if words[i].isNew {
                words[i].isNew = false
            }
        }
    }

    /// Reset transcript state
    func reset() {
        words = []
        fillerCounts = [:]
        finalizedCount = 0
        detectedFillerIndices = []
        lastFinalizedEndTime = 0
        hasRecentFinalUpdate = false
        markNotNewTimer?.invalidate()
        markNotNewTimer = nil
    }

    /// Get total filler count
    var totalFillers: Int {
        fillerCounts.values.reduce(0, +)
    }

    /// Get sorted filler list (highest count first)
    var sortedFillers: [(word: String, count: Int)] {
        fillerCounts
            .map { (word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
