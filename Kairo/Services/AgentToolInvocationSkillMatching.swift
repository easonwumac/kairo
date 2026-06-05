import Foundation

extension AgentToolInvocationPlanner {
    func candidate(for skill: AgentSkill, normalizedText: String) -> AgentToolInvocationCandidate? {
        switch skill.kind {
        case .homeKitControl:
            guard candidateMatcher.matches(
                skill: skill,
                normalizedText: normalizedText,
                parser: appIntegrationActionParser
            ) else { return nil }
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
            guard candidateMatcher.matches(
                skill: skill,
                normalizedText: normalizedText,
                parser: appIntegrationActionParser
            ) else { return nil }
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
            guard candidateMatcher.matches(
                skill: skill,
                normalizedText: normalizedText,
                parser: appIntegrationActionParser
            ) else { return nil }
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
            guard candidateMatcher.matches(
                skill: skill,
                normalizedText: normalizedText,
                parser: appIntegrationActionParser
            ) else { return nil }
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
        guard candidateMatcher.matches(
            integration: integration,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        ) else {
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

    func candidate(for skill: AppIntegrationSkill, userText: String, normalizedText: String) -> AgentToolInvocationCandidate? {
        guard candidateMatcher.matches(
            appIntegrationSkill: skill,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        ) else {
            return nil
        }
        guard skill.availabilityStatus != .disabled, skill.availabilityStatus != .unsupported else {
            return nil
        }
        let action = appIntegrationActionMapper.visibleHandoffAction(
            for: skill,
            userText: userText,
            normalizedText: normalizedText,
            parser: appIntegrationActionParser
        )

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
            handoffSummary: appIntegrationHandoffSummary(for: skill),
            action: action
        )
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
