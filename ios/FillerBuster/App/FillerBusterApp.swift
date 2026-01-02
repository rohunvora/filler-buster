import SwiftUI

@main
struct FillerBusterApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                RecordingView()
            } else {
                OnboardingView()
            }
        }
    }
}
