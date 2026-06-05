import Foundation

public protocol AppIntegrationToolInvocationCandidateMapping: Sendable {
    func candidate(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing,
        actionMapper: any AppIntegrationActionMapping
    ) -> AgentToolInvocationCandidate?
}

public struct DefaultAppIntegrationToolInvocationCandidateMapper: AppIntegrationToolInvocationCandidateMapping {
    public init() {}

    public func candidate(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing,
        actionMapper: any AppIntegrationActionMapping
    ) -> AgentToolInvocationCandidate? {
        guard skill.availabilityStatus != .disabled else {
            return nil
        }

        let isPrivateMessageRead = Self.isPrivateExternalMessageReadRequest(
            normalizedText,
            for: skill
        )
        let action = skill.canBeSuggestedAsExecutable && !isPrivateMessageRead
            ? actionMapper.visibleHandoffAction(
                for: skill,
                userText: userText,
                normalizedText: normalizedText,
                parser: parser
            )
            : nil

        return AgentToolInvocationCandidate(
            id: "app-integration-\(skill.id.rawValue)",
            title: skill.appName,
            source: .appIntegrationCatalog,
            skillID: skill.id.rawValue,
            integrationKey: skill.integrationKey,
            skillKind: skill.executionMode == .apiCall ? .oauthConnector : .custom,
            requiredCapabilities: skill.audit.capabilityKeys,
            riskTier: skill.riskTier,
            requiresConfirmation: skill.requiresConfirmation,
            handoffSummary: handoffSummary(for: skill, isPrivateMessageRead: isPrivateMessageRead),
            action: action
        )
    }

    private func handoffSummary(for skill: AppIntegrationSkill, isPrivateMessageRead: Bool) -> String {
        if skill.availabilityStatus == .unsupported || isPrivateMessageRead {
            return KairoL10n.string("chat.tool.summary.unsupportedSafeAlternative")
        }

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

    private static func isPrivateExternalMessageReadRequest(
        _ normalizedText: String,
        for skill: AppIntegrationSkill
    ) -> Bool {
        switch skill.id {
        case .appleMessagesHandoff, .whatsappMessageHandoff, .lineShareHandoff:
            return containsAny(normalizedText, [
                "read",
                "show",
                "open",
                "check",
                "查看",
                "讀",
                "讀取",
                "看",
                "檢查"
            ])
            && containsAny(normalizedText, [
                "message",
                "messages",
                "chat",
                "inbox",
                "訊息",
                "聊天",
                "對話"
            ])
        case .appleMailHandoff, .gmailDraftAPI, .applePhoneHandoff, .safariWebSearchHandoff,
             .appleMapsDirectionsHandoff, .googleMapsDirectionsHandoff, .slackOpenHandoff,
             .notionPageAPI, .todoistTaskAPI, .draftsCreateHandoff:
            return false
        }
    }

    private static func containsAny(_ value: String, _ terms: [String]) -> Bool {
        terms.contains { value.contains($0) }
    }
}
