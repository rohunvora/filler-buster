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

    // Multi-word filler phrases to detect
    private let multiWordFillers = ["you know", "i mean", "kind of", "sort of", "i guess", "i feel like"]

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
        // Replace everything after finalizedCount with new final words
        let newWords = responseWords.enumerated().map { index, dgWord -> TranscriptWord in
            let globalIndex = finalizedCount + index
            let isFiller = checkIfFiller(dgWord.word)
            let isNew = globalIndex >= words.count

            return TranscriptWord(
                id: globalIndex,
                text: dgWord.word,
                isFiller: isFiller,
                isFinal: true,
                isNew: isNew
            )
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

        // Mark all words as not new after a brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.markAllAsNotNew()
        }
    }

    /// Handle interim (partial) words - shown immediately but may change
    private func processInterimResponse(_ responseWords: [DeepgramWord]) {
        // Build new words starting from finalizedCount
        let newWords = responseWords.enumerated().map { index, dgWord -> TranscriptWord in
            let globalIndex = finalizedCount + index
            let isFiller = checkIfFiller(dgWord.word)

            // Check if this word already exists
            let existingWord = words.first { $0.id == globalIndex }
            let isNew = existingWord == nil

            return TranscriptWord(
                id: globalIndex,
                text: dgWord.word,
                isFiller: isFiller,
                isFinal: false,
                isNew: isNew
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

        // Mark as not new after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.markAllAsNotNew()
        }
    }

    /// Check if a word is a filler
    private func checkIfFiller(_ word: String) -> Bool {
        TranscriptWord.isFiller(word)
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
