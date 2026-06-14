import Foundation

public struct KairoBriefingSnapshot: Equatable, Sendable {
    public var pendingCaptureCount: Int
    public var confirmationCount: Int
    public var reminderDraftCount: Int
    public var handoffCount: Int
    public var memoryDraftCount: Int

    public init(
        pendingCaptureCount: Int = 0,
        confirmationCount: Int = 0,
        reminderDraftCount: Int = 0,
        handoffCount: Int = 0,
        memoryDraftCount: Int = 0
    ) {
        self.pendingCaptureCount = pendingCaptureCount
        self.confirmationCount = confirmationCount
        self.reminderDraftCount = reminderDraftCount
        self.handoffCount = handoffCount
        self.memoryDraftCount = memoryDraftCount
    }

    public static let empty = KairoBriefingSnapshot()

    public var hasPendingWork: Bool {
        pendingCaptureCount > 0 || confirmationCount > 0 || reminderDraftCount > 0 || handoffCount > 0 || memoryDraftCount > 0
    }
}

public struct KairoBriefingSnapshotBuilder: Sendable {
    public init() {}

    public func snapshot(from items: [ActionInboxItem]) -> KairoBriefingSnapshot {
        var snapshot = KairoBriefingSnapshot(pendingCaptureCount: items.count)

        for suggestion in items.flatMap(\.suggestions) {
            if suggestion.requiresConfirmation {
                snapshot.confirmationCount += 1
            }

            switch suggestion.kind {
            case .reminderDraft, .calendarDraft, .emailDraft, .messageDraft:
                snapshot.reminderDraftCount += suggestion.kind == .reminderDraft ? 1 : 0
            case .mapsHandoff, .webSearchHandoff, .phoneHandoff:
                snapshot.handoffCount += 1
            case .memorySave:
                snapshot.memoryDraftCount += 1
            case .summary, .setupRequired, .unsupported:
                break
            }
        }

        return snapshot
    }
}
