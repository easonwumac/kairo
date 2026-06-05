import Foundation

public protocol ShortcutNodeIntegrationGating: Sendable {
    func blockedOutput(for kind: ShortcutNodeKind, input: ShortcutNodeInput) -> ShortcutNodeOutput?
}

public struct CatalogBackedShortcutNodeIntegrationGate: ShortcutNodeIntegrationGating {
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    private let outputBuilder: any ShortcutIntegrationBlockedOutputBuilding

    public init(
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)? = nil,
        outputBuilder: any ShortcutIntegrationBlockedOutputBuilding = DefaultShortcutIntegrationBlockedOutputBuilder()
    ) {
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog ?? AppIntegrationSkillCatalog()
        self.outputBuilder = outputBuilder
    }

    public func blockedOutput(for kind: ShortcutNodeKind, input: ShortcutNodeInput) -> ShortcutNodeOutput? {
        switch appIntegrationSkillCatalog.resolveSkill(for: input) {
        case .notReferenced:
            return nil
        case .missing(let skillID):
            return outputBuilder.blockedOutput(
                kind: kind,
                input: input,
                skillID: skillID,
                displayText: KairoL10n.string("shortcut.integration.blocked.missingCatalog", skillID.rawValue),
                fields: AppIntegrationSkillResolution.missing(skillID).blockedExecutionFields,
                sourceNamePolicy: .omitWhenMissing
            )
        case .resolved(let skill):
            guard skill.canBeSuggestedAsExecutable else {
                return outputBuilder.blockedOutput(
                    kind: kind,
                    input: input,
                    skillID: skill.id,
                    displayText: KairoL10n.string("shortcut.integration.blocked.setupRequired", skill.appName),
                    fields: skill.blockedExecutionFields,
                    sourceNamePolicy: .omitWhenMissing
                )
            }

            guard skill.shortcutNodeKind == kind else {
                return outputBuilder.blockedOutput(
                    kind: kind,
                    input: input,
                    skillID: skill.id,
                    displayText: KairoL10n.string("shortcut.integration.blocked.nodeMismatch", skill.appName),
                    fields: skill.blockedExecutionFields,
                    sourceNamePolicy: .omitWhenMissing
                )
            }

            return nil
        }
    }
}
