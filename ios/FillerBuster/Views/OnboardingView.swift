import SwiftUI

struct OnboardingView: View {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Icon/illustration
                ZStack {
                    Circle()
                        .fill(Color.accent.opacity(0.2))
                        .frame(width: 140, height: 140)

                    Image(systemName: "waveform")
                        .font(.system(size: 60))
                        .foregroundColor(.accent)
                }

                // Title and description
                VStack(spacing: 16) {
                    Text("Filler Buster")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundColor(.textPrimary)

                    Text("Speak cleaner. One word at a time.")
                        .font(.system(size: 18))
                        .foregroundColor(.textMuted)
                }

                // Explanation
                VStack(spacing: 12) {
                    FeatureRow(
                        icon: "mic.fill",
                        text: "Record yourself speaking"
                    )
                    FeatureRow(
                        icon: "iphone.radiowaves.left.and.right",
                        text: "Feel a buzz when you say filler words"
                    )
                    FeatureRow(
                        icon: "chart.bar.fill",
                        text: "See your filler word counts"
                    )
                }
                .padding(.horizontal, 32)

                Spacer()

                // Get Started button
                Button(action: {
                    hasSeenOnboarding = true
                }) {
                    Text("Get Started")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 18)
                        .background(Color.accent)
                        .cornerRadius(16)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.accent)
                .frame(width: 32)

            Text(text)
                .font(.system(size: 16))
                .foregroundColor(.textPrimary)

            Spacer()
        }
    }
}

#Preview {
    OnboardingView()
}
