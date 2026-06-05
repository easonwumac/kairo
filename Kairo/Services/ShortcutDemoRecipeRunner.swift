import Foundation

public protocol ShortcutDemoRecipeRunnerProtocol: Sendable {
    func runSample(_ recipe: ShortcutDemoRecipe) async throws -> ShortcutDemoRecipeRun
}

public actor ShortcutDemoRecipeRunner: ShortcutDemoRecipeRunnerProtocol {
    private let runtime: ShortcutNodeRuntime
    private let integrationGate: any ShortcutDemoIntegrationGating

    public init(
        runtime: ShortcutNodeRuntime,
        appIntegrationSkillCatalog: (any AppIntegrationSkillCatalogProviding)? = nil,
        integrationGate: (any ShortcutDemoIntegrationGating)? = nil
    ) {
        let runtimeAppIntegrationSkillCatalog = appIntegrationSkillCatalog ?? AppIntegrationSkillCatalog()
        self.runtime = runtime
        self.integrationGate = integrationGate ?? CatalogBackedShortcutDemoIntegrationGate(
            appIntegrationSkillCatalog: runtimeAppIntegrationSkillCatalog
        )
    }

    public func runSample(_ recipe: ShortcutDemoRecipe) async throws -> ShortcutDemoRecipeRun {
        var stepRuns: [ShortcutDemoStepRun] = []
        var previousOutput: ShortcutNodeOutput?

        for step in recipe.steps {
            var input = step.sampleInput
            if input.variables["kairoInputSource"] == "previousStepOutput",
               let previousOutput {
                input.text = Self.chainedText(from: previousOutput)
            }

            if let blockedOutput = integrationGate.blockedOutput(for: step, input: input) {
                stepRuns.append(
                    ShortcutDemoStepRun(
                        shortcutActionTitle: step.shortcutActionTitle,
                        nodeKind: step.nodeKind,
                        input: input,
                        output: blockedOutput
                    )
                )
                previousOutput = blockedOutput
                continue
            }

            let output = try await runtime.run(step.nodeKind, input: input)
            stepRuns.append(
                ShortcutDemoStepRun(
                    shortcutActionTitle: step.shortcutActionTitle,
                    nodeKind: step.nodeKind,
                    input: input,
                    output: output
                )
            )
            previousOutput = output
        }

        return ShortcutDemoRecipeRun(
            recipeID: recipe.id,
            recipeTitle: recipe.title,
            displaySummary: Self.displaySummary(recipe: recipe, stepRuns: stepRuns),
            steps: stepRuns
        )
    }

    private static func displaySummary(recipe: ShortcutDemoRecipe, stepRuns: [ShortcutDemoStepRun]) -> String {
        let stepLabel = stepRuns.count == 1 ? "1 step" : "\(stepRuns.count) steps"
        let taskCount = stepRuns.reduce(0) { count, step in count + step.output.tasks.count }
        let reminderCount = stepRuns.reduce(0) { count, step in count + step.output.reminderDrafts.count }
        let calendarCount = stepRuns.reduce(0) { count, step in count + step.output.calendarDrafts.count }
        let contactCount = stepRuns.reduce(0) { count, step in count + step.output.contactDrafts.count }
        let emailCount = stepRuns.reduce(0) { count, step in count + step.output.emailDrafts.count }
        let phoneCount = stepRuns.reduce(0) { count, step in count + step.output.phoneCallDrafts.count }
        let webSearchCount = stepRuns.reduce(0) { count, step in count + step.output.webSearchDrafts.count }
        return "\(recipe.title): \(stepLabel), \(taskCount) task drafts, \(reminderCount) reminder drafts, \(calendarCount) calendar drafts, \(contactCount) contact drafts, \(emailCount) email drafts, \(phoneCount) phone handoffs, \(webSearchCount) web search handoffs."
    }

    private static func chainedText(from output: ShortcutNodeOutput) -> String {
        if let chainText = output.fields["chainText"]?.trimmingCharacters(in: .whitespacesAndNewlines),
           !chainText.isEmpty {
            return chainText
        }

        if !output.tasks.isEmpty {
            return output.tasks
                .map { "Action: \($0.title)" }
                .joined(separator: "\n")
        }

        if !output.reminderDrafts.isEmpty {
            return output.reminderDrafts
                .map { "Reminder: \($0.title)" }
                .joined(separator: "\n")
        }

        return output.displayText
    }
}
