import XCTest
import Foundation
#if canImport(AppIntents)
import AppIntents
#endif
@testable import KairoCore

final class KairoShortcutNodeTests: XCTestCase {
    func testAppleShortcutsIntegrationListsImplementedAppIntentIdentifiers() throws {
        let registry = IntegrationRegistry()
        let shortcuts = try XCTUnwrap(registry.integration(for: "apple-shortcuts"))

        XCTAssertEqual(
            shortcuts.appIntentIdentifiers,
            [
                "AskKairoIntent",
                "SaveToKairoMemoryIntent",
                "SearchKairoMemoryIntent",
                "SummarizeWithKairoIntent",
                "ExtractKairoTasksIntent",
                "CreateDailyBriefingIntent",
                "CreateReminderDraftsIntent",
                "RunKairoShortcutNodeIntent",
                "RunKairoRecipeIntent",
                "SuggestKairoRecipeIntent",
                "ListKairoRecipesIntent",
                "RunKairoDailyBriefingIntent"
            ]
        )
    }

#if canImport(AppIntents)
    @available(iOS 16.0, macOS 13.0, *)
    func testShortcutAppIntentTypesCoverShortcutRuntimeNodes() throws {
        _ = AskKairoIntent()
        _ = SaveToKairoMemoryIntent()
        _ = SearchKairoMemoryIntent()
        _ = SummarizeWithKairoIntent()
        _ = ExtractKairoTasksIntent()
        _ = CreateDailyBriefingIntent()
        _ = CreateReminderDraftsIntent()
        _ = RunKairoShortcutNodeIntent()
        _ = RunKairoRecipeIntent()
        _ = SuggestKairoRecipeIntent()
        _ = ListKairoRecipesIntent()
        _ = RunKairoDailyBriefingIntent()
    }
#endif

    func testShortcutDemoCatalogContainsPracticalRecipesWithNodeContracts() throws {
        let catalog = ShortcutDemoCatalog.default

        XCTAssertGreaterThanOrEqual(catalog.recipes.count, 4)
        XCTAssertEqual(catalog.recipe(id: "daily-briefing")?.steps.map(\.nodeKind), [.dailyBriefing])
        XCTAssertEqual(catalog.recipe(id: "save-shared-text")?.steps.map(\.nodeKind), [.saveMemory, .extractTasks])
        XCTAssertEqual(catalog.recipe(id: "screenshot-to-reminders")?.steps.map(\.nodeKind), [.extractTasks, .createReminderDraft])
        XCTAssertEqual(catalog.recipe(id: "generic-node-runner")?.steps.map(\.nodeKind), [.summarize, .extractTasks])

        for recipe in catalog.recipes {
            XCTAssertFalse(recipe.id.isEmpty)
            XCTAssertFalse(recipe.title.isEmpty)
            XCTAssertFalse(recipe.triggerSummary.isEmpty)
            XCTAssertFalse(recipe.steps.isEmpty)

            for step in recipe.steps {
                XCTAssertFalse(step.inputContract.requiredFields.isEmpty)
                XCTAssertFalse(step.outputContract.fields.isEmpty)
                XCTAssertFalse(step.shortcutActionTitle.isEmpty)
            }
        }
    }

    func testShortcutNodeInvocationRunsNodeFromJSONAndReturnsEncodedOutput() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let service = ShortcutNodeInvocationService(runtime: runtime)
        let input = ShortcutNodeInput(
            text: """
            User provided this through a Shortcut dictionary.
            Action: Validate generic Kairo node output
            """,
            sourceName: "Generic Shortcut Node",
            variables: ["shortcutRecipeID": "generic-node-runner"]
        )

        let outputJSON = try await service.run(
            nodeKindRawValue: "extractTasks",
            inputJSON: try input.encodedJSONString()
        )
        let output = try JSONDecoder().decode(ShortcutNodeOutput.self, from: Data(outputJSON.utf8))

        XCTAssertEqual(output.kind, .extractTasks)
        XCTAssertEqual(output.fields["sourceName"], "Generic Shortcut Node")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "generic-node-runner")
        XCTAssertEqual(output.fields["taskCount"], "1")
        XCTAssertEqual(output.tasks.map(\.title), ["Validate generic Kairo node output"])
        XCTAssertTrue(outputJSON.contains(#""kind":"extractTasks""#))
    }

    func testShortcutNodeInvocationRejectsUnsupportedNodeKind() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let service = ShortcutNodeInvocationService(runtime: runtime)

        do {
            _ = try await service.run(
                nodeKindRawValue: "silentCrossAppClick",
                inputJSON: try ShortcutNodeInput(text: "No private control.").encodedJSONString()
            )
            XCTFail("Unsupported Shortcut node kind should throw.")
        } catch let error as ShortcutNodeInvocationError {
            XCTAssertEqual(error, .unsupportedNodeKind("silentCrossAppClick"))
        }
    }

    func testShortcutDemoCatalogExportsSampleInputsForShortcutNodes() throws {
        let catalog = ShortcutDemoCatalog.default
        let saveSharedText = try XCTUnwrap(catalog.recipe(id: "save-shared-text"))
        let firstStep = try XCTUnwrap(saveSharedText.steps.first)

        XCTAssertEqual(firstStep.nodeKind, .saveMemory)
        XCTAssertEqual(firstStep.sampleInput.sourceName, "Share Sheet")
        XCTAssertTrue(firstStep.sampleInput.text.contains("TODO:"))
        XCTAssertEqual(firstStep.sampleInput.variables["shortcutRecipeID"], "save-shared-text")

        let encoded = try firstStep.sampleInput.encodedJSONString()
        XCTAssertTrue(encoded.contains(#""sourceName":"Share Sheet""#))
        XCTAssertTrue(encoded.contains(#""shortcutRecipeID":"save-shared-text""#))
    }

    func testShortcutDemoRecipeBuildsSettingsReadableContractSummaries() throws {
        let catalog = ShortcutDemoCatalog.default
        let dailyBriefing = try XCTUnwrap(catalog.recipe(id: "daily-briefing"))
        let saveSharedText = try XCTUnwrap(catalog.recipe(id: "save-shared-text"))

        XCTAssertEqual(dailyBriefing.settingsStepSummary, "1 step: dailyBriefing")
        XCTAssertEqual(saveSharedText.settingsStepSummary, "2 steps: saveMemory -> extractTasks")
        XCTAssertTrue(dailyBriefing.settingsContractSummary.contains("Input: text, sourceName, variables"))
        XCTAssertTrue(dailyBriefing.settingsContractSummary.contains("Output: displayText, fields.briefing, fields.taskCount, tasks"))
        XCTAssertTrue(saveSharedText.settingsSampleInputPreview.contains("User research note"))
    }

    func testAppleShortcutsIntegrationTemplatesMirrorDemoCatalog() throws {
        let registry = IntegrationRegistry()
        let shortcuts = try XCTUnwrap(registry.integration(for: "apple-shortcuts"))
        let templateIDs = Set(shortcuts.shortcutTemplates.map(\.identifier))
        let demoIDs = Set(ShortcutDemoCatalog.default.recipes.map(\.id))

        XCTAssertTrue(templateIDs.isSuperset(of: demoIDs))
    }

    func testShortcutTemplateRegistryShipsUserInstalledRecipeTemplates() throws {
        let registry = ShortcutTemplateRegistry.default
        let templateIDs = registry.templates.map(\.identifier)

        XCTAssertEqual(templateIDs, [
            "daily-briefing-shortcut",
            "meeting-prep-shortcut",
            "share-text-to-kairo-shortcut",
            "screenshot-to-tasks-shortcut",
            "action-button-ask-kairo-shortcut",
            "run-kairo-recipe-shortcut"
        ])
        XCTAssertTrue(registry.manualInstallDisclaimer.contains("Kairo creates internal recipes"))
        XCTAssertTrue(registry.manualInstallDisclaimer.contains("Apple Shortcuts installation requires user approval"))
        XCTAssertTrue(registry.templates.allSatisfy(\.requiresExplicitUserSetup))
        XCTAssertTrue(registry.templates.allSatisfy { !$0.setupInstructions.isEmpty })
        XCTAssertTrue(registry.templates.allSatisfy { $0.installURL == nil })
        XCTAssertFalse(registry.templates.flatMap(\.setupInstructions).contains { $0.localizedCaseInsensitiveContains("silent install") })

        let daily = try XCTUnwrap(registry.template(id: "daily-briefing-shortcut"))
        XCTAssertEqual(daily.category, .dailyBriefing)
        XCTAssertEqual(daily.recommendedRecipeTemplateID, "daily-briefing")
        XCTAssertTrue(daily.requiredIntentIdentifiers.contains("RunKairoDailyBriefingIntent"))

        let runRecipe = try XCTUnwrap(registry.template(id: "run-kairo-recipe-shortcut"))
        XCTAssertEqual(runRecipe.category, .genericRecipe)
        XCTAssertTrue(runRecipe.requiredIntentIdentifiers.contains("RunKairoRecipeIntent"))
        XCTAssertTrue(runRecipe.setupInstructions.joined(separator: " ").contains("Recipe ID"))
    }

    func testKairoRecipeAppIntentsAreDocumentedAsUserApprovedShortcutBridge() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let intentsSource = try String(contentsOf: root.appendingPathComponent("Kairo/Intents/KairoIntents.swift"), encoding: .utf8)

        XCTAssertTrue(intentsSource.contains("struct RunKairoRecipeIntent"))
        XCTAssertTrue(intentsSource.contains("struct SuggestKairoRecipeIntent"))
        XCTAssertTrue(intentsSource.contains("struct ListKairoRecipesIntent"))
        XCTAssertTrue(intentsSource.contains("struct RunKairoDailyBriefingIntent"))
        XCTAssertTrue(intentsSource.contains("FileBackedKairoRecipeStore"))
        XCTAssertTrue(intentsSource.contains("KairoRecipeRunner"))
        XCTAssertTrue(intentsSource.contains("surface: .shortcut"))
        XCTAssertTrue(intentsSource.contains("userConfirmed: false"))
        XCTAssertTrue(intentsSource.contains("requires confirmation in the Kairo app"))
        XCTAssertTrue(intentsSource.contains("does not create Apple Shortcuts"))
        XCTAssertFalse(intentsSource.contains("shortcuts://create"))
        XCTAssertFalse(intentsSource.contains("shortcuts://x-callback-url/create"))
    }

    func testAppleShortcutsIntegrationDocumentsUserVisibleHandoffURLScheme() throws {
        let registry = IntegrationRegistry()
        let shortcuts = try XCTUnwrap(registry.integration(for: "apple-shortcuts"))
        let scheme = try XCTUnwrap(shortcuts.urlSchemes.first { $0.scheme == "shortcuts" })

        XCTAssertTrue(shortcuts.surfaces.contains(.urlScheme))
        XCTAssertEqual(scheme.exampleURL, "shortcuts://run-shortcut?name=Kairo%20Daily%20Briefing&input=text")
        XCTAssertTrue(scheme.userVisibleOnly)
        XCTAssertTrue(scheme.notes.contains("user-visible"))
    }

    func testShortcutHandoffBuildsRunShortcutURLWithEncodedInputAndCallbackContract() throws {
        let service = ShortcutHandoffService()
        let request = ShortcutHandoffRequest(
            shortcutName: "Kairo Daily Briefing",
            input: ShortcutNodeInput(
                text: "Action: Review Shortcut handoff",
                sourceName: "Kairo App",
                variables: ["recipe": "daily-briefing"]
            ),
            callbackBaseURL: URL(string: "kairo://shortcuts/callback")!,
            requestID: "handoff-123"
        )

        let url = try service.runShortcutURL(for: request)
        let components = try XCTUnwrap(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })
        let encodedInput = try XCTUnwrap(query["text"])
        let decodedInput = try JSONDecoder().decode(ShortcutNodeInput.self, from: Data(encodedInput.utf8))

        XCTAssertEqual(components.scheme, "shortcuts")
        XCTAssertEqual(components.host, "run-shortcut")
        XCTAssertEqual(query["name"], "Kairo Daily Briefing")
        XCTAssertEqual(query["input"], "text")
        XCTAssertEqual(decodedInput.text, "Action: Review Shortcut handoff")
        XCTAssertEqual(decodedInput.sourceName, "Kairo App")
        XCTAssertEqual(decodedInput.variables["recipe"], "daily-briefing")
        XCTAssertEqual(decodedInput.variables["kairoHandoffRequestID"], "handoff-123")
        XCTAssertEqual(decodedInput.variables["kairoCallbackURL"], "kairo://shortcuts/callback?requestID=handoff-123")
    }

    func testShortcutHandoffParsesStructuredOutputCallback() throws {
        let service = ShortcutHandoffService()
        let output = ShortcutNodeOutput(
            kind: .dailyBriefing,
            displayText: "Briefing ready.",
            fields: ["briefing": "Review Shortcut handoff"]
        )
        var components = URLComponents(string: "kairo://shortcuts/callback")!
        components.queryItems = [
            URLQueryItem(name: "requestID", value: "handoff-123"),
            URLQueryItem(name: "output", value: try output.encodedJSONString())
        ]

        let callback = try service.parseCallback(try XCTUnwrap(components.url))

        XCTAssertEqual(callback.requestID, "handoff-123")
        XCTAssertEqual(callback.output, output)
    }

    func testShortcutSaveMemoryNodeSavesTextAndReturnsStructuredOutput() async throws {
        let store = InMemoryMemoryStore()
        let runtime = ShortcutNodeRuntime(memoryStore: store)
        let input = ShortcutNodeInput(
            text: """
            Client asked about Kairo Shortcuts.
            TODO: Send prototype link
            - [ ] Draft follow-up reminder
            """,
            sourceName: "Shortcut Input"
        )

        let output = try await runtime.run(.saveMemory, input: input)

        let memoryID = try XCTUnwrap(output.memoryID)
        let saved = try await store.search(query: "Shortcuts", limit: 10)
        XCTAssertEqual(saved.map(\.id), [memoryID])
        XCTAssertEqual(saved.first?.source, .appIntent)
        XCTAssertEqual(output.kind, .saveMemory)
        XCTAssertEqual(output.fields["memoryID"], memoryID.uuidString)
        XCTAssertEqual(output.fields["taskCount"], "2")
        XCTAssertEqual(output.tasks.map(\.title), ["Send prototype link", "Draft follow-up reminder"])
        XCTAssertTrue(output.displayText.contains("Saved"))
        XCTAssertTrue(try output.encodedJSONString().contains(memoryID.uuidString))
    }

    func testShortcutSearchMemoryNodeReturnsMatchesForDownstreamShortcutSteps() async throws {
        let memory = MemoryRecord(
            title: "Kairo Shortcut Recipes",
            summary: "Daily briefing and shared text recipe notes.",
            content: "Use Shortcuts to pass text into Kairo and return structured output.",
            source: .appIntent
        )
        let store = InMemoryMemoryStore(seed: [memory])
        let runtime = ShortcutNodeRuntime(memoryStore: store)

        let output = try await runtime.run(.searchMemory, input: ShortcutNodeInput(query: "briefing", limit: 5))

        XCTAssertEqual(output.kind, .searchMemory)
        XCTAssertEqual(output.fields["matchCount"], "1")
        XCTAssertEqual(output.memoryMatches.map(\.id), [memory.id])
        XCTAssertEqual(output.memoryMatches.first?.title, "Kairo Shortcut Recipes")
        XCTAssertTrue(output.displayText.contains("1 memory"))
    }

    func testShortcutExtractTasksNodeBuildsReminderDraftsWithoutExecuting() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let input = ShortcutNodeInput(
            text: """
            Meeting notes:
            Action: Review HomeKit capability matrix
            Reminder: Build OAuth login demo
            """
        )

        let output = try await runtime.run(.extractTasks, input: input)

        XCTAssertEqual(output.kind, .extractTasks)
        XCTAssertEqual(output.fields["taskCount"], "2")
        XCTAssertEqual(output.tasks.map(\.title), ["Review HomeKit capability matrix", "Build OAuth login demo"])
        XCTAssertEqual(output.reminderDrafts.map(\.title), ["Review HomeKit capability matrix", "Build OAuth login demo"])
        XCTAssertTrue(output.proposedActions.isEmpty)
        XCTAssertTrue(output.displayText.contains("2 tasks"))
    }

    func testShortcutDemoRecipeRunnerExecutesSampleStepsWithStructuredOutputs() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "save-shared-text"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "save-shared-text")
        XCTAssertEqual(run.recipeTitle, "Save Shared Text")
        XCTAssertEqual(run.steps.map(\.nodeKind), [.saveMemory, .extractTasks])
        XCTAssertEqual(run.steps.map(\.shortcutActionTitle), ["Save to Kairo Memory", "Extract Kairo Tasks"])
        XCTAssertEqual(run.steps[0].output.kind, .saveMemory)
        XCTAssertEqual(run.steps[0].output.fields["taskCount"], "1")
        XCTAssertNotNil(run.steps[0].output.memoryID)
        XCTAssertEqual(run.steps[1].output.kind, .extractTasks)
        XCTAssertEqual(run.steps[1].output.fields["taskCount"], "1")
        XCTAssertEqual(run.totalTaskCount, 2)
        XCTAssertTrue(run.displaySummary.contains("Save Shared Text"))
        XCTAssertTrue(run.displaySummary.contains("2 steps"))
    }

    func testShortcutDemoRecipeRunnerCanChainPreviousStepTextIntoNextStep() async throws {
        let recipe = ShortcutDemoRecipe(
            id: "chain-summary-to-tasks",
            title: "Chain Summary To Tasks",
            summary: "Summarize text, then extract tasks from the previous output.",
            triggerSummary: "Manual test recipe.",
            setupNotes: ["Use previous output as the next step input."],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Summarize",
                    nodeKind: .summarize,
                    inputContract: ShortcutNodeContract(requiredFields: ["text"], description: "Source text."),
                    outputContract: ShortcutNodeContract(requiredFields: ["displayText"], description: "Summary."),
                    sampleInput: ShortcutNodeInput(
                        text: "Action: Prepare Shortcut I/O schema\nReminder: Validate node chain",
                        variables: ["shortcutRecipeID": "chain-summary-to-tasks"]
                    )
                ),
                ShortcutDemoStep(
                    shortcutActionTitle: "Extract From Previous Output",
                    nodeKind: .extractTasks,
                    inputContract: ShortcutNodeContract(
                        requiredFields: ["text"],
                        optionalFields: ["previousStepOutput"],
                        description: "Previous Kairo output."
                    ),
                    outputContract: ShortcutNodeContract(requiredFields: ["fields.taskCount"], description: "Task count."),
                    sampleInput: ShortcutNodeInput(
                        text: "",
                        variables: [
                            "shortcutRecipeID": "chain-summary-to-tasks",
                            "kairoInputSource": "previousStepOutput"
                        ]
                    )
                )
            ]
        )
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        let expectedChainText = "Action: Prepare Shortcut I/O schema\nReminder: Validate node chain"
        XCTAssertEqual(run.steps[0].output.fields["chainText"], expectedChainText)
        XCTAssertEqual(run.steps[1].input.text, expectedChainText)
        XCTAssertEqual(run.steps[1].output.fields["taskCount"], "2")
        XCTAssertEqual(run.totalTaskCount, 2)
    }
}
