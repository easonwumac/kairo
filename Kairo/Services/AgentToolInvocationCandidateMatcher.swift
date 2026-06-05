import Foundation

public protocol AgentToolInvocationCandidateMatching: Sendable {
    func matches(
        skill: AgentSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool
    func matches(
        integration: AppIntegration,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool
    func matches(
        appIntegrationSkill: AppIntegrationSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool
}

public struct DefaultAgentToolInvocationCandidateMatcher: AgentToolInvocationCandidateMatching {
    public init() {}

    public func matches(
        skill: AgentSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        switch skill.kind {
        case .homeKitControl:
            return matchesHomeKit(skill: skill, normalizedText: normalizedText, parser: parser)
        case .shortcutWorkflow:
            return matchesShortcut(skill: skill, normalizedText: normalizedText, parser: parser)
        case .oauthConnector, .custom:
            return matchesGenericSkill(skill, normalizedText: normalizedText, parser: parser)
        case .localModel:
            return false
        }
    }

    public func matches(
        integration: AppIntegration,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        switch integration.key {
        case "gmail-google-workspace":
            return containsAny(normalizedText, ["gmail", "google workspace", "email", "mail", "郵件", "信箱"], parser: parser)
        case "microsoft-365":
            return containsAny(normalizedText, ["microsoft", "outlook", "365", "teams"], parser: parser)
        case "notion":
            return containsAny(normalizedText, ["notion"], parser: parser)
        case "slack":
            return containsAny(normalizedText, ["slack"], parser: parser)
        case "chatgpt":
            return containsAny(normalizedText, ["chatgpt", "openai"], parser: parser)
        case "github":
            return containsAny(normalizedText, ["github", "repository", "pull request"], parser: parser)
                || containsAnyToken(normalizedText, ["repo", "issue", "pr"], parser: parser)
        default:
            return parser.normalize("\(integration.key) \(integration.displayName)").split(separator: " ").contains { token in
                token.count >= 4 && normalizedText.contains(token)
            }
        }
    }

    public func matches(
        appIntegrationSkill skill: AppIntegrationSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        switch skill.id {
        case .appleMailHandoff, .gmailDraftAPI:
            return containsAny(normalizedText, ["gmail", "email", "mail", "compose email", "draft email", "郵件", "信箱", "寫信", "回信"], parser: parser)
        case .appleMessagesHandoff, .whatsappMessageHandoff, .lineShareHandoff:
            return containsAny(normalizedText, ["message", "sms", "text", "whatsapp", "line", "傳訊息", "發訊息", "簡訊"], parser: parser)
        case .applePhoneHandoff:
            return containsAny(normalizedText, ["phone", "call", "dial", "tel", "打電話", "撥號", "致電"], parser: parser)
        case .safariWebSearchHandoff:
            return containsAny(normalizedText, ["web search", "search web", "google", "look up online", "搜尋網路", "查網路"], parser: parser)
        case .appleMapsDirectionsHandoff, .googleMapsDirectionsHandoff:
            return containsAny(normalizedText, ["maps", "google maps", "directions", "navigate", "route", "map directions", "導航", "路線", "帶我去"], parser: parser)
        case .slackOpenHandoff:
            return containsAny(normalizedText, ["slack"], parser: parser)
        case .notionPageAPI:
            return containsAny(normalizedText, ["notion"], parser: parser)
        case .todoistTaskAPI:
            return containsAny(normalizedText, ["todoist", "task", "todo", "待辦", "任務"], parser: parser)
        case .draftsCreateHandoff:
            return containsAny(normalizedText, ["drafts", "draft note", "text draft", "草稿", "筆記草稿"], parser: parser)
        }
    }

    private func matchesHomeKit(
        skill: AgentSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        if skill.id.contains("front-door-lock") {
            return containsAny(normalizedText, ["front door", "door lock", "lock", "unlock", "entry", "門鎖", "前門", "開鎖", "上鎖"], parser: parser)
        }

        if skill.id.contains("desk-lamp") {
            return containsAny(normalizedText, ["desk lamp", "lamp", "light", "office", "燈", "檯燈", "書桌"], parser: parser)
        }

        if skill.id.contains("evening-scene") {
            return containsAny(normalizedText, ["evening", "scene", "wind down", "homekit", "home", "晚安", "場景", "家庭"], parser: parser)
        }

        return containsAny(normalizedText, ["homekit", "home", "家庭", "燈", "門鎖", "冷氣"], parser: parser)
    }

    private func matchesShortcut(
        skill: AgentSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        switch skill.shortcutRecipeID {
        case "daily-briefing":
            return containsAny(normalizedText, ["daily", "briefing", "morning", "agenda", "每天", "早上", "簡報"], parser: parser)
        case "save-shared-text":
            return containsAny(normalizedText, ["todo", "task", "tasks", "reminder", "share", "shared text", "text", "待辦", "提醒", "分享", "內容"], parser: parser)
        case "screenshot-to-reminders":
            return containsAny(normalizedText, ["screenshot", "ocr", "image", "photo", "reminder", "截圖", "圖片", "照片", "提醒"], parser: parser)
        case "reply-draft-from-shared-text":
            return containsAny(normalizedText, ["reply", "draft reply", "respond", "email reply", "message reply", "回覆", "回信", "覆信", "草稿"], parser: parser)
        case "message-reply-handoff":
            return containsAny(normalizedText, ["message", "sms", "text message", "send text", "message reply", "簡訊", "訊息", "傳訊息"], parser: parser)
        case "phone-call-handoff":
            return containsAny(normalizedText, ["phone call", "call", "dial", "tel", "call alex", "打電話", "撥號", "致電"], parser: parser)
        case "email-triage":
            return containsAny(normalizedText, ["email triage", "triage", "inbox", "vendor email", "follow-up", "follow up", "mail tasks", "郵件整理", "信件整理", "分類", "追蹤"], parser: parser)
        case "email-draft-from-shared-text":
            return containsAny(normalizedText, ["email draft", "compose email", "mail draft", "write email", "send draft", "email body", "郵件草稿", "信件草稿", "寫信", "回信草稿"], parser: parser)
        case "contact-draft-from-shared-text":
            return containsAny(normalizedText, ["contact draft", "create contact", "save contact", "business card", "phone number", "通訊錄", "聯絡人", "名片", "電話"], parser: parser)
        case "meeting-prep-brief":
            return containsAny(normalizedText, ["meeting", "meeting prep", "prepare meeting", "customer meeting", "calendar", "會議", "開會", "會前", "準備"], parser: parser)
        default:
            return matchesGenericSkill(skill, normalizedText: normalizedText, parser: parser)
        }
    }

    private func matchesGenericSkill(
        _ skill: AgentSkill,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        let searchable = parser.normalize("\(skill.id) \(skill.displayName) \(skill.summary)")
        return searchable
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { token in
                token.count >= 4 && normalizedText.contains(token)
            }
    }

    private func containsAny(
        _ text: String,
        _ needles: [String],
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        needles.contains { text.contains(parser.normalize($0)) }
    }

    private func containsAnyToken(
        _ text: String,
        _ needles: [String],
        parser: any AgentToolInvocationActionParsing
    ) -> Bool {
        let tokens = Set(text.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        return needles.contains { tokens.contains(parser.normalize($0)) }
    }
}
