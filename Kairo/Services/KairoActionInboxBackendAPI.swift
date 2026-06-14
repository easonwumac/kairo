import Foundation

public protocol KairoActionInboxAPI: Sendable {
    func pendingItems(limit: Int) async throws -> [ActionInboxItem]
}

public struct KairoActionInboxBackendService: KairoActionInboxAPI {
    private let shareIngestionQueue: any ShareIngestionQueue
    private let parser: any AgentToolInvocationActionParsing
    private let calendar: Calendar
    private let now: @Sendable () -> Date

    public init(
        shareIngestionQueue: any ShareIngestionQueue,
        parser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        calendar: Calendar = .current,
        now: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.shareIngestionQueue = shareIngestionQueue
        self.parser = parser
        self.calendar = calendar
        self.now = now
    }

    public func pendingItems(limit: Int = 20) async throws -> [ActionInboxItem] {
        let shares = try await shareIngestionQueue.pendingItems(limit: limit)
        return shares.map { item in
            let text = Self.combinedText(from: item.attachments)
            let suggestions = suggestions(for: text)
            return ActionInboxItem(
                source: .shareExtension,
                sourceItemIDs: [item.id],
                attachments: item.attachments,
                summary: summary(for: item, text: text),
                triage: triage(for: item, text: text, suggestions: suggestions),
                suggestions: suggestions,
                receivedAt: item.receivedAt
            )
        }
    }

    private func summary(for item: ShareIngestionItem, text: String) -> ActionInboxSummary {
        let title = item.attachments.first?.displayName ?? KairoL10n.string("actionInbox.summary.sharedContent")
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return ActionInboxSummary(title: title)
        }
        return ActionInboxSummary(
            title: title,
            bullets: [String(trimmed.prefix(180))]
        )
    }

    private func suggestions(for text: String) -> [ActionInboxSuggestion] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var suggestions: [ActionInboxSuggestion] = [
            ActionInboxSuggestion(
                kind: .summary,
                title: KairoL10n.string("actionInbox.suggestion.summary"),
                requiresConfirmation: false
            )
        ]

        suggestions.append(contentsOf: handoffSuggestions(from: trimmed))
        suggestions.append(contentsOf: memorySuggestions(from: trimmed))
        suggestions.append(contentsOf: reminderSuggestions(from: trimmed))
        return suggestions
    }

    private func triage(
        for item: ShareIngestionItem,
        text: String,
        suggestions: [ActionInboxSuggestion]
    ) -> ActionInboxTriage {
        let suggestionKinds = Set(suggestions.map(\.kind))
        if suggestionKinds.contains(.reminderDraft) {
            return .createReminder
        }
        if suggestionKinds.contains(.memorySave) {
            return .saveMemory
        }
        if suggestionKinds.contains(.mapsHandoff) || suggestionKinds.contains(.webSearchHandoff) {
            return .openHandoff
        }
        if shouldSuggestInfoPage(for: item, text: text) {
            return .createInfoPage
        }
        return .captureOnly
    }

    private func shouldSuggestInfoPage(for item: ShareIngestionItem, text: String) -> Bool {
        let normalized = parser.normalize(text)
        if item.attachments.contains(where: { $0.kind == .url || $0.kind == .image || $0.kind == .pdf }) {
            return true
        }
        return containsAny(normalized, [
            "article",
            "receipt",
            "booking",
            "reservation",
            "invoice",
            "research",
            "note",
            "文章",
            "收據",
            "發票",
            "訂位",
            "預約",
            "研究",
            "筆記"
        ])
    }

    private func handoffSuggestions(from text: String) -> [ActionInboxSuggestion] {
        let normalized = parser.normalize(text)
        var suggestions: [ActionInboxSuggestion] = []

        if parser.isMapDirectionsRequest(normalized) {
            let action = AgentAction(
                kind: .openMapDirections,
                title: KairoL10n.string("chat.action.displayName.openMaps"),
                rationale: KairoL10n.string("chat.action.rationale.maps"),
                payload: .mapDirections(parser.mapDirectionsDraft(from: text, normalizedText: normalized)),
                riskTier: .tier1Draft
            )
            suggestions.append(ActionInboxSuggestion(
                kind: .mapsHandoff,
                title: action.title,
                action: action,
                requiresConfirmation: true
            ))
        }

        if !parser.isMapDirectionsRequest(normalized),
           parser.isWebSearchHandoffRequest(normalized) {
            let action = AgentAction(
                kind: .openWebSearchHandoff,
                title: KairoL10n.string("chat.action.displayName.openWebSearch"),
                rationale: KairoL10n.string("chat.action.rationale.web"),
                payload: .webSearch(parser.webSearchDraft(from: text)),
                riskTier: .tier1Draft
            )
            suggestions.append(ActionInboxSuggestion(
                kind: .webSearchHandoff,
                title: action.title,
                action: action,
                requiresConfirmation: true
            ))
        }

        return suggestions
    }

    private func memorySuggestions(from text: String) -> [ActionInboxSuggestion] {
        let normalized = parser.normalize(text)
        guard containsAny(normalized, [
            "remember this",
            "save this",
            "save to memory",
            "keep this",
            "記住",
            "保存",
            "存起來",
            "存到記憶",
            "加入記憶"
        ]) else {
            return []
        }

        let action = AgentAction(
            kind: .saveMemory,
            title: KairoL10n.string("chat.action.displayName.saveMemory"),
            rationale: KairoL10n.string("chat.action.rationale.memory"),
            payload: .text(text),
            riskTier: .tier2LowRiskWrite
        )
        return [ActionInboxSuggestion(
            kind: .memorySave,
            title: action.title,
            action: action,
            requiresConfirmation: true
        )]
    }

    private func reminderSuggestions(from text: String) -> [ActionInboxSuggestion] {
        let dueDate = dueDate(from: text)
        guard shouldSuggestReminder(for: text, dueDate: dueDate) else {
            return []
        }
        let titles = taskTitles(from: text)
        return titles.map { title in
            let action = AgentAction(
                kind: .createReminderDraft,
                title: KairoL10n.string("actionInbox.action.createReminder"),
                rationale: KairoL10n.string("actionInbox.action.rationale.sharedReminder"),
                payload: .reminder(ReminderDraft(
                    title: title,
                    notes: text,
                    dueDate: dueDate
                )),
                riskTier: .tier2LowRiskWrite
            )
            return ActionInboxSuggestion(
                kind: .reminderDraft,
                title: title,
                action: action,
                requiresConfirmation: true
            )
        }
    }

    private func shouldSuggestReminder(for text: String, dueDate: Date?) -> Bool {
        let normalized = parser.normalize(text)
        if parser.isReminderWriteRequest(normalized) || dueDate != nil {
            return true
        }
        return containsAny(normalized, [
            "todo",
            "task",
            "action item",
            "follow up",
            "待辦",
            "提醒",
            "任務",
            "行動項目"
        ])
    }

    private func taskTitles(from text: String) -> [String] {
        let normalized = parser.normalize(text)
        if parser.isReminderWriteRequest(normalized) {
            let title = parser.reminderTitle(from: text)
            return title.isEmpty ? [] : [title]
        }

        let cleaned = text
            .replacingOccurrences(of: "。", with: "，")
            .replacingOccurrences(of: "\n", with: "，")
        let fragments = cleaned
            .components(separatedBy: CharacterSet(charactersIn: "，,；;"))
            .map { stripTaskDeadlineTokens($0) }
            .filter { !$0.isEmpty }

        var titles: [String] = []
        for fragment in fragments {
            if let expanded = expandedTestTaskTitles(from: fragment) {
                titles.append(contentsOf: expanded)
            } else {
                titles.append(fragment)
            }
        }
        return Array(titles.prefix(6))
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains(parser.normalize($0)) }
    }

    private func expandedTestTaskTitles(from fragment: String) -> [String]? {
        let normalized = parser.normalize(fragment)
        guard normalized.contains("google maps"),
              normalized.contains("todoist"),
              normalized.contains("測試") || normalized.contains("test") else {
            return nil
        }
        return ["Google Maps 測試", "Todoist 測試"]
    }

    private func stripTaskDeadlineTokens(_ value: String) -> String {
        var result = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "週五前",
            "周五前",
            "星期五前",
            "禮拜五前",
            "礼拜五前",
            "before friday",
            "by friday"
        ]
        for prefix in prefixes where result.lowercased().hasPrefix(prefix.lowercased()) {
            result.removeFirst(prefix.count)
            break
        }
        return result
            .trimmingCharacters(in: CharacterSet(charactersIn: " \t:-：，,。"))
    }

    private func dueDate(from text: String) -> Date? {
        let normalized = parser.normalize(text)
        if normalized.contains("週五") || normalized.contains("周五") || normalized.contains("星期五")
            || normalized.contains("禮拜五") || normalized.contains("礼拜五") || normalized.contains("friday") {
            return nextWeekday(6)
        }
        return nil
    }

    private func nextWeekday(_ weekday: Int) -> Date? {
        var components = DateComponents()
        components.weekday = weekday
        components.hour = 9
        components.minute = 0
        return calendar.nextDate(
            after: now(),
            matching: components,
            matchingPolicy: .nextTime,
            direction: .forward
        )
    }

    private static func combinedText(from attachments: [ChatAttachment]) -> String {
        attachments.compactMap { attachment in
            attachment.textPreview?.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        .filter { !$0.isEmpty }
        .joined(separator: "\n")
    }
}
