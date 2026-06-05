import Foundation

public protocol ShortcutNodeIntegrationGating: Sendable {
    func blockedOutput(for kind: ShortcutNodeKind, input: ShortcutNodeInput) -> ShortcutNodeOutput?
}

public struct CatalogBackedShortcutNodeIntegrationGate: ShortcutNodeIntegrationGating {
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()) {
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
    }

    public func blockedOutput(for kind: ShortcutNodeKind, input: ShortcutNodeInput) -> ShortcutNodeOutput? {
        guard let rawSkillID = input.variables["integrationSkillID"]?.trimmingCharacters(in: .whitespacesAndNewlines),
              !rawSkillID.isEmpty,
              let skillID = AppIntegrationSkillID(rawValue: rawSkillID) else {
            return nil
        }

        guard let skill = appIntegrationSkillCatalog.skill(id: skillID) else {
            return blockedOutput(
                kind: kind,
                input: input,
                skillID: skillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.missingCatalog", skillID.rawValue),
                fields: [
                    "integrationAvailability": AppIntegrationSkillAvailabilityStatus.unsupported.rawValue,
                    "integrationSetupRequirement": AppIntegrationSkillSetupRequirement.unsupported.rawValue,
                    "integrationExecutionMode": AppIntegrationExecutionMode.previewOnly.rawValue
                ]
            )
        }

        guard skill.canBeSuggestedAsExecutable else {
            return blockedOutput(
                kind: kind,
                input: input,
                skillID: skillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.setupRequired", skill.appName),
                fields: blockedFields(for: skill)
            )
        }

        guard Self.nodeKind(for: skill.id) == kind else {
            return blockedOutput(
                kind: kind,
                input: input,
                skillID: skillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.nodeMismatch", skill.appName),
                fields: blockedFields(for: skill)
            )
        }

        return nil
    }

    private func blockedFields(for skill: AppIntegrationSkill) -> [String: String] {
        [
            "integrationAvailability": skill.availabilityStatus.rawValue,
            "integrationSetupRequirement": skill.setupRequirement.rawValue,
            "integrationExecutionMode": skill.executionMode.rawValue,
            "integrationFallbackReasonKey": skill.fallback.reasonKey,
            "integrationFallbackSafeAlternativeKey": skill.fallback.safeAlternativeKey
        ]
    }

    private func blockedOutput(
        kind: ShortcutNodeKind,
        input: ShortcutNodeInput,
        skillID: AppIntegrationSkillID,
        displayText: String,
        fields: [String: String]
    ) -> ShortcutNodeOutput {
        var outputFields = input.variables
        if let sourceName = input.sourceName {
            outputFields["sourceName"] = sourceName
        }
        outputFields["integrationSkillID"] = skillID.rawValue
        outputFields["success"] = "false"
        for (key, value) in fields {
            outputFields[key] = value
        }

        return ShortcutNodeOutput(
            kind: kind,
            displayText: displayText,
            fields: outputFields
        )
    }

    private static func nodeKind(for skillID: AppIntegrationSkillID) -> ShortcutNodeKind? {
        switch skillID {
        case .appleMailHandoff:
            return .createEmailDraft
        case .appleMessagesHandoff:
            return .prepareMessageHandoff
        case .applePhoneHandoff:
            return .preparePhoneCallHandoff
        case .safariWebSearchHandoff:
            return .prepareWebSearchHandoff
        case .appleMapsDirectionsHandoff,
             .googleMapsDirectionsHandoff,
             .gmailDraftAPI,
             .whatsappMessageHandoff,
             .lineShareHandoff,
             .slackOpenHandoff,
             .notionPageAPI,
             .todoistTaskAPI,
             .draftsCreateHandoff:
            return nil
        }
    }
}
