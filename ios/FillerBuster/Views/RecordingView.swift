import SwiftUI

struct RecordingView: View {
    @StateObject private var viewModel = RecordingViewModel()

    var body: some View {
        ZStack {
            Color.appBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                VStack(spacing: 8) {
                    Text("Filler Counter")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(.textPrimary)

                    Text("Speak cleaner. One word at a time.")
                        .font(.system(size: 16))
                        .foregroundColor(.textMuted)
                }
                .padding(.top, 60)
                .padding(.bottom, 48)

                // Error message
                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.recording)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.errorBackground)
                        .cornerRadius(8)
                        .padding(.bottom, 16)
                }

                Spacer()

                // Record button
                Button(action: {
                    viewModel.toggleRecording()
                }) {
                    ZStack {
                        Circle()
                            .fill(viewModel.isRecording ? Color.recording : Color.accent)
                            .frame(width: 120, height: 120)
                            .shadow(color: .black.opacity(0.06), radius: 10, y: 2)
                            .scaleEffect(viewModel.isRecording ? viewModel.pulseScale : 1.0)

                        if viewModel.isProcessing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(1.2)
                        } else {
                            Text(viewModel.isRecording ? "Stop" : "Record")
                                .font(.system(size: 17, weight: .medium))
                                .foregroundColor(.white)
                        }
                    }
                }
                .disabled(viewModel.isProcessing)
                .animation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true), value: viewModel.isRecording)

                // Status text
                Text(viewModel.statusText)
                    .font(.system(size: 15))
                    .foregroundColor(.textMuted)
                    .padding(.top, 24)

                Spacer()

                // Results (if available)
                if let results = viewModel.results {
                    ResultsView(results: results) {
                        viewModel.clearResults()
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: viewModel.results != nil)
    }
}

#Preview {
    RecordingView()
}
