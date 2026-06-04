import XCTest
@testable import KairoCore

final class KairoRecipeLifecycleTests: XCTestCase {
    func testKairoRecipeTemplateFactoryProvidesInternalSampleRecipes() throws {
        let catalog = KairoRecipeTemplateFactory.sampleCatalog()

        let dailyBriefing = try XCTUnwrap(catalog.recipe(id: "daily-briefing"))
        let sharedTextToTasks = try XCTUnwrap(catalog.recipe(id: "shared-text-to-tasks"))
        let keyboardTodoCapture = try XCTUnwrap(catalog.recipe(id: "keyboard-todo-capture"))

        XCTAssertEqual(dailyBriefing.title, "Daily Briefing")
        XCTAssertEqual(dailyBriefing.createdBy, .template)
        XCTAssertEqual(dailyBriefing.triggerHint, .dailyTime(hour: 8, minute: 30))
        XCTAssertEqual(dailyBriefing.riskTier, .tier1Draft)
        XCTAssertTrue(dailyBriefing.requiredCapabilities.contains(.memory))
        XCTAssertTrue(dailyBriefing.requiredCapabilities.contains(.notifications))
        XCTAssertTrue(dailyBriefing.steps.contains { $0.kind == .askKairo })
        XCTAssertTrue(sharedTextToTasks.steps.contains { $0.kind == .extractTasks })
        XCTAssertTrue(sharedTextToTasks.steps.contains { $0.kind == .createReminderDraft })
        XCTAssertTrue(keyboardTodoCapture.requiredCapabilities.contains(.keyboard))
        XCTAssertFalse(catalog.recipes.contains { $0.title.contains("Apple Shortcut") })
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

    func testKairoRecipeEngineStaysSplitAcrossSupportFiles() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let modelsSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeModels.swift"),
            encoding: .utf8
        )
        let storesSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeStores.swift"),
            encoding: .utf8
        )
        let templatesSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeTemplates.swift"),
            encoding: .utf8
        )
        let planningSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipePlanning.swift"),
            encoding: .utf8
        )
        let runnerSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoRecipeRunner.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("Kairo/Services/KairoRecipeEngine.swift").path))
        XCTAssertLessThan(modelsSource.split(separator: "\n").count, 260)
        XCTAssertLessThan(runnerSource.split(separator: "\n").count, 380)
        XCTAssertTrue(modelsSource.contains("public struct KairoRecipe"))
        XCTAssertTrue(storesSource.contains("public actor FileBackedKairoRecipeStore"))
        XCTAssertTrue(templatesSource.contains("public enum KairoRecipeTemplateFactory"))
        XCTAssertTrue(planningSource.contains("public struct KairoRecipePlanner"))
        XCTAssertTrue(runnerSource.contains("public struct KairoRecipeRunner"))
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }
}
