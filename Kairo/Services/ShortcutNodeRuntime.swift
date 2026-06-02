import Foundation

public enum ShortcutNodeKind: String, Codable, CaseIterable, Sendable {
    case ask
    case saveMemory
    case searchMemory
    case summarize
    case extractTasks
    case createReminderDraft
    case draftReply
    case dailyBriefing
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
    public var kind: ShortcutNodeKind
    public var displayText: String
    public var fields: [String: String]
    public var memoryID: UUID?
    public var memoryMatches: [ShortcutMemoryMatch]
    public var tasks: [ShortcutTaskDraft]
    public var reminderDrafts: [ReminderDraft]
    public var proposedActions: [AgentAction]

    public init(
        kind: ShortcutNodeKind,
        displayText: String,
        fields: [String: String] = [:],
        memoryID: UUID? = nil,
        memoryMatches: [ShortcutMemoryMatch] = [],
        tasks: [ShortcutTaskDraft] = [],
        reminderDrafts: [ReminderDraft] = [],
        proposedActions: [AgentAction] = []
    ) {
        self.kind = kind
        self.displayText = displayText
        self.fields = fields
        self.memoryID = memoryID
        self.memoryMatches = memoryMatches
        self.tasks = tasks
        self.reminderDrafts = reminderDrafts
        self.proposedActions = proposedActions
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

public actor ShortcutNodeRuntime {
    private let memoryStore: MemoryStore

    public init(memoryStore: MemoryStore) {
        self.memoryStore = memoryStore
    }

    public static func live(paths: KairoPaths = KairoSharedAppStorage.paths()) async throws -> ShortcutNodeRuntime {
        let store = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        return ShortcutNodeRuntime(memoryStore: store)
    }

    public func run(_ kind: ShortcutNodeKind, input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        switch kind {
        case .saveMemory:
            return try await saveMemory(input)
        case .searchMemory:
            return try await searchMemory(input)
        case .extractTasks:
            return try extractTasks(input)
        case .createReminderDraft:
            return try createReminderDrafts(input)
        case .draftReply:
            return try draftReply(input)
        case .summarize:
            return try summarize(input)
        case .dailyBriefing:
            return try dailyBriefing(input)
        case .ask:
            return try await ask(input)
        }
    }

    private func saveMemory(_ input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let memory = MemoryRecord(
            title: title(for: text),
            summary: String(text.prefix(160)),
            content: text,
            source: .appIntent,
            tags: input.sourceName.map { ["shortcut", $0] } ?? ["shortcut"]
        )
        try await memoryStore.save(memory)

        let tasks = extractTaskDrafts(from: text)
        var fields = baseFields(for: input)
        fields["memoryID"] = memory.id.uuidString
        fields["taskCount"] = String(tasks.count)

        return ShortcutNodeOutput(
            kind: .saveMemory,
            displayText: "Saved memory. Extracted \(tasks.count) tasks.",
            fields: fields,
            memoryID: memory.id,
            tasks: tasks
        )
    }

    private func searchMemory(_ input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        let query = try validatedText(input.query ?? input.text)
        let limit = max(input.limit, 1)
        let memories = try await memoryStore.search(query: query, limit: limit)
        let matches = memories.map { memory in
            ShortcutMemoryMatch(id: memory.id, title: memory.title, summary: memory.summary)
        }

        var fields = baseFields(for: input)
        fields["query"] = query
        fields["matchCount"] = String(matches.count)

        return ShortcutNodeOutput(
            kind: .searchMemory,
            displayText: "Found \(matches.count) memory matches.",
            fields: fields,
            memoryMatches: matches
        )
    }

    private func extractTasks(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tasks = extractTaskDrafts(from: text)
        var fields = baseFields(for: input)
        fields["taskCount"] = String(tasks.count)

        return ShortcutNodeOutput(
            kind: .extractTasks,
            displayText: "Extracted \(tasks.count) tasks.",
            fields: fields,
            tasks: tasks,
            reminderDrafts: tasks.map { ReminderDraft(title: $0.title, notes: $0.notes, dueDate: nil) }
        )
    }

    private func createReminderDrafts(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tasks = extractTaskDrafts(from: text)
        let reminderDrafts = tasks.isEmpty
            ? [ReminderDraft(title: title(for: text), notes: text, dueDate: nil)]
            : tasks.map { ReminderDraft(title: $0.title, notes: $0.notes, dueDate: nil) }
        var fields = baseFields(for: input)
        fields["reminderDraftCount"] = String(reminderDrafts.count)

        return ShortcutNodeOutput(
            kind: .createReminderDraft,
            displayText: "Prepared \(reminderDrafts.count) reminder drafts.",
            fields: fields,
            reminderDrafts: reminderDrafts
        )
    }

    private func draftReply(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tone = input.variables["tone"]?.trimmingCharacters(in: .whitespacesAndNewlines)
            .nilIfEmpty ?? "polite"
        let context = deterministicSummary(for: text)
        let replyDraft = """
        Thanks for the context. Kairo can help with this: \(context)

        I will review the details and follow up with the next step. No message has been sent automatically.
        """

        var fields = baseFields(for: input)
        fields["replyDraftTone"] = tone
        fields["replyDraft"] = replyDraft
        fields["chainText"] = replyDraft

        return ShortcutNodeOutput(
            kind: .draftReply,
            displayText: "Draft reply ready. Review before sending.",
            fields: fields
        )
    }

    private func summarize(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let summary = deterministicSummary(for: text)
        var fields = baseFields(for: input)
        fields["summary"] = summary
        fields["chainText"] = text

        return ShortcutNodeOutput(
            kind: .summarize,
            displayText: summary,
            fields: fields
        )
    }

    private func dailyBriefing(_ input: ShortcutNodeInput) throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let tasks = extractTaskDrafts(from: text)
        var fields = baseFields(for: input)
        fields["briefing"] = deterministicSummary(for: text)
        fields["taskCount"] = String(tasks.count)

        return ShortcutNodeOutput(
            kind: .dailyBriefing,
            displayText: "Briefing ready with \(tasks.count) suggested actions.",
            fields: fields,
            tasks: tasks
        )
    }

    private func ask(_ input: ShortcutNodeInput) async throws -> ShortcutNodeOutput {
        let text = try validatedText(input.text)
        let memories = try await memoryStore.search(query: text, limit: max(input.limit, 1))
        let memorySummary = memories.first?.summary
        let answer = memorySummary ?? deterministicSummary(for: text)
        var fields = baseFields(for: input)
        fields["answer"] = answer

        return ShortcutNodeOutput(
            kind: .ask,
            displayText: answer,
            fields: fields,
            memoryMatches: memories.map { ShortcutMemoryMatch(id: $0.id, title: $0.title, summary: $0.summary) }
        )
    }

    private func baseFields(for input: ShortcutNodeInput) -> [String: String] {
        var fields = input.variables
        if let sourceName = input.sourceName {
            fields["sourceName"] = sourceName
        }
        return fields
    }

    private func validatedText(_ text: String) throws -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ShortcutNodeRuntimeError.emptyInput
        }
        return trimmed
    }

    private func title(for text: String) -> String {
        String(text.prefix(40))
    }

    private func deterministicSummary(for text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized.count > 180 else { return normalized }
        return "\(normalized.prefix(177))..."
    }

    private func extractTaskDrafts(from text: String) -> [ShortcutTaskDraft] {
        let prefixes = [
            "todo:",
            "action:",
            "reminder:",
            "task:",
            "- [ ]",
            "☐"
        ]

        return text
            .components(separatedBy: .newlines)
            .compactMap { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                let lowercased = trimmed.lowercased()
                guard let prefix = prefixes.first(where: { lowercased.hasPrefix($0) }) else {
                    return nil
                }
                let title = String(trimmed.dropFirst(prefix.count))
                    .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-"))
                guard !title.isEmpty else { return nil }
                return ShortcutTaskDraft(title: title, notes: "Extracted from Shortcut input.")
            }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
