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
            .navigationTitle("Today")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct TimeBoxSheet: View {
    private enum TimeField {
        case start
        case end

        var title: String {
            switch self {
            case .start:
                return "Start Time"
            case .end:
                return "End Time"
            }
        }
    }

    let taskText: String
    let title: String
    let confirmTitle: String
    let onCancel: () -> Void
    let onConfirm: (Date, Date) -> Void
    @State private var draftStartAt: Date
    @State private var draftEndAt: Date
    @State private var editingTimeField: TimeField?
    @State private var pickerDraftAt: Date = .now

    init(
        taskText: String,
        title: String,
        confirmTitle: String,
        startAt: Date,
        endAt: Date,
        onCancel: @escaping () -> Void,
        onConfirm: @escaping (Date, Date) -> Void
    ) {
        self.taskText = taskText
        self.title = title
        self.confirmTitle = confirmTitle
        self.onCancel = onCancel
        self.onConfirm = onConfirm
        _draftStartAt = State(initialValue: startAt)
        _draftEndAt = State(initialValue: endAt)
    }

    var body: some View {
        NavigationStack {
            Group {
                if let editingTimeField {
                    timePickerContent(for: editingTimeField)
                } else {
                    timeBlockContent
                }
            }
            .padding(16)
            .frame(maxWidth: 420, alignment: .topLeading)
            .presentationDetents([.height(editingTimeField == nil ? 230 : 320)])
            .presentationBackground(Theme.background)
            .background(AppBackgroundView())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var timeBlockContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.text)

            Text(taskText)
                .font(.caption)
                .foregroundStyle(Theme.subtle)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 10) {
                LabeledContent("Start") {
                    Button(draftStartAt.formatted(.dateTime.hour().minute())) {
                        openTimePicker(.start, date: draftStartAt)
                    }
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                }

                LabeledContent("End") {
                    Button(draftEndAt.formatted(.dateTime.hour().minute())) {
                        openTimePicker(.end, date: draftEndAt)
                    }
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                }
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(Theme.text)

            HStack {
                Button("Cancel", action: onCancel)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                Spacer()

                Button(confirmTitle) {
                    onConfirm(draftStartAt, draftEndAt)
                }
                .buttonStyle(MonochromeButtonStyle(kind: .filled))
            }
        }
    }

    private func timePickerContent(for field: TimeField) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(field.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.text)

            DatePicker("", selection: $pickerDraftAt, displayedComponents: .hourAndMinute)
                .datePickerStyle(.wheel)
                .labelsHidden()
                .frame(maxWidth: .infinity)

            HStack {
                Button("Cancel") {
                    editingTimeField = nil
                }
                .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                Spacer()

                Button("OK") {
                    confirmPickedTime(field)
                }
                .buttonStyle(MonochromeButtonStyle(kind: .filled))
            }
        }
    }

    private func openTimePicker(_ field: TimeField, date: Date) {
        pickerDraftAt = date
        editingTimeField = field
    }

    private func confirmPickedTime(_ field: TimeField) {
        switch field {
        case .start:
            draftStartAt = pickerDraftAt
        case .end:
            draftEndAt = pickerDraftAt
        }

        editingTimeField = nil
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
    @State private var isConfirmingArchive = false
    @State private var isShowingMissingFeedbackAlert = false

    private var pendingTasks: [LoopTask] {
        session.tasks
            .filter { $0.state == .pending }
            .sorted {
                if $0.plannedStartAt == $1.plannedStartAt {
                    return $0.createdAt < $1.createdAt
                }
                return $0.plannedStartAt < $1.plannedStartAt
            }
    }

    private var resolvedTasks: [LoopTask] {
        session.tasks.filter { $0.state != .pending }
    }

    var body: some View {
        VStack(spacing: 18) {
            SessionHeader(
                title: "Today",
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
                    EmptyInlineRow(text: "Resolved items stay in Today.")
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

                        Button("Archive Today") {
                            if session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                isShowingMissingFeedbackAlert = true
                            } else {
                                isConfirmingArchive = true
                            }
                        }
                        .buttonStyle(MonochromeButtonStyle(kind: .filled))
                    }
                }
            }
        }
        .simultaneousGesture(TapGesture().onEnded {
            feedbackFocused = false
        })
        .alert("Archive Today?", isPresented: $isConfirmingArchive) {
            Button("Cancel", role: .cancel) {}
            Button("Archive", role: .destructive, action: onArchive)
        } message: {
            Text("Today will move to Archive and cannot be edited afterward.")
        }
        .alert("Feedback required", isPresented: $isShowingMissingFeedbackAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Add feedback before archiving Today.")
        }
    }
}

struct ArchivedLoopView: View {
    let session: LoopSession
    let onOpenCurrentLoop: () -> Void
    let onDeleteArchive: (LoopSession) -> Void
    @State private var isConfirmingDelete = false

    private var sortedTasks: [LoopTask] {
        session.tasks.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                SessionHeader(
                    title: "Archived Today",
                    subtitle: session.displayDate.formatted(.dateTime.year().month().day()),
                    compact: true,
                    maxWidth: 520
                ) {
                    EmptyView()
                }

                SectionCard(title: "Tasks", count: sortedTasks.count) {
                    if sortedTasks.isEmpty {
                        EmptyInlineRow(text: "This archived day had no tasks.")
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

                Button("Delete Archived Today", role: .destructive) {
                    isConfirmingDelete = true
                }
                .buttonStyle(MonochromeButtonStyle(kind: .ghost))
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(AppBackgroundView())
        .alert("Delete archived Today?", isPresented: $isConfirmingDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                onDeleteArchive(session)
            }
        } message: {
            Text("All tasks and feedback in this archive will be removed.")
        }
    }
}

struct EmptyLoopView: View {
    let onStartLoop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NO ACTIVE TODAY")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(Theme.subtle)

            Text("Start Today when you are ready to turn raw thoughts into today's work.")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.text)

            Button("Start Today", action: onStartLoop)
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
