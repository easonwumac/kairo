import Foundation

extension AgentToolInvocationPlanner {
    func candidate(for skill: AgentSkill, normalizedText: String) -> AgentToolInvocationCandidate? {
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
                handoffSummary: KairoL10n.string("chat.tool.summary.homeKitSkill"),
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
                handoffSummary: shortcutHandoffSummary(for: skill)
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
                handoffSummary: KairoL10n.string("chat.tool.summary.oauthSkill")
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
                handoffSummary: KairoL10n.string("chat.tool.summary.managedSkill"),
                action: skill.action
            )
        case .localModel:
            return nil
        }
    }

    func candidate(for integration: AppIntegration, normalizedText: String) -> AgentToolInvocationCandidate? {
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
            handoffSummary: KairoL10n.string("chat.tool.summary.integration", integration.displayName)
        )
    }

    func candidate(for skill: AppIntegrationSkill, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard matchesAppIntegration(skill, normalizedText: normalizedText) else {
            return nil
        }
        guard skill.availabilityStatus != .disabled, skill.availabilityStatus != .unsupported else {
            return nil
        }

        return AgentToolInvocationCandidate(
            id: "app-integration-\(skill.id.rawValue)",
            title: skill.appName,
            source: .appIntegrationCatalog,
            integrationKey: skill.integrationKey,
            skillKind: skill.executionMode == .apiCall ? .oauthConnector : .custom,
            requiredCapabilities: skill.audit.capabilityKeys,
            riskTier: skill.riskTier,
            requiresConfirmation: skill.requiresConfirmation,
            handoffSummary: appIntegrationHandoffSummary(for: skill)
        )
    }

    func matchesHomeKit(skill: AgentSkill, normalizedText: String) -> Bool {
        if skill.id.contains("front-door-lock") {
            return containsAny(normalizedText, ["front door", "door lock", "lock", "unlock", "entry", "門鎖", "前門", "開鎖", "上鎖"])
        }

        if skill.id.contains("desk-lamp") {
            return containsAny(normalizedText, ["desk lamp", "lamp", "light", "office", "燈", "檯燈", "書桌"])
        }

        if skill.id.contains("evening-scene") {
            return containsAny(normalizedText, ["evening", "scene", "wind down", "homekit", "home", "晚安", "場景", "家庭"])
        }

        return containsAny(normalizedText, ["homekit", "home", "家庭", "燈", "門鎖", "冷氣"])
    }

    func matchesShortcut(skill: AgentSkill, normalizedText: String) -> Bool {
        switch skill.shortcutRecipeID {
        case "daily-briefing":
            return containsAny(normalizedText, ["daily", "briefing", "morning", "agenda", "每天", "早上", "簡報"])
        case "save-shared-text":
            return containsAny(normalizedText, ["todo", "task", "tasks", "reminder", "share", "shared text", "text", "待辦", "提醒", "分享", "內容"])
        case "screenshot-to-reminders":
            return containsAny(normalizedText, ["screenshot", "ocr", "image", "photo", "reminder", "截圖", "圖片", "照片", "提醒"])
        case "reply-draft-from-shared-text":
            return containsAny(normalizedText, ["reply", "draft reply", "respond", "email reply", "message reply", "回覆", "回信", "覆信", "草稿"])
        case "message-reply-handoff":
            return containsAny(normalizedText, ["message", "sms", "text message", "send text", "message reply", "簡訊", "訊息", "傳訊息"])
        case "phone-call-handoff":
            return containsAny(normalizedText, ["phone call", "call", "dial", "tel", "call alex", "打電話", "撥號", "致電"])
        case "email-triage":
            return containsAny(normalizedText, ["email triage", "triage", "inbox", "vendor email", "follow-up", "follow up", "mail tasks", "郵件整理", "信件整理", "分類", "追蹤"])
        case "email-draft-from-shared-text":
            return containsAny(normalizedText, ["email draft", "compose email", "mail draft", "write email", "send draft", "email body", "郵件草稿", "信件草稿", "寫信", "回信草稿"])
        case "contact-draft-from-shared-text":
            return containsAny(normalizedText, ["contact draft", "create contact", "save contact", "business card", "phone number", "通訊錄", "聯絡人", "名片", "電話"])
        case "meeting-prep-brief":
            return containsAny(normalizedText, ["meeting", "meeting prep", "prepare meeting", "customer meeting", "calendar", "會議", "開會", "會前", "準備"])
        default:
            return matchesGenericSkill(skill, normalizedText: normalizedText)
        }
    }

    func shortcutHandoffSummary(for skill: AgentSkill) -> String {
        let boundary = KairoL10n.string("chat.tool.summary.shortcutBoundary")
        guard
            let recipeID = skill.shortcutRecipeID,
            let recipe = ShortcutDemoCatalog.default.recipe(id: recipeID)
        else {
            return boundary
        }
        return "\(boundary) \(recipe.settingsStepSummary). \(recipe.settingsInputSummary). \(recipe.settingsOutputSummary)."
    }

    func matchesGenericSkill(_ skill: AgentSkill, normalizedText: String) -> Bool {
        let searchable = normalize("\(skill.id) \(skill.displayName) \(skill.summary)")
        return searchable
            .split(whereSeparator: { !$0.isLetter && !$0.isNumber })
            .contains { token in
                token.count >= 4 && normalizedText.contains(token)
            }
    }

    func matchesIntegration(_ integration: AppIntegration, normalizedText: String) -> Bool {
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

    func matchesAppIntegration(_ skill: AppIntegrationSkill, normalizedText: String) -> Bool {
        switch skill.id {
        case .appleMailHandoff, .gmailDraftAPI:
            return containsAny(normalizedText, ["gmail", "email", "mail", "compose email", "draft email", "郵件", "信箱", "寫信", "回信"])
        case .appleMessagesHandoff, .whatsappMessageHandoff, .lineShareHandoff:
            return containsAny(normalizedText, ["message", "sms", "text", "whatsapp", "line", "傳訊息", "發訊息", "簡訊"])
        case .applePhoneHandoff:
            return containsAny(normalizedText, ["phone", "call", "dial", "tel", "打電話", "撥號", "致電"])
        case .safariWebSearchHandoff:
            return containsAny(normalizedText, ["web search", "search web", "google", "look up online", "搜尋網路", "查網路"])
        case .appleMapsDirectionsHandoff, .googleMapsDirectionsHandoff:
            return containsAny(normalizedText, ["maps", "google maps", "directions", "navigate", "route", "map directions", "導航", "路線", "帶我去"])
        case .slackOpenHandoff:
            return containsAny(normalizedText, ["slack"])
        case .notionPageAPI:
            return containsAny(normalizedText, ["notion"])
        case .todoistTaskAPI:
            return containsAny(normalizedText, ["todoist", "task", "todo", "待辦", "任務"])
        case .draftsCreateHandoff:
            return containsAny(normalizedText, ["drafts", "draft note", "text draft", "草稿", "筆記草稿"])
        }
    }

    func appIntegrationHandoffSummary(for skill: AppIntegrationSkill) -> String {
        switch skill.executionMode {
        case .apiCall:
            return KairoL10n.string("chat.tool.summary.integration", skill.appName)
        case .openURL:
            return KairoL10n.string("chat.tool.summary.visibleExternalApp", skill.appName)
        case .runUserShortcut:
            return KairoL10n.string("chat.tool.summary.shortcutBoundary")
        case .draftOnly:
            return KairoL10n.string("chat.tool.summary.managedSkill")
        case .previewOnly:
            return KairoL10n.string("chat.tool.summary.unsupportedSafeAlternative")
        }
    }
}
