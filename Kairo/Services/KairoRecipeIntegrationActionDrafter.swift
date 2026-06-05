import Foundation

public struct KairoRecipeIntegrationActionDraftResult: Sendable {
    public var stepResult: KairoRecipeStepResult
    public var actions: [AgentAction]

    public init(stepResult: KairoRecipeStepResult, actions: [AgentAction]) {
        self.stepResult = stepResult
        self.actions = actions
    }
}

public protocol KairoRecipeIntegrationActionDrafting: Sendable {
    func draftIntegrationAction(
        for step: KairoRecipeStep,
        inputText: String,
        recipe: KairoRecipe
    ) -> KairoRecipeIntegrationActionDraftResult?
}

public struct CatalogBackedKairoRecipeIntegrationActionDrafter: KairoRecipeIntegrationActionDrafting {
    private let appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    private let appIntegrationActionDrafter: any AppIntegrationActionDrafting

    public init(
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionDrafter: any AppIntegrationActionDrafting = DefaultAppIntegrationActionDrafter()
    ) {
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionDrafter = appIntegrationActionDrafter
    }

    public func draftIntegrationAction(
        for step: KairoRecipeStep,
        inputText: String,
        recipe: KairoRecipe
    ) -> KairoRecipeIntegrationActionDraftResult? {
        switch appIntegrationSkillCatalog.resolveSkill(for: step) {
        case .notReferenced:
            return nil
        case .missing(let integrationSkillID):
            return KairoRecipeIntegrationActionDraftResult(
                stepResult: KairoRecipeStepResult(
                    stepID: step.id,
                    integrationSkillID: integrationSkillID,
                    summary: KairoL10n.string("recipes.integration.missingCatalog.summary"),
                    outputText: KairoL10n.string("recipes.integration.missingCatalog.output"),
                    success: false,
                    errorMessage: KairoL10n.string("recipes.integration.missingCatalog.error", integrationSkillID.rawValue)
                ),
                actions: []
            )
        case .resolved(let skill):
            guard skill.canBeSuggestedAsExecutable else {
                return KairoRecipeIntegrationActionDraftResult(
                    stepResult: KairoRecipeStepResult(
                        stepID: step.id,
                        integrationSkillID: skill.id,
                        summary: KairoL10n.string("recipes.integration.setupRequired.summary"),
                        outputText: KairoL10n.string("recipes.integration.setupRequired.output", skill.appName),
                        success: false,
                        errorMessage: KairoL10n.string(
                            "recipes.integration.setupRequired.error",
                            skill.id.rawValue,
                            skill.availabilityStatus.rawValue
                        )
                    ),
                    actions: []
                )
            }

            guard let action = appIntegrationActionDrafter.draftAction(for: skill, inputText: inputText) else {
                return KairoRecipeIntegrationActionDraftResult(
                    stepResult: KairoRecipeStepResult(
                        stepID: step.id,
                        integrationSkillID: skill.id,
                        summary: KairoL10n.string("recipes.integration.previewUnavailable.summary"),
                        outputText: KairoL10n.string("recipes.integration.previewUnavailable.output", skill.appName),
                        success: false,
                        errorMessage: KairoL10n.string("recipes.integration.previewUnavailable.error", skill.id.rawValue)
                    ),
                    actions: []
                )
            }

            return KairoRecipeIntegrationActionDraftResult(
                stepResult: KairoRecipeStepResult(
                    stepID: step.id,
                    integrationSkillID: skill.id,
                    summary: KairoL10n.string("recipes.integration.prepared.summary", skill.appName),
                    outputText: inputText,
                    success: true
                ),
                actions: [action]
            )
        }
    }
}
