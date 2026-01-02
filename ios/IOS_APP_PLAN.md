# Filler Buster iOS App - Implementation Plan

## Summary

Native iOS app that streams speech to Deepgram, shows your words appearing in real-time with filler words highlighted, and buzzes when you slip up.

**Core Experience:** You speak → words appear live (~300ms) → fillers highlight + buzz → you self-correct.

---

## Architecture

**Pattern:** MVVM with Combine
- Optimized for real-time updates (word-by-word streaming)
- Minimal UI redraws via granular state

---

## The UI

### During Recording (Main Experience)

```
┌─────────────────────────────────────┐
│                                     │
│  "I think that we should, um,       │
│   basically just go with the..."    │
│                    ▲                │
│              [live cursor]          │
│                                     │
│         ┌─────────────┐             │
│         │    Stop     │             │
│         └─────────────┘             │
│                                     │
└─────────────────────────────────────┘

- Transcript is the hero, centered
- Words appear one by one with subtle fade-in
- Filler words: orange background + slight shake
- Minimal chrome, maximum focus on your words
```

### After Recording

```
┌─────────────────────────────────────┐
│                                     │
│  "I think that we should, [um],     │
│   [basically] just go with the..."  │
│                                     │
│  ┌─────────────────────────────────┐│
│  │ "um" ×3  "basically" ×2  ...    ││
│  │ Total: 7 fillers                ││
│  └─────────────────────────────────┘│
│                                     │
│         [ Record Again ]            │
│                                     │
└─────────────────────────────────────┘

- Transcript persists with fillers still highlighted
- Summary card slides up from bottom
- Tap "Record Again" to clear and restart
```

---

## Animations (Minimal, Meaningful)

Only animate where it creates feedback or delight:

| Element | Animation | Duration | Purpose |
|---------|-----------|----------|---------|
| Word appearance | opacity 0→1, scale 0.97→1 | 80ms ease-out | Shows speech flowing |
| Filler highlight | bg color fade-in + 2px horizontal shake (2 cycles) | 150ms | "Caught" moment, synced with haptic |
| Recording button | Slow pulse scale 1→1.05 | 1.5s loop | Indicates active recording |
| Results card | Slide up from bottom | 250ms spring | Reveals summary |

**No animations on:**
- Regular UI elements
- Navigation
- Static text

---

## Performance Strategy

Real-time transcript with 100+ words needs care:

1. **Word-level components**: Each word is its own view with stable identity (index-based ID). Only new words trigger view creation.

2. **Animation batching**: If multiple words arrive within 50ms, batch them into a single animated group.

3. **Lazy transcript**: Use `ScrollViewReader` with anchor to bottom. Only render visible words + small buffer.

4. **Simple animations only**: opacity + scale + position. No blur, shadow, or complex effects during recording.

5. **Main thread discipline**: Deepgram parsing happens off main thread. Only final word array hits `@Published`.

```swift
// Word model - stable identity for SwiftUI diffing
struct TranscriptWord: Identifiable {
    let id: Int  // Index in transcript, never changes
    let text: String
    let isFiller: Bool
    var isFinal: Bool  // Interim words may update
}
```

---

## Data Flow

```
Audio Buffer (16kHz PCM)
       ↓
Deepgram WebSocket
       ↓
JSON Response (interim/final)
       ↓
[Background] Parse → Diff against current words
       ↓
[Main] Update word array (append new, mark final)
       ↓
SwiftUI diffing (only new words animate in)
       ↓
If filler: trigger haptic + highlight animation
```

---

## Handling Interim Results

Deepgram sends partial transcripts that refine over time. Strategy:

```swift
class TranscriptManager {
    private var words: [TranscriptWord] = []
    private var finalizedCount: Int = 0  // Words we've locked in

    func processResponse(_ response: DeepgramResponse) {
        let newWords = response.words ?? []

        if response.isFinal {
            // Replace interim words with final, lock them
            replaceInterimWords(with: newWords)
            finalizedCount = words.count
        } else {
            // Append/update interim words (after finalized ones)
            updateInterimWords(newWords)
        }
    }
}
```

**Key insight**: Only trigger haptic on NEW filler words, not refinements of existing ones.

---

## File Structure

```
FillerBuster/
├── App/
│   └── FillerBusterApp.swift
├── Views/
│   ├── OnboardingView.swift
│   ├── RecordingView.swift        # Main view, hosts transcript
│   ├── LiveTranscriptView.swift   # Real-time word display
│   ├── TranscriptWordView.swift   # Single word with animation
│   └── ResultsSummaryView.swift   # Bottom card after recording
├── ViewModels/
│   └── RecordingViewModel.swift
├── Services/
│   ├── AudioCaptureService.swift
│   ├── DeepgramService.swift
│   ├── TranscriptManager.swift    # Word diffing, filler detection
│   └── HapticService.swift
├── Models/
│   ├── TranscriptWord.swift
│   └── DeepgramModels.swift
├── Theme/
│   └── Theme.swift                # Colors + constants only
└── Resources/
    └── Info.plist
```

---

## Design Tokens

Minimal palette, let content breathe:

```swift
enum Theme {
    static let background = Color(hex: "#f7f5f2")
    static let text = Color(hex: "#2d2a26")
    static let textMuted = Color(hex: "#7a756e")
    static let accent = Color(hex: "#e8a87c")
    static let filler = Color(hex: "#e8a87c").opacity(0.3)  // Filler word background
    static let recording = Color(hex: "#e85d5d")
}
```

No shadows, no gradients, no borders. Just color and type.

---

## Implementation Phases

### Phase 1: Live Transcript UI (Static)
- [ ] Create TranscriptWord model
- [ ] Build TranscriptWordView with entrance animation
- [ ] Build LiveTranscriptView with mock data
- [ ] Test with 50+ words, verify smooth scrolling
- [ ] Add filler highlight animation

### Phase 2: Audio + Deepgram
- [ ] AudioCaptureService (16kHz PCM streaming)
- [ ] DeepgramService (WebSocket, Nova-2, filler_words=true)
- [ ] TranscriptManager (interim/final handling, filler detection)
- [ ] Wire up: audio → deepgram → transcript manager

### Phase 3: Integration
- [ ] RecordingViewModel connects all services
- [ ] Haptic triggers on new filler detection
- [ ] Recording button states (idle/recording/processing)
- [ ] Results summary card

### Phase 4: Polish
- [ ] Onboarding (single screen)
- [ ] Error states (no mic, no network)
- [ ] Test on physical device
- [ ] Performance profiling with Instruments

---

## Decisions Made

- **Haptics:** Single uniform buzz, synced with visual highlight
- **Offline:** Internet required (Deepgram only)
- **History:** Stateless
- **Architecture:** MVVM + Combine
- **Onboarding:** Simple intro screen, one tap to dismiss

---

## Decided

- **Filler highlight**: Orange background + 2px horizontal shake (2 cycles)
- **Word timing**: Show interim immediately (~300ms), update in place as they finalize
