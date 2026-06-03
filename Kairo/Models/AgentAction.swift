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
    case createContactDraft
    case composeEmailDraft
    case openMapDirections
    case openMessageHandoff
    case openPhoneCallHandoff
    case openWebSearchHandoff
    case sendNotification
    case openURL
    case controlHome
    case externalAPIRequest
    case unsupportedSandboxAction
}

public enum AgentActionPayload: Codable, Equatable, Sendable {
    case text(String)
    case reminder(ReminderDraft)
    case calendarEvent(CalendarEventDraft)
    case contact(ContactDraft)
    case email(EmailDraft)
    case mapDirections(MapDirectionsDraft)
    case message(MessageDraft)
    case phoneCall(PhoneCallDraft)
    case webSearch(WebSearchDraft)
    case notification(NotificationDraft)
    case url(String)
    case homeControl(HomeControlRequest)
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

public struct ContactDraft: Codable, Equatable, Sendable {
    public var givenName: String
    public var familyName: String
    public var phoneNumbers: [String]
    public var emailAddresses: [String]
    public var notes: String?

    public init(
        givenName: String,
        familyName: String = "",
        phoneNumbers: [String] = [],
        emailAddresses: [String] = [],
        notes: String? = nil
    ) {
        self.givenName = givenName
        self.familyName = familyName
        self.phoneNumbers = phoneNumbers
        self.emailAddresses = emailAddresses
        self.notes = notes
    }

    public var displayName: String {
        [givenName, familyName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

public struct EmailDraft: Codable, Equatable, Sendable {
    public var to: [String]
    public var cc: [String]
    public var bcc: [String]
    public var subject: String
    public var body: String

    public init(
        to: [String] = [],
        cc: [String] = [],
        bcc: [String] = [],
        subject: String,
        body: String
    ) {
        self.to = to
        self.cc = cc
        self.bcc = bcc
        self.subject = subject
        self.body = body
    }
}

public struct MapDirectionsDraft: Codable, Equatable, Sendable {
    public var destinationQuery: String
    public var mode: MapDirectionsMode

    public init(destinationQuery: String, mode: MapDirectionsMode = .driving) {
        self.destinationQuery = destinationQuery
        self.mode = mode
    }
}

public enum MapDirectionsMode: String, Codable, CaseIterable, Equatable, Sendable {
    case driving
    case walking
    case transit
}

public struct MessageDraft: Codable, Equatable, Sendable {
    public var recipients: [String]
    public var body: String

    public init(recipients: [String] = [], body: String) {
        self.recipients = recipients
        self.body = body
    }
}

public struct PhoneCallDraft: Codable, Equatable, Sendable {
    public var phoneNumber: String
    public var label: String?
    public var notes: String?

    public init(phoneNumber: String, label: String? = nil, notes: String? = nil) {
        self.phoneNumber = phoneNumber
        self.label = label
        self.notes = notes
    }
}

public struct WebSearchDraft: Codable, Equatable, Sendable {
    public var query: String
    public var searchURL: String
    public var providerName: String

    public init(query: String, searchURL: String? = nil, providerName: String = "DuckDuckGo") {
        self.query = query
        self.searchURL = searchURL ?? Self.defaultSearchURL(for: query)
        self.providerName = providerName
    }

    public var urlString: String { searchURL }

    private enum CodingKeys: String, CodingKey {
        case query
        case searchURL
        case urlString
        case providerName
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        query = try container.decode(String.self, forKey: .query)
        searchURL = try container.decodeIfPresent(String.self, forKey: .searchURL)
            ?? container.decodeIfPresent(String.self, forKey: .urlString)
            ?? Self.defaultSearchURL(for: query)
        providerName = try container.decodeIfPresent(String.self, forKey: .providerName) ?? "DuckDuckGo"
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(query, forKey: .query)
        try container.encode(searchURL, forKey: .searchURL)
        try container.encode(providerName, forKey: .providerName)
    }

    private static func defaultSearchURL(for query: String) -> String {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "duckduckgo.com"
        components.path = "/"
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        return components.url?.absoluteString ?? "https://duckduckgo.com/"
    }
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

public struct HomeControlRequest: Codable, Equatable, Sendable {
    public var homeName: String?
    public var roomName: String?
    public var targetName: String
    public var command: HomeControlCommand
    public var value: HomeControlValue?

    public init(
        homeName: String? = nil,
        roomName: String? = nil,
        targetName: String,
        command: HomeControlCommand,
        value: HomeControlValue? = nil
    ) {
        self.homeName = homeName
        self.roomName = roomName
        self.targetName = targetName
        self.command = command
        self.value = value
    }
}

public enum HomeControlCommand: String, Codable, Equatable, Sendable {
    case runScene
    case setPower
    case setBrightness
    case setTargetTemperature
}

public enum HomeControlValue: Codable, Equatable, Sendable {
    case bool(Bool)
    case double(Double)
    case string(String)
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

public enum ActionRiskTier: String, Codable, CaseIterable, Sendable, Comparable {
    case tier0ReadOnly
    case tier1Draft
    case tier2LowRiskWrite
    case tier3HighRiskExternal

    public static func < (lhs: ActionRiskTier, rhs: ActionRiskTier) -> Bool {
        lhs.sortOrder < rhs.sortOrder
    }

    public var sortOrder: Int {
        switch self {
        case .tier0ReadOnly:
            return 0
        case .tier1Draft:
            return 1
        case .tier2LowRiskWrite:
            return 2
        case .tier3HighRiskExternal:
            return 3
        }
    }

    public var requiresConfirmation: Bool {
        switch self {
        case .tier0ReadOnly:
            return false
        case .tier1Draft, .tier2LowRiskWrite, .tier3HighRiskExternal:
            return true
        }
    }
}
