import Foundation

struct FillerResult: Equatable {
    let fillers: [String: Int]
    let transcript: String

    var total: Int {
        fillers.values.reduce(0, +)
    }

    var sortedFillers: [(word: String, count: Int)] {
        fillers
            .map { (word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}
