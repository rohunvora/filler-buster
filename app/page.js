/**
 * Filler Counter - Main Page Component
 *
 * A speech analysis tool that records audio, transcribes it via OpenAI Whisper,
 * and counts filler words to help users improve their speaking clarity.
 */
'use client'

import { useState, useRef } from 'react'

/**
 * List of common filler words to detect in transcribed speech.
 * These are matched case-insensitively as whole words.
 */
const FILLER_WORDS = [
  'um', 'uh', 'like', 'you know', 'basically', 'literally',
  'actually', 'honestly', 'right', 'so', 'well', 'i mean',
  'kind of', 'sort of', 'i guess', 'i feel like', 'whatever'
]

export default function Home() {
  const [isRecording, setIsRecording] = useState(false)
  const [isProcessing, setIsProcessing] = useState(false)
  const [status, setStatus] = useState('Tap to start recording')
  const [results, setResults] = useState(null)
  const [error, setError] = useState(null)

  const mediaRecorderRef = useRef(null)
  const chunksRef = useRef([])

  /**
   * Start recording audio from the user's microphone.
   * Creates a MediaRecorder and collects audio chunks until stopped.
   */
  const startRecording = async () => {
    try {
      setError(null)
      const stream = await navigator.mediaDevices.getUserMedia({ audio: true })
      const mediaRecorder = new MediaRecorder(stream)
      mediaRecorderRef.current = mediaRecorder
      chunksRef.current = []

      mediaRecorder.ondataavailable = (e) => {
        if (e.data.size > 0) {
          chunksRef.current.push(e.data)
        }
      }

      mediaRecorder.onstop = async () => {
        stream.getTracks().forEach(track => track.stop())
        const audioBlob = new Blob(chunksRef.current, { type: 'audio/webm' })
        await processAudio(audioBlob)
      }

      mediaRecorder.start()
      setIsRecording(true)
      setStatus('Recording... tap to stop')
    } catch (err) {
      setError('Could not access microphone. Please allow microphone access.')
      console.error(err)
    }
  }

  /**
   * Stop recording and trigger audio processing.
   */
  const stopRecording = () => {
    if (mediaRecorderRef.current && isRecording) {
      mediaRecorderRef.current.stop()
      setIsRecording(false)
      setStatus('Processing...')
      setIsProcessing(true)
    }
  }

  /**
   * Send recorded audio to the transcription API and count filler words.
   * @param {Blob} audioBlob - The recorded audio as a webm blob
   */
  const processAudio = async (audioBlob) => {
    try {
      const formData = new FormData()
      formData.append('audio', audioBlob, 'recording.webm')

      const response = await fetch('/api/transcribe', {
        method: 'POST',
        body: formData,
      })

      if (!response.ok) {
        const data = await response.json()
        throw new Error(data.error || 'Transcription failed')
      }

      const data = await response.json()
      const fillerCounts = countFillerWords(data.text)

      setResults({
        transcript: data.text,
        fillers: fillerCounts,
        total: Object.values(fillerCounts).reduce((a, b) => a + b, 0)
      })
      setStatus('Tap to record again')
    } catch (err) {
      setError(err.message)
      setStatus('Tap to try again')
    } finally {
      setIsProcessing(false)
    }
  }

  /**
   * Count occurrences of filler words in transcribed text.
   * @param {string} text - The transcribed text to analyze
   * @returns {Object} Map of filler words to their counts (only non-zero)
   */
  const countFillerWords = (text) => {
    const lowerText = text.toLowerCase()
    const counts = {}

    FILLER_WORDS.forEach(filler => {
      const regex = new RegExp(`\\b${filler}\\b`, 'gi')
      const matches = lowerText.match(regex)
      if (matches && matches.length > 0) {
        counts[filler] = matches.length
      }
    })

    return counts
  }

  const handleClick = () => {
    if (isProcessing) return
    if (isRecording) {
      stopRecording()
    } else {
      startRecording()
    }
  }

  return (
    <div className="container">
      <h1>Filler Counter</h1>
      <p className="subtitle">Speak cleaner. One word at a time.</p>

      {error && <div className="error">{error}</div>}

      <button
        className={`record-btn ${isRecording ? 'recording' : ''}`}
        onClick={handleClick}
        disabled={isProcessing}
      >
        {isProcessing ? '...' : isRecording ? 'Stop' : 'Record'}
      </button>

      <p className="status">{status}</p>

      {results && (
        <div className="results">
          <h2>Your filler words</h2>

          {Object.keys(results.fillers).length === 0 ? (
            <p className="empty-state">No filler words detected. Nice!</p>
          ) : (
            <ul className="filler-list">
              {Object.entries(results.fillers)
                .sort((a, b) => b[1] - a[1])
                .map(([word, count]) => (
                  <li key={word} className="filler-item">
                    <span className="filler-word">"{word}"</span>
                    <span className="filler-count">{count}x</span>
                  </li>
                ))}
            </ul>
          )}

          <div className="total">
            <span className="total-label">Total: </span>
            {results.total} filler{results.total !== 1 ? 's' : ''}
          </div>
        </div>
      )}
    </div>
  )
}
