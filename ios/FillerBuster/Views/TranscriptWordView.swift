import SwiftUI

/// Single word in transcript with entrance animation and filler highlight
struct TranscriptWordView: View {
    let word: TranscriptWord
    let onFillerAppear: () -> Void

    @State private var isVisible = false
    @State private var shakeOffset: CGFloat = 0

    var body: some View {
        Text(word.text)
            .font(.system(size: 24, weight: .regular))
            .foregroundColor(Theme.text)
            .padding(.horizontal, word.isFiller ? 4 : 0)
            .padding(.vertical, word.isFiller ? 2 : 0)
            .background(
                word.isFiller
                    ? Theme.filler
                    : Color.clear
            )
            .cornerRadius(4)
            .offset(x: shakeOffset)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.97)
            .onAppear {
                if word.isNew {
                    // Entrance animation
                    withAnimation(.easeOut(duration: 0.08)) {
                        isVisible = true
                    }

                    // Filler shake + haptic
                    if word.isFiller {
                        triggerFillerEffect()
                    }
                } else {
                    isVisible = true
                }
            }
    }

    private func triggerFillerEffect() {
        // Notify for haptic
        onFillerAppear()

        // Shake animation: 2px, 2 cycles
        let shakeDuration = 0.075
        withAnimation(.linear(duration: shakeDuration)) {
            shakeOffset = 2
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
            withAnimation(.linear(duration: shakeDuration)) {
                shakeOffset = -2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 2) {
            withAnimation(.linear(duration: shakeDuration)) {
                shakeOffset = 2
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 3) {
            withAnimation(.linear(duration: shakeDuration)) {
                shakeOffset = 0
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TranscriptWordView(
            word: TranscriptWord(id: 0, text: "hello", isFiller: false, isFinal: true, isNew: true),
            onFillerAppear: {}
        )
        TranscriptWordView(
            word: TranscriptWord(id: 1, text: "um", isFiller: true, isFinal: true, isNew: true),
            onFillerAppear: {}
        )
    }
    .padding()
    .background(Theme.background)
}
