import Foundation

public struct AgentAction: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var kind: AgentActionKind
    public var title: String
    public var rationale: String
    public var payload: AgentActionPayload
    public var riskTier: ActionRiskTier
    public var requiresConfirmation: Bool

    public init(
        id: UUID = UUID(),
        kind: AgentActionKind,
        title: String,
        rationale: String,
        payload: AgentActionPayload,
        riskTier: ActionRiskTier
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.rationale = rationale
        self.payload = payload
        self.riskTier = riskTier
        self.requiresConfirmation = riskTier.requiresConfirmation
    }
}

public enum AgentActionKind: String, Codable, CaseIterable, Sendable {
    case answer
    case saveMemory
    case createReminderDraft
    case createCalendarDraft
    case sendNotification
    case openURL
    case externalAPIRequest
    case unsupportedSandboxAction
}

public enum AgentActionPayload: Codable, Equatable, Sendable {
    case text(String)
    case reminder(ReminderDraft)
    case calendarEvent(CalendarEventDraft)
    case notification(NotificationDraft)
    case url(String)
    case unsupported(UnsupportedActionExplanation)
    case empty
}

public struct ReminderDraft: Codable, Equatable, Sendable {
    public var title: String
    public var notes: String?
    public var dueDate: Date?
}

public struct CalendarEventDraft: Codable, Equatable, Sendable {
    public var title: String
    public var notes: String?
    public var startDate: Date
    public var endDate: Date
}

public struct NotificationDraft: Codable, Equatable, Sendable {
    public var title: String
    public var body: String
    public var deliveryDate: Date?

    public init(title: String, body: String, deliveryDate: Date? = nil) {
        self.title = title
        self.body = body
        self.deliveryDate = deliveryDate
    }
}

public struct UnsupportedActionExplanation: Codable, Equatable, Sendable {
    public var requestedAction: String
    public var reason: String
    public var safeAlternative: String?

    public init(requestedAction: String, reason: String, safeAlternative: String? = nil) {
        self.requestedAction = requestedAction
        self.reason = reason
        self.safeAlternative = safeAlternative
    }
}

public enum ActionRiskTier: String, Codable, CaseIterable, Sendable {
    case tier0ReadOnly
    case tier1Draft
    case tier2LowRiskWrite
    case tier3HighRiskExternal

    public var requiresConfirmation: Bool {
        switch self {
        case .tier0ReadOnly:
            return false
        case .tier1Draft, .tier2LowRiskWrite, .tier3HighRiskExternal:
            return true
        }
    }
}
