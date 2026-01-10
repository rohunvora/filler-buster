# Riff (formerly Filler Buster)

A speech coaching app for streamers and video creators. Get personalized warm-up drills before you go live.

## What It Does

Tell the app what you're about to stream or record, and it generates a custom practice session with 2-4 drills tailored to your content. Practice your opening hook, nail your key points, and build confidence before hitting record.

### Flow

1. **Hold to speak** - Tell it what you're making ("I'm streaming a coding session" or "Recording a product demo")
2. **Answer quick questions** - The AI asks 2-3 clarifying questions (format, audience, what you're nervous about)
3. **Get your warm-up** - Personalized drills based on your answers
4. **Practice each drill** - Record yourself, get instant feedback on energy and clarity
5. **Go crush it** - You're warmed up and ready

### Drill Types

- **Opening Hook** - Practice your first 15 seconds (critical for retention)
- **Explain to Chat** - Casual explanations like you're talking to your audience
- **Recovery** - What to say when you mess up or something breaks
- **Key Point** - Nail the ONE thing viewers should remember
- **Wrap Up** - Practice your ending and call-to-action
- **Handle Question** - Respond to chat questions on the spot

## Requirements

- iOS 17+
- iPhone (haptics work best on device)
- Deepgram API key (for transcription)
- Anthropic API key (for AI coaching)

## Setup

1. Open `ios/FillerBuster.xcodeproj` in Xcode
2. Connect your iPhone
3. Run (Cmd+R)
4. Allow microphone access when prompted

API keys are configured in `FillerBuster/App/APIKeys.swift`.

## Tech Stack

- SwiftUI + Combine
- Claude API (claude-sonnet-4-20250514) for coaching intelligence
- Deepgram WebSocket (Nova-2) for real-time transcription
- AVFoundation for audio capture

## Project Structure

```
ios/FillerBuster/
├── App/                    # Entry point, API keys
├── Views/
│   └── StreamPracticeView  # Main practice flow UI
├── ViewModels/
│   └── StreamPracticeViewModel  # Flow state machine
├── Services/
│   ├── StreamCoachingService    # Claude API integration
│   ├── DeepgramService          # Real-time transcription
│   ├── AudioCaptureService      # Mic input
│   └── TranscriptManager        # Word processing
├── Models/
│   └── StreamPracticeModels     # Drills, sessions, feedback
└── Theme/                  # Colors + styling
```

## Current Stage

**Working:** Full stream practice flow with hold-to-record, AI clarifying questions, personalized drill generation, and feedback.

**Next:** Session history, progress tracking across sessions, pattern recognition for recurring issues.

## License

MIT
