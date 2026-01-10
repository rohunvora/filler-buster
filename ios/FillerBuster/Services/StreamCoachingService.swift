import Foundation

enum StreamCoachingError: Error {
    case noApiKey
    case apiError
    case parseError
}

/// Agent-style coaching service for streaming/video practice
/// Handles the conversation flow: voice input → clarifying questions → personalized drills
actor StreamCoachingService {

    private let apiKey: String
    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    init(apiKey: String? = nil) {
        if let key = apiKey, !key.isEmpty {
            self.apiKey = key
        } else {
            // Use centralized API keys
            self.apiKey = APIKeys.anthropic
        }
    }

    // MARK: - Step 1: Parse initial voice input

    /// Parse the user's voice input to understand what they want to practice
    func parseIntent(transcript: String) async throws -> (intent: PracticeIntent, questions: [ClarifyingQuestion]) {
        let systemPrompt = """
        You are a speaking coach helping someone prepare for streaming/video content.

        The user just told you what they want to practice for. Your job:
        1. Extract what you understand about their intent
        2. Generate 2-3 clarifying questions to personalize their practice

        For streaming/video, you care about:
        - What's the topic/content?
        - What format? (livestream, recorded video, short-form, podcast)
        - How long is the content?
        - Who's the audience?
        - What's the ONE thing viewers should walk away with?
        - What part are they most nervous about?
        - How much time do they have to practice right now?

        Don't ask all of these - pick the 2-3 most important based on what they said.

        Respond in JSON:
        {
            "intent": {
                "rawTranscript": "exactly what they said",
                "detectedTopic": "the topic if you can tell",
                "detectedContext": "stream" | "video" | "presentation" | null,
                "detectedTimeframe": "when it's happening if mentioned"
            },
            "questions": [
                {
                    "id": "unique_id",
                    "question": "The question to ask",
                    "options": [
                        {"id": "opt1", "label": "Display text", "value": "value"}
                    ] or null,
                    "allowsVoiceResponse": true
                }
            ]
        }

        Keep questions conversational and brief. Include quick-tap options when there are obvious choices.
        """

        let userMessage = "Here's what the user said: \"\(transcript)\""

        let response = try await callClaude(system: systemPrompt, user: userMessage)

        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let intentDict = json["intent"] as? [String: Any],
              let questionsArray = json["questions"] as? [[String: Any]] else {
            throw StreamCoachingError.parseError
        }

        let intent = PracticeIntent(
            rawTranscript: intentDict["rawTranscript"] as? String ?? transcript,
            detectedTopic: intentDict["detectedTopic"] as? String,
            detectedContext: intentDict["detectedContext"] as? String,
            detectedTimeframe: intentDict["detectedTimeframe"] as? String
        )

        let questions = questionsArray.compactMap { q -> ClarifyingQuestion? in
            guard let id = q["id"] as? String,
                  let question = q["question"] as? String else { return nil }

            var options: [ClarifyingQuestion.QuickOption]? = nil
            if let opts = q["options"] as? [[String: Any]] {
                options = opts.compactMap { o in
                    guard let optId = o["id"] as? String,
                          let label = o["label"] as? String,
                          let value = o["value"] as? String else { return nil }
                    return ClarifyingQuestion.QuickOption(id: optId, label: label, value: value)
                }
            }

            return ClarifyingQuestion(
                id: id,
                question: question,
                options: options,
                allowsVoiceResponse: q["allowsVoiceResponse"] as? Bool ?? true
            )
        }

        return (intent, questions)
    }

    // MARK: - Step 2: Generate practice session from context

    /// After clarifying questions, generate a personalized practice session
    func generateSession(intent: PracticeIntent, answers: [ClarifyingAnswer]) async throws -> StreamPracticeSession {
        let systemPrompt = """
        You are a speaking coach creating a personalized warm-up for someone about to stream or record video.

        Based on what they told you, create a focused practice session with 2-4 drills.

        Drill types to choose from:
        - opening_hook: Practice the first 15 seconds. Critical for streams/videos.
        - explain_to_chat: Practice explaining something casually, like you're talking to chat.
        - recovery: Practice what to say when you mess up, lose your place, or something breaks.
        - key_point: Practice nailing the ONE thing viewers should remember.
        - wrap_up: Practice your ending/CTA.
        - handle_question: Practice responding to a chat question on the spot.

        Pick drills based on:
        1. What they're nervous about (address this directly)
        2. What's most important for their format (streams need recovery drills, videos need hooks)
        3. How much time they have

        Respond in JSON:
        {
            "context": {
                "topic": "what they're talking about",
                "format": "livestream" | "recorded_video" | "short_form" | "podcast" | "presentation",
                "duration": "how long their content is",
                "audience": "who's watching",
                "keyMessage": "the one thing viewers should remember",
                "nervousAbout": "what they're worried about",
                "timeAvailable": minutes as integer or null
            },
            "drills": [
                {
                    "id": "unique_id",
                    "type": "drill_type from above",
                    "title": "Short title",
                    "instruction": "What to do - be specific to THEIR topic",
                    "timeLimit": seconds (15-60),
                    "evaluationCriteria": ["what makes this good", "what to avoid"]
                }
            ],
            "estimatedMinutes": total practice time,
            "coachingNotes": "Brief note on what to focus on based on their nervousness"
        }

        Make instructions SPECIFIC to their topic. Not "explain your process" but "explain why you use Claude for vibecoding".
        """

        var userMessage = "Initial intent: \(intent.rawTranscript)\n\n"
        userMessage += "Clarifying answers:\n"
        for answer in answers {
            userMessage += "- \(answer.answer)\n"
        }

        let response = try await callClaude(system: systemPrompt, user: userMessage)

        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StreamCoachingError.parseError
        }

        return try parseSession(from: json)
    }

    // MARK: - Step 3: Evaluate a drill attempt

    /// Evaluate the user's attempt at a drill
    func evaluateDrill(drill: StreamDrill, transcript: String, duration: TimeInterval) async throws -> StreamDrillFeedback {
        let systemPrompt = """
        You are evaluating a practice attempt for streaming/video.

        Drill type: \(drill.type.rawValue)
        Title: \(drill.title)
        Instruction: \(drill.instruction)
        Time limit: \(drill.timeLimit) seconds
        Evaluation criteria: \(drill.evaluationCriteria.joined(separator: ", "))

        Actual duration: \(Int(duration)) seconds

        For streaming/video, pay attention to:
        - Energy: Is it engaging for viewers? Too flat? Too manic?
        - Clarity: Would someone just tuning in understand?
        - Pacing: Appropriate for the format?
        - Did they hit the key points?

        Respond in JSON:
        {
            "drillId": "\(drill.id)",
            "passed": true/false,
            "energyLevel": "too_low" | "good" | "too_high" | null,
            "clarityScore": 1-5 or null,
            "notes": "What worked or didn't - be specific",
            "suggestion": "One concrete thing to try differently"
        }

        Be encouraging but honest. This is practice - they want to improve.
        """

        let userMessage = "Here's what they said:\n\"\(transcript)\""

        let response = try await callClaude(system: systemPrompt, user: userMessage)

        guard let data = response.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw StreamCoachingError.parseError
        }

        var energyLevel: StreamDrillFeedback.EnergyAssessment? = nil
        if let energy = json["energyLevel"] as? String {
            energyLevel = StreamDrillFeedback.EnergyAssessment(rawValue: energy)
        }

        return StreamDrillFeedback(
            drillId: json["drillId"] as? String ?? drill.id,
            passed: json["passed"] as? Bool ?? false,
            energyLevel: energyLevel,
            clarityScore: json["clarityScore"] as? Int,
            notes: json["notes"] as? String ?? "",
            suggestion: json["suggestion"] as? String ?? ""
        )
    }

    // MARK: - Helpers

    private func parseSession(from json: [String: Any]) throws -> StreamPracticeSession {
        guard let contextDict = json["context"] as? [String: Any],
              let drillsArray = json["drills"] as? [[String: Any]] else {
            throw StreamCoachingError.parseError
        }

        let formatString = contextDict["format"] as? String ?? "livestream"
        let format = StreamFormat(rawValue: formatString) ?? .livestream

        let context = PracticeContext(
            topic: contextDict["topic"] as? String ?? "Unknown",
            format: format,
            duration: contextDict["duration"] as? String,
            audience: contextDict["audience"] as? String,
            keyMessage: contextDict["keyMessage"] as? String,
            nervousAbout: contextDict["nervousAbout"] as? String,
            timeAvailable: contextDict["timeAvailable"] as? Int
        )

        let drills = drillsArray.compactMap { d -> StreamDrill? in
            guard let id = d["id"] as? String,
                  let typeString = d["type"] as? String,
                  let type = StreamDrill.DrillType(rawValue: typeString),
                  let title = d["title"] as? String,
                  let instruction = d["instruction"] as? String,
                  let timeLimit = d["timeLimit"] as? Int else { return nil }

            let criteria = d["evaluationCriteria"] as? [String] ?? []

            return StreamDrill(
                id: id,
                type: type,
                title: title,
                instruction: instruction,
                timeLimit: timeLimit,
                evaluationCriteria: criteria
            )
        }

        return StreamPracticeSession(
            context: context,
            drills: drills,
            estimatedMinutes: json["estimatedMinutes"] as? Int ?? 5,
            coachingNotes: json["coachingNotes"] as? String
        )
    }

    private func callClaude(system: String, user: String) async throws -> String {
        guard !apiKey.isEmpty else {
            throw StreamCoachingError.noApiKey
        }

        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2048,
            "system": system,
            "messages": [
                ["role": "user", "content": user]
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw StreamCoachingError.apiError
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let firstContent = content.first,
              let text = firstContent["text"] as? String else {
            throw StreamCoachingError.parseError
        }

        // Extract JSON from response (might be wrapped in markdown code blocks)
        return extractJSON(from: text)
    }

    private func extractJSON(from text: String) -> String {
        // Try to extract JSON from markdown code blocks
        if let jsonStart = text.range(of: "```json"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let jsonStart = text.range(of: "```"),
           let jsonEnd = text.range(of: "```", range: jsonStart.upperBound..<text.endIndex) {
            return String(text[jsonStart.upperBound..<jsonEnd.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
