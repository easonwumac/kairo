import Foundation

public enum AgentToolInvocationSource: String, Codable, Equatable, Sendable {
    case installedSkill
    case integrationRegistry
    case actionCatalog
}

public struct AgentToolInvocationRequest: Codable, Equatable, Sendable {
    public var userText: String
    public var allowsToolUse: Bool

    public init(userText: String, allowsToolUse: Bool = true) {
        self.userText = userText
        self.allowsToolUse = allowsToolUse
    }
}

public struct AgentToolInvocationPlan: Codable, Equatable, Sendable {
    public var candidates: [AgentToolInvocationCandidate]
    public var unsupportedMessage: String?

    public init(candidates: [AgentToolInvocationCandidate], unsupportedMessage: String? = nil) {
        self.candidates = candidates
        self.unsupportedMessage = unsupportedMessage
    }

    public var proposedActions: [AgentAction] {
        candidates.compactMap(\.action)
    }
}

public struct AgentToolInvocationCandidate: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var source: AgentToolInvocationSource
    public var skillID: String?
    public var integrationKey: String?
    public var skillKind: AgentSkillKind
    public var shortcutRecipeID: String?
    public var requiredCapabilities: [CapabilityKey]
    public var riskTier: ActionRiskTier
    public var requiresConfirmation: Bool
    public var handoffSummary: String
    public var action: AgentAction?

    public init(
        id: String,
        title: String,
        source: AgentToolInvocationSource,
        skillID: String? = nil,
        integrationKey: String? = nil,
        skillKind: AgentSkillKind,
        shortcutRecipeID: String? = nil,
        requiredCapabilities: [CapabilityKey],
        riskTier: ActionRiskTier,
        requiresConfirmation: Bool,
        handoffSummary: String,
        action: AgentAction? = nil
    ) {
        self.id = id
        self.title = title
        self.source = source
        self.skillID = skillID
        self.integrationKey = integrationKey
        self.skillKind = skillKind
        self.shortcutRecipeID = shortcutRecipeID
        self.requiredCapabilities = requiredCapabilities
        self.riskTier = riskTier
        self.requiresConfirmation = requiresConfirmation
        self.handoffSummary = handoffSummary
        self.action = action
    }
}

public struct AgentToolInvocationPlanner: Sendable {
    public var skillCatalog: AgentSkillCatalog
    public var integrationRegistry: IntegrationRegistry
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        skillCatalog: AgentSkillCatalog = .default,
        integrationRegistry: IntegrationRegistry = IntegrationRegistry(),
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.skillCatalog = skillCatalog
        self.integrationRegistry = integrationRegistry
        self.safetyPolicyEngine = safetyPolicyEngine
    }

    public func plan(for request: AgentToolInvocationRequest) -> AgentToolInvocationPlan {
        guard request.allowsToolUse else {
            return AgentToolInvocationPlan(
                candidates: [],
                unsupportedMessage: "Local model fallback cannot use tools, browse the web, or perform account actions."
            )
        }

        let normalizedText = normalize(request.userText)
        guard !normalizedText.isEmpty else {
            return AgentToolInvocationPlan(candidates: [])
        }

        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: skillCatalog.installedSkills.compactMap { skill in
            candidate(for: skill, normalizedText: normalizedText)
        })
        candidates.append(contentsOf: integrationRegistry.oauthConnectors.compactMap { integration in
            candidate(for: integration, normalizedText: normalizedText)
        })
        if let calendarCandidate = calendarActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(calendarCandidate)
        }
        if let reminderCandidate = reminderActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(reminderCandidate)
        }
        if let notificationCandidate = notificationActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(notificationCandidate)
        }

        return AgentToolInvocationPlan(candidates: uniqueCandidates(candidates))
    }

    private func candidate(for skill: AgentSkill, normalizedText: String) -> AgentToolInvocationCandidate? {
        switch skill.kind {
        case .homeKitControl:
            guard matchesHomeKit(skill: skill, normalizedText: normalizedText) else { return nil }
            let riskTier = skill.action?.riskTier ?? .tier3HighRiskExternal
            let requiresConfirmation = skill.action.map { safetyPolicyEngine.evaluate($0).requiresConfirmation } ?? riskTier.requiresConfirmation
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: riskTier,
                requiresConfirmation: requiresConfirmation,
                handoffSummary: "Preview the installed HomeKit skill; HomeKit permission and visible confirmation are required before execution.",
                action: skill.action
            )
        case .shortcutWorkflow:
            guard matchesShortcut(skill: skill, normalizedText: normalizedText) else { return nil }
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                shortcutRecipeID: skill.shortcutRecipeID,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: .tier1Draft,
                requiresConfirmation: true,
                handoffSummary: "Visible App Intents/Shortcuts handoff; Kairo does not install Apple Shortcuts silently."
            )
        case .oauthConnector:
            guard matchesGenericSkill(skill, normalizedText: normalizedText) else { return nil }
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: .tier3HighRiskExternal,
                requiresConfirmation: true,
                handoffSummary: "Use the installed OAuth connector through official OAuth/API access; private app data is unavailable."
            )
        case .custom:
            guard matchesGenericSkill(skill, normalizedText: normalizedText) else { return nil }
            return AgentToolInvocationCandidate(
                id: "skill-\(skill.id)",
                title: skill.displayName,
                source: .installedSkill,
                skillID: skill.id,
                skillKind: skill.kind,
                requiredCapabilities: skill.requiredCapabilities,
                riskTier: skill.action?.riskTier ?? .tier1Draft,
                requiresConfirmation: (skill.action?.riskTier ?? .tier1Draft).requiresConfirmation,
                handoffSummary: "Use the installed managed skill package through Kairo's confirmation flow.",
                action: skill.action
            )
        case .localModel:
            return nil
        }
    }

    private func candidate(for integration: AppIntegration, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard matchesIntegration(integration, normalizedText: normalizedText) else {
            return nil
        }

        return AgentToolInvocationCandidate(
            id: "integration-\(integration.key)",
            title: integration.displayName,
            source: .integrationRegistry,
            integrationKey: integration.key,
            skillKind: .oauthConnector,
            requiredCapabilities: integration.requiredCapabilities,
            riskTier: .tier3HighRiskExternal,
            requiresConfirmation: true,
            handoffSummary: "Use \(integration.displayName) through official OAuth/API connector metadata; private app data is unavailable and account writes require confirmation."
        )
    }

    private func matchesHomeKit(skill: AgentSkill, normalizedText: String) -> Bool {
        if skill.id.contains("desk-lamp") {
            return containsAny(normalizedText, ["desk lamp", "lamp", "light", "office", "燈", "檯燈", "書桌"])
        }

        if skill.id.contains("evening-scene") {
            return containsAny(normalizedText, ["evening", "scene", "wind down", "homekit", "home", "晚安", "場景", "家庭"])
        }

        return containsAny(normalizedText, ["homekit", "home", "家庭", "燈", "門鎖", "冷氣"])
    }

    private func matchesShortcut(skill: AgentSkill, normalizedText: String) -> Bool {
        switch skill.shortcutRecipeID {
        case "daily-briefing":
            return containsAny(normalizedText, ["daily", "briefing", "morning", "agenda", "每天", "早上", "簡報"])
        case "save-shared-text":
            return containsAny(normalizedText, ["todo", "task", "tasks", "reminder", "share", "shared text", "text", "待辦", "提醒", "分享", "內容"])
        case "screenshot-to-reminders":
            return containsAny(normalizedText, ["screenshot", "ocr", "image", "photo", "reminder", "截圖", "圖片", "照片", "提醒"])
        case "reply-draft-from-shared-text":
            return containsAny(normalizedText, ["reply", "draft reply", "respond", "email reply", "message reply", "回覆", "回信", "覆信", "草稿"])
        case "meeting-prep-brief":
            return containsAny(normalizedText, ["meeting", "meeting prep", "prepare meeting", "customer meeting", "calendar", "會議", "開會", "會前", "準備"])
        default:
            return matchesGenericSkill(skill, normalizedText: normalizedText)
        }
    }

    private func matchesGenericSkill(_ skill: AgentSkill, normalizedText: String) -> Bool {
        let searchable = normalize("\(skill.id) \(skill.displayName) \(skill.summary)")
        return searchable
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { token in
                token.count >= 4 && normalizedText.contains(token)
            }
    }

    private func matchesIntegration(_ integration: AppIntegration, normalizedText: String) -> Bool {
        switch integration.key {
        case "gmail-google-workspace":
            return containsAny(normalizedText, ["gmail", "google workspace", "email", "mail", "郵件", "信箱"])
        case "microsoft-365":
            return containsAny(normalizedText, ["microsoft", "outlook", "365", "teams"])
        case "notion":
            return containsAny(normalizedText, ["notion"])
        case "slack":
            return containsAny(normalizedText, ["slack"])
        case "chatgpt":
            return containsAny(normalizedText, ["chatgpt", "openai"])
        case "github":
            return containsAny(normalizedText, ["github", "repo", "repository", "issue", "pull request", "pr"])
        default:
            return normalize("\(integration.key) \(integration.displayName)").split(separator: " ").contains { token in
                token.count >= 4 && normalizedText.contains(token)
            }
        }
    }

    private func notificationActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard !isCalendarWriteRequest(normalizedText) else {
            return nil
        }
        guard !isReminderWriteRequest(normalizedText) else {
            return nil
        }
        guard containsAny(normalizedText, [
            "notify me",
            "notification",
            "send notification",
            "remind me",
            "reminder alert",
            "通知我",
            "通知",
            "提醒我",
            "提醒"
        ]) else {
            return nil
        }

        let draft = NotificationDraft(
            title: "Kairo Notification",
            body: notificationBody(from: userText)
        )
        let action = AgentAction(
            kind: .sendNotification,
            title: "Schedule Local Notification",
            rationale: "User asked Kairo to prepare a local notification through the public UserNotifications API.",
            payload: .notification(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-send-notification",
            title: "Schedule Local Notification",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.notifications],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use UserNotifications for a local notification after runtime permission and visible confirmation.",
            action: action
        )
    }

    private func calendarActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isCalendarWriteRequest(normalizedText) else {
            return nil
        }

        let startDate = Date().addingTimeInterval(3600)
        let draft = CalendarEventDraft(
            title: calendarTitle(from: userText),
            notes: "Drafted from a Kairo chat request.",
            startDate: startDate,
            endDate: startDate.addingTimeInterval(3600)
        )
        let action = AgentAction(
            kind: .createCalendarDraft,
            title: "Create Calendar Event",
            rationale: "User asked Kairo to create a calendar event through the public EventKit Calendar API.",
            payload: .calendarEvent(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-calendar-event",
            title: "Create Calendar Event",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.calendar],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use EventKit Calendar after runtime permission and visible confirmation.",
            action: action
        )
    }

    private func reminderActionCandidate(userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard isReminderWriteRequest(normalizedText) else {
            return nil
        }

        let draft = ReminderDraft(
            title: reminderTitle(from: userText),
            notes: "Drafted from a Kairo chat request.",
            dueDate: nil
        )
        let action = AgentAction(
            kind: .createReminderDraft,
            title: "Create Reminder",
            rationale: "User asked Kairo to create a reminder through the public EventKit Reminders API.",
            payload: .reminder(draft),
            riskTier: .tier2LowRiskWrite
        )

        return AgentToolInvocationCandidate(
            id: "action-create-reminder",
            title: "Create Reminder",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.reminders],
            riskTier: .tier2LowRiskWrite,
            requiresConfirmation: true,
            handoffSummary: "Use EventKit Reminders after runtime permission and visible confirmation.",
            action: action
        )
    }

    private func isCalendarWriteRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "create a calendar event",
            "create calendar event",
            "add a calendar event",
            "add calendar event",
            "create an event",
            "add an event",
            "schedule event",
            "calendar event",
            "建立行程",
            "新增行程",
            "加入行程",
            "建立日曆",
            "新增日曆",
            "加入日曆"
        ])
    }

    private func isReminderWriteRequest(_ normalizedText: String) -> Bool {
        containsAny(normalizedText, [
            "create a reminder",
            "create reminder",
            "add a reminder",
            "add reminder",
            "reminder to",
            "task reminder",
            "提醒事項",
            "建立提醒",
            "新增提醒",
            "加入提醒",
            "建立待辦",
            "新增待辦",
            "加入待辦"
        ])
    }

    private func calendarTitle(from userText: String) -> String {
        var title = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Create a calendar event:",
            "Create calendar event:",
            "Add a calendar event:",
            "Add calendar event:",
            "Create an event:",
            "Add an event:",
            "Schedule event:",
            "Calendar event:",
            "建立行程：",
            "建立行程:",
            "新增行程：",
            "新增行程:",
            "加入行程：",
            "加入行程:",
            "建立日曆：",
            "建立日曆:",
            "新增日曆：",
            "新增日曆:"
        ]

        for prefix in prefixes where title.lowercased().hasPrefix(prefix.lowercased()) {
            title.removeFirst(prefix.count)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        return title.isEmpty ? "Kairo calendar event" : title
    }

    private func reminderTitle(from userText: String) -> String {
        var title = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefixes = [
            "Create a reminder to",
            "Create reminder to",
            "Add a reminder to",
            "Add reminder to",
            "Reminder:",
            "Todo:",
            "TODO:",
            "建立提醒事項：",
            "建立提醒事項:",
            "建立提醒：",
            "建立提醒:",
            "新增提醒事項：",
            "新增提醒事項:",
            "待辦：",
            "待辦:"
        ]

        for prefix in prefixes where title.lowercased().hasPrefix(prefix.lowercased()) {
            title.removeFirst(prefix.count)
            title = title.trimmingCharacters(in: .whitespacesAndNewlines)
            break
        }

        return title.isEmpty ? "Kairo reminder" : title
    }

    private func notificationBody(from userText: String) -> String {
        let trimmed = userText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Kairo notification requested by the user."
        }
        return trimmed
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains(normalize($0)) }
    }

    private func normalize(_ value: String) -> String {
        value
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func uniqueCandidates(_ candidates: [AgentToolInvocationCandidate]) -> [AgentToolInvocationCandidate] {
        var seen: Set<String> = []
        var result: [AgentToolInvocationCandidate] = []

        for candidate in candidates where !seen.contains(candidate.id) {
            seen.insert(candidate.id)
            result.append(candidate)
        }

        return result
    }
}
