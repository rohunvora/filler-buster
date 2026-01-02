# Filler Buster iOS App - Implementation Plan

## Summary

Build a native iOS app (SwiftUI + MVVM) that streams audio to Deepgram for real-time transcription and triggers haptic feedback the moment a filler word is detected.

---

## Architecture

**Pattern:** MVVM with Combine
- **View:** SwiftUI views (RecordingView, ResultsView)
- **ViewModel:** RecordingViewModel - manages state, audio session, Deepgram connection
- **Model:** FillerResult, TranscriptChunk

**Why MVVM:** Standard iOS pattern, clean separation, works naturally with SwiftUI's reactive model.

---

## Core Components

### 1. Audio Capture (`AudioCaptureService`)
```
- AVAudioEngine for real-time audio capture
- 16kHz sample rate, mono (Deepgram optimal settings)
- Stream PCM audio buffers to Deepgram
- Handle audio session configuration and interruptions
```

### 2. Deepgram WebSocket (`DeepgramService`)
```
- Establish WebSocket connection to wss://api.deepgram.com/v1/listen
- Query params: model=nova-2, filler_words=true, interim_results=true, encoding=linear16, sample_rate=16000
- Send audio chunks as they're captured
- Parse JSON responses for transcript words
- Handle connection lifecycle (connect, disconnect, errors, reconnect)
```

**Note:** Using Nova-2 (not Nova-3) due to known filler word detection bugs in Nova-3.

### 3. Filler Detection (`FillerDetector`)
```
Filler words to detect:
um, uh, like, you know, basically, literally, actually, honestly,
right, so, well, i mean, kind of, sort of, i guess, i feel like, whatever

Detection strategy:
- Track word indices already processed to avoid double-counting from interim results
- When new words arrive, check if they're fillers
- Immediately trigger haptic on new filler detection
- Accumulate counts for final display
```

### 4. Haptic Feedback (`HapticService`)
```
- Use UIImpactFeedbackGenerator with .medium style
- Single uniform buzz for all filler words
- Prepare generator before recording for lowest latency
- Rate-limit to prevent buzzing fatigue (min 200ms between buzzes)
```

### 5. Views

**RecordingView (Main Screen)**
```
- Large circular record button (120x120pt)
- Status text below button
- Tap to start/stop recording
- Pulsing animation while recording
- Match web app colors: #f7f5f2 background, #e8a87c accent, #e85d5d recording
```

**ResultsView (After Recording)**
```
- Card showing filler counts
- List items: filler word + count
- Sorted by count (highest first)
- Total count at bottom
- "Record again" to return
```

**OnboardingView (First Launch Only)**
```
- Single screen explaining the app
- "Filler Buster buzzes your phone when you say filler words"
- Brief explanation of how it helps
- "Get Started" button → RecordingView
- Store flag in UserDefaults to show only once
```

---

## Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│  User taps Record                                               │
│       ↓                                                         │
│  AudioCaptureService starts AVAudioEngine                       │
│       ↓                                                         │
│  DeepgramService opens WebSocket                                │
│       ↓                                                         │
│  Audio buffers → WebSocket (streaming)                          │
│       ↓                                                         │
│  Deepgram returns interim/final transcripts                     │
│       ↓                                                         │
│  FillerDetector checks for new filler words                     │
│       ↓                                                         │
│  If filler found → HapticService.buzz()                         │
│       ↓                                                         │
│  User taps Stop                                                 │
│       ↓                                                         │
│  Close WebSocket, stop audio                                    │
│       ↓                                                         │
│  Display ResultsView with final counts                          │
└─────────────────────────────────────────────────────────────────┘
```

---

## Handling Interim Results (Critical)

Deepgram sends partial transcripts that update as more context is received. To avoid double-counting:

```swift
// Track the last processed word index
var lastProcessedIndex: Int = 0

func processTranscript(_ response: DeepgramResponse) {
    let words = response.channel.alternatives.first?.words ?? []

    // Only process words we haven't seen
    let newWords = words.dropFirst(lastProcessedIndex)

    for word in newWords {
        if fillerWords.contains(word.word.lowercased()) {
            hapticService.buzz()
            counts[word.word, default: 0] += 1
        }
    }

    // Update index only for final responses
    if response.isFinal {
        lastProcessedIndex = words.count
    }
}
```

**Key insight:** Only update `lastProcessedIndex` on `is_final=true` responses. This ensures we don't miss fillers that appear in later refinements of interim results.

---

## File Structure

```
FillerBuster/
├── App/
│   └── FillerBusterApp.swift          # App entry point
├── Views/
│   ├── OnboardingView.swift           # First-launch intro screen
│   ├── RecordingView.swift            # Main recording screen
│   └── ResultsView.swift              # Filler count results
├── ViewModels/
│   └── RecordingViewModel.swift       # Recording state & logic
├── Services/
│   ├── AudioCaptureService.swift      # AVAudioEngine wrapper
│   ├── DeepgramService.swift          # WebSocket streaming
│   ├── FillerDetector.swift           # Filler word matching
│   └── HapticService.swift            # Haptic feedback
├── Models/
│   ├── DeepgramModels.swift           # API response types
│   └── FillerResult.swift             # Recording results
├── Theme/
│   └── Colors.swift                   # Design tokens from web app
└── Resources/
    └── Info.plist                     # Microphone permission, etc.
```

---

## Design Tokens (from Web App)

```swift
extension Color {
    static let appBackground = Color(hex: "#f7f5f2")  // Warm beige
    static let textPrimary = Color(hex: "#2d2a26")
    static let textMuted = Color(hex: "#7a756e")
    static let accent = Color(hex: "#e8a87c")         // Tan/orange
    static let accentDark = Color(hex: "#c98860")
    static let recording = Color(hex: "#e85d5d")      // Red
    static let cardBackground = Color.white
}
```

---

## Implementation Phases

### Phase 1: Project Setup & UI Shell
- [ ] Create Xcode project (SwiftUI, iOS 17+)
- [ ] Set up file structure
- [ ] Implement OnboardingView (first-launch intro)
- [ ] Implement RecordingView with static UI (button, status)
- [ ] Implement ResultsView with mock data
- [ ] Add color theme

### Phase 2: Audio Capture
- [ ] Configure AVAudioSession for recording
- [ ] Set up AVAudioEngine with tap
- [ ] Convert audio to 16kHz PCM format
- [ ] Test audio capture works

### Phase 3: Deepgram Integration
- [ ] Add API key handling (from environment or hardcoded for testing)
- [ ] Implement WebSocket connection
- [ ] Stream audio to Deepgram
- [ ] Parse transcript responses
- [ ] Handle connection errors

### Phase 4: Filler Detection & Haptics
- [ ] Implement FillerDetector with word list
- [ ] Handle interim vs final results correctly
- [ ] Integrate UIImpactFeedbackGenerator
- [ ] Test end-to-end: speak "um" → feel buzz

### Phase 5: Polish
- [ ] Add recording animation (pulsing button)
- [ ] Handle microphone permission flow
- [ ] Error states (no network, permission denied)
- [ ] Test on physical device (haptics don't work in simulator)

---

## Dependencies

- **None required** - using native iOS APIs only
  - AVFoundation for audio
  - URLSession for WebSocket
  - UIKit for haptics
  - SwiftUI for UI

---

## API Key Handling

```swift
// For development, environment variable
let apiKey = ProcessInfo.processInfo.environment["DEEPGRAM_API_KEY"]

// For production, store in Keychain
// Or hardcode during development and remove before distribution
```

---

## Testing Notes

- **Haptics:** Must test on physical device (simulator has no haptic feedback)
- **Microphone:** Simulator can use Mac's mic, but physical device preferred
- **Network:** Deepgram requires internet; test with airplane mode for error handling

---

## Risks & Mitigations

| Risk | Mitigation |
|------|------------|
| Deepgram latency too high for useful haptic feedback | Their docs claim ~300ms; acceptable for this use case. Test early. |
| Nova-2 misses some fillers | The `filler_words=true` param should help. Can also do client-side regex as backup. |
| Battery drain from continuous streaming | Recording sessions are short (a few minutes max). Acceptable. |
| Audio format issues | Use exactly what Deepgram recommends: linear16, 16kHz, mono |

---

## Decisions Made

- **Onboarding:** Simple intro screen on first launch (one screen, explains haptic feedback, "Get Started" button)
- **Settings:** None - keeping it dead simple
- **Haptics:** Single uniform buzz for all filler words
- **Offline:** Internet required (Deepgram only, no offline fallback)
- **History:** Stateless (no persistence across sessions)
- **Architecture:** MVVM with Combine

## Open for Discussion

1. **App icon:** Should match the warm beige/orange aesthetic?
