import SwiftUI

/// Main view for the stream/video practice flow
struct StreamPracticeView: View {
    @StateObject private var viewModel = StreamPracticeViewModel()

    var body: some View {
        ZStack {
            Theme.background
                .ignoresSafeArea()

            switch viewModel.flowState {
            case .initial:
                initialView

            case .processingIntent:
                loadingView(message: "Understanding what you need...")

            case .clarifying:
                clarifyingView

            case .generatingSession:
                loadingView(message: "Creating your warm-up...")

            case .sessionReady:
                sessionReadyView

            case .drilling:
                drillingView

            case .drillingFeedback:
                drillFeedbackView

            case .sessionComplete:
                sessionCompleteView
            }
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.8), value: viewModel.flowState)
        .alert("Oops", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Initial View (Hold to Record)

    private var initialView: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("What are you making today?")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)
                .multilineTextAlignment(.center)

            Text("Hold to tell me what you're practicing for")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)

            // Hold to record button
            if viewModel.isConnecting || !viewModel.isReadyToRecord {
                VStack(spacing: 12) {
                    ProgressView()
                        .scaleEffect(1.2)
                        .tint(Theme.accent)
                    Text(viewModel.isConnecting ? "Connecting..." : "Preparing...")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textMuted)
                }
                .frame(height: 160)
            } else {
                HoldToRecordButton(
                    isHolding: $viewModel.isHoldingToRecord,
                    transcript: viewModel.words.map { $0.text }.joined(separator: " "),
                    onStart: { viewModel.startRecordingIntent() },
                    onEnd: { viewModel.stopRecordingIntent() }
                )
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .onAppear {
            viewModel.prepareForRecording()
        }
    }

    // MARK: - Loading View

    private func loadingView(message: String) -> some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(Theme.accent)

            Text(message)
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
        }
    }

    // MARK: - Clarifying Questions View

    private var clarifyingView: some View {
        VStack(spacing: 24) {
            // Progress indicator
            HStack(spacing: 4) {
                ForEach(0..<viewModel.questions.count, id: \.self) { index in
                    Circle()
                        .fill(index <= viewModel.currentQuestionIndex ? Theme.accent : Theme.buttonSecondary)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 20)

            Spacer()

            if let question = viewModel.currentQuestion {
                VStack(spacing: 20) {
                    Text(question.question)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(Theme.text)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Quick options if available
                    if let options = question.options, !options.isEmpty {
                        VStack(spacing: 12) {
                            ForEach(options) { option in
                                Button(action: {
                                    viewModel.answerWithOption(option)
                                }) {
                                    Text(option.label)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(Theme.text)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                        .background(Theme.buttonSecondary)
                                        .cornerRadius(12)
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                    }

                    // Text input
                    HStack {
                        TextField("Type your answer...", text: $viewModel.currentAnswerText)
                            .textFieldStyle(.plain)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                            .background(Theme.card)
                            .cornerRadius(12)

                        if !viewModel.currentAnswerText.isEmpty {
                            Button(action: { viewModel.answerWithText() }) {
                                Image(systemName: "arrow.right.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundColor(Theme.accent)
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }

            Spacer()

            // Back button
            Button(action: { viewModel.startOver() }) {
                Text("Start over")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding(.bottom, 20)
        }
    }

    // MARK: - Session Ready View

    private var sessionReadyView: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Text("Your Warm-Up")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(Theme.text)

                if let session = viewModel.session {
                    Text("\(session.estimatedMinutes) min · \(session.drills.count) drills")
                        .font(.system(size: 14))
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .padding(.top, 20)

            // Coaching notes
            if let notes = viewModel.session?.coachingNotes {
                Text(notes)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .padding(16)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.accent.opacity(0.08))
                    .cornerRadius(12)
                    .padding(.horizontal, 20)
            }

            // Drills list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(Array((viewModel.session?.drills ?? []).enumerated()), id: \.offset) { index, drill in
                        DrillPreviewRow(index: index + 1, drill: drill)
                    }
                }
                .padding(.horizontal, 20)
            }

            Spacer()

            // Start button
            Button(action: { viewModel.startSession() }) {
                Text("Let's go")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
                    .shadow(color: Theme.accent.opacity(0.35), radius: 12, x: 0, y: 4)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Drilling View

    private var drillingView: some View {
        VStack(spacing: 0) {
            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Theme.buttonSecondary)
                    Rectangle()
                        .fill(Theme.accent)
                        .frame(width: geo.size.width * viewModel.progress)
                }
            }
            .frame(height: 4)

            if let drill = viewModel.currentDrill {
                VStack(spacing: 16) {
                    // Drill type badge
                    Text(drillTypeLabel(drill.type))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.accent.opacity(0.1))
                        .cornerRadius(12)

                    // Title
                    Text(drill.title)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.text)

                    // Instruction
                    Text(drill.instruction)
                        .font(.system(size: 16))
                        .foregroundColor(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)

                    // Time limit
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.system(size: 13))
                        Text("\(drill.timeLimit)s")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundColor(Theme.textMuted)
                }
                .padding(.top, 32)
            }

            // Transcript area
            if viewModel.isRecording && !viewModel.words.isEmpty {
                ScrollView {
                    Text(viewModel.words.map { $0.text }.joined(separator: " "))
                        .font(.system(size: 16))
                        .foregroundColor(Theme.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                }
                .frame(maxHeight: 200)
                .background(Theme.card)
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }

            Spacer()

            // Record button
            if viewModel.isRecording {
                Button(action: { viewModel.stopDrill() }) {
                    ZStack {
                        Circle()
                            .fill(Theme.recordingGlow)
                            .frame(width: 140, height: 140)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.recordingLight, Theme.recording],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color.white)
                            .frame(width: 28, height: 28)
                    }
                }
                .buttonStyle(RecordButtonStyle())
            } else {
                Button(action: { viewModel.startDrill() }) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent.opacity(0.15))
                            .frame(width: 140, height: 140)

                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 100, height: 100)

                        Image(systemName: "mic.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                    }
                }
                .buttonStyle(RecordButtonStyle())
            }

            Spacer()
                .frame(height: 60)
        }
    }

    // MARK: - Drill Feedback View

    private var drillFeedbackView: some View {
        VStack(spacing: 20) {
            if let feedback = viewModel.currentDrillFeedback,
               viewModel.feedbackDrill != nil {

                // Result header
                HStack {
                    Image(systemName: feedback.passed ? "checkmark.circle.fill" : "arrow.counterclockwise.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(feedback.passed ? Theme.accent : Theme.recording)

                    Text(feedback.passed ? "Nice!" : "Almost")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(Theme.text)

                    Spacer()

                    // Energy badge if available
                    if let energy = feedback.energyLevel {
                        Text(energyLabel(energy))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(energyColor(energy))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(energyColor(energy).opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)

                // Notes
                Text(feedback.notes)
                    .font(.system(size: 15))
                    .foregroundColor(Theme.text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(Theme.card)
                    .cornerRadius(12)
                    .padding(.horizontal, 20)

                // Suggestion
                VStack(alignment: .leading, spacing: 8) {
                    Label("Try this", systemImage: "lightbulb")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(Theme.accent)

                    Text(feedback.suggestion)
                        .font(.system(size: 15))
                        .foregroundColor(Theme.text)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .background(Theme.accent.opacity(0.08))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                Spacer()

                // Actions
                VStack(spacing: 12) {
                    Button(action: { viewModel.nextDrill() }) {
                        Text(feedback.passed ? "Next drill" : "Move on anyway")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 54)
                            .background(
                                LinearGradient(
                                    colors: [Theme.accent, Theme.accentDark],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .cornerRadius(14)
                    }
                    .buttonStyle(PressableButtonStyle())

                    if !feedback.passed {
                        Button(action: { viewModel.retryDrill() }) {
                            Text("Try again")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(Theme.textSecondary)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
    }

    // MARK: - Session Complete View

    private var sessionCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundColor(Theme.accent)

            Text("You're warmed up!")
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(Theme.text)

            Text("Go crush it")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)

            Spacer()

            Button(action: { viewModel.startOver() }) {
                Text("Done")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .cornerRadius(14)
            }
            .buttonStyle(PressableButtonStyle())
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
    }

    // MARK: - Helpers

    private func drillTypeLabel(_ type: StreamDrill.DrillType) -> String {
        switch type {
        case .openingHook: return "OPENING HOOK"
        case .explainToChatMode: return "EXPLAIN TO CHAT"
        case .recoveryDrill: return "RECOVERY"
        case .keyPoint: return "KEY POINT"
        case .wrapUp: return "WRAP UP"
        case .handleQuestion: return "HANDLE QUESTION"
        }
    }

    private func energyLabel(_ energy: StreamDrillFeedback.EnergyAssessment) -> String {
        switch energy {
        case .tooLow: return "Low energy"
        case .good: return "Good energy"
        case .tooHigh: return "Too hyped"
        }
    }

    private func energyColor(_ energy: StreamDrillFeedback.EnergyAssessment) -> Color {
        switch energy {
        case .tooLow: return Theme.textMuted
        case .good: return Theme.accent
        case .tooHigh: return Theme.recording
        }
    }
}

// MARK: - Supporting Views

struct HoldToRecordButton: View {
    @Binding var isHolding: Bool
    let transcript: String
    let onStart: () -> Void
    let onEnd: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Transcript preview while holding
            if isHolding && !transcript.isEmpty {
                Text(transcript)
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)
                    .padding(.horizontal, 20)
                    .lineLimit(3)
            }

            // Hold button
            ZStack {
                Circle()
                    .fill(isHolding ? Theme.recordingGlow : Theme.accent.opacity(0.15))
                    .frame(width: 160, height: 160)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: isHolding
                                ? [Theme.recordingLight, Theme.recording]
                                : [Theme.accent, Theme.accentDark],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                Image(systemName: isHolding ? "waveform" : "mic.fill")
                    .font(.system(size: 36))
                    .foregroundColor(.white)
            }
            .scaleEffect(isHolding ? 1.05 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isHolding)
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if !isHolding {
                            onStart()
                        }
                    }
                    .onEnded { _ in
                        if isHolding {
                            onEnd()
                        }
                    }
            )

            Text(isHolding ? "Release when done" : "Hold to speak")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted)
        }
    }
}

struct DrillPreviewRow: View {
    let index: Int
    let drill: StreamDrill

    var body: some View {
        HStack(spacing: 12) {
            Text("\(index)")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 28, height: 28)
                .background(Theme.accent)
                .cornerRadius(14)

            VStack(alignment: .leading, spacing: 4) {
                Text(drill.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(Theme.text)

                Text("\(drill.timeLimit)s")
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textSecondary)
            }

            Spacer()
        }
        .padding(12)
        .background(Theme.card)
        .cornerRadius(12)
    }
}

#Preview {
    StreamPracticeView()
}
