import Foundation

public protocol ShortcutDemoIntegrationGating: Sendable {
    func blockedOutput(for step: ShortcutDemoStep, input: ShortcutNodeInput) -> ShortcutNodeOutput?
}

public struct CatalogBackedShortcutDemoIntegrationGate: ShortcutDemoIntegrationGating {
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    private let outputBuilder: any ShortcutIntegrationBlockedOutputBuilding

    public init(
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        outputBuilder: any ShortcutIntegrationBlockedOutputBuilding = DefaultShortcutIntegrationBlockedOutputBuilder()
    ) {
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.outputBuilder = outputBuilder
    }

    public func blockedOutput(for step: ShortcutDemoStep, input: ShortcutNodeInput) -> ShortcutNodeOutput? {
        switch appIntegrationSkillCatalog.resolveSkill(for: step) {
        case .notReferenced:
            return nil
        case .missing(let integrationSkillID):
            return outputBuilder.blockedOutput(
                kind: step.nodeKind,
                input: input,
                skillID: integrationSkillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.missingCatalog", integrationSkillID.rawValue),
                fields: AppIntegrationSkillResolution.missing(integrationSkillID).blockedExecutionFields,
                sourceNamePolicy: .includeEmptyWhenMissing
            )
        case .resolved(let skill):
            guard skill.canBeSuggestedAsExecutable else {
                return outputBuilder.blockedOutput(
                    kind: step.nodeKind,
                    input: input,
                    skillID: skill.id,
                    displayText: KairoL10n.string("shortcut.integration.blocked.setupRequired", skill.appName),
                    fields: skill.blockedExecutionFields,
                    sourceNamePolicy: .includeEmptyWhenMissing
                )
            }

            return nil
        }
    }
}
