import SwiftUI

/// Main recording screen - transcript-centric UI
struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header (minimal)
                if !viewModel.isRecording && viewModel.words.isEmpty {
                    VStack(spacing: 8) {
                        Text("Filler Buster")
                            .font(.system(size: 28, weight: .medium))
                            .foregroundColor(Theme.text)

                        Text("Tap to start speaking")
                            .font(.system(size: 16))
                            .foregroundColor(Theme.textMuted)
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
                            Circle()
                                .fill(viewModel.isRecording ? Theme.recording : Theme.accent)
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
    }
}

#Preview {
    RecordingView()
}
