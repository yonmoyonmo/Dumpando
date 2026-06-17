//
//  Item.swift
//  dumpando
//
//  Created by yonmo on 6/17/26.
//

import Foundation
import SwiftData

enum LoopTaskState: String, Codable, CaseIterable {
    case pending
    case done
    case redumped

    var label: String {
        switch self {
        case .pending:
            return "PENDING"
        case .done:
            return "DONE"
        case .redumped:
            return "REDUMPED"
        }
    }

    var symbol: String {
        switch self {
        case .pending:
            return "⏳"
        case .done:
            return "✅"
        case .redumped:
            return "🔁"
        }
    }
}

@Model
final class BrainDumpItem {
    var text: String
    var createdAt: Date

    init(text: String, createdAt: Date = .now) {
        self.text = text
        self.createdAt = createdAt
    }
}

@Model
final class LoopSession {
    var startedAt: Date
    var archivedAt: Date?
    var feedback: String

    @Relationship(deleteRule: .cascade, inverse: \LoopTask.session)
    var tasks: [LoopTask] = []

    init(startedAt: Date = .now, archivedAt: Date? = nil, feedback: String = "") {
        self.startedAt = startedAt
        self.archivedAt = archivedAt
        self.feedback = feedback
    }

    var isArchived: Bool {
        archivedAt != nil
    }

    var displayDate: Date {
        archivedAt ?? startedAt
    }
}

@Model
final class LoopTask {
    var text: String
    var createdAt: Date
    var completedAt: Date?
    var plannedStartAt: Date
    var plannedEndAt: Date
    var stateRaw: String

    var session: LoopSession?

    init(
        text: String,
        createdAt: Date = .now,
        completedAt: Date? = nil,
        plannedStartAt: Date = .now,
        plannedEndAt: Date = .now.addingTimeInterval(3600),
        state: LoopTaskState = .pending,
        session: LoopSession? = nil
    ) {
        self.text = text
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.plannedStartAt = plannedStartAt
        self.plannedEndAt = plannedEndAt
        self.stateRaw = state.rawValue
        self.session = session
    }

    var state: LoopTaskState {
        get { LoopTaskState(rawValue: stateRaw) ?? .pending }
        set { stateRaw = newValue.rawValue }
    }
}
