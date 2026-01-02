# Filler Buster iOS App

## The Goal

Build an iOS version of the Filler Buster web app with one key addition: **haptic feedback the moment you say a filler word**.

The web app records speech, transcribes it, and counts filler words. The iOS app should do the same but buzz your phone instantly when you say "um" or "uh" - giving you immediate tactile feedback to help you self-correct.

---

## Reference: The Web App

See `/app/page.js` in this repo. It's simple:

1. Record audio via browser
2. Send to OpenAI Whisper for transcription (batch, not streaming)
3. Regex-match for filler words in transcript
4. Display counts

The filler words we track:
```
um, uh, like, you know, i mean, basically, actually, literally,
right, so, well, kind of, sort of, i guess, i feel like, whatever, honestly
```

---

## The Key Challenge: Real-Time Detection

For haptic feedback to work, we need to detect filler words **as they're spoken**, not after the recording ends. This means streaming transcription, not batch.

### Research: Transcription Options

| Option | Latency | Filler Word Support | Notes |
|--------|---------|---------------------|-------|
| **Deepgram** | ~300ms | `filler_words=true` parameter explicitly includes "um", "uh" | WebSocket streaming. Nova-3 is newest but there's a [GitHub issue](https://github.com/orgs/deepgram/discussions/1224) about filler detection bugs - Nova-2 may be more reliable |
| **Apple Speech Framework** | ~500ms | Unknown - designed for clean transcription like Siri, may strip fillers | On-device, free, no API key. New SpeechAnalyzer API in iOS 26 |
| **WhisperKit** | ~450ms | Should include fillers (Whisper does) | On-device Whisper. Open source. Needs model download |
| **AssemblyAI** | ~300ms | Has filler word support | Similar to Deepgram |

**We have a Deepgram API key** - likely the path of least resistance.

Deepgram docs for filler words: https://developers.deepgram.com/docs/filler-words

### The Deepgram Filler Word Feature

From their docs:
- Set `filler_words=true` in the request
- Transcribes "um" and "uh" (and other fillers) explicitly
- Always uses consistent spelling (never "uhhhh")
- Works with streaming (WebSocket) API

---

## Design Direction

The web app has a warm, minimal aesthetic:
- Background: `#f7f5f2` (warm beige)
- Accent: `#e8a87c` (tan/orange)
- Recording state: `#e85d5d` (red)
- Large circular record button (120x120)
- Card-based results with filler counts

Match it or improve on it - your call.

---

## Open Questions / Decisions for You

1. **Haptic pattern**: Single buzz per filler? Different intensity for "um" vs "like"? Escalating pattern if too many?

2. **Interim results handling**: Deepgram sends partial transcripts that update. How do you avoid double-counting fillers as the transcript refines?

3. **Architecture**: MVVM? TCA? Your preferred pattern

4. **Offline fallback**: Worth supporting Apple Speech as a fallback when no network? Or just require internet?

5. **State between sessions**: Persist filler history? Track improvement over time? Or keep it stateless like the web app?

---

## What's in the Repo

```
/app
  page.js           # Main React component - the recording + detection logic
  globals.css       # Design tokens (colors, typography)
  api/transcribe/route.js  # Server-side Whisper API call

/.env               # Has OPENAI_API_KEY, you'll add DEEPGRAM_API_KEY
```

---

## API Key

Deepgram API key will be provided. Needs to be stored securely (Keychain, env var, whatever you prefer).

---

## Sources from Research

- [Deepgram Filler Words Docs](https://developers.deepgram.com/docs/filler-words)
- [Deepgram Speech-to-Text Benchmarks](https://deepgram.com/learn/speech-to-text-benchmarks) - Nova-3 claims 54% better WER than competitors
- [Deepgram Latency Guide](https://deepgram.com/learn/understanding-and-reducing-latency-in-speech-to-text-apis)
- [Known Issue: Nova-3 Filler Word Bug](https://github.com/orgs/deepgram/discussions/1224)
- [Apple SpeechAnalyzer (iOS 26)](https://developer.apple.com/videos/play/wwdc2025/277/)
- [WhisperKit Paper](https://arxiv.org/html/2507.10860v1) - on-device Whisper, 0.45s latency, 2.2% WER
