import SwiftUI
import SwiftData

/// Bottom sheet showing recording history
struct HistorySheetView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \RecordingSession.createdAt, order: .reverse)
    private var sessions: [RecordingSession]

    @State private var selectedSession: RecordingSession?

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    emptyState
                } else {
                    sessionList
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(Theme.accent)
                }
            }
            .sheet(item: $selectedSession) { session in
                SessionDetailView(session: session)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "waveform")
                .font(.system(size: 48))
                .foregroundColor(Theme.textMuted.opacity(0.5))

            Text("No recordings yet")
                .font(.system(size: 17))
                .foregroundColor(Theme.textMuted)

            Text("Your practice sessions will appear here")
                .font(.system(size: 14))
                .foregroundColor(Theme.textMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background)
    }

    private var sessionList: some View {
        List {
            ForEach(sessions) { session in
                SessionRowView(session: session)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedSession = session
                    }
                    .listRowBackground(Theme.background)
            }
            .onDelete(perform: deleteSessions)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Theme.background)
    }

    private func deleteSessions(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            // Delete audio file
            if let audioFile = session.audioFileName {
                AudioStorageService.shared.deleteAudio(fileName: audioFile)
            }
            // Delete from SwiftData
            modelContext.delete(session)
        }
    }
}

/// Row displaying session preview and stats
struct SessionRowView: View {
    let session: RecordingSession

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Preview text
            Text(session.previewText)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Theme.text)
                .lineLimit(2)

            // Stats row
            HStack(spacing: 16) {
                // Filler count with icon
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.bubble.fill")
                        .font(.system(size: 11))
                    Text("\(session.totalFillers)")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(session.totalFillers > 0 ? Theme.accent : Theme.textMuted)

                // Duration
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.system(size: 11))
                    Text(formatDuration(session.sessionDuration))
                        .font(.system(size: 13))
                }
                .foregroundColor(Theme.textMuted)

                Spacer()

                // Relative date
                Text(session.createdAt, style: .relative)
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textMuted.opacity(0.7))
            }
        }
        .padding(.vertical, 10)
    }

    private func formatDuration(_ seconds: Double) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        if mins > 0 {
            return "\(mins):\(String(format: "%02d", secs))"
        }
        return "\(secs)s"
    }
}

// MARK: - Identifiable conformance for sheet presentation

extension RecordingSession: Identifiable {}

#Preview {
    HistorySheetView()
        .modelContainer(for: RecordingSession.self, inMemory: true)
}
