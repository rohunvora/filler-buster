/**
 * Transcription API Route
 *
 * Accepts audio file uploads and transcribes them using OpenAI Whisper API.
 * Returns the transcribed text for filler word analysis.
 */
import { NextResponse } from 'next/server'

/**
 * POST /api/transcribe
 * Transcribe uploaded audio file to text using OpenAI Whisper.
 *
 * @param {Request} request - FormData with 'audio' file field
 * @returns {Response} JSON with { text: string } or { error: string }
 */
export async function POST(request) {
  try {
    const formData = await request.formData()
    const audioFile = formData.get('audio')

    if (!audioFile) {
      return NextResponse.json(
        { error: 'No audio file provided' },
        { status: 400 }
      )
    }

    const apiKey = process.env.OPENAI_API_KEY
    if (!apiKey) {
      return NextResponse.json(
        { error: 'OpenAI API key not configured' },
        { status: 500 }
      )
    }

    // Convert uploaded file to blob format that Whisper API accepts
    const audioBuffer = await audioFile.arrayBuffer()
    const audioBlob = new Blob([audioBuffer], { type: 'audio/webm' })

    const whisperFormData = new FormData()
    whisperFormData.append('file', audioBlob, 'recording.webm')
    whisperFormData.append('model', 'whisper-1')
    whisperFormData.append('language', 'en')

    const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${apiKey}`,
      },
      body: whisperFormData,
    })

    if (!response.ok) {
      const error = await response.json()
      console.error('Whisper API error:', error)
      return NextResponse.json(
        { error: 'Transcription failed' },
        { status: 500 }
      )
    }

    const data = await response.json()

    return NextResponse.json({ text: data.text })
  } catch (err) {
    console.error('Transcription error:', err)
    return NextResponse.json(
      { error: 'Internal server error' },
      { status: 500 }
    )
  }
}
