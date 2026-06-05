import Foundation

public protocol ShortcutDemoIntegrationGating: Sendable {
    func blockedOutput(for step: ShortcutDemoStep, input: ShortcutNodeInput) -> ShortcutNodeOutput?
}

public struct CatalogBackedShortcutDemoIntegrationGate: ShortcutDemoIntegrationGating {
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding

    public init(appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()) {
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
    }

    public func blockedOutput(for step: ShortcutDemoStep, input: ShortcutNodeInput) -> ShortcutNodeOutput? {
        guard let integrationSkillID = step.integrationSkillID else {
            return nil
        }

        guard let skill = appIntegrationSkillCatalog.skill(id: integrationSkillID) else {
            return blockedOutput(
                for: step,
                input: input,
                skillID: integrationSkillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.missingCatalog", integrationSkillID.rawValue),
                fields: [
                    "integrationAvailability": AppIntegrationSkillAvailabilityStatus.unsupported.rawValue,
                    "integrationSetupRequirement": AppIntegrationSkillSetupRequirement.unsupported.rawValue,
                    "integrationExecutionMode": AppIntegrationExecutionMode.previewOnly.rawValue
                ]
            )
        }

        guard skill.canBeSuggestedAsExecutable else {
            return blockedOutput(
                for: step,
                input: input,
                skillID: integrationSkillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.setupRequired", skill.appName),
                fields: [
                    "integrationAvailability": skill.availabilityStatus.rawValue,
                    "integrationSetupRequirement": skill.setupRequirement.rawValue,
                    "integrationExecutionMode": skill.executionMode.rawValue,
                    "integrationFallbackReasonKey": skill.fallback.reasonKey,
                    "integrationFallbackSafeAlternativeKey": skill.fallback.safeAlternativeKey
                ]
            )
        }

        return nil
    }

    private func blockedOutput(
        for step: ShortcutDemoStep,
        input: ShortcutNodeInput,
        skillID: AppIntegrationSkillID,
        displayText: String,
        fields: [String: String]
    ) -> ShortcutNodeOutput {
        var outputFields = input.variables
        outputFields["sourceName"] = input.sourceName ?? ""
        outputFields["integrationSkillID"] = skillID.rawValue
        outputFields["success"] = "false"
        for (key, value) in fields {
            outputFields[key] = value
        }

        return ShortcutNodeOutput(
            kind: step.nodeKind,
            displayText: displayText,
            fields: outputFields
        )
    }
}
