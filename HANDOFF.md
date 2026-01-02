# Filler Word Counter — iOS Handoff Doc

## What This Is

A real-time speech tool that helps users reduce filler words (um, uh, like, you know, etc.) through immediate feedback. Think "Duolingo for speaking confidence."

**Live prototype:** https://progressive-prototype.vercel.app

---

## Validated Core Loop

```
User speaks → Real-time transcription → Filler words detected → Visual feedback
```

This works. The web prototype proves the technical feasibility. What's missing is the *physical* feedback (haptics, audio cues) that makes behavior change stick.

---

## Technical Stack (Current Web Prototype)

| Component | Implementation |
|-----------|---------------|
| Speech-to-text | Deepgram Nova-2 via WebSocket |
| Latency | ~250ms chunks, near real-time |
| Filler detection | Regex on transcript |
| API cost | Deepgram free tier: 200 hours |

### Deepgram API Details

- **WebSocket endpoint:** `wss://api.deepgram.com/v1/listen`
- **Key params:** `model=nova-2&punctuate=true&filler_words=true`
- **Auth:** API key passed as WebSocket subprotocol `['token', key]`
- **Input:** Audio chunks (webm/opus work, check iOS audio formats)
- **Output:** JSON with `channel.alternatives[0].transcript` and `is_final` boolean

### Filler Words Detected

```
um, uh, uhh, umm, ah, ahh, er, err, like, you know,
i mean, basically, literally, actually, honestly,
right, so, well, anyway, ok so
```

This list should be configurable per user—some people overuse "like," others overuse "basically."

---

## Research: What Actually Works

From speech therapy literature:

1. **Self-awareness** — Recording yourself is step one (we do this)
2. **Immediate feedback** — Physical cues create habit loops (iOS haptics!)
3. **Strategic pausing** — Train users to pause instead of fill
4. **Filler rate metric** — Target: <1.3% of total words (study showed drop-off above this)
5. **Same-script practice** — Rehearsing same content reduces fillers

**Key insight:** Fillers happen when mouth outruns brain. Fix = slow down OR pause instead of fill.

---

## iOS Feature Priorities

### P0 — Core (ship first)
- [ ] Tap to record, tap to stop
- [ ] Real-time transcript with highlighted fillers
- [ ] Filler count
- [ ] **Haptic buzz on each filler detected** (this is the differentiator)

### P1 — Metrics
- [ ] Filler rate (% of words that are fillers)
- [ ] Fillers per minute
- [ ] Session history

### P2 — Training Mode
- [ ] Practice prompts (read this sentence, try to beat your score)
- [ ] Before/after comparison
- [ ] "Clean streak" timer (seconds since last filler)

### P3 — Engagement
- [ ] Daily challenge (speak 60 seconds with <3 fillers)
- [ ] Share card for social proof
- [ ] Streak tracking
- [ ] Custom filler word list

---

## iOS-Specific Considerations

### Audio
- Need `AVAudioSession` for mic access
- Check what audio format Deepgram accepts from iOS (likely need Linear PCM or AAC)
- Background audio? Probably not needed for MVP

### Haptics
- Use `UIImpactFeedbackGenerator` for filler detection
- Consider `.heavy` impact for fillers—should feel like a mistake
- Could also add success haptic for completing a clean sentence

### Permissions
- Microphone permission required
- Speech recognition permission (if using on-device as fallback)

### Offline?
- Deepgram requires network
- Could explore on-device Speech framework as fallback, but it filters fillers (that's why we switched away from Web Speech API)

---

## Credentials

```
DEEPGRAM_API_KEY=<your-deepgram-api-key>
```

Get your API key from https://deepgram.com. Free tier: 200 hours.

Deepgram pricing: https://deepgram.com/pricing

---

## Repo Structure

```
/
├── index.html              # Full working prototype (70 lines)
├── api/deepgram-token.js   # Returns API key (for web, iOS won't need this)
├── package.json
└── HANDOFF.md              # This file
```

---

## Open Questions

1. **Monetization:** One-time purchase vs subscription? Freemium with limits?
2. **Onboarding:** How do we explain the value prop quickly?
3. **Customization:** Let users pick which fillers to track?
4. **Apple Watch:** Could be interesting for discreet haptic feedback in meetings

---

## Contact

[Add your contact info here]

---

*Last updated: January 2025*
