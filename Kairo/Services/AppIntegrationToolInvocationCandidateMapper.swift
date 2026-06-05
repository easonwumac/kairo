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
        guard skill.availabilityStatus != .disabled, skill.availabilityStatus != .unsupported else {
            return nil
        }

        let action = skill.canBeSuggestedAsExecutable
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
            handoffSummary: handoffSummary(for: skill),
            action: action
        )
    }

    private func handoffSummary(for skill: AppIntegrationSkill) -> String {
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
