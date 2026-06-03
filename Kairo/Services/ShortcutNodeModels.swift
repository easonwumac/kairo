import Foundation

public enum ShortcutNodeKind: String, Codable, CaseIterable, Sendable {
    case ask
    case saveMemory
    case searchMemory
    case summarize
    case extractTasks
    case createReminderDraft
    case createCalendarDraft
    case createContactDraft
    case createEmailDraft
    case prepareMessageHandoff
    case preparePhoneCallHandoff
    case prepareWebSearchHandoff
    case createRecipeDraft
    case draftReply
    case dailyBriefing
    case previewHomeAction
}

public struct ShortcutNodeInput: Codable, Equatable, Sendable {
    public var text: String
    public var query: String?
    public var sourceName: String?
    public var variables: [String: String]
    public var limit: Int

    public init(
        text: String = "",
        query: String? = nil,
        sourceName: String? = nil,
        variables: [String: String] = [:],
        limit: Int = 10
    ) {
        self.text = text
        self.query = query
        self.sourceName = sourceName
        self.variables = variables
        self.limit = limit
    }

    public func encodedJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public struct ShortcutTaskDraft: Codable, Equatable, Sendable {
    public var title: String
    public var notes: String?

    public init(title: String, notes: String? = nil) {
        self.title = title
        self.notes = notes
    }
}

public struct ShortcutMemoryMatch: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var title: String
    public var summary: String

    public init(id: UUID, title: String, summary: String) {
        self.id = id
        self.title = title
        self.summary = summary
    }
}

public struct ShortcutNodeOutput: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var kind: ShortcutNodeKind
    public var displayText: String
    public var fields: [String: String]
    public var memoryID: UUID?
    public var memoryMatches: [ShortcutMemoryMatch]
    public var tasks: [ShortcutTaskDraft]
    public var reminderDrafts: [ReminderDraft]
    public var calendarDrafts: [CalendarEventDraft]
    public var contactDrafts: [ContactDraft]
    public var emailDrafts: [EmailDraft]
    public var phoneCallDrafts: [PhoneCallDraft]
    public var webSearchDrafts: [WebSearchDraft]
    public var recipeDrafts: [KairoRecipe]
    public var proposedActions: [AgentAction]

    public init(
        kind: ShortcutNodeKind,
        displayText: String,
        schemaVersion: Int = 1,
        fields: [String: String] = [:],
        memoryID: UUID? = nil,
        memoryMatches: [ShortcutMemoryMatch] = [],
        tasks: [ShortcutTaskDraft] = [],
        reminderDrafts: [ReminderDraft] = [],
        calendarDrafts: [CalendarEventDraft] = [],
        contactDrafts: [ContactDraft] = [],
        emailDrafts: [EmailDraft] = [],
        phoneCallDrafts: [PhoneCallDraft] = [],
        webSearchDrafts: [WebSearchDraft] = [],
        recipeDrafts: [KairoRecipe] = [],
        proposedActions: [AgentAction] = []
    ) {
        self.schemaVersion = schemaVersion
        self.kind = kind
        self.displayText = displayText
        self.fields = fields
        self.memoryID = memoryID
        self.memoryMatches = memoryMatches
        self.tasks = tasks
        self.reminderDrafts = reminderDrafts
        self.calendarDrafts = calendarDrafts
        self.contactDrafts = contactDrafts
        self.emailDrafts = emailDrafts
        self.phoneCallDrafts = phoneCallDrafts
        self.webSearchDrafts = webSearchDrafts
        self.recipeDrafts = recipeDrafts
        self.proposedActions = proposedActions
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case kind
        case displayText
        case fields
        case memoryID
        case memoryMatches
        case tasks
        case reminderDrafts
        case calendarDrafts
        case contactDrafts
        case emailDrafts
        case phoneCallDrafts
        case webSearchDrafts
        case recipeDrafts
        case proposedActions
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        kind = try container.decode(ShortcutNodeKind.self, forKey: .kind)
        displayText = try container.decode(String.self, forKey: .displayText)
        fields = try container.decodeIfPresent([String: String].self, forKey: .fields) ?? [:]
        memoryID = try container.decodeIfPresent(UUID.self, forKey: .memoryID)
        memoryMatches = try container.decodeIfPresent([ShortcutMemoryMatch].self, forKey: .memoryMatches) ?? []
        tasks = try container.decodeIfPresent([ShortcutTaskDraft].self, forKey: .tasks) ?? []
        reminderDrafts = try container.decodeIfPresent([ReminderDraft].self, forKey: .reminderDrafts) ?? []
        calendarDrafts = try container.decodeIfPresent([CalendarEventDraft].self, forKey: .calendarDrafts) ?? []
        contactDrafts = try container.decodeIfPresent([ContactDraft].self, forKey: .contactDrafts) ?? []
        emailDrafts = try container.decodeIfPresent([EmailDraft].self, forKey: .emailDrafts) ?? []
        phoneCallDrafts = try container.decodeIfPresent([PhoneCallDraft].self, forKey: .phoneCallDrafts) ?? []
        webSearchDrafts = try container.decodeIfPresent([WebSearchDraft].self, forKey: .webSearchDrafts) ?? []
        recipeDrafts = try container.decodeIfPresent([KairoRecipe].self, forKey: .recipeDrafts) ?? []
        proposedActions = try container.decodeIfPresent([AgentAction].self, forKey: .proposedActions) ?? []
    }

    public func encodedJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public enum ShortcutNodeRuntimeError: Error, Equatable {
    case emptyInput
}
