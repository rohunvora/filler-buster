import Foundation

/// User's initial voice input describing what they want to practice
struct PracticeIntent: Codable {
    let rawTranscript: String
    let detectedTopic: String?
    let detectedContext: String? // "stream", "video", "presentation"
    let detectedTimeframe: String? // "tomorrow", "in an hour", etc.
}

/// A clarifying question from the agent
struct ClarifyingQuestion: Codable, Identifiable {
    let id: String
    let question: String
    let options: [QuickOption]? // Optional tap-to-answer options
    let allowsVoiceResponse: Bool

    struct QuickOption: Codable, Identifiable {
        let id: String
        let label: String
        let value: String
    }
}

/// User's answer to a clarifying question
struct ClarifyingAnswer: Codable {
    let questionId: String
    let answer: String
    let wasVoiceInput: Bool
}

/// The agent's understanding after Q&A
struct PracticeContext: Codable {
    let topic: String // "vibecoding with Claude"
    let format: StreamFormat
    let duration: String? // "1 hour stream", "5 min video"
    let audience: String? // "developers", "general tech"
    let keyMessage: String? // The one thing viewers should remember
    let nervousAbout: String? // What they're worried about
    let timeAvailable: Int? // Minutes available to practice
}

enum StreamFormat: String, Codable {
    case livestream = "livestream"
    case recordedVideo = "recorded_video"
    case shortForm = "short_form" // TikTok, Reels, Shorts
    case podcast = "podcast"
    case presentation = "presentation"
}

/// A practice drill generated for streaming
struct StreamDrill: Codable, Identifiable {
    let id: String
    let type: DrillType
    let title: String
    let instruction: String
    let timeLimit: Int // seconds
    let evaluationCriteria: [String]

    enum DrillType: String, Codable {
        case openingHook = "opening_hook" // First 15 seconds
        case explainToChatMode = "explain_to_chat" // Casual, like talking to chat
        case recoveryDrill = "recovery" // What to say when you mess up
        case keyPoint = "key_point" // Nail the main message
        case wrapUp = "wrap_up" // Ending/CTA
        case handleQuestion = "handle_question" // Responding to chat questions
    }
}

/// Full practice session plan
struct StreamPracticeSession: Codable {
    let context: PracticeContext
    let drills: [StreamDrill]
    let estimatedMinutes: Int
    let coachingNotes: String? // Agent's thoughts on what to focus on
}

/// Feedback specific to streaming/video
struct StreamDrillFeedback: Codable {
    let drillId: String
    let passed: Bool
    let energyLevel: EnergyAssessment?
    let clarityScore: Int? // 1-5
    let notes: String
    let suggestion: String

    enum EnergyAssessment: String, Codable {
        case tooLow = "too_low"
        case good = "good"
        case tooHigh = "too_high" // Manic, overwhelming
    }
}
