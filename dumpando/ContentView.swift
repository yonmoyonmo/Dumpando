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
                onSendToLoop: requestPromotion
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
                onRestoreToToday: restoreToToday,
                onArchive: archiveActiveSession
            )
            .tabItem {
                Label("Today", systemImage: "sparkles")
            }
            .tag(RootTab.loop)

            ArchiveScreen(
                archivedSessions: archivedSessions,
                onOpenCurrentLoop: { selectedTab = .loop },
                onDeleteArchive: deleteArchive
            )
            .tabItem {
                Label("Archive", systemImage: "tray.full")
            }
            .tag(RootTab.archive)
        }
        .preferredColorScheme(.light)
        .sheet(item: $pendingPromotion) { draft in
            TimeBoxSheet(
                taskText: draft.text,
                title: "Set time block",
                confirmTitle: "Add to Today",
                startAt: pendingPromotionStartAt,
                endAt: pendingPromotionEndAt,
                onCancel: {
                    pendingPromotion = nil
                    pendingPromotionStartAt = .now
                    pendingPromotionEndAt = .now.addingTimeInterval(3600)
                },
                onConfirm: { startAt, endAt in
                    commitPromotion(
                        draft: draft,
                        startAt: startAt,
                        endAt: endAt
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
                onCancel: { editingDump = nil },
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
                startAt: editingTaskStartAt,
                endAt: editingTaskEndAt,
                onCancel: { editingTaskTime = nil },
                onConfirm: { startAt, endAt in
                    saveTaskTimeEdit(draft: draft, startAt: startAt, endAt: endAt)
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

        if saveContext(fallback: "Could not start Today.") {
            selectedTab = .loop
        }
    }

    private func requestPromotion(_ item: BrainDumpItem) {
        guard activeSession != nil else {
            selectedTab = .loop
            alertMessage = "Start Today first."
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

    private func normalizedTimeRange(startAt: Date, endAt: Date) -> (startAt: Date, endAt: Date) {
        var normalizedEndAt = endAt

        while normalizedEndAt <= startAt {
            normalizedEndAt = Calendar.current.date(byAdding: .day, value: 1, to: normalizedEndAt)
                ?? startAt.addingTimeInterval(3600)
        }

        return (startAt, normalizedEndAt)
    }

    private func commitPromotion(draft: PromotionDraft, startAt: Date, endAt: Date) {
        guard let activeSession else {
            alertMessage = "Start Today first."
            return
        }

        let normalizedRange = normalizedTimeRange(startAt: startAt, endAt: endAt)

        guard let item = modelContext.model(for: draft.itemID) as? BrainDumpItem else {
            alertMessage = "That dump item is no longer available."
            return
        }

        withAnimation {
            modelContext.insert(
                LoopTask(
                    text: item.text,
                    plannedStartAt: normalizedRange.startAt,
                    plannedEndAt: normalizedRange.endAt,
                    session: activeSession
                )
            )
            modelContext.delete(item)
        }

        _ = saveContext(fallback: "Could not move dump into Today.")
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
        let normalizedRange = normalizedTimeRange(startAt: startAt, endAt: endAt)

        guard let task = modelContext.model(for: draft.taskID) as? LoopTask else {
            alertMessage = "That task is no longer available."
            return
        }

        withAnimation {
            task.plannedStartAt = normalizedRange.startAt
            task.plannedEndAt = normalizedRange.endAt
        }

        _ = saveContext(fallback: "Could not update task time.")
    }

    private func restoreToToday(_ task: LoopTask) {
        withAnimation {
            task.state = .pending
            task.completedAt = nil
        }

        _ = saveContext(fallback: "Could not restore task to today.")
    }

    private func restoreToDump(_ task: LoopTask) {
        let trimmed = task.text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        withAnimation {
            modelContext.insert(BrainDumpItem(text: trimmed))
            modelContext.delete(task)
        }

        _ = saveContext(fallback: "Could not restore task to dump.")
    }

    private func markDone(_ task: LoopTask) {
        withAnimation {
            task.state = .done
            task.completedAt = .now
        }

        _ = saveContext(fallback: "Could not mark task as done.")
    }

    private func redump(_ task: LoopTask) {
        restoreToDump(task)
    }

    private func archiveActiveSession() {
        guard let activeSession else { return }
        guard !activeSession.feedback.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        withAnimation {
            activeSession.archivedAt = .now
        }

        if saveContext(fallback: "Could not archive Today.") {
            selectedTab = .archive
        }
    }

    private func deleteArchive(_ session: LoopSession) -> Bool {
        withAnimation {
            modelContext.delete(session)
        }

        return saveContext(fallback: "Could not delete archived Today.")
    }
}
