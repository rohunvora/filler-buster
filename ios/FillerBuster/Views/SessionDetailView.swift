import SwiftUI
import SwiftData

/// Full detail view for a recording session with audio playback
struct SessionDetailView: View {
    let session: RecordingSession
    @Environment(\.dismiss) private var dismiss

    @StateObject private var playbackManager = PlaybackManager()
    @State private var showShareSheet = false
    @State private var copiedToast = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // Transcript with highlighting
                    transcriptSection

                    // Stats bar
                    statsSummaryBar

                    // Playback controls (if audio exists)
                    if session.audioFileName != nil && playbackManager.isLoaded {
                        playbackControls
                    }
                }
            }
            .navigationTitle(formatDate(session.createdAt))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button(action: copyTranscript) {
                            Label("Copy Transcript", systemImage: "doc.on.doc")
                        }
                        if session.audioFileName != nil {
                            Button(action: { showShareSheet = true }) {
                                Label("Share Audio", systemImage: "square.and.arrow.up")
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .onAppear {
                if let fileName = session.audioFileName {
                    playbackManager.loadAudio(fileName: fileName)
                }
            }
            .onDisappear {
                playbackManager.stop()
            }
            .sheet(isPresented: $showShareSheet) {
                if let fileName = session.audioFileName {
                    ShareSheet(items: [AudioStorageService.shared.audioURL(fileName: fileName)])
                }
            }
            .overlay {
                if copiedToast {
                    copiedOverlay
                }
            }
        }
    }

    // MARK: - Transcript Section

    private var transcriptSection: some View {
        ScrollViewReader { proxy in
            ScrollView {
                PlaybackTranscriptView(
                    words: session.sortedWords,
                    currentTime: playbackManager.currentTime
                )
                .padding(.horizontal, 24)
                .padding(.vertical, 24)
            }
            .onChange(of: currentWordIndex) { _, newIndex in
                if let index = newIndex {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(index, anchor: .center)
                    }
                }
            }
        }
    }

    /// Current word index based on playback time
    private var currentWordIndex: Int? {
        let words = session.sortedWords
        guard !words.isEmpty else { return nil }

        for word in words.reversed() {
            if playbackManager.currentTime >= word.startTime {
                return word.index
            }
        }
        return nil
    }

    // MARK: - Stats Bar

    private var statsSummaryBar: some View {
        HStack(spacing: 0) {
            statItem(value: "\(session.totalFillers)", label: "Fillers", highlight: session.totalFillers > 0)
            Divider().frame(height: 32)
            statItem(value: "\(Int(session.wordsPerMinute))", label: "WPM", highlight: false)
            Divider().frame(height: 32)
            statItem(value: "\(session.longPauseCount)", label: "Pauses", highlight: false)
            Divider().frame(height: 32)
            statItem(value: formatDuration(session.sessionDuration), label: "Duration", highlight: false)
        }
        .padding(.vertical, 12)
        .background(Theme.card)
        .shadow(color: Theme.cardShadow, radius: 4, x: 0, y: -2)
    }

    private func statItem(value: String, label: String, highlight: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .foregroundColor(highlight ? Theme.accent : Theme.text)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(Theme.textMuted)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Playback Controls

    private var playbackControls: some View {
        VStack(spacing: 12) {
            // Progress slider
            Slider(
                value: Binding(
                    get: { playbackManager.currentTime },
                    set: { playbackManager.seek(to: $0) }
                ),
                in: 0...max(playbackManager.duration, 0.1)
            )
            .tint(Theme.accent)

            // Time labels
            HStack {
                Text(formatTime(playbackManager.currentTime))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textMuted)

                Spacer()

                Text(formatTime(playbackManager.duration))
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(Theme.textMuted)
            }

            // Transport controls
            HStack(spacing: 40) {
                Button(action: { playbackManager.skipBackward() }) {
                    Image(systemName: "gobackward.5")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.text)
                }

                Button(action: { playbackManager.toggle() }) {
                    Image(systemName: playbackManager.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 56))
                        .foregroundColor(Theme.accent)
                }

                Button(action: { playbackManager.skipForward() }) {
                    Image(systemName: "goforward.5")
                        .font(.system(size: 24))
                        .foregroundColor(Theme.text)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Theme.card)
    }

    // MARK: - Actions

    private func copyTranscript() {
        UIPasteboard.general.string = session.transcriptText
        withAnimation {
            copiedToast = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation {
                copiedToast = false
            }
        }
    }

    private var copiedOverlay: some View {
        Text("Copied!")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Theme.text.opacity(0.9))
            .cornerRadius(8)
            .transition(.opacity.combined(with: .scale(scale: 0.9)))
    }

    // MARK: - Formatters

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return "\(mins):\(String(format: "%02d", secs))"
    }

    private func formatTime(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

// MARK: - Playback Transcript View

/// Transcript that highlights words based on playback time
struct PlaybackTranscriptView: View {
    let words: [PersistedWord]
    let currentTime: Double

    var body: some View {
        FlowLayout(spacing: 6) {
            ForEach(words, id: \.index) { word in
                PlaybackWordView(
                    word: word,
                    isActive: isWordActive(word),
                    isPast: isWordPast(word)
                )
                .id(word.index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func isWordActive(_ word: PersistedWord) -> Bool {
        currentTime >= word.startTime && currentTime < word.endTime
    }

    private func isWordPast(_ word: PersistedWord) -> Bool {
        currentTime >= word.endTime
    }
}

/// Individual word with playback-aware styling
struct PlaybackWordView: View {
    let word: PersistedWord
    let isActive: Bool
    let isPast: Bool

    var body: some View {
        Text(word.text)
            .font(.system(size: 20, weight: isActive ? .semibold : .regular))
            .foregroundColor(textColor)
            .padding(.horizontal, word.isFiller ? 6 : 0)
            .padding(.vertical, word.isFiller ? 3 : 0)
            .background(backgroundColor)
            .cornerRadius(4)
            .scaleEffect(isActive ? 1.05 : 1.0)
            .animation(.easeOut(duration: 0.12), value: isActive)
    }

    private var textColor: Color {
        if isActive {
            return Theme.text
        } else if isPast {
            return Theme.text
        } else {
            return Theme.textMuted.opacity(0.6)
        }
    }

    private var backgroundColor: Color {
        if word.isFiller {
            return isActive ? Theme.accent.opacity(0.5) : Theme.filler
        } else if isActive {
            return Theme.accent.opacity(0.15)
        }
        return .clear
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

#Preview {
    // Mock session for preview
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: RecordingSession.self, configurations: config)

    let session = RecordingSession(
        previewText: "I think that um we should...",
        totalFillers: 3,
        wordsPerMinute: 120,
        longPauseCount: 2,
        sessionDuration: 45,
        totalWords: 25,
        fillerCountsData: try! JSONEncoder().encode(["um": 2, "like": 1])
    )

    SessionDetailView(session: session)
        .modelContainer(container)
}
