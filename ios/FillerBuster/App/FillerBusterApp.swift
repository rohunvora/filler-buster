import SwiftUI
import SwiftData

@main
struct FillerBusterApp: App {
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            // New Riff models
            Riff.self,
            Take.self,
            PersistedWord.self,
            // Legacy (keep for migration)
            RecordingSession.self
        ])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none  // Local-only for now, can enable iCloud later
        )
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            if hasSeenOnboarding {
                StreamPracticeView()
            } else {
                OnboardingView()
            }
        }
        .modelContainer(sharedModelContainer)
    }
}
