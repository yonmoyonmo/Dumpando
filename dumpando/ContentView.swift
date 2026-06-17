//
//  ContentView.swift
//  dumpando
//
//  Created by yonmo on 6/17/26.
//

import SwiftData
import SwiftUI

private enum RootTab: Hashable {
    case dump
    case loop
    case archive
}

private struct PromotionDraft: Identifiable {
    let id: PersistentIdentifier
    let itemID: PersistentIdentifier
    let text: String
}

private struct DumpEditDraft: Identifiable {
    let id: PersistentIdentifier
    let itemID: PersistentIdentifier
    let text: String
}

private struct TaskTimeDraft: Identifiable {
    let id: PersistentIdentifier
    let taskID: PersistentIdentifier
    let text: String
}

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \BrainDumpItem.createdAt, order: .reverse) private var dumpItems: [BrainDumpItem]
    @Query(sort: \LoopSession.startedAt, order: .reverse) private var sessions: [LoopSession]

    @State private var draftDumpText = ""
    @State private var selectedTab: RootTab = .dump
    @State private var pendingPromotion: PromotionDraft?
    @State private var pendingPromotionStartAt: Date = .now
    @State private var pendingPromotionEndAt: Date = .now.addingTimeInterval(3600)
    @State private var editingDump: DumpEditDraft?
    @State private var editingDumpText = ""
    @State private var editingTaskTime: TaskTimeDraft?
    @State private var editingTaskStartAt: Date = .now
    @State private var editingTaskEndAt: Date = .now.addingTimeInterval(3600)
    @State private var alertMessage: String?

    private var activeSession: LoopSession? {
        sessions.first { $0.archivedAt == nil }
    }

    private var archivedSessions: [LoopSession] {
        sessions.filter { $0.archivedAt != nil }
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            DumpScreen(
                draftDumpText: $draftDumpText,
                dumpItems: dumpItems,
                activeSessionExists: activeSession != nil,
                onCreateDump: createDump,
                onEditDump: requestDumpEdit,
                onDeleteDump: deleteDump,
                onSendToLoop: requestPromotion,
                onOpenLoop: {
                    selectedTab = .loop
                }
            )
            .tabItem {
                Label("Dump", systemImage: "square.and.pencil")
            }
            .tag(RootTab.dump)

            LoopScreen(
                activeSession: activeSession,
                dumpItems: dumpItems,
                onStartLoop: startLoop,
                onEditDump: requestDumpEdit,
                onDeleteDump: deleteDump,
                onSendToLoop: requestPromotion,
                onMarkDone: markDone,
                onRedump: redump,
                onEditTime: requestTaskTimeEdit,
                onArchive: archiveActiveSession
            )
            .tabItem {
                Label("Loop", systemImage: "sparkles")
            }
            .tag(RootTab.loop)

            ArchiveScreen(
                archivedSessions: archivedSessions,
                onOpenCurrentLoop: {
                    selectedTab = .loop
                }
            )
            .tabItem {
                Label("Archive", systemImage: "tray.full")
            }
            .tag(RootTab.archive)
        }
        .preferredColorScheme(.dark)
        .sheet(item: $pendingPromotion) { draft in
            TimeBoxSheet(
                taskText: draft.text,
                title: "Set time block",
                confirmTitle: "Add to Today",
                startAt: $pendingPromotionStartAt,
                endAt: $pendingPromotionEndAt,
                onCancel: {
                    pendingPromotion = nil
                    pendingPromotionStartAt = .now
                    pendingPromotionEndAt = .now.addingTimeInterval(3600)
                },
                onConfirm: {
                    commitPromotion(
                        draft: draft,
                        startAt: pendingPromotionStartAt,
                        endAt: pendingPromotionEndAt
                    )
                    pendingPromotion = nil
                    pendingPromotionStartAt = .now
                    pendingPromotionEndAt = .now.addingTimeInterval(3600)
                }
            )
        }
        .sheet(item: $editingDump) { draft in
            DumpEditSheet(
                text: $editingDumpText,
                onCancel: {
                    editingDump = nil
                },
                onSave: {
                    saveDumpEdit(draft: draft, text: editingDumpText)
                    editingDump = nil
                },
                onDelete: {
                    deleteDump(draft: draft)
                    editingDump = nil
                }
            )
        }
        .sheet(item: $editingTaskTime) { draft in
            TimeBoxSheet(
                taskText: draft.text,
                title: "Edit time block",
                confirmTitle: "Save Time",
                startAt: $editingTaskStartAt,
                endAt: $editingTaskEndAt,
                onCancel: {
                    editingTaskTime = nil
                },
                onConfirm: {
                    saveTaskTimeEdit(draft: draft, startAt: editingTaskStartAt, endAt: editingTaskEndAt)
                    editingTaskTime = nil
                }
            )
        }
        .alert("Action failed", isPresented: Binding(
            get: { alertMessage != nil },
            set: { if !$0 { alertMessage = nil } }
        )) {
            Button("OK", role: .cancel) {
                alertMessage = nil
            }
        } message: {
            Text(alertMessage ?? "Unknown error")
        }
    }

    private func saveContext(fallback: String) -> Bool {
        do {
            try modelContext.save()
            return true
        } catch {
            alertMessage = fallback
            return false
        }
    }

    private func createDump() {
        let trimmed = draftDumpText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            modelContext.insert(BrainDumpItem(text: trimmed))
        }

        guard saveContext(fallback: "Could not save dump.") else { return }
        draftDumpText = ""
    }

    private func requestDumpEdit(_ item: BrainDumpItem) {
        editingDumpText = item.text
        editingDump = DumpEditDraft(id: item.persistentModelID, itemID: item.persistentModelID, text: item.text)
    }

    private func saveDumpEdit(draft: DumpEditDraft, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            alertMessage = "Dump text cannot be empty."
            return
        }

        guard let item = modelContext.model(for: draft.itemID) as? BrainDumpItem else {
            alertMessage = "That dump item is no longer available."
            return
        }

        withAnimation {
            item.text = trimmed
        }

        _ = saveContext(fallback: "Could not update dump.")
    }

    private func deleteDump(draft: DumpEditDraft) {
        guard let item = modelContext.model(for: draft.itemID) as? BrainDumpItem else {
            alertMessage = "That dump item is no longer available."
            return
        }

        withAnimation {
            modelContext.delete(item)
        }

        _ = saveContext(fallback: "Could not delete dump.")
    }

    private func deleteDump(_ item: BrainDumpItem) {
        withAnimation {
            modelContext.delete(item)
        }

        _ = saveContext(fallback: "Could not delete dump.")
    }

    private func startLoop() {
        if activeSession != nil {
            selectedTab = .loop
            return
        }

        withAnimation {
            modelContext.insert(LoopSession())
        }

        if saveContext(fallback: "Could not start a new loop.") {
            selectedTab = .loop
        }
    }

    private func requestPromotion(_ item: BrainDumpItem) {
        guard activeSession != nil else {
            selectedTab = .loop
            alertMessage = "Start a loop first."
            return
        }

        pendingPromotionStartAt = .now
        pendingPromotionEndAt = .now.addingTimeInterval(3600)
        pendingPromotion = PromotionDraft(
            id: item.persistentModelID,
            itemID: item.persistentModelID,
            text: item.text
        )
        selectedTab = .loop
    }

    private func commitPromotion(draft: PromotionDraft, startAt: Date, endAt: Date) {
        guard let activeSession else {
            alertMessage = "Start a loop first."
            return
        }

        let normalizedEndAt = max(endAt, startAt.addingTimeInterval(60))

        guard let item = modelContext.model(for: draft.itemID) as? BrainDumpItem else {
            alertMessage = "That dump item is no longer available."
            return
        }

        withAnimation {
            modelContext.insert(
                LoopTask(
                    text: item.text,
                    plannedStartAt: startAt,
                    plannedEndAt: normalizedEndAt,
                    session: activeSession
                )
            )
            modelContext.delete(item)
        }

        _ = saveContext(fallback: "Could not move dump into today's loop.")
    }

    private func requestTaskTimeEdit(_ task: LoopTask) {
        editingTaskStartAt = task.plannedStartAt
        editingTaskEndAt = task.plannedEndAt
        editingTaskTime = TaskTimeDraft(
            id: task.persistentModelID,
            taskID: task.persistentModelID,
            text: task.text
        )
    }

    private func saveTaskTimeEdit(draft: TaskTimeDraft, startAt: Date, endAt: Date) {
        let normalizedEndAt = max(endAt, startAt.addingTimeInterval(60))

        guard let task = modelContext.model(for: draft.taskID) as? LoopTask else {
            alertMessage = "That task is no longer available."
            return
        }

        withAnimation {
            task.plannedStartAt = startAt
            task.plannedEndAt = normalizedEndAt
        }

        _ = saveContext(fallback: "Could not update task time.")
    }

    private func markDone(_ task: LoopTask) {
        withAnimation {
            task.state = .done
            task.completedAt = .now
        }

        _ = saveContext(fallback: "Could not mark task as done.")
    }

    private func redump(_ task: LoopTask) {
        let trimmed = task.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            task.state = .redumped
            task.completedAt = .now
            modelContext.insert(BrainDumpItem(text: trimmed))
        }

        _ = saveContext(fallback: "Could not re-dump task.")
    }

    private func archiveActiveSession() {
        guard let activeSession else { return }
        guard !activeSession.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        withAnimation {
            activeSession.archivedAt = .now
        }

        if saveContext(fallback: "Could not archive the loop.") {
            selectedTab = .archive
        }
    }
}

private struct DumpScreen: View {
    @Binding var draftDumpText: String
    let dumpItems: [BrainDumpItem]
    let activeSessionExists: Bool
    let onCreateDump: () -> Void
    let onEditDump: (BrainDumpItem) -> Void
    let onDeleteDump: (BrainDumpItem) -> Void
    let onSendToLoop: (BrainDumpItem) -> Void
    let onOpenLoop: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    SectionCard(title: "Brain Dump", count: draftDumpText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1) {
                        VStack(alignment: .leading, spacing: 12) {
                            TextField("Drop a thought", text: $draftDumpText, axis: .vertical)
                                .textFieldStyle(.plain)
                                .foregroundStyle(.white)
                                .lineLimit(1...4)
                                .submitLabel(.done)
                                .onSubmit(onCreateDump)
                                .focused($draftFocused)

                            HStack {
                                Button("Add Dump", action: onCreateDump)
                                    .buttonStyle(MonochromeButtonStyle(kind: .filled))

                                Spacer()

                                Button(activeSessionExists ? "Open Loop" : "Go to Loop", action: onOpenLoop)
                                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))
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
                                    actionTitle: activeSessionExists ? "To Loop" : "Locked",
                                    isActionEnabled: activeSessionExists,
                                    onEdit: {
                                        onEditDump(item)
                                    },
                                    onDelete: {
                                        onDeleteDump(item)
                                    },
                                    onAction: {
                                        onSendToLoop(item)
                                    }
                                )
                                }
                            }
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
            .simultaneousGesture(TapGesture().onEnded { draftFocused = false })
            .background(BlackBackgroundView())
            .navigationTitle("Dump")
        }
    }

    @FocusState private var draftFocused: Bool
}

private struct LoopScreen: View {
    let activeSession: LoopSession?
    let dumpItems: [BrainDumpItem]
    let onStartLoop: () -> Void
    let onEditDump: (BrainDumpItem) -> Void
    let onDeleteDump: (BrainDumpItem) -> Void
    let onSendToLoop: (BrainDumpItem) -> Void
    let onMarkDone: (LoopTask) -> Void
    let onRedump: (LoopTask) -> Void
    let onEditTime: (LoopTask) -> Void
    let onArchive: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
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
            .background(BlackBackgroundView())
            .navigationTitle("Loop")
        }
    }
}

private struct ArchiveScreen: View {
    let archivedSessions: [LoopSession]
    let onOpenCurrentLoop: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if archivedSessions.isEmpty {
                    Text("No archived loops yet.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(archivedSessions.sorted { ($0.archivedAt ?? $0.startedAt) > ($1.archivedAt ?? $1.startedAt) }) { session in
                        NavigationLink {
                            ArchivedLoopView(
                                session: session,
                                onOpenCurrentLoop: onOpenCurrentLoop
                            )
                        } label: {
                            ArchiveRow(session: session)
                        }
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Archive")
            .background(BlackBackgroundView())
        }
    }
}

private struct TimeBoxSheet: View {
    let taskText: String
    let title: String
    let confirmTitle: String
    @Binding var startAt: Date
    @Binding var endAt: Date
    let onCancel: () -> Void
    let onConfirm: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.largeTitle.weight(.semibold))

                Text(taskText)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 10) {
                    Text("Time Window")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    DatePicker("Start", selection: $startAt, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)

                    DatePicker("End", selection: $endAt, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                        .datePickerStyle(.compact)
                }

                Spacer()

                HStack {
                    Button("Cancel", action: onCancel)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                    Spacer()

                    Button(confirmTitle, action: onConfirm)
                        .buttonStyle(MonochromeButtonStyle(kind: .filled))
                }
            }
            .padding(20)
            .frame(maxWidth: 500, maxHeight: .infinity, alignment: .topLeading)
            .background(BlackBackgroundView())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct DumpEditSheet: View {
    @Binding var text: String
    let onCancel: () -> Void
    let onSave: () -> Void
    let onDelete: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                Text("Edit dump")
                    .font(.largeTitle.weight(.semibold))

                TextEditor(text: $text)
                    .frame(minHeight: 180)
                    .scrollContentBackground(.hidden)
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    )

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
            .background(BlackBackgroundView())
            .toolbar(.hidden, for: .navigationBar)
        }
    }
}

private struct ActiveLoopView: View {
    @Bindable var session: LoopSession
    let dumpItems: [BrainDumpItem]
    let onSendToLoop: (BrainDumpItem) -> Void
    let onEditDump: (BrainDumpItem) -> Void
    let onDeleteDump: (BrainDumpItem) -> Void
    let onMarkDone: (LoopTask) -> Void
    let onRedump: (LoopTask) -> Void
    let onEditTime: (LoopTask) -> Void
    let onArchive: () -> Void

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
                subtitle: session.startedAt.formatted(.dateTime.year().month().day().hour().minute())
            ) {
                Button("Archive", action: onArchive)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                    .disabled(session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            SectionCard(title: "Brain Dump Pool", count: dumpItems.count) {
                if dumpItems.isEmpty {
                    EmptyInlineRow(text: "No pool items waiting.")
                } else {
                    VStack(spacing: 10) {
                        ForEach(dumpItems) { item in
                            PoolRow(
                                item: item,
                                actionTitle: "To Today",
                                isActionEnabled: true,
                                onEdit: { onEditDump(item) },
                                onDelete: { onDeleteDump(item) },
                                onAction: {
                                    onSendToLoop(item)
                                }
                            )
                        }
                    }
                }
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
                                TaskRow(task: task, onMarkDone: {}, onRedump: {}, onEditTime: {}, isReadOnly: true)
                            }
                        }
                }
            }

            SectionCard(title: "Feedback", count: session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0 : 1) {
                VStack(alignment: .leading, spacing: 12) {
                    TextEditor(text: $session.feedback)
                        .frame(minHeight: 140)
                        .scrollContentBackground(.hidden)
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )

                    HStack {
                        Text("Feedback is required before archiving.")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Spacer()

                        Button("Archive Loop", action: onArchive)
                            .buttonStyle(MonochromeButtonStyle(kind: .filled))
                            .disabled(session.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
            }
        }
    }
}

private struct ArchivedLoopView: View {
    let session: LoopSession
    let onOpenCurrentLoop: () -> Void

    private var sortedTasks: [LoopTask] {
        session.tasks.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                SessionHeader(
                    title: "Archived Loop",
                    subtitle: session.displayDate.formatted(.dateTime.year().month().day())
                ) {
                    Button("Current Loop", action: onOpenCurrentLoop)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))
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
                        .foregroundStyle(.white)
                        .padding(14)
                        .background(Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                }
            }
            .padding(20)
            .frame(maxWidth: 900)
            .frame(maxWidth: .infinity)
        }
        .background(BlackBackgroundView())
    }
}

private struct EmptyLoopView: View {
    let onStartLoop: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("NO ACTIVE LOOP")
                .font(.caption.weight(.semibold))
                .tracking(1.4)
                .foregroundStyle(.secondary)

            Text("Start a loop when you are ready to turn raw thoughts into today's work.")
                .font(.title.weight(.semibold))
                .foregroundStyle(.white)

            Text("The loop can stay empty until you need it. The dump screen remains available either way.")
                .foregroundStyle(.secondary)

            Button("Start Loop", action: onStartLoop)
                .buttonStyle(MonochromeButtonStyle(kind: .filled))
        }
        .padding(24)
        .frame(maxWidth: 560, alignment: .leading)
        .background(Color.white.opacity(0.045))
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
    }
}

private struct SectionCard<Content: View>: View {
    let title: String
    let count: Int
    let content: Content

    init(title: String, count: Int, @ViewBuilder content: () -> Content) {
        self.title = title
        self.count = count
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.2)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            content
        }
        .padding(16)
        .background(Color.white.opacity(0.045))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct SessionHeader<Trailing: View>: View {
    let title: String
    let subtitle: String
    let trailing: Trailing

    init(title: String, subtitle: String, @ViewBuilder trailing: () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title.uppercased())
                    .font(.caption.weight(.semibold))
                    .tracking(1.4)
                    .foregroundStyle(.secondary)

                Text(subtitle)
                    .font(.largeTitle.weight(.semibold))
                    .foregroundStyle(.white)
            }

            Spacer()

            trailing
        }
    }
}

private struct ArchiveRow: View {
    let session: LoopSession

    private var taskCount: Int {
        session.tasks.count
    }

    private var pendingCount: Int {
        session.tasks.filter { $0.state == .pending }.count
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayDate.formatted(.dateTime.year().month().day()))
                    .font(.headline)
                    .foregroundStyle(.primary)

                Text("\(taskCount) tasks · \(pendingCount) open")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
    }
}

private struct PoolRow: View {
    let item: BrainDumpItem
    let actionTitle: String
    let isActionEnabled: Bool
    let onEdit: () -> Void
    let onDelete: () -> Void
    let onAction: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(item.text)
                    .foregroundStyle(.white)
                    .lineLimit(2)

                Text(item.createdAt.formatted(.dateTime.hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            HStack(spacing: 8) {
                Button("Edit", action: onEdit)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                Button("Delete", action: onDelete)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                Button(actionTitle, action: onAction)
                    .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                    .disabled(!isActionEnabled)
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct TaskRow: View {
    let task: LoopTask
    let onMarkDone: () -> Void
    let onRedump: () -> Void
    let onEditTime: () -> Void
    var isReadOnly: Bool = false

    private var stateText: String {
        task.state.symbol
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(task.text)
                    .foregroundStyle(task.state == .pending ? .white : .secondary)
                    .lineLimit(2)

                HStack(spacing: 8) {
                    Text(stateText)
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    Text("\(task.plannedStartAt.formatted(.dateTime.hour().minute())) ~ \(task.plannedEndAt.formatted(.dateTime.hour().minute()))")
                        .font(.caption2.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())

                    if let completedAt = task.completedAt {
                        Text(completedAt.formatted(.dateTime.hour().minute()))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            if !isReadOnly && task.state == .pending {
                HStack(spacing: 8) {
                    Button("Edit", action: onEditTime)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))

                    Button("Done", action: onMarkDone)
                        .buttonStyle(MonochromeButtonStyle(kind: .filled))

                    Button("Re-dump", action: onRedump)
                        .buttonStyle(MonochromeButtonStyle(kind: .ghost))
                }
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.045))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.12), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

private struct EmptyInlineRow: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.callout)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
    }
}

private struct MonochromeButtonStyle: ButtonStyle {
    enum Kind: Equatable {
        case filled
        case ghost
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(kind == .filled ? Color.black : Color.white)
            .background(kind == .filled ? Color.white : Color.clear)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(kind == .filled ? 0 : 0.18), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}

private struct BlackBackgroundView: View {
    var body: some View {
        LinearGradient(
            colors: [Color.black, Color.black.opacity(0.94)],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [BrainDumpItem.self, LoopSession.self, LoopTask.self], inMemory: true)
}
