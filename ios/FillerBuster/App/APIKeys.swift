import Foundation

/// API Keys configuration
///
/// To set up your keys:
/// 1. Create `Secrets.swift` in this folder (it's gitignored)
/// 2. Paste this and add your keys:
///
///    enum Secrets {
///        static let deepgram = "your-deepgram-key"
///        static let anthropic = "your-anthropic-key"
///    }
///
/// Get keys at:
/// - Deepgram: https://console.deepgram.com
/// - Anthropic: https://console.anthropic.com
enum APIKeys {
    static let deepgram = Secrets.deepgram
    static let anthropic = Secrets.anthropic
}
