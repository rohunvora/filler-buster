import Foundation

/// Manages audio file storage in Documents directory
class AudioStorageService {
    static let shared = AudioStorageService()

    private let fileManager = FileManager.default

    /// Directory for audio files
    private var audioDirectory: URL {
        let docs = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = docs.appendingPathComponent("recordings", isDirectory: true)

        // Create if needed
        if !fileManager.fileExists(atPath: audioDir.path) {
            try? fileManager.createDirectory(at: audioDir, withIntermediateDirectories: true)
        }

        return audioDir
    }

    /// Save PCM audio data as WAV file, returns filename
    func saveAudioAsWAV(_ pcmData: Data, sessionId: UUID) throws -> String {
        let wavData = addWAVHeader(to: pcmData, sampleRate: 16000, channels: 1, bitsPerSample: 16)
        let fileName = "session_\(sessionId.uuidString).wav"
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        try wavData.write(to: fileURL)
        return fileName
    }

    /// Load audio data by filename
    func loadAudio(fileName: String) throws -> Data {
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        return try Data(contentsOf: fileURL)
    }

    /// Delete audio file
    func deleteAudio(fileName: String) {
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }

    /// Get file URL for AVAudioPlayer
    func audioURL(fileName: String) -> URL {
        audioDirectory.appendingPathComponent(fileName)
    }

    /// Check if audio file exists
    func audioExists(fileName: String) -> Bool {
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        return fileManager.fileExists(atPath: fileURL.path)
    }

    // MARK: - WAV Header

    /// Add WAV header to raw PCM data
    private func addWAVHeader(to pcmData: Data, sampleRate: Int, channels: Int, bitsPerSample: Int) -> Data {
        var header = Data()
        let byteRate = sampleRate * channels * bitsPerSample / 8
        let blockAlign = channels * bitsPerSample / 8
        let dataSize = pcmData.count
        let fileSize = 36 + dataSize

        // RIFF header
        header.append("RIFF".data(using: .ascii)!)
        header.append(UInt32(fileSize).littleEndianData)
        header.append("WAVE".data(using: .ascii)!)

        // fmt chunk
        header.append("fmt ".data(using: .ascii)!)
        header.append(UInt32(16).littleEndianData)  // Chunk size
        header.append(UInt16(1).littleEndianData)   // PCM format
        header.append(UInt16(channels).littleEndianData)
        header.append(UInt32(sampleRate).littleEndianData)
        header.append(UInt32(byteRate).littleEndianData)
        header.append(UInt16(blockAlign).littleEndianData)
        header.append(UInt16(bitsPerSample).littleEndianData)

        // data chunk
        header.append("data".data(using: .ascii)!)
        header.append(UInt32(dataSize).littleEndianData)

        return header + pcmData
    }
}

// MARK: - Extensions for WAV header encoding

private extension FixedWidthInteger {
    var littleEndianData: Data {
        var value = self.littleEndian
        return Data(bytes: &value, count: MemoryLayout<Self>.size)
    }
}
