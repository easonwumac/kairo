import Foundation

public struct KairoRecipeRunner: Sendable {
    private let recipeStore: any KairoRecipeStore
    private let memoryStore: (any MemoryStore)?
    private let aiProvider: (any AIProvider)?
    private let actionGate: any PhoneToolActionGating

    public init(dependencies: KairoRecipeRunnerDependencies) {
        self.recipeStore = dependencies.recipeStore
        self.memoryStore = dependencies.memoryStore
        self.aiProvider = dependencies.aiProvider
        self.actionGate = dependencies.actionGate
    }

    public init(
        recipeStore: any KairoRecipeStore,
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil,
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        actionGate: (any PhoneToolActionGating)? = nil
    ) {
        self.init(dependencies: KairoRecipeRunnerDependencies(
            recipeStore: recipeStore,
            memoryStore: memoryStore,
            aiProvider: aiProvider,
            actionGate: actionGate ?? BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        ))
    }

    public func run(_ request: KairoRecipeRunRequest) async throws -> KairoRecipeRunResult {
        let startedAt = Date()
        guard let recipe = try await recipeStore.recipe(id: request.recipeID) else {
            return failureResult(
                request: request,
                startedAt: startedAt,
                summary: "Recipe not found: \(request.recipeID).",
                riskTier: .tier0ReadOnly,
                requiresConfirmation: false,
                errorMessage: "Recipe not found."
            )
        }

        guard recipe.isEnabled else {
            return failureResult(
                request: request,
                startedAt: startedAt,
                summary: "\(recipe.title) is disabled.",
                riskTier: recipe.riskTier,
                requiresConfirmation: false,
                errorMessage: "Recipe disabled."
            )
        }

        let effectiveRisk = max(recipe.riskTier, recipe.steps.map(stepRisk).max() ?? .tier0ReadOnly)
        if effectiveRisk >= .tier2LowRiskWrite, !request.userConfirmed, !request.dryRun {
            return KairoRecipeRunResult(
                recipeID: recipe.id,
                startedAt: startedAt,
                finishedAt: Date(),
                surface: request.surface,
                summary: "\(recipe.title) requires confirmation before write operations.",
                stepResults: [],
                proposedActions: [],
                riskTier: effectiveRisk,
                requiresConfirmation: true,
                success: false,
                errorMessage: nil
            )
        }

        var previousOutput = request.input ?? ""
        var stepResults: [KairoRecipeStepResult] = []
        var proposedActions: [AgentAction] = []

        for step in recipe.steps {
            let inputText = resolveInput(step.input, requestInput: request.input, previousOutput: previousOutput)
            if let blockedTool = actionGate.blockedTool(for: step.kind) {
                stepResults.append(blockedStepResult(step, tool: blockedTool))
                continue
            }
            let execution = try await execute(
                step,
                inputText: inputText,
                request: request,
                recipe: recipe
            )
            stepResults.append(execution.result)
            proposedActions.append(contentsOf: filterRecipeActions(execution.actions))
            if let outputText = execution.result.outputText, !outputText.isEmpty {
                previousOutput = outputText
            }
        }

        let draftCount = proposedActions.count
        let draftSummary = draftCount == 0 ? "no drafts" : "\(draftCount) draft\(draftCount == 1 ? "" : "s")"
        let requiresActionConfirmation = proposedActions.contains { $0.requiresConfirmation }
        return KairoRecipeRunResult(
            recipeID: recipe.id,
            startedAt: startedAt,
            finishedAt: Date(),
            surface: request.surface,
            summary: "\(request.dryRun ? "Previewed" : "Ran") \(recipe.title) with \(draftSummary).",
            stepResults: stepResults,
            proposedActions: proposedActions,
            riskTier: effectiveRisk,
            requiresConfirmation: requiresActionConfirmation,
            success: stepResults.allSatisfy(\.success),
            errorMessage: stepResults.first(where: { !$0.success })?.errorMessage
        )
    }

    private func blockedStepResult(
        _ step: KairoRecipeStep,
        tool: BuiltInPhoneToolDefinition
    ) -> KairoRecipeStepResult {
        KairoRecipeStepResult(
            stepID: step.id,
            summary: tool.fallback.unsupportedReason,
            outputText: tool.fallback.safeAlternative,
            success: false,
            errorMessage: "\(tool.id.rawValue) is \(tool.availabilityStatus.rawValue)."
        )
    }

    private func filterRecipeActions(_ actions: [AgentAction]) -> [AgentAction] {
        actions.filter { action in
            action.kind == .answer || actionGate.allowsExecutablePreview(action)
        }
    }

    private func failureResult(
        request: KairoRecipeRunRequest,
        startedAt: Date,
        summary: String,
        riskTier: ActionRiskTier,
        requiresConfirmation: Bool,
        errorMessage: String
    ) -> KairoRecipeRunResult {
        KairoRecipeRunResult(
            recipeID: request.recipeID,
            startedAt: startedAt,
            finishedAt: Date(),
            surface: request.surface,
            summary: summary,
            stepResults: [],
            proposedActions: [],
            riskTier: riskTier,
            requiresConfirmation: requiresConfirmation,
            success: false,
            errorMessage: errorMessage
        )
    }

    private func execute(
        _ step: KairoRecipeStep,
        inputText: String,
        request: KairoRecipeRunRequest,
        recipe: KairoRecipe
    ) async throws -> (result: KairoRecipeStepResult, actions: [AgentAction]) {
        switch step.kind {
        case .askKairo:
            let prompt = inputText.isEmpty ? recipe.summary : inputText
            let output: String
            if let aiProvider {
                let response = try await aiProvider.complete(AICompletionRequest(
                    systemPrompt: "You are Kairo. Return a concise recipe step draft.",
                    userPrompt: prompt
                ))
                output = response.message
            } else {
                output = KairoL10n.string("recipes.localFallback.output", prompt)
            }
            return (KairoRecipeStepResult(stepID: step.id, summary: step.title, outputText: output, success: true), [])

        case .searchMemory:
            guard let memoryStore else {
                return (KairoRecipeStepResult(
                    stepID: step.id,
                    summary: "Memory search unavailable.",
                    outputText: "Memory search unavailable in this environment.",
                    success: true
                ), [])
            }
            let records = try await memoryStore.search(query: inputText, limit: 5)
            let output = records.map { "\($0.title): \($0.summary)" }.joined(separator: "\n")
            return (KairoRecipeStepResult(
                stepID: step.id,
                summary: "Found \(records.count) memory match\(records.count == 1 ? "" : "es").",
                outputText: output,
                success: true
            ), [])

        case .saveMemory:
            guard !request.dryRun else {
                return (KairoRecipeStepResult(stepID: step.id, summary: "Dry-run memory save skipped.", outputText: inputText, success: true), [])
            }
            guard let memoryStore else {
                return (KairoRecipeStepResult(
                    stepID: step.id,
                    summary: "Memory store unavailable.",
                    outputText: inputText,
                    success: false,
                    errorMessage: "Memory store unavailable."
                ), [])
            }
            let memory = MemoryRecord(
                title: recipe.title,
                summary: "Saved by Kairo recipe \(recipe.id).",
                content: inputText,
                source: memorySource(for: request.surface)
            )
            try await memoryStore.save(memory)
            return (KairoRecipeStepResult(stepID: step.id, summary: "Saved Kairo memory.", outputText: inputText, success: true), [])

        case .summarizeText:
            let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
            let prefix = String(trimmed.prefix(400))
            let output = prefix.isEmpty ? "No text provided to summarize." : "Summary draft: \(prefix)"
            return (KairoRecipeStepResult(stepID: step.id, summary: step.title, outputText: output, success: true), [])

        case .extractTasks:
            let tasks = extractTasks(from: inputText)
            let output = tasks.joined(separator: "\n")
            return (KairoRecipeStepResult(
                stepID: step.id,
                summary: "Extracted \(tasks.count) task\(tasks.count == 1 ? "" : "s").",
                outputText: output,
                success: true
            ), [])

        case .createReminderDraft:
            let tasks = draftLines(from: inputText)
            let actions = tasks.map { task in
                AgentAction(
                    kind: .createReminderDraft,
                    title: task,
                    rationale: "Kairo recipe \(recipe.title) created a reminder draft only.",
                    payload: .reminder(ReminderDraft(title: task, notes: "Draft from Kairo recipe \(recipe.id).", dueDate: nil)),
                    riskTier: .tier1Draft
                )
            }
            return (KairoRecipeStepResult(
                stepID: step.id,
                summary: "Created \(actions.count) reminder draft\(actions.count == 1 ? "" : "s").",
                outputText: tasks.joined(separator: "\n"),
                success: true
            ), actions)

        case .createCalendarDraft:
            let title = inputText.isEmpty ? recipe.title : inputText
            let action = AgentAction(
                kind: .createCalendarDraft,
                title: title,
                rationale: "Kairo recipe \(recipe.title) created a calendar draft only.",
                payload: .calendarEvent(CalendarEventDraft(
                    title: title,
                    notes: "Draft from Kairo recipe \(recipe.id).",
                    startDate: Date(),
                    endDate: Date().addingTimeInterval(3600)
                )),
                riskTier: .tier1Draft
            )
            return (KairoRecipeStepResult(stepID: step.id, summary: "Created calendar draft.", outputText: title, success: true), [action])

        case .enqueueActionDraft:
            let title = inputText.isEmpty ? recipe.title : String(inputText.prefix(80))
            let action = AgentAction(
                kind: .answer,
                title: title,
                rationale: "Kairo recipe \(recipe.title) queued an internal draft.",
                payload: .text(inputText.isEmpty ? recipe.summary : inputText),
                riskTier: .tier1Draft
            )
            return (KairoRecipeStepResult(stepID: step.id, summary: "Queued internal action draft.", outputText: inputText, success: true), [action])

        case .sendLocalNotificationDraft:
            let action = AgentAction(
                kind: .sendNotification,
                title: recipe.title,
                rationale: "Kairo recipe \(recipe.title) created a notification draft only.",
                payload: .notification(NotificationDraft(title: recipe.title, body: inputText.isEmpty ? recipe.summary : inputText)),
                riskTier: .tier1Draft
            )
            return (KairoRecipeStepResult(stepID: step.id, summary: "Created notification draft.", outputText: inputText, success: true), [action])

        case .readHomeState:
            return (KairoRecipeStepResult(
                stepID: step.id,
                summary: "Home state read is not configured.",
                outputText: "HomeKit provider is not configured for this recipe runner.",
                success: true
            ), [])

        case .proposeHomeAction:
            let action = AgentAction(
                kind: .controlHome,
                title: "Home action preview",
                rationale: "Kairo recipe \(recipe.title) created a HomeKit preview only.",
                payload: .unsupported(UnsupportedActionExplanation(
                    requestedAction: inputText,
                    reason: "HomeKit writes require a dedicated provider and explicit confirmation.",
                    safeAlternative: "Open Kairo Access to review HomeKit capability setup."
                )),
                riskTier: .tier3HighRiskExternal
            )
            return (KairoRecipeStepResult(stepID: step.id, summary: "Prepared HomeKit preview.", outputText: inputText, success: true), [action])

        case .noOp:
            return (KairoRecipeStepResult(stepID: step.id, summary: step.title, outputText: inputText, success: true), [])
        }
    }

    private func resolveInput(_ input: StepInput, requestInput: String?, previousOutput: String) -> String {
        switch input {
        case .literal(let text):
            return text
        case .previousStepOutput:
            return previousOutput
        case .shortcutInput, .sharedContent, .keyboardContext:
            return requestInput ?? previousOutput
        }
    }

    private func stepRisk(_ step: KairoRecipeStep) -> ActionRiskTier {
        switch step.kind {
        case .saveMemory:
            return .tier2LowRiskWrite
        case .proposeHomeAction:
            return .tier3HighRiskExternal
        case .createReminderDraft, .createCalendarDraft, .enqueueActionDraft, .sendLocalNotificationDraft:
            return .tier1Draft
        case .askKairo, .searchMemory, .summarizeText, .extractTasks, .readHomeState, .noOp:
            return .tier0ReadOnly
        }
    }

    private func memorySource(for surface: AgentSurface) -> MemorySource {
        switch surface {
        case .shareExtension:
            return .shareExtension
        case .appIntent, .shortcut:
            return .appIntent
        default:
            return .manual
        }
    }

    private func extractTasks(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { line in
                let lowercased = line.lowercased()
                return line.hasPrefix("- ")
                    || line.hasPrefix("• ")
                    || lowercased.contains("todo")
                    || lowercased.contains("action")
                    || lowercased.contains("reminder")
                    || lowercased.contains("待辦")
                    || lowercased.contains("提醒")
            }
            .map(cleanTaskLine)
            .filter { !$0.isEmpty }
    }

    private func draftLines(from text: String) -> [String] {
        text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map(cleanTaskLine)
            .filter { !$0.isEmpty }
    }

    private func cleanTaskLine(_ line: String) -> String {
        var cleaned = line.trimmingCharacters(in: .whitespacesAndNewlines)
        for prefix in ["TODO:", "Todo:", "todo:", "Action:", "action:", "Reminder:", "reminder:", "- ", "• "] {
            if cleaned.hasPrefix(prefix) {
                cleaned = String(cleaned.dropFirst(prefix.count))
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return cleaned
    }
}
