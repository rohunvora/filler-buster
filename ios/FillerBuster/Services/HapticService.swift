import UIKit

/// Triggers haptic feedback for filler word detection and UI interactions
class HapticService {
    private var impactGenerator: UIImpactFeedbackGenerator?
    private var lightGenerator: UIImpactFeedbackGenerator?
    private var mediumGenerator: UIImpactFeedbackGenerator?
    private var lastHapticTime: Date = .distantPast
    private let minimumInterval: TimeInterval = 0.2  // Prevent buzzing fatigue

    /// Prepare the haptic engine for lowest latency
    func prepare() {
        impactGenerator = UIImpactFeedbackGenerator(style: .medium)
        impactGenerator?.prepare()
        lightGenerator = UIImpactFeedbackGenerator(style: .light)
        lightGenerator?.prepare()
        mediumGenerator = UIImpactFeedbackGenerator(style: .medium)
        mediumGenerator?.prepare()
    }

    /// Trigger a single haptic buzz (for filler detection)
    func buzz() {
        let now = Date()
        guard now.timeIntervalSince(lastHapticTime) >= minimumInterval else {
            return  // Rate limited
        }

        lastHapticTime = now
        impactGenerator?.impactOccurred()
        impactGenerator?.prepare()  // Prepare for next
    }

    /// Light tap for button press feedback
    func lightTap() {
        lightGenerator?.impactOccurred()
        lightGenerator?.prepare()
    }

    /// Medium tap for confirmation feedback (recording started/stopped)
    func mediumTap() {
        mediumGenerator?.impactOccurred()
        mediumGenerator?.prepare()
    }

    /// Stop and release the haptic engine
    func stop() {
        impactGenerator = nil
        lightGenerator = nil
        mediumGenerator = nil
    }
}
