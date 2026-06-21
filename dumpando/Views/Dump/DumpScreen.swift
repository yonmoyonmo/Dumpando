import SwiftData
import SwiftUI

struct DumpScreen: View {
    @Binding var draftDumpText: String
    let dumpItems: [BrainDumpItem]
    let activeSessionExists: Bool
    let onCreateDump: () -> Void
    let onEditDump: (BrainDumpItem) -> Void
    let onDeleteDump: (BrainDumpItem) -> Void
    let onSendToLoop: (BrainDumpItem) -> Void

    @FocusState private var draftFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    SectionCard(title: "Brain Dump", count: 0, showsCount: false) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Drop a thought", text: $draftDumpText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .foregroundStyle(Theme.text)
                                .lineLimit(1...4)
                                .submitLabel(.done)
                                .onSubmit(onCreateDump)
                                .focused($draftFocused)

                            HStack {
                                Button("Add Dump", action: onCreateDump)
                                    .buttonStyle(MonochromeButtonStyle(kind: .filled))
                            }
                        }
                    }

                    SectionCard(title: "Pool", count: dumpItems.count) {
                        if dumpItems.isEmpty {
                            EmptyInlineRow(text: "Nothing in the pool yet.")
                        } else {
                            VStack(spacing: 10) {
                                ForEach(dumpItems) { item in
                                    PoolRow(
                                        item: item,
                                        actionTitle: activeSessionExists ? "➡️" : nil,
                                        isActionEnabled: activeSessionExists,
                                        onEdit: { onEditDump(item) },
                                        onDelete: { onDeleteDump(item) },
                                        onAction: { onSendToLoop(item) }
                                    )
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .padding(.top, 4)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { draftFocused = false })
            .background(AppBackgroundView())
            .navigationTitle("Dump")
        }
    }
}

struct DumpEditSheet: View {
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Edit dump")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(Theme.text)

                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(Theme.text)
                    .padding(10)
                    .background(Color.black.opacity(0.04))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Theme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                Spacer()

                HStack {
                    Button("Delete", action: onDelete)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                    Spacer()

                    Button("Cancel", action: onCancel)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                    Button("Save", action: onSave)
                        .buttonStyle(MonochromeButtonStyle(kind: .filled))
                }
            }
            .padding(20)
            .frame(maxWidth: 520, maxHeight: .infinity, alignment: .topLeading)
            .background(AppBackgroundView())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct PoolRow: View {
    let item: BrainDumpItem
    let actionTitle: String?
    let isActionEnabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .foregroundStyle(Theme.text)
                    .lineLimit(2)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("✏️", action: onEdit)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                Button("🗑️", action: onDelete)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                if let actionTitle {
                    Button(actionTitle, action: onAction)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                        .disabled(!isActionEnabled)
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.03))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
