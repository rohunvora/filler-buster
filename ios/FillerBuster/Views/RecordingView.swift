import SwiftUI
import SwiftData

/// Main recording screen - transcript-centric UI
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showHistory = false
    @State private var showSessionDetail = false
    @State private var showShareSheet = false

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()
            PinstripeBackground()
                .ignoresSafeArea()

            // History button (top-right)
            VStack {
                HStack {
                    Spacer()
                    if !viewModel.isRecording && !viewModel.showResults {
                        Button(action: { showHistory = true }) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 20))
                                .foregroundColor(Theme.textMuted)
                                .padding(12)
                                .contentShape(Rectangle())
                        }
                        .transition(.opacity)
                    }
                }
                .padding(.top, 8)
                .padding(.trailing, 8)
                Spacer()
            }

            VStack(spacing: 0) {
                // Header (minimal) - visible when not recording and no words yet
                if !viewModel.isRecording && !viewModel.isConnecting && viewModel.words.isEmpty && !viewModel.showResults {
                    VStack(spacing: 12) {
                        Text("Filler Buster")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(Theme.text)

                        Text("Tap to start speaking")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textMuted)

                        // Prompt section (only show picker when not recording)
                        if viewModel.showPrompt {
                            // Prompt card
                            VStack(spacing: 12) {
                                Text(viewModel.currentPrompt)
                                    .font(.system(size: 17, weight: .medium))
                                    .foregroundColor(Theme.text)
                                    .multilineTextAlignment(.center)
                                    .fixedSize(horizontal: false, vertical: true)

                                Button(action: { viewModel.shufflePrompt() }) {
                                    Label("shuffle", systemImage: "shuffle")
                                        .font(.system(size: 13))
                                        .foregroundColor(Theme.textMuted)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Theme.pressedBackground)
                                        .cornerRadius(14)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(Color.black.opacity(0.04), lineWidth: 1)
                                        )
                                }
                            }
                            .padding(20)
                            .frame(maxWidth: 280)
                            .background(Theme.card)
                            .cornerRadius(16)
                            .shadow(color: Theme.cardShadow, radius: 6, x: 0, y: 2)
                            .padding(.top, 8)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .scale(scale: 0.95)).combined(with: .offset(y: 8)),
                                removal: .opacity.combined(with: .scale(scale: 0.98))
                            ))
                        } else {
                            // Prompt trigger
                            Button("need a topic?") {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    viewModel.revealPrompt()
                                }
                            }
                            .font(.system(size: 14))
                            .foregroundColor(Theme.textMuted)
                            .padding(.top, 4)
                        }
                    }
                    .padding(.top, 80)
                    .transition(.opacity)
                }

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.recording)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Theme.recording.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 20)
                }

                // Live transcript (hero) - with prompt above if set
                if !viewModel.words.isEmpty || viewModel.isRecording || viewModel.isConnecting {
                    VStack(spacing: 0) {
                        // Show prompt at top during recording (scrolls away naturally)
                        if !viewModel.currentPrompt.isEmpty && (viewModel.isRecording || viewModel.isConnecting) {
                            Text(viewModel.currentPrompt)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                                .padding(.top, 60)
                                .padding(.bottom, 20)
                        }

                        if !viewModel.words.isEmpty {
                            LiveTranscriptView(
                                words: viewModel.words,
                                onFillerDetected: { }  // Haptic handled by ViewModel
                            )
                        } else if viewModel.isConnecting {
                            // Connecting state
                            VStack(spacing: 16) {
                                Spacer()
                                Text("Connecting...")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.textMuted)
                                Spacer()
                            }
                        } else if viewModel.isRecording {
                            // Listening state (connected, waiting for speech)
                            VStack(spacing: 16) {
                                Spacer()
                                Text("Listening...")
                                    .font(.system(size: 18))
                                    .foregroundColor(Theme.textMuted)
                                Spacer()
                            }
                        }
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 0)

                // Record button
                if !viewModel.showResults {
                    Button(action: {
                        viewModel.toggleRecording()
                    }) {
                        ZStack {
                            // Connecting ring animation (behind button)
                            if viewModel.isConnecting {
                                Circle()
                                    .stroke(Theme.recording.opacity(0.3), lineWidth: 2)
                                    .frame(width: 72, height: 72)
                                    .scaleEffect(viewModel.connectingRingScale)
                                    .opacity(2.0 - viewModel.connectingRingScale)  // Fade as it expands
                            }

                            // Base with gradient - immediately red when connecting or recording
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            (viewModel.isRecording || viewModel.isConnecting) ? Theme.recording : Theme.accent,
                                            ((viewModel.isRecording || viewModel.isConnecting) ? Theme.recording : Theme.accent).opacity(0.85)
                                        ],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .scaleEffect(viewModel.isRecording ? viewModel.pulseScale : 1.0)
                                .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)

                            // Highlight overlay
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.buttonHighlight, Color.clear],
                                        startPoint: .top,
                                        endPoint: .center
                                    )
                                )
                                .frame(width: 72, height: 72)
                                .scaleEffect(viewModel.isRecording ? viewModel.pulseScale : 1.0)

                            // Icon: stop square when recording, dot when connecting, circle when idle
                            if viewModel.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            } else if viewModel.isConnecting {
                                // Pulsing dot while connecting
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 20, height: 20)
                                    .opacity(0.8)
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .disabled(viewModel.isConnecting)  // Prevent double-tap while connecting
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                }

                // Results summary (slides up from bottom)
                if viewModel.showResults {
                    ResultsSummaryView(
                        fillerCounts: viewModel.fillerCounts,
                        wordsPerMinute: viewModel.wordsPerMinute,
                        longPauseCount: viewModel.longPauseCount,
                        hasAudio: viewModel.lastSavedSession?.audioFileName != nil,
                        onRecordAgain: {
                            viewModel.recordAgain()
                        },
                        onPlay: {
                            if viewModel.lastSavedSession != nil {
                                showSessionDetail = true
                            }
                        },
                        onShare: {
                            if viewModel.lastSavedSession?.audioFileName != nil {
                                showShareSheet = true
                            }
                        },
                        onHistory: {
                            showHistory = true
                        }
                    )
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity.combined(with: .scale(scale: 0.95))
                    ))
                }
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isRecording)
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.isConnecting)
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: viewModel.showResults)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: viewModel.showPrompt)
        .sheet(isPresented: $showHistory) {
            HistorySheetView()
        }
        .sheet(isPresented: $showSessionDetail) {
            if let session = viewModel.lastSavedSession {
                SessionDetailView(session: session)
            }
        }
        .sheet(isPresented: $showShareSheet) {
            if let fileName = viewModel.lastSavedSession?.audioFileName {
                ShareSheet(items: [AudioStorageService.shared.audioURL(fileName: fileName)])
            }
        }
        .onAppear {
            // Inject persistence service
            let persistence = SessionPersistenceService(modelContext: modelContext)
            viewModel.setPersistenceService(persistence)
        }
    }
}

#Preview {
    RecordingView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
}
