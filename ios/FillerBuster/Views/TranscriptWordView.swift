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

        // Shake animation: 2px, 2 cycles using spring animation
        // More efficient than multiple asyncAfter calls with withAnimation wrappers
        let shakeDuration = 0.075
        shakeOffset = 2
        
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration) {
            shakeOffset = -2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 2) {
            shakeOffset = 2
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + shakeDuration * 3) {
            shakeOffset = 0
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        TranscriptWordView(
            word: TranscriptWord(id: 0, text: "hello", isFiller: false, isFinal: true, isNew: true, startTime: 0, endTime: 0.5, confidence: 0.99, pauseBefore: nil),
            onFillerAppear: {}
        )
        TranscriptWordView(
            word: TranscriptWord(id: 1, text: "um", isFiller: true, isFinal: true, isNew: true, startTime: 0.5, endTime: 0.8, confidence: 0.95, pauseBefore: 0.1),
            onFillerAppear: {}
        )
    }
    .padding()
    .background(Theme.background)
}
