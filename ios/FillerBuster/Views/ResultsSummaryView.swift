import SwiftUI

/// Bottom card showing filler counts after recording
struct ResultsSummaryView: View {
    let fillerCounts: [String: Int]
    let wordsPerMinute: Double
    let longPauseCount: Int
    let hasAudio: Bool
    let onRecordAgain: () -> Void
    let onPlay: () -> Void
    let onShare: () -> Void
    let onHistory: () -> Void

    var sortedFillers: [(word: String, count: Int)] {
        fillerCounts
            .map { (word: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }

    var total: Int {
        fillerCounts.values.reduce(0, +)
    }

    /// Subtle stats line - only shown if we have meaningful data
    var statsLine: String? {
        var parts: [String] = []

        // Show pace if we have enough words
        if wordsPerMinute >= 10 {
            parts.append("\(Int(wordsPerMinute)) wpm")
        }

        // Show long pauses if any
        if longPauseCount > 0 {
            parts.append("\(longPauseCount) pause\(longPauseCount == 1 ? "" : "s")")
        }

        return parts.isEmpty ? nil : parts.joined(separator: " · ")
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

            // Action buttons row
            HStack(spacing: 0) {
                ActionButton(icon: "play.fill", label: "Play", action: onPlay)
                    .opacity(hasAudio ? 1.0 : 0.4)
                    .disabled(!hasAudio)

                ActionButton(icon: "square.and.arrow.up", label: "Share", action: onShare)
                    .opacity(hasAudio ? 1.0 : 0.4)
                    .disabled(!hasAudio)

                ActionButton(icon: "clock.arrow.circlepath", label: "History", action: onHistory)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)

            // Total + Record Again
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Total")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textMuted)
                    Text("\(total) filler\(total == 1 ? "" : "s")")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.text)

                    // Subtle timing stats
                    if let stats = statsLine {
                        Text(stats)
                            .font(.system(size: 12))
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                Button(action: onRecordAgain) {
                    Text("Record Again")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(
                            LinearGradient(
                                colors: [Theme.accent, Theme.accent.opacity(0.85)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .cornerRadius(24)
                        .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
                }
            }
            .padding(.horizontal, 20)
        }
        .padding(.vertical, 20)
        .background(Theme.card)
        .shadow(color: Theme.cardShadow, radius: 8, x: 0, y: -2)
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
        .background(Theme.pressedBackground)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.black.opacity(0.04), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 1, x: 0, y: 1)
    }
}

/// Compact action button with icon and label
struct ActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(Theme.accent)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textMuted)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    VStack {
        Spacer()
        ResultsSummaryView(
            fillerCounts: ["um": 5, "like": 3, "basically": 2],
            wordsPerMinute: 142,
            longPauseCount: 3,
            hasAudio: true,
            onRecordAgain: {},
            onPlay: {},
            onShare: {},
            onHistory: {}
        )
    }
    .background(Theme.background)
}
