import SwiftData
import SwiftUI

struct ArchiveScreen: View {
    let archivedSessions: [LoopSession]
    let onOpenCurrentLoop: () -> Void
    let onDeleteArchive: (LoopSession) -> Bool
    @State private var path: [PersistentIdentifier] = []

    var body: some View {
        NavigationStack(path: $path) {
            List {
                if archivedSessions.isEmpty {
                    HStack {
                        Text("No archived days yet.")
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.vertical, 8)
                        .listRowBackground(Theme.background)
                        .listRowSeparator(.hidden)
                } else {
                    ForEach(archivedSessions.sorted { ($0.archivedAt ?? $0.startedAt) > ($1.archivedAt ?? $1.startedAt) }) { session in
                        NavigationLink(value: session.persistentModelID) {
                            ArchiveRow(session: session)
                        }
                        .listRowBackground(Theme.background)
                        .listRowInsets(EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16))
                        .listRowSeparator(.hidden)
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .contentMargins(.top, 0, for: .scrollContent)
            .background(AppBackgroundView())
            .navigationTitle("Archive")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: PersistentIdentifier.self) { id in
                if let session = archivedSessions.first(where: { $0.persistentModelID == id }) {
                    ArchivedLoopView(
                        session: session,
                        onOpenCurrentLoop: onOpenCurrentLoop,
                        onDeleteArchive: { session in
                            if onDeleteArchive(session) {
                                path.removeAll()
                            }
                        }
                    )
                } else {
                    Text("Archived day not found.")
                        .foregroundStyle(Theme.subtle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(AppBackgroundView())
                }
            }
        }
    }
}

struct ArchiveRow: View {
    let session: LoopSession

    private var feedbackPreview: String {
        let feedback = session.feedback.trimmingCharacters(in: .whitespacesAndNewlines)
        guard feedback.count > 12 else { return feedback }
        return "\(feedback.prefix(12))..."
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(session.displayDate.formatted(.dateTime.year().month().day()))
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(Theme.text)

                Text(feedbackPreview)
                    .font(.caption2)
                    .foregroundStyle(Theme.subtle)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()
        }
        .padding(4)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Color.black.opacity(0.03)))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
    }
}
