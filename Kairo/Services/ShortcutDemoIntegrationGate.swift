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
        switch appIntegrationSkillCatalog.resolveSkill(for: step) {
        case .notReferenced:
            return nil
        case .missing(let integrationSkillID):
            return blockedOutput(
                for: step,
                input: input,
                skillID: integrationSkillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.missingCatalog", integrationSkillID.rawValue),
                fields: AppIntegrationSkillResolution.missing(integrationSkillID).blockedExecutionFields
            )
        case .resolved(let skill):
            guard skill.canBeSuggestedAsExecutable else {
                return blockedOutput(
                    for: step,
                    input: input,
                    skillID: skill.id,
                    displayText: KairoL10n.string("shortcut.integration.blocked.setupRequired", skill.appName),
                    fields: skill.blockedExecutionFields
                )
            }

            return nil
        }
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
        outputFields[ShortcutNodeInput.integrationSkillIDVariableKey] = skillID.rawValue
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
