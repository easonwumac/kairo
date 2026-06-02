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

    public init(
        id: String,
        title: String,
        kind: KairoRecipeStepKind,
        input: StepInput = .previousStepOutput
    ) {
        self.id = id
        self.title = title
        self.kind = kind
        self.input = input
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

public protocol KairoRecipeStore: Sendable {
    func listRecipes() async throws -> [KairoRecipe]
    func recipe(id: String) async throws -> KairoRecipe?
    func save(_ recipe: KairoRecipe) async throws
    func delete(id: String) async throws
    func setEnabled(_ enabled: Bool, id: String) async throws
}

public actor InMemoryKairoRecipeStore: KairoRecipeStore {
    private var recipes: [String: KairoRecipe]

    public init(recipes: [KairoRecipe] = []) {
        self.recipes = Dictionary(uniqueKeysWithValues: recipes.map { ($0.id, $0) })
    }

    public func listRecipes() async throws -> [KairoRecipe] {
        recipes.values.sorted { $0.title < $1.title }
    }

    public func recipe(id: String) async throws -> KairoRecipe? {
        recipes[id]
    }

    public func save(_ recipe: KairoRecipe) async throws {
        var updated = recipe
        updated.updatedAt = Date()
        recipes[recipe.id] = updated
    }

    public func delete(id: String) async throws {
        recipes[id] = nil
    }

    public func setEnabled(_ enabled: Bool, id: String) async throws {
        guard var recipe = recipes[id] else { return }
        recipe.isEnabled = enabled
        recipe.updatedAt = Date()
        recipes[id] = recipe
    }
}

public actor FileBackedKairoRecipeStore: KairoRecipeStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var recipes: [String: KairoRecipe] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func listRecipes() async throws -> [KairoRecipe] {
        recipes.values.sorted { $0.title < $1.title }
    }

    public func recipe(id: String) async throws -> KairoRecipe? {
        recipes[id]
    }

    public func save(_ recipe: KairoRecipe) async throws {
        var updated = recipe
        updated.updatedAt = Date()
        recipes[recipe.id] = updated
        try persist()
    }

    public func delete(id: String) async throws {
        recipes[id] = nil
        try persist()
    }

    public func setEnabled(_ enabled: Bool, id: String) async throws {
        guard var recipe = recipes[id] else { return }
        recipe.isEnabled = enabled
        recipe.updatedAt = Date()
        recipes[id] = recipe
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            recipes = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            recipes = [:]
            return
        }

        let decoded = try decoder.decode([KairoRecipe].self, from: data)
        recipes = Dictionary(uniqueKeysWithValues: decoded.map { ($0.id, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let sortedRecipes = recipes.values.sorted { $0.createdAt < $1.createdAt }
        let data = try encoder.encode(sortedRecipes)
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public enum KairoRecipeTemplateFactory {
    public static func sampleCatalog(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipeCatalog {
        KairoRecipeCatalog(recipes: [
            dailyBriefing(now: now),
            meetingPrep(now: now),
            sharedTextToTasks(now: now),
            keyboardTodoCapture(now: now)
        ])
    }

    public static func dailyBriefing(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "daily-briefing",
            title: "Daily Briefing",
            summary: "Create a concise morning briefing from Kairo-owned context and return draft actions.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .dailyTime(hour: 8, minute: 30),
            steps: [
                KairoRecipeStep(
                    id: "ask-kairo",
                    title: "Draft briefing",
                    kind: .askKairo,
                    input: .literal("Create a concise daily briefing from calendar, reminders, and Kairo memory. If unavailable, ask user to connect capabilities.")
                ),
                KairoRecipeStep(
                    id: "enqueue-draft",
                    title: "Create briefing draft",
                    kind: .enqueueActionDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.memory, .aiProvider, .notifications],
            riskTier: .tier1Draft,
            cloudPolicy: .askEachTime,
            isEnabled: true
        )
    }

    public static func meetingPrep(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "meeting-prep",
            title: "Meeting Prep",
            summary: "Search Kairo memory and prepare a short meeting brief.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .beforeCalendarEvent(minutes: 30),
            steps: [
                KairoRecipeStep(
                    id: "search-memory",
                    title: "Search meeting memory",
                    kind: .searchMemory,
                    input: .literal("upcoming meeting")
                ),
                KairoRecipeStep(
                    id: "ask-kairo",
                    title: "Prepare meeting brief",
                    kind: .askKairo,
                    input: .literal("Prepare a meeting brief from the matching Kairo memory. Include open questions and follow-ups.")
                )
            ],
            requiredCapabilities: [.memory, .aiProvider, .calendar],
            riskTier: .tier1Draft,
            cloudPolicy: .askEachTime,
            isEnabled: true
        )
    }

    public static func sharedTextToTasks(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "shared-text-to-tasks",
            title: "Shared Text to Tasks",
            summary: "Summarize shared text and turn action lines into reminder drafts.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .shareSheet,
            steps: [
                KairoRecipeStep(
                    id: "summarize",
                    title: "Summarize shared text",
                    kind: .summarizeText,
                    input: .sharedContent
                ),
                KairoRecipeStep(
                    id: "extract",
                    title: "Extract tasks",
                    kind: .extractTasks,
                    input: .sharedContent
                ),
                KairoRecipeStep(
                    id: "reminder-drafts",
                    title: "Create reminder drafts",
                    kind: .createReminderDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.shareExtension, .reminders],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
    }

    public static func keyboardTodoCapture(now: Date = Date(timeIntervalSince1970: 0)) -> KairoRecipe {
        KairoRecipe(
            id: "keyboard-todo-capture",
            title: "Keyboard Todo Capture",
            summary: "Turn selected keyboard context into Kairo-owned draft queue items.",
            createdAt: now,
            updatedAt: now,
            createdBy: .template,
            triggerHint: .keyboard,
            steps: [
                KairoRecipeStep(
                    id: "extract",
                    title: "Extract keyboard tasks",
                    kind: .extractTasks,
                    input: .keyboardContext
                ),
                KairoRecipeStep(
                    id: "queue-draft",
                    title: "Queue task draft",
                    kind: .enqueueActionDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.keyboard, .reminders],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
    }
}

public struct KairoRecipePlanner: Sendable {
    public init() {}

    public func suggestRecipes(for request: String, now: Date = Date()) -> [KairoRecipe] {
        let normalized = request.lowercased()
        var recipes: [KairoRecipe] = []

        if containsAny(normalized, ["每天", "daily", "morning", "早上"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.dailyBriefing(now: now)))
        }
        if containsAny(normalized, ["meeting", "會議", "calendar"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.meetingPrep(now: now)))
        }
        if containsAny(normalized, ["todo", "待辦", "reminder", "提醒"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.sharedTextToTasks(now: now)))
        }
        if containsAny(normalized, ["keyboard", "鍵盤"]) {
            recipes.append(suggested(KairoRecipeTemplateFactory.keyboardTodoCapture(now: now)))
        }
        if containsAny(normalized, ["home", "homekit", "燈", "門鎖", "冷氣"]) {
            recipes.append(suggested(homeStateSummary(now: now)))
        }

        if recipes.isEmpty {
            recipes.append(suggested(KairoRecipe(
                id: "suggested-custom-recipe",
                title: "Suggested Kairo Recipe",
                summary: "Review this Kairo-owned recipe draft before enabling it.",
                createdAt: now,
                updatedAt: now,
                createdBy: .agentSuggested,
                triggerHint: .manual,
                steps: [
                    KairoRecipeStep(
                        id: "ask-kairo",
                        title: "Draft response",
                        kind: .askKairo,
                        input: .literal(request)
                    )
                ],
                requiredCapabilities: [.aiProvider],
                riskTier: .tier1Draft,
                cloudPolicy: .askEachTime,
                isEnabled: false
            )))
        }

        return recipes
    }

    private func suggested(_ recipe: KairoRecipe) -> KairoRecipe {
        var draft = recipe
        draft.createdBy = .agentSuggested
        draft.isEnabled = false
        draft.updatedAt = draft.createdAt
        return draft
    }

    private func homeStateSummary(now: Date) -> KairoRecipe {
        KairoRecipe(
            id: "home-state-summary",
            title: "Home State Summary",
            summary: "Read HomeKit state and prepare a user-confirmed action preview if needed.",
            createdAt: now,
            updatedAt: now,
            createdBy: .agentSuggested,
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "read-home",
                    title: "Read Home state",
                    kind: .readHomeState,
                    input: .shortcutInput
                ),
                KairoRecipeStep(
                    id: "home-preview",
                    title: "Prepare Home action preview",
                    kind: .proposeHomeAction,
                    input: .shortcutInput
                )
            ],
            requiredCapabilities: [.homeKit],
            riskTier: .tier3HighRiskExternal,
            cloudPolicy: .localOnly,
            isEnabled: false
        )
    }

    private func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0) }
    }
}

public struct KairoRecipeRunner: Sendable {
    private let recipeStore: any KairoRecipeStore
    private let memoryStore: (any MemoryStore)?
    private let aiProvider: (any AIProvider)?

    public init(
        recipeStore: any KairoRecipeStore,
        memoryStore: (any MemoryStore)? = nil,
        aiProvider: (any AIProvider)? = nil
    ) {
        self.recipeStore = recipeStore
        self.memoryStore = memoryStore
        self.aiProvider = aiProvider
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
            let execution = try await execute(
                step,
                inputText: inputText,
                request: request,
                recipe: recipe
            )
            stepResults.append(execution.result)
            proposedActions.append(contentsOf: execution.actions)
            if let outputText = execution.result.outputText, !outputText.isEmpty {
                previousOutput = outputText
            }
        }

        let draftCount = proposedActions.count
        let draftSummary = draftCount == 0 ? "no drafts" : "\(draftCount) draft\(draftCount == 1 ? "" : "s")"
        return KairoRecipeRunResult(
            recipeID: recipe.id,
            startedAt: startedAt,
            finishedAt: Date(),
            surface: request.surface,
            summary: "\(request.dryRun ? "Previewed" : "Ran") \(recipe.title) with \(draftSummary).",
            stepResults: stepResults,
            proposedActions: proposedActions,
            riskTier: effectiveRisk,
            requiresConfirmation: false,
            success: stepResults.allSatisfy(\.success),
            errorMessage: stepResults.first(where: { !$0.success })?.errorMessage
        )
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
                output = "Kairo local fallback: \(prompt)"
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
