import SwiftData
import SwiftUI

struct LoopScreen: View {
    let activeSession: LoopSession?
    let dumpItems: [BrainDumpItem]
    let onStartLoop: () -> Void
    let onEditDump: (BrainDumpItem) -> Void
    let onDeleteDump: (BrainDumpItem) -> Void
    let onSendToLoop: (BrainDumpItem) -> Void
    let onMarkDone: (LoopTask) -> Void
    let onRedump: (LoopTask) -> Void
    let onEditTime: (LoopTask) -> Void
    let onRestoreToToday: (LoopTask) -> Void
    let onArchive: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 10) {
                    if let activeSession {
                        ActiveLoopView(
                            session: activeSession,
                            dumpItems: dumpItems,
                            onSendToLoop: onSendToLoop,
                            onEditDump: onEditDump,
                            onDeleteDump: onDeleteDump,
                            onMarkDone: onMarkDone,
                            onRedump: onRedump,
                            onEditTime: onEditTime,
                            onRestoreToToday: onRestoreToToday,
                            onArchive: onArchive
                        )
                    } else {
                        EmptyLoopView(onStartLoop: onStartLoop)
                    }
                }
                .padding(20)
                .frame(maxWidth: 940)
                .frame(maxWidth: .infinity)
            }
            .background(AppBackgroundView())
            .navigationTitle("Loop")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TimeBoxSheet: View {
    let taskText: String
    let title: String
    let confirmTitle: String
    @Binding var startAt: Date
    @Binding var endAt: Date
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(Theme.text)

                Text(taskText)
                    .font(.caption)
                    .foregroundStyle(Theme.subtle)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    LabeledContent("시작") {
                        DatePicker("", selection: $startAt, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }

                    LabeledContent("끝") {
                        DatePicker("", selection: $endAt, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                            .datePickerStyle(.compact)
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.text)

                HStack {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                    Spacer()

                    Button(confirmTitle, action: onConfirm)
                        .buttonStyle(MonochromeButtonStyle(kind: .filled))
                }
            }
            .padding(16)
            .frame(maxWidth: 420, alignment: .topLeading)
            .presentationDetents([.height(230)])
            .presentationBackground(Theme.background)
            .background(AppBackgroundView())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

struct ActiveLoopView: View {
    @Bindable var session: LoopSession
    let dumpItems: [BrainDumpItem]
    let onSendToLoop: (BrainDumpItem) -> Void
    let onEditDump: (BrainDumpItem) -> Void
    let onDeleteDump: (BrainDumpItem) -> Void
    let onMarkDone: (LoopTask) -> Void
    let onRedump: (LoopTask) -> Void
    let onEditTime: (LoopTask) -> Void
    let onRestoreToToday: (LoopTask) -> Void
    let onArchive: () -> Void
    @FocusState private var feedbackFocused: Bool

    private var pendingTasks: [LoopTask] {
        session.tasks.filter { $0.state == .pending }
    }

    private var resolvedTasks: [LoopTask] {
        session.tasks.filter { $0.state != .pending }
    }

    var body: some View {
        VStack(spacing: 18) {
            SessionHeader(
                title: "Live Loop",
                subtitle: session.startedAt.formatted(.dateTime.year().month().day()),
                compact: true,
                maxWidth: 520
            ) {
                EmptyView()
            }

            SectionCard(title: "Brain Dump Pool", count: dumpItems.count) {
                ScrollView {
                    if dumpItems.isEmpty {
                        EmptyInlineRow(text: "No pool items waiting.")
                            .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
                    } else {
                        LazyVStack(spacing: 4) {
                            ForEach(dumpItems) { item in
                                PoolRow(
                                    item: item,
                                    actionTitle: "➡️",
                                    isActionEnabled: true,
                                    onEdit: { onEditDump(item) },
                                    onDelete: { onDeleteDump(item) },
                                    onAction: { onSendToLoop(item) }
                                )
                            }
                        }
                    }
                }
                .frame(height: 150)
                .scrollIndicators(.visible)
                .padding(4)
                .background(Color.black.opacity(0.025))
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Theme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            }

            SectionCard(title: "Today", count: pendingTasks.count) {
                if pendingTasks.isEmpty {
                    EmptyInlineRow(text: "Nothing in today's workset.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(pendingTasks) { task in
                            TaskRow(
                                task: task,
                                onMarkDone: { onMarkDone(task) },
                                onRedump: { onRedump(task) },
                                onEditTime: { onEditTime(task) }
                            )
                        }
                    }
                }
            }

            SectionCard(title: "Resolved", count: resolvedTasks.count) {
                if resolvedTasks.isEmpty {
                    EmptyInlineRow(text: "Resolved items stay in this loop.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(resolvedTasks) { task in
                            TaskRow(
                                task: task,
                                onMarkDone: {},
                                onRedump: {},
                                onEditTime: {},
                                onRestoreToToday: {
                                    onRestoreToToday(task)
                                },
                                isReadOnly: true,
                                showsRestoreActions: true
                            )
                        }
                    }
                }
            }

            SectionCard(title: "Feedback", count: session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1) {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $session.feedback)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(Theme.text)
                        .focused($feedbackFocused)
                        .padding(10)
                        .background(Color.black.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                    HStack {
                        Text("Feedback is required before archiving.")
                            .font(.caption)
                            .foregroundStyle(Theme.subtle)

                        Spacer()

                        Button("Archive Loop", action: onArchive)
                            .buttonStyle(MonochromeButtonStyle(kind: .filled))
                            .disabled(session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            feedbackFocused = false
        })
    }
}

struct ArchivedLoopView: View {
    let session: LoopSession
    let onOpenCurrentLoop: () -> Void
    let onDeleteArchive: (LoopSession) -> Void

    private var sortedTasks: [LoopTask] {
        session.tasks.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                SessionHeader(
                    title: "Archived Loop",
                    subtitle: session.displayDate.formatted(.dateTime.year().month().day()),
                    compact: true,
                    maxWidth: 520
                ) {
                    EmptyView()
                }

                SectionCard(title: "Tasks", count: sortedTasks.count) {
                    if sortedTasks.isEmpty {
                        EmptyInlineRow(text: "This loop had no tasks.")
                    } else {
                        VStack(spacing: 10) {
                            ForEach(sortedTasks) { task in
                                TaskRow(task: task, onMarkDone: {}, onRedump: {}, onEditTime: {}, isReadOnly: true)
                            }
                        }
                    }
                }

                SectionCard(title: "Feedback", count: session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1) {
                    Text(session.feedback.isEmpty ? "No feedback was recorded." : session.feedback)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .foregroundStyle(Theme.text)
                        .padding(14)
                        .background(Color.black.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Theme.border, lineWidth: 1)
                        )
                }

                Button("Delete Archived Loop", role: .destructive) {
                    onDeleteArchive(session)
                }
                .buttonStyle(MonochromeButtonStyle(kind: .ghost))
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppBackgroundView())
    }
}

struct EmptyLoopView: View {
    let onStartLoop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NO ACTIVE LOOP")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.subtle)

            Text("Start a loop when you are ready to turn raw thoughts into today's work.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)

            Button("Start Loop", action: onStartLoop)
                .buttonStyle(MonochromeButtonStyle(kind: .filled))
        }
        .padding(18)
        .frame(maxWidth: 560, alignment: .leading)
        .background(Color.black.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Theme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

struct TaskRow: View {
    let task: LoopTask
    let onMarkDone: () -> Void
    let onRedump: () -> Void
    let onEditTime: () -> Void
    let onRestoreToToday: (() -> Void)?
    let onRestoreToDump: (() -> Void)?
    var isReadOnly: Bool = false
    var showsRestoreActions: Bool = false

    init(
        task: LoopTask,
        onMarkDone: @escaping () -> Void,
        onRedump: @escaping () -> Void,
        onEditTime: @escaping () -> Void,
        onRestoreToToday: (() -> Void)? = nil,
        onRestoreToDump: (() -> Void)? = nil,
        isReadOnly: Bool = false,
        showsRestoreActions: Bool = false
    ) {
        self.task = task
        self.onMarkDone = onMarkDone
        self.onRedump = onRedump
        self.onEditTime = onEditTime
        self.onRestoreToToday = onRestoreToToday
        self.onRestoreToDump = onRestoreToDump
        self.isReadOnly = isReadOnly
        self.showsRestoreActions = showsRestoreActions
    }

    private var stateText: String {
        task.state.symbol
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.text)
                    .foregroundStyle(task.state == .pending ? Theme.text : Theme.subtle)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(stateText)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Capsule())

                    Text("\(task.plannedStartAt.formatted(.dateTime.hour().minute())) ~ \(task.plannedEndAt.formatted(.dateTime.hour().minute()))")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(Color.black.opacity(0.06))
                        .clipShape(Capsule())

                    if let completedAt = task.completedAt {
                        Text(completedAt.formatted(.dateTime.hour().minute()))
                            .font(.caption2)
                            .foregroundStyle(Theme.subtle)
                    }
                }
            }

            Spacer()

            if !isReadOnly && task.state == .pending {
                HStack(spacing: 8) {
                    Button("✏️", action: onEditTime)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                    Button("✅", action: onMarkDone)
                        .buttonStyle(MonochromeButtonStyle(kind: .filled))

                    Button("🔁", action: onRedump)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                }
            } else if showsRestoreActions {
                HStack(spacing: 8) {
                    if let onRestoreToToday {
                        Button("↩️", action: onRestoreToToday)
                            .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                    }
                    if let onRestoreToDump {
                        Button("🔁", action: onRestoreToDump)
                            .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                    }
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
