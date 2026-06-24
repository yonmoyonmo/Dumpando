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
                        Text("No archived loops yet.")
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
                    Text("Archived loop not found.")
                        .foregroundStyle(Theme.subtle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                        .background(AppBackgroundView())
                }
            }
        }
    }
}
