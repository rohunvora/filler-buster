import UIKit

/// Triggers haptic feedback for filler word detection
class HapticService {
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var lastHapticTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.2  // Prevent buzzing fatigue

    /// Prepare the haptic engine for lowest latency
    func prepare() {
        impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator?.prepare()
    }

    /// Trigger a single haptic buzz
    func buzz() {
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= minimumInterval else {
            return  // Rate limited
        }

        lastHapticTime = now
        impactGenerator?.impactOccurred()
        impactGenerator?.prepare()  // Prepare for next
    }

    /// Stop and release the haptic engine
    func stop() {
        impactGenerator = nil
    }
}
