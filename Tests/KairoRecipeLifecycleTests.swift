import XCTest
@testable import KairoCore

final class KairoRecipeLifecycleTests: XCTestCase {
    func testKairoRecipeTemplateFactoryProvidesInternalSampleRecipes() throws {
        let catalog = KairoRecipeTemplateFactory.sampleCatalog()

        let dailyBriefing = try XCTUnwrap(catalog.recipe(id: "daily-briefing"))
        let sharedTextToTasks = try XCTUnwrap(catalog.recipe(id: "shared-text-to-tasks"))
        let recipeIDs = Set(catalog.recipes.map(\.id))

        XCTAssertEqual(recipeIDs, ["daily-briefing", "meeting-prep", "shared-text-to-tasks"])
        XCTAssertEqual(dailyBriefing.title, "Daily Briefing")
        XCTAssertEqual(dailyBriefing.createdBy, .template)
        XCTAssertEqual(dailyBriefing.triggerHint, .dailyTime(hour: 8, minute: 30))
        XCTAssertEqual(dailyBriefing.riskTier, .tier1Draft)
        XCTAssertTrue(dailyBriefing.requiredCapabilities.contains(.memory))
        XCTAssertTrue(dailyBriefing.requiredCapabilities.contains(.notifications))
        XCTAssertTrue(dailyBriefing.steps.contains { $0.kind == .askKairo })
        XCTAssertTrue(sharedTextToTasks.steps.contains { $0.kind == .extractTasks })
        XCTAssertTrue(sharedTextToTasks.steps.contains { $0.kind == .createReminderDraft })
        XCTAssertFalse(catalog.recipes.contains { $0.requiredCapabilities.contains(.keyboard) })
        XCTAssertFalse(catalog.recipes.contains { $0.title.contains("Apple Shortcut") })
    }

    func testRecipePlannerDoesNotSuggestPausedKeyboardRecipeSurface() throws {
        let recipes = KairoRecipePlanner().suggestRecipes(for: "Capture keyboard todo")

        XCTAssertFalse(recipes.contains { $0.requiredCapabilities.contains(.keyboard) })
        XCTAssertFalse(recipes.contains { $0.triggerHint == .keyboard })
    }

    func testFileBackedKairoRecipeStorePersistsAndTogglesInternalRecipes() async throws {
        let fileURL = temporaryFileURL(named: "kairo-recipes.json")
        let recipe = try XCTUnwrap(KairoRecipeTemplateFactory.sampleCatalog().recipe(id: "daily-briefing"))

        let firstStore = try await FileBackedKairoRecipeStore(fileURL: fileURL)
        try await firstStore.save(recipe)
        try await firstStore.setEnabled(false, id: recipe.id)

        let secondStore = try await FileBackedKairoRecipeStore(fileURL: fileURL)
        let reloadedRecipe = try await secondStore.recipe(id: recipe.id)
        let reloaded = try XCTUnwrap(reloadedRecipe)
        let listedRecipeIDs = try await secondStore.listRecipes().map(\.id)

        XCTAssertEqual(listedRecipeIDs, [recipe.id])
        XCTAssertFalse(reloaded.isEnabled)

        try await secondStore.delete(id: recipe.id)
        let recipesAfterDelete = try await secondStore.listRecipes()
        XCTAssertTrue(recipesAfterDelete.isEmpty)
    }

    func testFileBackedKairoRecipeStorePersistsIntegrationSkillBindings() async throws {
        let fileURL = temporaryFileURL(named: "kairo-recipe-integration-bindings.json")
        let recipe = KairoRecipe(
            id: "maps-handoff-workflow",
            title: "Maps Handoff Workflow",
            summary: "References an app integration catalog skill.",
            steps: [
                KairoRecipeStep(
                    id: "maps",
                    title: "Prepare Maps Handoff",
                    kind: .enqueueActionDraft,
                    integrationSkillID: .googleMapsDirectionsHandoff
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let firstStore = try await FileBackedKairoRecipeStore(fileURL: fileURL)
        try await firstStore.save(recipe)

        let secondStore = try await FileBackedKairoRecipeStore(fileURL: fileURL)
        let reloadedRecipe = try await secondStore.recipe(id: recipe.id)
        let reloaded = try XCTUnwrap(reloadedRecipe)

        XCTAssertEqual(reloaded.steps.first?.integrationSkillID, .googleMapsDirectionsHandoff)
        XCTAssertNotNil(AppIntegrationSkillCatalog().skill(for: try XCTUnwrap(reloaded.steps.first)))
    }

    func testKairoRecipeRunnerRequiresConfirmationBeforeLowRiskWrites() async throws {
        let recipe = KairoRecipe(
            id: "low-risk-write",
            title: "Low Risk Write",
            summary: "Tests confirmation gating.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "save-memory",
                    title: "Save Memory",
                    kind: .saveMemory,
                    input: .literal("Remember the confirmation gate.")
                )
            ],
            requiredCapabilities: [.memory],
            riskTier: .tier2LowRiskWrite,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let memoryStore = InMemoryMemoryStore()
        let recipeStore = InMemoryKairoRecipeStore(recipes: [recipe])
        let runner = KairoRecipeRunner(recipeStore: recipeStore, memoryStore: memoryStore)

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: false
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertTrue(result.summary.contains("requires confirmation"))
        let memories = try await memoryStore.list(limit: 10)
        XCTAssertTrue(memories.isEmpty)
    }

    func testKairoRecipeRunnerExtractsTasksAndCreatesDraftsDeterministically() async throws {
        let recipe = KairoRecipe(
            id: "task-draft",
            title: "Task Draft",
            summary: "Extracts tasks into drafts.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "extract",
                    title: "Extract Tasks",
                    kind: .extractTasks,
                    input: .sharedContent
                ),
                KairoRecipeStep(
                    id: "draft",
                    title: "Reminder Draft",
                    kind: .createReminderDraft,
                    input: .previousStepOutput
                )
            ],
            requiredCapabilities: [.reminders],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .shareExtension,
            input: "TODO: Send Automations UI screenshot\n- Book review meeting",
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertEqual(result.proposedActions.count, 2)
        XCTAssertEqual(result.proposedActions.map(\.kind), [.createReminderDraft, .createReminderDraft])
        XCTAssertTrue(result.proposedActions.allSatisfy(\.requiresConfirmation))
        XCTAssertTrue(result.stepResults.first?.outputText?.contains("Send Automations UI screenshot") == true)
        XCTAssertTrue(result.summary.contains("2 draft"))
    }

    func testDailyBriefingRecipeRunsAsDraftOnlyAndRequiresActionConfirmation() async throws {
        let recipe = KairoRecipeTemplateFactory.dailyBriefing()
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: "Review launch plan and prepare follow-up drafts.",
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        XCTAssertTrue(result.requiresConfirmation)
        XCTAssertEqual(result.recipeID, recipe.id)
        XCTAssertEqual(result.proposedActions.map(\.kind), [.answer])
        XCTAssertTrue(result.proposedActions.allSatisfy(\.requiresConfirmation))
        XCTAssertTrue(result.stepResults.allSatisfy(\.success))
    }

    func testKairoRecipeRunnerBuildsAppIntegrationPreviewThroughCatalogBinding() async throws {
        let recipe = KairoRecipe(
            id: "mail-handoff-workflow",
            title: "Mail Handoff Workflow",
            summary: "Prepares an integration preview through the catalog.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "mail",
                    title: "Prepare Mail Handoff",
                    kind: .enqueueActionDraft,
                    input: .literal("Draft an email to alex@example.com subject Kairo update body Please review the roadmap."),
                    integrationSkillID: .appleMailHandoff
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.proposedActions.map { $0.kind }, [AgentActionKind.composeEmailDraft])
        XCTAssertTrue(result.stepResults.allSatisfy { $0.success })
    }

    func testKairoRecipeRunnerUsesInjectedIntegrationActionDrafter() async throws {
        let recipe = KairoRecipe(
            id: "injected-integration-drafter-workflow",
            title: "Injected Integration Drafter Workflow",
            summary: "Verifies recipe runner dependency inversion for integration drafts.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "integration",
                    title: "Prepare Integration",
                    kind: .enqueueActionDraft,
                    input: .literal("Use injected drafter"),
                    integrationSkillID: .appleMailHandoff
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let drafter = StubRecipeIntegrationActionDrafter()
        let runner = KairoRecipeRunner(dependencies: KairoRecipeRunnerDependencies(
            recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]),
            actionGate: BuiltInPhoneToolActionGate(),
            integrationActionDrafter: drafter
        ))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        let proposedActionIDs = result.proposedActions.map(\.id)
        XCTAssertEqual(proposedActionIDs, [StubRecipeIntegrationActionDrafter.actionID])
        XCTAssertEqual(drafter.receivedStepIDs, ["integration"])
        XCTAssertEqual(drafter.receivedRecipeIDs, [recipe.id])
        XCTAssertEqual(drafter.receivedInputTexts, ["Use injected drafter"])
    }

    func testKairoRecipeRunnerUsesInjectedStepInputResolver() async throws {
        let recipe = KairoRecipe(
            id: "injected-input-resolver-workflow",
            title: "Injected Input Resolver Workflow",
            summary: "Verifies recipe runner dependency inversion for step input resolution.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "noop",
                    title: "Resolved Noop",
                    kind: .noOp,
                    input: .literal("Original step input")
                )
            ],
            requiredCapabilities: [],
            riskTier: .tier0ReadOnly,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let resolver = StubRecipeStepInputResolver(resolvedInput: "Injected resolved input")
        let runner = KairoRecipeRunner(dependencies: KairoRecipeRunnerDependencies(
            recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]),
            actionGate: BuiltInPhoneToolActionGate(),
            inputResolver: resolver
        ))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: "Request input",
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepResults.first?.outputText, "Injected resolved input")
        XCTAssertEqual(resolver.receivedInputs, [.literal("Original step input")])
        XCTAssertEqual(resolver.receivedRequestInputs, ["Request input"])
        XCTAssertEqual(resolver.receivedPreviousOutputs, ["Request input"])
    }

    func testKairoRecipeRunnerFailsClosedWhenIntegrationBindingIsMissingFromCatalog() async throws {
        let recipe = KairoRecipe(
            id: "missing-integration-workflow",
            title: "Missing Integration Workflow",
            summary: "Must not bypass catalog binding.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "mail",
                    title: "Prepare Mail Handoff",
                    kind: .enqueueActionDraft,
                    input: .literal("Draft an email to alex@example.com"),
                    integrationSkillID: .appleMailHandoff
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(
            recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.proposedActions.isEmpty)
        XCTAssertFalse(result.stepResults.first?.success ?? true)
    }

    func testKairoRecipeRunnerPreparesThirdPartyVisibleHandoffPreviewFromCatalogSkill() async throws {
        let recipe = KairoRecipe(
            id: "google-maps-workflow",
            title: "Google Maps Workflow",
            summary: "Third-party handoff must stay visible and confirmation-gated.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "maps",
                    title: "Prepare Google Maps Handoff",
                    kind: .enqueueActionDraft,
                    input: .literal("Open Google Maps directions to Taipei 101"),
                    integrationSkillID: .googleMapsDirectionsHandoff
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        let action = try XCTUnwrap(result.proposedActions.first)
        XCTAssertEqual(action.kind, .openURL)
        XCTAssertTrue(action.requiresConfirmation)
        guard case .url(let urlString) = action.payload else {
            return XCTFail("Expected Google Maps visible URL handoff payload.")
        }
        let components = try XCTUnwrap(URLComponents(string: urlString))
        XCTAssertEqual(components.scheme, "https")
        XCTAssertEqual(components.host, "www.google.com")
        XCTAssertEqual(components.path, "/maps/dir/")
        XCTAssertTrue(result.stepResults.first?.success ?? false)
    }

    func testKairoRecipeRunnerDoesNotConvertOAuthSetupRequiredCatalogSkillIntoExecutableAction() async throws {
        let recipe = KairoRecipe(
            id: "todoist-workflow",
            title: "Todoist Workflow",
            summary: "OAuth setup-required tools must not become executable.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "todoist",
                    title: "Prepare Todoist Task",
                    kind: .enqueueActionDraft,
                    input: .literal("Create a Todoist task to check Kairo tomorrow"),
                    integrationSkillID: .todoistTaskAPI
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.proposedActions.isEmpty)
        XCTAssertFalse(result.stepResults.first?.success ?? true)
    }

    func testKairoRecipeRunnerPreflightsPhoneToolAvailabilityBeforeExecutingStep() async throws {
        var reminderTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .reminderWrite))
        reminderTool.availabilityStatus = .unsupported
        let recipe = try XCTUnwrap(KairoRecipeTemplateFactory.sampleCatalog().recipe(id: "shared-text-to-tasks"))
        let runner = KairoRecipeRunner(
            recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]),
            toolCatalog: BuiltInPhoneToolCatalog(tools: [reminderTool])
        )

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .shareExtension,
            input: "TODO: Follow up with design",
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.proposedActions.isEmpty)
        XCTAssertEqual(result.errorMessage, "reminder.write is unsupported.")
        XCTAssertTrue(result.stepResults.contains { $0.errorMessage == "reminder.write is unsupported." })
    }

    func testLiveRecipeRunnerProviderUsesInjectedToolCatalogForStepGate() async throws {
        let paths = KairoPaths(appName: "LiveRecipeRunnerProvider-\(UUID().uuidString)")
        let recipe = try XCTUnwrap(KairoRecipeTemplateFactory.sampleCatalog().recipe(id: "shared-text-to-tasks"))
        let store = try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)
        try await store.save(recipe)
        let provider = LiveKairoRecipeRunnerProvider(
            paths: paths,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [])
        )

        let runner = try await provider.makeRunner()
        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .shortcut,
            input: "TODO: Follow up with design",
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertFalse(result.success)
        XCTAssertTrue(result.proposedActions.isEmpty)
        XCTAssertTrue(result.stepResults.contains { $0.errorMessage == "reminder.write is unsupported." })
    }

    func testKairoRecipeRunnerUsesLocalizedLocalFallbackWhenAskStepHasNoProvider() async throws {
        let recipe = KairoRecipe(
            id: "ask-local-fallback",
            title: "Ask Local Fallback",
            summary: "Draft a local-only recipe answer.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "ask",
                    title: "Ask Kairo",
                    kind: .askKairo,
                    input: .literal("Summarize today's plan")
                )
            ],
            requiredCapabilities: [],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: true
        )
        let runner = KairoRecipeRunner(recipeStore: InMemoryKairoRecipeStore(recipes: [recipe]))

        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipe.id,
            surface: .app,
            input: nil,
            dryRun: false,
            userConfirmed: true
        ))

        XCTAssertTrue(result.success)
        XCTAssertEqual(result.stepResults.first?.outputText, KairoL10n.string("recipes.localFallback.output", "Summarize today's plan"))
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }
}

private final class StubRecipeIntegrationActionDrafter: KairoRecipeIntegrationActionDrafting, @unchecked Sendable {
    static let actionID = UUID(uuidString: "00000000-0000-0000-0000-000000000123")!

    private(set) var receivedStepIDs: [String] = []
    private(set) var receivedRecipeIDs: [String] = []
    private(set) var receivedInputTexts: [String] = []

    func draftIntegrationAction(
        for step: KairoRecipeStep,
        inputText: String,
        recipe: KairoRecipe
    ) -> KairoRecipeIntegrationActionDraftResult? {
        receivedStepIDs.append(step.id)
        receivedRecipeIDs.append(recipe.id)
        receivedInputTexts.append(inputText)

        return KairoRecipeIntegrationActionDraftResult(
            stepResult: KairoRecipeStepResult(
                stepID: step.id,
                summary: "Injected integration draft.",
                outputText: inputText,
                success: true
            ),
            actions: [
                AgentAction(
                    id: Self.actionID,
                    kind: .answer,
                    title: "Stub integration action",
                    rationale: "Injected by test drafter.",
                    payload: .text(inputText),
                    riskTier: .tier1Draft
                )
            ]
        )
    }
}

private final class StubRecipeStepInputResolver: KairoRecipeStepInputResolving, @unchecked Sendable {
    private let resolvedInput: String
    private(set) var receivedInputs: [StepInput] = []
    private(set) var receivedRequestInputs: [String?] = []
    private(set) var receivedPreviousOutputs: [String] = []

    init(resolvedInput: String) {
        self.resolvedInput = resolvedInput
    }

    func resolveInput(
        _ input: StepInput,
        requestInput: String?,
        previousOutput: String
    ) -> String {
        receivedInputs.append(input)
        receivedRequestInputs.append(requestInput)
        receivedPreviousOutputs.append(previousOutput)
        return resolvedInput
    }
}
