import SwiftUI

/// Real-time transcript display with word-by-word animations
struct LiveTranscriptView: View {
    let words: [TranscriptWord]
    let onFillerDetected: () -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                WrappingHStack(words: words, onFillerDetected: onFillerDetected)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 40)
                    .id("transcript")
            }
            .onChange(of: words.count) { _, _ in
                // Auto-scroll to bottom when new words arrive
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }
}

/// Custom wrapping layout for words (FlowLayout style)
struct WrappingHStack: View {
    let words: [TranscriptWord]
    let onFillerDetected: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            FlowLayout(spacing: 6) {
                ForEach(words) { word in
                    TranscriptWordView(word: word, onFillerAppear: onFillerDetected)
                }
                // Invisible anchor for scrolling
                Color.clear
                    .frame(width: 1, height: 1)
                    .id("bottom")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Flow layout that wraps children to next line
struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> ArrangeResult {
        let maxWidth = proposal.width ?? .infinity

        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if currentX + size.width > maxWidth && currentX > 0 {
                // Move to next line
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            currentX += size.width + spacing
            lineHeight = max(lineHeight, size.height)
        }

        let totalHeight = currentY + lineHeight
        return ArrangeResult(
            size: CGSize(width: maxWidth, height: totalHeight),
            positions: positions,
            sizes: sizes
        )
    }

    struct ArrangeResult {
        let size: CGSize
        let positions: [CGPoint]
        let sizes: [CGSize]
    }
}

#Preview {
    let mockWords = [
        TranscriptWord(id: 0, text: "I", isFiller: false, isFinal: true, isNew: false),
        TranscriptWord(id: 1, text: "think", isFiller: false, isFinal: true, isNew: false),
        TranscriptWord(id: 2, text: "that", isFiller: false, isFinal: true, isNew: false),
        TranscriptWord(id: 3, text: "um", isFiller: true, isFinal: true, isNew: false),
        TranscriptWord(id: 4, text: "we", isFiller: false, isFinal: true, isNew: false),
        TranscriptWord(id: 5, text: "should", isFiller: false, isFinal: true, isNew: false),
        TranscriptWord(id: 6, text: "basically", isFiller: true, isFinal: true, isNew: false),
        TranscriptWord(id: 7, text: "just", isFiller: false, isFinal: true, isNew: false),
        TranscriptWord(id: 8, text: "go", isFiller: false, isFinal: true, isNew: true),
    ]

    return LiveTranscriptView(words: mockWords, onFillerDetected: {})
        .background(Theme.background)
}
