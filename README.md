# Filler Counter

A web app that helps you speak more clearly by counting your filler words (um, uh, like, you know, etc.).

## How It Works

1. Tap the **Record** button and speak
2. Tap **Stop** when finished
3. See your filler word counts instantly

The app uses OpenAI Whisper for speech-to-text transcription, then analyzes the transcript for common filler words.

## Tech Stack

- **Framework**: Next.js 16
- **Speech-to-Text**: OpenAI Whisper API
- **Deployment**: Vercel

## Getting Started

### Prerequisites

- Node.js 18+
- OpenAI API key

### Installation

```bash
# Clone the repo
git clone https://github.com/rohunvora/filler-buster.git
cd filler-buster

# Install dependencies
npm install

# Set up environment variables
cp .env.example .env
# Add your OPENAI_API_KEY to .env

# Run development server
npm run dev
```

Open [http://localhost:3000](http://localhost:3000) to use the app.

## Environment Variables

| Variable | Description |
|----------|-------------|
| `OPENAI_API_KEY` | Your OpenAI API key for Whisper transcription |

## Detected Filler Words

The app currently detects these filler words:

- um, uh
- like, you know, I mean
- basically, literally, actually, honestly
- right, so, well
- kind of, sort of
- I guess, I feel like, whatever

## Project Structure

```
filler-buster/
├── app/
│   ├── api/transcribe/route.js  # Whisper API endpoint
│   ├── page.js                   # Main UI component
│   ├── layout.js                 # Root layout
│   └── globals.css               # Styles
├── .env.example                  # Environment template
└── package.json
```

## License

MIT
