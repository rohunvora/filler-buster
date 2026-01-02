import SwiftUI
import SwiftData

/// Main recording screen - transcript-centric UI
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()
    @Environment(\.modelContext) private var modelContext
    @State private var showHistory = false

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
                // Header (minimal)
                if !viewModel.isRecording && viewModel.words.isEmpty {
                    VStack(spacing: 12) {
                        Text("Filler Buster")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(Theme.text)

                        Text("Tap to start speaking")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textMuted)

                        // Prompt section
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
                            .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

                // Live transcript (hero)
                if !viewModel.words.isEmpty {
                    LiveTranscriptView(
                        words: viewModel.words,
                        onFillerDetected: { }  // Haptic handled by ViewModel
                    )
                    .transition(.opacity)
                } else if viewModel.isRecording {
                    // Listening state
                    VStack(spacing: 16) {
                        Spacer()
                        if !viewModel.currentPrompt.isEmpty {
                            Text(viewModel.currentPrompt)
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textMuted)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Text("Listening...")
                            .font(.system(size: 18))
                            .foregroundColor(Theme.textMuted)
                        Spacer()
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
                            // Base with gradient
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            viewModel.isRecording ? Theme.recording : Theme.accent,
                                            (viewModel.isRecording ? Theme.recording : Theme.accent).opacity(0.85)
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

                            if viewModel.isRecording {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            } else {
                                Circle()
                                    .fill(Color.white)
                                    .frame(width: 24, height: 24)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                    .transition(.scale.combined(with: .opacity))
                }

                // Results summary (slides up from bottom)
                if viewModel.showResults {
                    ResultsSummaryView(
                        fillerCounts: viewModel.fillerCounts,
                        wordsPerMinute: viewModel.wordsPerMinute,
                        longPauseCount: viewModel.longPauseCount,
                        onRecordAgain: {
                            viewModel.recordAgain()
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.isRecording)
        .animation(.easeInOut(duration: 0.25), value: viewModel.showResults)
        .animation(.easeInOut(duration: 0.25), value: viewModel.words.isEmpty)
        .animation(.easeInOut(duration: 0.2), value: viewModel.showPrompt)
        .animation(.easeInOut(duration: 0.15), value: viewModel.currentPrompt)
        .sheet(isPresented: $showHistory) {
            HistorySheetView()
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
