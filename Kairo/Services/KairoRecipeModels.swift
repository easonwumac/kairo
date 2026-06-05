import Foundation

public enum CapabilityID: String, Codable, CaseIterable, Sendable, Identifiable {
    case memory
    case aiProvider
    case shareExtension
    case appIntents
    case shortcuts
    case keyboard
    case reminders
    case calendar
    case notifications
    case homeKit
    case oauthConnector
    case carMode

    public var id: String { rawValue }
}

public enum RecipeCreator: String, Codable, CaseIterable, Sendable {
    case user
    case agentSuggested
    case template
    case system
}

public enum TriggerHint: Codable, Equatable, Sendable {
    case manual
    case shortcut
    case shareSheet
    case keyboard
    case dailyTime(hour: Int, minute: Int)
    case beforeCalendarEvent(minutes: Int)
    case carMode
}

public enum CloudPolicy: String, Codable, CaseIterable, Sendable {
    case localOnly
    case cloudAllowed
    case askEachTime
}

public enum StepInput: Codable, Equatable, Sendable {
    case literal(String)
    case previousStepOutput
    case shortcutInput
    case sharedContent
    case keyboardContext
}

public enum KairoRecipeStepKind: String, Codable, CaseIterable, Sendable {
    case askKairo
    case searchMemory
    case saveMemory
    case summarizeText
    case extractTasks
    case createReminderDraft
    case createCalendarDraft
    case enqueueActionDraft
    case sendLocalNotificationDraft
    case readHomeState
    case proposeHomeAction
    case noOp
}

public struct KairoRecipeStep: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var kind: KairoRecipeStepKind
    public var input: StepInput
    public var integrationSkillID: AppIntegrationSkillID?

    public init(
        id: String,
        title: String,
        kind: KairoRecipeStepKind,
        input: StepInput = .previousStepOutput,
        integrationSkillID: AppIntegrationSkillID? = nil
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.input = input
        self.integrationSkillID = integrationSkillID
    }
}

public struct KairoRecipe: Codable, Identifiable, Equatable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var createdAt: Date
    public var updatedAt: Date
    public var createdBy: RecipeCreator
    public var triggerHint: TriggerHint?
    public var steps: [KairoRecipeStep]
    public var requiredCapabilities: [CapabilityID]
    public var riskTier: ActionRiskTier
    public var cloudPolicy: CloudPolicy
    public var isEnabled: Bool
    public var version: Int

    public init(
        id: String,
        title: String,
        summary: String,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        createdBy: RecipeCreator = .user,
        triggerHint: TriggerHint? = .manual,
        steps: [KairoRecipeStep],
        requiredCapabilities: [CapabilityID],
        riskTier: ActionRiskTier,
        cloudPolicy: CloudPolicy,
        isEnabled: Bool,
        version: Int = 1
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.createdBy = createdBy
        self.triggerHint = triggerHint
        self.steps = steps
        self.requiredCapabilities = requiredCapabilities
        self.riskTier = riskTier
        self.cloudPolicy = cloudPolicy
        self.isEnabled = isEnabled
        self.version = version
    }
}

public struct KairoRecipeCatalog: Codable, Equatable, Sendable {
    public var recipes: [KairoRecipe]

    public init(recipes: [KairoRecipe]) {
        self.recipes = recipes
    }

    public func recipe(id: String) -> KairoRecipe? {
        recipes.first { $0.id == id }
    }
}

public struct KairoRecipeRunRequest: Codable, Equatable, Sendable {
    public var recipeID: String
    public var surface: AgentSurface
    public var input: String?
    public var dryRun: Bool
    public var userConfirmed: Bool

    public init(
        recipeID: String,
        surface: AgentSurface,
        input: String?,
        dryRun: Bool,
        userConfirmed: Bool
    ) {
        self.recipeID = recipeID
        self.surface = surface
        self.input = input
        self.dryRun = dryRun
        self.userConfirmed = userConfirmed
    }
}

public struct KairoRecipeRunResult: Codable, Equatable, Sendable {
    public var recipeID: String
    public var startedAt: Date
    public var finishedAt: Date
    public var surface: AgentSurface
    public var summary: String
    public var stepResults: [KairoRecipeStepResult]
    public var proposedActions: [AgentAction]
    public var riskTier: ActionRiskTier
    public var requiresConfirmation: Bool
    public var success: Bool
    public var errorMessage: String?

    public init(
        recipeID: String,
        startedAt: Date,
        finishedAt: Date,
        surface: AgentSurface,
        summary: String,
        stepResults: [KairoRecipeStepResult],
        proposedActions: [AgentAction],
        riskTier: ActionRiskTier,
        requiresConfirmation: Bool,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.recipeID = recipeID
        self.startedAt = startedAt
        self.finishedAt = finishedAt
        self.surface = surface
        self.summary = summary
        self.stepResults = stepResults
        self.proposedActions = proposedActions
        self.riskTier = riskTier
        self.requiresConfirmation = requiresConfirmation
        self.success = success
        self.errorMessage = errorMessage
    }
}

public struct KairoRecipeStepResult: Codable, Equatable, Sendable {
    public var stepID: String
    public var summary: String
    public var outputText: String?
    public var success: Bool
    public var errorMessage: String?

    public init(
        stepID: String,
        summary: String,
        outputText: String?,
        success: Bool,
        errorMessage: String? = nil
    ) {
        self.stepID = stepID
        self.summary = summary
        self.outputText = outputText
        self.success = success
        self.errorMessage = errorMessage
    }
}
