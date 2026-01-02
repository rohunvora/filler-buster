import SwiftUI

/// Simple onboarding - one screen, one tap to dismiss
struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.15))
                        .frame(width: 120, height: 120)

                    Image(systemName: "waveform")
                        .font(.system(size: 48))
                        .foregroundColor(Theme.accent)
                }

                // Text
                VStack(spacing: 12) {
                    Text("Filler Buster")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(Theme.text)

                    Text("Your phone buzzes when you say\n\"um\", \"like\", or other filler words.")
                        .font(.system(size: 17))
                        .foregroundColor(Theme.textMuted)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }

                Spacer()

                // Get Started
                Button(action: {
                    hasSeenOnboarding = true
                }) {
                    Text("Get Started")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.accent)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 48)
            }
        }
    }
}

#Preview {
    OnboardingView()
}
