import SwiftUI

struct ResultsView: View {
    let results: FillerResult
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Your filler words")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundColor(.textMuted)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.textMuted.opacity(0.5))
                }
            }
            .padding(.bottom, 20)

            // Filler list or empty state
            if results.fillers.isEmpty {
                Text("No filler words detected. Nice!")
                    .font(.system(size: 15))
                    .foregroundColor(.textMuted)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(results.sortedFillers, id: \.word) { filler in
                        FillerRow(word: filler.word, count: filler.count)

                        if filler.word != results.sortedFillers.last?.word {
                            Divider()
                                .background(Color.cardBorder)
                        }
                    }
                }
            }

            // Total
            HStack {
                Text("Total:")
                    .foregroundColor(.textMuted)
                Spacer()
                Text("\(results.total) filler\(results.total == 1 ? "" : "s")")
                    .fontWeight(.medium)
            }
            .font(.system(size: 20))
            .foregroundColor(.textPrimary)
            .padding(.top, 20)
            .padding(.top, 12)
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color.cardBorder)
                    .frame(height: 2)
                    .padding(.top, 12)
            }
        }
        .padding(24)
        .background(Color.cardBackground)
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.06), radius: 20, y: 2)
        .padding(.horizontal, 16)
        .padding(.bottom, 32)
    }
}

struct FillerRow: View {
    let word: String
    let count: Int

    var body: some View {
        HStack {
            Text("\"\(word)\"")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.textPrimary)

            Spacer()

            Text("\(count)x")
                .font(.system(size: 14))
                .foregroundColor(.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(Color.appBackground)
                .cornerRadius(20)
        }
        .padding(.vertical, 12)
    }
}

#Preview {
    ZStack {
        Color.appBackground.ignoresSafeArea()

        ResultsView(
            results: FillerResult(
                fillers: ["um": 5, "like": 3, "you know": 2],
                transcript: "Sample transcript"
            ),
            onDismiss: {}
        )
    }
}
