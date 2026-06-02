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
                "CreateReminderDraftsIntent"
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
    }
#endif

    func testShortcutDemoCatalogContainsPracticalRecipesWithNodeContracts() throws {
        let catalog = ShortcutDemoCatalog.default

        XCTAssertGreaterThanOrEqual(catalog.recipes.count, 3)
        XCTAssertEqual(catalog.recipe(id: "daily-briefing")?.steps.map(\.nodeKind), [.dailyBriefing])
        XCTAssertEqual(catalog.recipe(id: "save-shared-text")?.steps.map(\.nodeKind), [.saveMemory, .extractTasks])
        XCTAssertEqual(catalog.recipe(id: "screenshot-to-reminders")?.steps.map(\.nodeKind), [.extractTasks, .createReminderDraft])

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
}
