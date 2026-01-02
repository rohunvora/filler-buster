# Changelog

## [1.0.0] - 2026-01-02

### Added - iOS App

- **Real-time transcription**: Words appear as you speak with ~300ms latency via Deepgram Nova-2
- **Haptic feedback**: Phone buzzes instantly when you say a filler word
- **Visual highlighting**: Filler words get orange background + horizontal shake animation
- **Live transcript UI**: Transcript-centric design, words flow as you speak
- **37 filler words/phrases detected**:
  - Hesitation sounds: um, uh, er, ah, hmm, eh
  - Common fillers: like, basically, literally, actually, honestly, right, so, well, whatever
  - Emphasis overuse: seriously, really, obviously, clearly, totally, absolutely, definitely
  - Affirmations: yeah, okay
  - Transitions: anyway, anyways
  - Phrases: you know, y'know, i mean, kind of, sort of, kinda, sorta, i guess, i feel like
  - Hyphenated: uh-oh, uh-huh, um-hum, mm-hmm, mm-mm (+ any uh-*/um-*)
- **Simple onboarding**: One-screen intro explaining the app
- **Results summary**: Card slides up after recording with filler counts
- **App icon**: Waveform design matching app aesthetic

### Technical

- SwiftUI + Combine architecture (MVVM)
- Deepgram WebSocket streaming with interim results
- AVAudioEngine for 16kHz PCM audio capture
- Word-level animations with SwiftUI diffing
- Rate-limited haptics to prevent buzz fatigue

---

## [0.1.0] - 2024-12-XX

### Added - Web App

- Initial web app with OpenAI Whisper transcription
- Record/stop functionality
- Filler word counting after transcription
- Warm beige/orange design
