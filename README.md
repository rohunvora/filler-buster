# Filler Buster

A speech coaching app that helps you speak more clearly by detecting filler words in real-time.

## iOS App (Primary)

The iOS app buzzes your phone the moment you say "um", "like", or other filler words—giving you instant feedback to self-correct.

### Features

- **Real-time transcript**: Words appear as you speak (~300ms latency)
- **Haptic feedback**: Feel a buzz when you say a filler word
- **Visual highlighting**: Filler words highlighted with orange background + shake animation
- **37 filler words detected**: um, uh, like, basically, literally, you know, and more
- **Session history**: All recordings saved with transcript, stats, and audio
- **Audio playback**: Replay sessions with synchronized transcript highlighting
- **Speech prompts**: Random prompts to help you practice speaking naturally

### Requirements

- iOS 17+
- iPhone (haptics don't work in simulator)
- Deepgram API key

### Setup

1. Open `ios/FillerBuster.xcodeproj` in Xcode
2. Connect your iPhone
3. Run (⌘R)
4. Allow microphone access when prompted

The Deepgram API key is already configured in the app.

## Web App (Archived Prototype)

The original web app in `/app` was an early prototype using OpenAI Whisper for batch transcription. It's kept for reference but is no longer actively developed. Use the iOS app for the best experience.

## Detected Filler Words

| Category | Words |
|----------|-------|
| Hesitation | um, uh, er, ah, hmm, eh |
| Common | like, basically, literally, actually, honestly, right, so, well, whatever |
| Emphasis | seriously, really, obviously, clearly, totally, absolutely, definitely |
| Affirmation | yeah, okay |
| Transition | anyway, anyways |
| Phrases | you know, y'know, i mean, kind of, sort of, kinda, sorta, i guess, i feel like |
| Hyphenated | uh-oh, uh-huh, um-hum, mm-hmm, mm-mm |

## Project Structure

```
filler-buster/
├── ios/                        # iOS app (PRIMARY)
│   ├── FillerBuster/
│   │   ├── App/                # Entry point + SwiftData config
│   │   ├── Views/              # SwiftUI views
│   │   │   ├── RecordingView   # Main recording screen
│   │   │   ├── HistorySheetView # Session history list
│   │   │   └── SessionDetailView # Playback with synced transcript
│   │   ├── ViewModels/         # State management
│   │   ├── Services/           # Audio, Deepgram, Haptics, Persistence
│   │   ├── Models/             # TranscriptWord, RecordingSession, PersistedWord
│   │   └── Theme/              # Colors + styling
│   └── FillerBuster.xcodeproj
├── app/                        # Web app (archived prototype)
└── README.md
```

## Tech Stack

**iOS**
- SwiftUI + Combine
- SwiftData (local persistence, iCloud-ready)
- Deepgram WebSocket (Nova-2)
- AVFoundation

## License

MIT
