import SwiftUI

/// Bottom card showing filler counts after recording
struct ResultsSummaryView: View {
    let fillerCounts: [String: Int]
    let onRecordAgain: () -> Void

    var sortedFillers: [(word: String, count: Int)] {
        fillerCounts
            .map { (word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var total: Int {
        fillerCounts.values.reduce(0, +)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Filler pills row
            if !fillerCounts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(sortedFillers.prefix(5), id: \.word) { filler in
                            FillerPill(word: filler.word, count: filler.count)
                        }
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.bottom, 16)
            }

            // Total + Record Again
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                    Text("\(total) filler\(total == 1 ? "" : "s")")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.text)
                }

                Spacer()

                Button(action: onRecordAgain) {
                    Text("Record Again")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Theme.accent)
                        .cornerRadius(24)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Theme.card)
    }
}

struct FillerPill: View {
    let word: String
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Text("\"\(word)\"")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(Theme.text)
            Text("×\(count)")
                .font(.system(size: 13))
                .foregroundColor(Theme.textMuted)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.background)
        .cornerRadius(20)
    }
}

#Preview {
    VStack {
        Spacer()
        ResultsSummaryView(
            fillerCounts: ["um": 5, "like": 3, "basically": 2],
            onRecordAgain: {}
        )
    }
    .background(Theme.background)
}
