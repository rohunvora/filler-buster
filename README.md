# Filler Buster

A speech coaching app that helps you speak more clearly by detecting filler words in real-time.

**Web app**: Batch transcription with filler word counts
**iOS app**: Real-time transcription with haptic feedback when you say a filler word

## iOS App

The iOS app buzzes your phone the moment you say "um", "like", or other filler words—giving you instant feedback to self-correct.

### Features

- **Real-time transcript**: Words appear as you speak (~300ms latency)
- **Haptic feedback**: Feel a buzz when you say a filler word
- **Visual highlighting**: Filler words highlighted with orange background + shake animation
- **37 filler words detected**: um, uh, like, basically, literally, you know, and more

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

## Web App

The original web app uses OpenAI Whisper for batch transcription after recording.

### Setup

```bash
npm install
cp .env.example .env
# Add your OPENAI_API_KEY to .env
npm run dev
```

Open [http://localhost:3000](http://localhost:3000)

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
├── app/                    # Next.js web app
│   ├── api/transcribe/     # Whisper API endpoint
│   ├── page.js             # Main UI
│   └── globals.css         # Styles
├── ios/                    # iOS app
│   ├── FillerBuster/
│   │   ├── App/            # Entry point
│   │   ├── Views/          # SwiftUI views
│   │   ├── ViewModels/     # State management
│   │   ├── Services/       # Audio, Deepgram, Haptics
│   │   ├── Models/         # Data models
│   │   └── Theme/          # Colors
│   └── FillerBuster.xcodeproj
└── README.md
```

## Tech Stack

**Web**
- Next.js 16
- OpenAI Whisper API
- Vercel

**iOS**
- SwiftUI + Combine
- Deepgram WebSocket (Nova-2)
- AVFoundation

## License

MIT
