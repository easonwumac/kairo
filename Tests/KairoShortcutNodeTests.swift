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
                "CreateCalendarDraftsIntent",
                "CreateContactDraftsIntent",
                "CreateEmailDraftsIntent",
                "PrepareMessageHandoffIntent",
                "PreparePhoneCallHandoffIntent",
                "PrepareWebSearchHandoffIntent",
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
        _ = CreateCalendarDraftsIntent()
        _ = CreateContactDraftsIntent()
        _ = CreateEmailDraftsIntent()
        _ = PrepareMessageHandoffIntent()
        _ = PreparePhoneCallHandoffIntent()
        _ = PrepareWebSearchHandoffIntent()
        _ = RunKairoShortcutNodeIntent()
        _ = RunKairoRecipeIntent()
        _ = SuggestKairoRecipeIntent()
        _ = ListKairoRecipesIntent()
        _ = RunKairoDailyBriefingIntent()
    }
#endif

    func testShortcutDemoCatalogContainsPracticalRecipesWithNodeContracts() throws {
        let catalog = ShortcutDemoCatalog.default

        XCTAssertGreaterThanOrEqual(catalog.recipes.count, 10)
        XCTAssertEqual(catalog.recipe(id: "daily-briefing")?.steps.map(\.nodeKind), [.dailyBriefing])
        XCTAssertEqual(catalog.recipe(id: "save-shared-text")?.steps.map(\.nodeKind), [.saveMemory, .extractTasks])
        XCTAssertEqual(catalog.recipe(id: "screenshot-to-reminders")?.steps.map(\.nodeKind), [.extractTasks, .createReminderDraft])
        XCTAssertEqual(catalog.recipe(id: "reply-draft-from-shared-text")?.steps.map(\.nodeKind), [.summarize, .draftReply])
        XCTAssertEqual(catalog.recipe(id: "email-triage")?.steps.map(\.nodeKind), [.summarize, .extractTasks, .draftReply])
        XCTAssertEqual(catalog.recipe(id: "message-reply-handoff")?.steps.map(\.nodeKind.rawValue), ["prepareMessageHandoff"])
        XCTAssertEqual(catalog.recipe(id: "phone-call-handoff")?.steps.map(\.nodeKind.rawValue), ["preparePhoneCallHandoff"])
        XCTAssertEqual(catalog.recipe(id: "web-search-handoff")?.steps.map(\.nodeKind.rawValue), ["prepareWebSearchHandoff"])
        XCTAssertEqual(catalog.recipe(id: "contact-draft-from-shared-text")?.steps.map(\.nodeKind.rawValue), ["createContactDraft"])
        XCTAssertEqual(catalog.recipe(id: "meeting-prep-brief")?.steps.map(\.nodeKind), [.searchMemory, .summarize, .extractTasks])
        XCTAssertEqual(catalog.recipe(id: "request-to-recipe-draft")?.steps.map(\.nodeKind.rawValue), ["createRecipeDraft"])
        XCTAssertEqual(catalog.recipe(id: "meeting-text-to-calendar-draft")?.steps.map(\.nodeKind), [.createCalendarDraft])
        XCTAssertEqual(catalog.recipe(id: "email-draft-from-shared-text")?.steps.map(\.nodeKind), [.createEmailDraft])
        XCTAssertEqual(catalog.recipe(id: "home-action-preview")?.steps.map(\.nodeKind.rawValue), ["previewHomeAction"])
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

#if canImport(AppIntents)
    func testShortcutIntentSupportBuildsInvocationServiceFromInjectedRuntimeProvider() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let provider = StubShortcutNodeRuntimeProvider(runtime: runtime)
        let service = try await KairoShortcutIntentSupport.invocationService(provider: provider)
        let input = ShortcutNodeInput(
            text: "Action: Validate injected runtime provider",
            sourceName: "Injected Shortcut Runtime"
        )

        let outputJSON = try await service.run(
            nodeKindRawValue: "extractTasks",
            inputJSON: try input.encodedJSONString()
        )
        let output = try JSONDecoder().decode(ShortcutNodeOutput.self, from: Data(outputJSON.utf8))

        XCTAssertEqual(output.kind, .extractTasks)
        XCTAssertEqual(output.tasks.map(\.title), ["Validate injected runtime provider"])
        XCTAssertEqual(output.fields["sourceName"], "Injected Shortcut Runtime")
    }
#endif

    func testLiveAgentProviderUsesFileBackedMemoryAndInjectedToolCatalog() async throws {
        let paths = KairoPaths(appName: "LiveAgentProvider-\(UUID().uuidString)")
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        try await memoryStore.save(MemoryRecord(
            title: "Project Alpha",
            summary: "Provider memory context",
            content: "Project Alpha launch review is tomorrow.",
            source: .manual
        ))
        let proposedAction = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "Provider test action",
            payload: .text("Filtered"),
            riskTier: .tier2LowRiskWrite
        )
        let aiProvider = BackendAPICapturingAIProvider(response: AICompletionResponse(
            message: "Provider response",
            proposedActions: [proposedAction]
        ))
        let calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        let capabilityRegistry = CapabilityRegistry(capabilities: [
            Capability(
                key: .calendar,
                displayName: "Injected Calendar",
                description: "Injected live agent capability boundary.",
                permission: .runtimePrompt,
                status: .available,
                isMVP: true
            )
        ])
        let provider = LiveKairoAgentProvider(
            paths: paths,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: aiProvider,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [calendarTool]),
            capabilityRegistry: capabilityRegistry
        )

        let agent = try await provider.makeAgent()
        let response = try await agent.respond(to: "Project Alpha")
        let capturedRequestValue = await aiProvider.capturedRequest()
        let capturedRequest: AICompletionRequest = try XCTUnwrap(capturedRequestValue)

        XCTAssertEqual(response.message, "Provider response")
        XCTAssertEqual(capturedRequest.memoryContext.map(\.title), ["Project Alpha"])
        XCTAssertEqual(capturedRequest.allowedCapabilities, [.calendar])
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testLiveAgentProviderBuildsDefaultRegistryFromInjectedAppIntegrationCatalog() async throws {
        let paths = KairoPaths(appName: "LiveAgentProviderCatalog-\(UUID().uuidString)")
        let todoistSkill = try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .todoistTaskAPI))
        let provider = LiveKairoAgentProvider(
            paths: paths,
            credentialStore: InMemoryCredentialStore(),
            aiProvider: BackendAPICapturingAIProvider(response: AICompletionResponse(message: "Provider response")),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [todoistSkill])
        )

        let agent = try await provider.makeAgent()
        let response = try await agent.respond(to: "Read Gmail and create a Todoist task")

        XCTAssertNotNil(response.toolCandidates.first { $0.skillID == AppIntegrationSkillID.todoistTaskAPI.rawValue })
        XCTAssertFalse(response.toolCandidates.contains { $0.integrationKey == "gmail-google-workspace" })
    }

    func testShortcutSafetyCriticalNodesReturnStableSchemaAndConfirmationFields() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let safetyCases: [(ShortcutNodeKind, ShortcutNodeInput, String, AgentActionKind?)] = [
            (
                .createReminderDraft,
                ShortcutNodeInput(text: "Reminder: Review beta safety checklist", sourceName: "Safety Shortcut"),
                "reminderRequiresConfirmation",
                nil
            ),
            (
                .createCalendarDraft,
                ShortcutNodeInput(
                    text: "Meeting: Beta safety review",
                    sourceName: "Safety Shortcut",
                    variables: [
                        "startDateISO": "2026-06-03T09:00:00Z",
                        "endDateISO": "2026-06-03T10:00:00Z"
                    ]
                ),
                "calendarRequiresConfirmation",
                nil
            ),
            (
                .createContactDraft,
                ShortcutNodeInput(
                    text: "Name: Alex Chen\nPhone: +1-555-0100",
                    sourceName: "Safety Shortcut"
                ),
                "contactRequiresConfirmation",
                .createContactDraft
            ),
            (
                .createEmailDraft,
                ShortcutNodeInput(
                    text: "To: ops@example.com\nSubject: Beta\nPlease review Kairo.",
                    sourceName: "Safety Shortcut"
                ),
                "emailRequiresConfirmation",
                .composeEmailDraft
            ),
            (
                .prepareMessageHandoff,
                ShortcutNodeInput(
                    text: "Please review the Kairo beta.",
                    sourceName: "Safety Shortcut",
                    variables: ["recipient": "0912345678", "body": "Please review the Kairo beta."]
                ),
                "messageRequiresConfirmation",
                .openMessageHandoff
            ),
            (
                .preparePhoneCallHandoff,
                ShortcutNodeInput(
                    text: "Call Alex about Kairo.",
                    sourceName: "Safety Shortcut",
                    variables: ["phoneNumber": "+1 (555) 0100", "label": "Alex"]
                ),
                "phoneCallRequiresConfirmation",
                .openPhoneCallHandoff
            ),
            (
                .prepareWebSearchHandoff,
                ShortcutNodeInput(
                    text: "SwiftUI App Intents examples",
                    sourceName: "Safety Shortcut",
                    variables: ["query": "SwiftUI App Intents examples"]
                ),
                "webSearchRequiresConfirmation",
                .openWebSearchHandoff
            ),
            (
                .previewHomeAction,
                ShortcutNodeInput(
                    text: "Turn on the office desk lamp",
                    sourceName: "Safety Shortcut",
                    variables: [
                        "homeName": "Home",
                        "roomName": "Office",
                        "targetName": "Desk Lamp",
                        "command": "setPower",
                        "value": "true"
                    ]
                ),
                "homeActionRequiresConfirmation",
                .controlHome
            )
        ]

        for (kind, input, confirmationField, expectedActionKind) in safetyCases {
            let output = try await runtime.run(kind, input: input)
            let outputJSON = try output.encodedJSONString()
            let object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(outputJSON.utf8)) as? [String: Any],
                "Expected ShortcutNodeOutput JSON object for \(kind.rawValue)."
            )

            XCTAssertEqual(object["schemaVersion"] as? Int, 1, kind.rawValue)
            XCTAssertEqual(output.fields[confirmationField], "true", kind.rawValue)
            XCTAssertTrue(output.proposedActions.allSatisfy(\.requiresConfirmation), kind.rawValue)

            if let expectedActionKind {
                XCTAssertTrue(output.proposedActions.contains { $0.kind == expectedActionKind }, kind.rawValue)
            } else {
                XCTAssertTrue(output.proposedActions.isEmpty, kind.rawValue)
            }
        }
    }

    func testShortcutCreateRecipeDraftNodeReturnsDisabledInternalRecipePreview() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let kind = try XCTUnwrap(ShortcutNodeKind(rawValue: "createRecipeDraft"))
        let input = ShortcutNodeInput(
            text: "每天早上整理今天事情，包含待辦和會議提醒",
            sourceName: "Automation Idea Shortcut",
            variables: ["shortcutRecipeID": "request-to-recipe-draft"]
        )

        let output = try await runtime.run(kind, input: input)
        let outputJSON = try output.encodedJSONString()

        XCTAssertEqual(output.kind.rawValue, "createRecipeDraft")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "request-to-recipe-draft")
        XCTAssertEqual(output.fields["sourceName"], "Automation Idea Shortcut")
        XCTAssertEqual(output.fields["recipeCount"], "3")
        XCTAssertEqual(output.fields["recipeID"], "daily-briefing")
        XCTAssertEqual(output.fields["recipeTitle"], "Daily Briefing")
        XCTAssertEqual(output.fields["recipeRequiresReview"], "true")
        XCTAssertEqual(output.fields["recipeStepCount"], "2")
        XCTAssertEqual(output.fields["recipeRiskTier"], ActionRiskTier.tier1Draft.rawValue)
        XCTAssertTrue(output.displayText.contains("Review and enable in Kairo"))
        XCTAssertTrue(output.displayText.contains("does not create Apple Shortcuts"))
        XCTAssertTrue(output.tasks.isEmpty)
        XCTAssertTrue(output.reminderDrafts.isEmpty)
        XCTAssertTrue(output.proposedActions.isEmpty)
        XCTAssertTrue(outputJSON.contains(#""recipeDrafts""#))
        XCTAssertTrue(outputJSON.contains(#""isEnabled":false"#))
        XCTAssertTrue(outputJSON.contains(#""createdBy":"agentSuggested""#))
    }

    func testShortcutCreateRecipeDraftNodeUsesInjectedRecipePlanner() async throws {
        let recipe = KairoRecipe(
            id: "shortcut-runtime-injected-recipe",
            title: "Shortcut Runtime Injected Recipe",
            summary: "Shortcut node runtime planner boundary.",
            triggerHint: .manual,
            steps: [
                KairoRecipeStep(
                    id: "ask",
                    title: "Ask",
                    kind: .askKairo,
                    input: .literal("Injected")
                )
            ],
            requiredCapabilities: [.appIntents],
            riskTier: .tier1Draft,
            cloudPolicy: .localOnly,
            isEnabled: false
        )
        let runtime = ShortcutNodeRuntime(
            memoryStore: InMemoryMemoryStore(),
            recipePlanner: ShortcutNodeRecipePlannerStub(recipes: [recipe])
        )

        let output = try await runtime.run(
            .createRecipeDraft,
            input: ShortcutNodeInput(text: "ignored by stub planner")
        )

        XCTAssertEqual(output.fields["recipeID"], recipe.id)
        XCTAssertEqual(output.fields["recipeStepCount"], "1")
        XCTAssertEqual(output.recipeDrafts.map(\.id), [recipe.id])
    }

    func testShortcutPreviewHomeActionNodeReturnsConfirmationOnlyAction() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let kind = try XCTUnwrap(ShortcutNodeKind(rawValue: "previewHomeAction"))
        let input = ShortcutNodeInput(
            text: "Turn on the office desk lamp",
            sourceName: "Home Shortcut",
            variables: [
                "shortcutRecipeID": "home-action-preview",
                "homeName": "Home",
                "roomName": "Office",
                "targetName": "Desk Lamp",
                "command": "setPower",
                "value": "true"
            ]
        )

        let output = try await runtime.run(kind, input: input)
        let action = try XCTUnwrap(output.proposedActions.first)

        XCTAssertEqual(output.kind.rawValue, "previewHomeAction")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "home-action-preview")
        XCTAssertEqual(output.fields["homeActionCount"], "1")
        XCTAssertEqual(output.fields["homeActionRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["homeActionRiskTier"], ActionRiskTier.tier3HighRiskExternal.rawValue)
        XCTAssertTrue(output.displayText.contains("Review in Kairo"))
        XCTAssertEqual(output.tasks, [])
        XCTAssertEqual(output.reminderDrafts, [])
        XCTAssertEqual(action.kind, .controlHome)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertEqual(action.riskTier, .tier3HighRiskExternal)
        guard case let .homeControl(request) = action.payload else {
            return XCTFail("Expected HomeControlRequest payload.")
        }
        XCTAssertEqual(request.homeName, "Home")
        XCTAssertEqual(request.roomName, "Office")
        XCTAssertEqual(request.targetName, "Desk Lamp")
        XCTAssertEqual(request.command, .setPower)
        XCTAssertEqual(request.value, .bool(true))
    }

    func testShortcutRuntimePreflightsNodeAvailabilityThroughBuiltInToolCatalog() async throws {
        var homeTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .homeKitPreview))
        homeTool.availabilityStatus = .unsupported
        let runtime = ShortcutNodeRuntime(
            memoryStore: InMemoryMemoryStore(),
            toolCatalog: BuiltInPhoneToolCatalog(tools: [homeTool])
        )
        let input = ShortcutNodeInput(
            text: "Turn on the office desk lamp",
            sourceName: "Home Shortcut"
        )

        let output = try await runtime.run(.previewHomeAction, input: input)

        XCTAssertTrue(output.proposedActions.isEmpty)
        XCTAssertEqual(output.kind, .previewHomeAction)
        XCTAssertEqual(output.fields["toolID"], BuiltInPhoneToolID.homeKitPreview.rawValue)
        XCTAssertEqual(output.fields["toolAvailability"], BuiltInPhoneToolAvailabilityStatus.unsupported.rawValue)
        XCTAssertEqual(output.fields["success"], "false")
        XCTAssertTrue(output.displayText.contains("HomeKit"))
    }

    func testLiveShortcutRuntimeProviderUsesInjectedToolCatalogForNodeGate() async throws {
        let paths = KairoPaths(appName: "LiveShortcutRuntimeProvider-\(UUID().uuidString)")
        let calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        let provider = LiveShortcutNodeRuntimeProvider(
            paths: paths,
            toolCatalog: BuiltInPhoneToolCatalog(tools: [calendarTool])
        )
        let runtime = try await provider.makeRuntime()

        let output = try await runtime.run(
            .saveMemory,
            input: ShortcutNodeInput(text: "Do not save when memory.save is absent from catalog.")
        )
        let store = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let memories = try await store.list(limit: 10)

        XCTAssertEqual(output.kind, .saveMemory)
        XCTAssertEqual(output.fields["toolID"], BuiltInPhoneToolID.memorySave.rawValue)
        XCTAssertEqual(output.fields["success"], "false")
        XCTAssertTrue(memories.isEmpty)
    }

    func testShortcutDraftReplyNodeReturnsDraftWithoutSending() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let input = ShortcutNodeInput(
            text: "Client asks if Kairo can turn screenshots into tasks before Friday.",
            sourceName: "Shared Email",
            variables: [
                "shortcutRecipeID": "reply-draft-from-shared-text",
                "tone": "concise"
            ]
        )

        let output = try await runtime.run(.draftReply, input: input)

        XCTAssertEqual(output.kind, .draftReply)
        XCTAssertEqual(output.fields["shortcutRecipeID"], "reply-draft-from-shared-text")
        XCTAssertEqual(output.fields["sourceName"], "Shared Email")
        XCTAssertEqual(output.fields["replyDraftTone"], "concise")
        XCTAssertTrue(try XCTUnwrap(output.fields["replyDraft"]).contains("Thanks"))
        XCTAssertTrue(try XCTUnwrap(output.fields["replyDraft"]).contains("Kairo"))
        XCTAssertTrue(output.displayText.contains("Draft reply ready"))
        XCTAssertTrue(output.tasks.isEmpty)
        XCTAssertTrue(output.reminderDrafts.isEmpty)
        XCTAssertTrue(output.proposedActions.isEmpty)
    }

    func testShortcutPrepareMessageHandoffNodeReturnsVisibleHandoffWithoutBodyInURL() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let kind = try XCTUnwrap(ShortcutNodeKind(rawValue: "prepareMessageHandoff"))
        let body = "I am running late but will join in 10 minutes."
        let input = ShortcutNodeInput(
            text: """
            To: 0912345678
            Body: \(body)
            """,
            sourceName: "Shared Message",
            variables: [
                "shortcutRecipeID": "message-reply-handoff",
                "recipient": "0912345678",
                "body": body
            ]
        )

        let output = try await runtime.run(kind, input: input)
        let action = try XCTUnwrap(output.proposedActions.first)

        XCTAssertEqual(output.kind.rawValue, "prepareMessageHandoff")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "message-reply-handoff")
        XCTAssertEqual(output.fields["sourceName"], "Shared Message")
        XCTAssertEqual(output.fields["messageHandoffCount"], "1")
        XCTAssertEqual(output.fields["messageRecipient"], "0912345678")
        XCTAssertEqual(output.fields["messageBody"], body)
        XCTAssertEqual(output.fields["messageBodyInURL"], "false")
        XCTAssertEqual(output.fields["messageRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["chainText"], body)
        XCTAssertEqual(output.fields["messageHandoffURL"], "sms:0912345678")
        XCTAssertFalse(try XCTUnwrap(output.fields["messageHandoffURL"]).contains(body))
        XCTAssertTrue(output.displayText.contains("Review in Kairo"))
        XCTAssertTrue(output.displayText.contains("No message has been sent"))
        XCTAssertTrue(output.tasks.isEmpty)
        XCTAssertTrue(output.reminderDrafts.isEmpty)
        XCTAssertEqual(action.kind, .openMessageHandoff)
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)

        guard case let .message(draft) = action.payload else {
            return XCTFail("Expected MessageDraft payload.")
        }
        XCTAssertEqual(draft.recipients, ["0912345678"])
        XCTAssertEqual(draft.body, body)
    }

    func testShortcutNodeRuntimeBlocksIntegrationIDMissingFromCatalog() async throws {
        let runtime = ShortcutNodeRuntime(
            memoryStore: InMemoryMemoryStore(),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )
        let input = ShortcutNodeInput(
            text: "To: 0912345678\nBody: Running late.",
            variables: [
                "integrationSkillID": AppIntegrationSkillID.appleMessagesHandoff.rawValue,
                "recipient": "0912345678",
                "body": "Running late."
            ]
        )

        let output = try await runtime.run(.prepareMessageHandoff, input: input)

        XCTAssertEqual(output.kind, .prepareMessageHandoff)
        XCTAssertEqual(output.fields["integrationSkillID"], AppIntegrationSkillID.appleMessagesHandoff.rawValue)
        XCTAssertEqual(output.fields["success"], "false")
        XCTAssertEqual(output.fields["integrationAvailability"], AppIntegrationSkillAvailabilityStatus.unsupported.rawValue)
        XCTAssertTrue(output.proposedActions.isEmpty)
    }

    func testShortcutNodeIntegrationGateUsesInjectedBlockedOutputBuilder() throws {
        let builder = StubShortcutIntegrationBlockedOutputBuilder()
        let gate = CatalogBackedShortcutNodeIntegrationGate(
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            outputBuilder: builder
        )
        let input = ShortcutNodeInput(
            text: "To: 0912345678\nBody: Running late.",
            variables: [
                ShortcutNodeInput.integrationSkillIDVariableKey: AppIntegrationSkillID.appleMessagesHandoff.rawValue
            ]
        )

        let output = try XCTUnwrap(gate.blockedOutput(for: .prepareMessageHandoff, input: input))

        XCTAssertEqual(output.fields["builder"], "stub")
        XCTAssertEqual(builder.receivedSkillIDs, [.appleMessagesHandoff])
        XCTAssertEqual(builder.receivedKinds, [.prepareMessageHandoff])
        XCTAssertEqual(builder.receivedSourceNamePolicies, [.omitWhenMissing])
    }

    func testShortcutNodeInputResolvesIntegrationSkillThroughCatalogReference() throws {
        let input = ShortcutNodeInput(
            text: "To: 0912345678\nBody: Running late.",
            variables: [
                ShortcutNodeInput.integrationSkillIDVariableKey: AppIntegrationSkillID.appleMessagesHandoff.rawValue
            ]
        )

        let skill = try XCTUnwrap(AppIntegrationSkillCatalog().skill(for: input))

        XCTAssertEqual(input.integrationSkillID, .appleMessagesHandoff)
        XCTAssertEqual(skill.id, .appleMessagesHandoff)
        XCTAssertEqual(skill.shortcutNodeKind, .prepareMessageHandoff)
    }

    func testShortcutNodeRuntimeDoesNotUseAppleMessagesNodeForThirdPartyMessageIntegration() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let input = ShortcutNodeInput(
            text: "To: 0912345678\nBody: Running late.",
            variables: [
                "integrationSkillID": AppIntegrationSkillID.whatsappMessageHandoff.rawValue,
                "recipient": "0912345678",
                "body": "Running late."
            ]
        )

        let output = try await runtime.run(.prepareMessageHandoff, input: input)

        XCTAssertEqual(output.kind, .prepareMessageHandoff)
        XCTAssertEqual(output.fields["integrationSkillID"], AppIntegrationSkillID.whatsappMessageHandoff.rawValue)
        XCTAssertEqual(output.fields["success"], "false")
        XCTAssertEqual(output.fields["integrationExecutionMode"], AppIntegrationExecutionMode.openURL.rawValue)
        XCTAssertTrue(output.proposedActions.isEmpty)
    }

    func testShortcutPreparePhoneCallHandoffNodeReturnsVisibleTelHandoffWithoutCalling() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let kind = try XCTUnwrap(ShortcutNodeKind(rawValue: "preparePhoneCallHandoff"))
        let input = ShortcutNodeInput(
            text: """
            Call Alex at +1 (555) 0100 about the Kairo TestFlight.
            """,
            sourceName: "Shared Phone Text",
            variables: [
                "shortcutRecipeID": "phone-call-handoff",
                "phoneNumber": "+1 (555) 0100",
                "label": "Alex"
            ]
        )

        let output = try await runtime.run(kind, input: input)
        let draft = try XCTUnwrap(output.phoneCallDrafts.first)
        let action = try XCTUnwrap(output.proposedActions.first)
        let outputJSON = try output.encodedJSONString()

        XCTAssertEqual(output.kind.rawValue, "preparePhoneCallHandoff")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "phone-call-handoff")
        XCTAssertEqual(output.fields["sourceName"], "Shared Phone Text")
        XCTAssertEqual(output.fields["phoneCallHandoffCount"], "1")
        XCTAssertEqual(output.fields["phoneCallLabel"], "Alex")
        XCTAssertEqual(output.fields["phoneCallNumber"], "+1 (555) 0100")
        XCTAssertEqual(output.fields["phoneCallURL"], "tel:+15550100")
        XCTAssertEqual(output.fields["phoneCallRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["chainText"], "Alex +1 (555) 0100")
        XCTAssertEqual(draft.phoneNumber, "+1 (555) 0100")
        XCTAssertEqual(draft.label, "Alex")
        XCTAssertEqual(draft.notes, "Call Alex at +1 (555) 0100 about the Kairo TestFlight.")
        XCTAssertTrue(output.displayText.contains("Review before opening Phone"))
        XCTAssertTrue(output.displayText.contains("No call has been placed"))
        XCTAssertEqual(action.kind, .openPhoneCallHandoff)
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .phoneCall(actionDraft) = action.payload else {
            return XCTFail("Expected PhoneCallDraft payload.")
        }
        XCTAssertEqual(actionDraft, draft)
        XCTAssertTrue(outputJSON.contains(#""phoneCallDrafts""#))
        XCTAssertTrue(outputJSON.contains(#""openPhoneCallHandoff""#))
    }

    func testShortcutPrepareWebSearchHandoffNodeReturnsVisibleSafariHandoffWithoutBrowsing() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let kind = try XCTUnwrap(ShortcutNodeKind(rawValue: "prepareWebSearchHandoff"))
        let input = ShortcutNodeInput(
            text: "Search web for SwiftUI App Intents examples",
            sourceName: "Search Shortcut",
            variables: [
                "shortcutRecipeID": "web-search-handoff",
                "query": "SwiftUI App Intents examples"
            ]
        )

        let output = try await runtime.run(kind, input: input)
        let draft = try XCTUnwrap(output.webSearchDrafts.first)
        let action = try XCTUnwrap(output.proposedActions.first)
        let outputJSON = try output.encodedJSONString()

        XCTAssertEqual(output.kind.rawValue, "prepareWebSearchHandoff")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "web-search-handoff")
        XCTAssertEqual(output.fields["sourceName"], "Search Shortcut")
        XCTAssertEqual(output.fields["webSearchHandoffCount"], "1")
        XCTAssertEqual(output.fields["webSearchQuery"], "SwiftUI App Intents examples")
        XCTAssertEqual(output.fields["webSearchURL"], "https://duckduckgo.com/?q=SwiftUI%20App%20Intents%20examples")
        XCTAssertEqual(output.fields["webSearchRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["chainText"], "SwiftUI App Intents examples")
        XCTAssertEqual(draft.query, "SwiftUI App Intents examples")
        XCTAssertTrue(output.displayText.contains("Review before opening Safari"))
        XCTAssertTrue(output.displayText.contains("No browsing has happened"))
        XCTAssertEqual(action.kind, .openWebSearchHandoff)
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .webSearch(actionDraft) = action.payload else {
            return XCTFail("Expected WebSearchDraft payload.")
        }
        XCTAssertEqual(actionDraft, draft)
        XCTAssertTrue(outputJSON.contains(#""webSearchDrafts""#))
        XCTAssertTrue(outputJSON.contains(#""openWebSearchHandoff""#))
    }

    func testShortcutCreateContactDraftNodeBuildsDraftWithoutWritingContacts() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let kind = try XCTUnwrap(ShortcutNodeKind(rawValue: "createContactDraft"))
        let input = ShortcutNodeInput(
            text: """
            Name: Alex Chen
            Phone: +1-555-0100
            Email: alex@example.com
            Notes: Met at WWDC and wants the Kairo TestFlight link.
            """,
            sourceName: "Shared Contact Text",
            variables: ["shortcutRecipeID": "contact-draft-from-shared-text"]
        )

        let output = try await runtime.run(kind, input: input)
        let draft = try XCTUnwrap(output.contactDrafts.first)
        let action = try XCTUnwrap(output.proposedActions.first)
        let outputJSON = try output.encodedJSONString()

        XCTAssertEqual(output.kind.rawValue, "createContactDraft")
        XCTAssertEqual(output.fields["shortcutRecipeID"], "contact-draft-from-shared-text")
        XCTAssertEqual(output.fields["sourceName"], "Shared Contact Text")
        XCTAssertEqual(output.fields["contactDraftCount"], "1")
        XCTAssertEqual(output.fields["contactDisplayName"], "Alex Chen")
        XCTAssertEqual(output.fields["contactPhoneCount"], "1")
        XCTAssertEqual(output.fields["contactEmailCount"], "1")
        XCTAssertEqual(output.fields["contactRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["chainText"], "Alex Chen")
        XCTAssertEqual(draft.givenName, "Alex")
        XCTAssertEqual(draft.familyName, "Chen")
        XCTAssertEqual(draft.phoneNumbers, ["+1-555-0100"])
        XCTAssertEqual(draft.emailAddresses, ["alex@example.com"])
        XCTAssertEqual(draft.notes, "Met at WWDC and wants the Kairo TestFlight link.")
        XCTAssertEqual(action.kind, .createContactDraft)
        XCTAssertEqual(action.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .contact(actionDraft) = action.payload else {
            return XCTFail("Expected ContactDraft payload.")
        }
        XCTAssertEqual(actionDraft, draft)
        XCTAssertTrue(output.displayText.contains("Review before writing to Contacts"))
        XCTAssertTrue(outputJSON.contains(#""contactDrafts""#))
        XCTAssertTrue(outputJSON.contains(#""createContactDraft""#))
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
        let emailTriage = try XCTUnwrap(catalog.recipe(id: "email-triage"))

        XCTAssertEqual(dailyBriefing.settingsStepSummary, "1 step: dailyBriefing")
        XCTAssertEqual(saveSharedText.settingsStepSummary, "2 steps: saveMemory -> extractTasks")
        XCTAssertEqual(emailTriage.settingsStepSummary, "3 steps: summarize -> extractTasks -> draftReply")
        XCTAssertEqual(catalog.recipe(id: "reply-draft-from-shared-text")?.settingsStepSummary, "2 steps: summarize -> draftReply")
        XCTAssertEqual(catalog.recipe(id: "message-reply-handoff")?.settingsStepSummary, "1 step: prepareMessageHandoff")
        XCTAssertEqual(catalog.recipe(id: "web-search-handoff")?.settingsStepSummary, "1 step: prepareWebSearchHandoff")
        XCTAssertEqual(catalog.recipe(id: "contact-draft-from-shared-text")?.settingsStepSummary, "1 step: createContactDraft")
        XCTAssertEqual(catalog.recipe(id: "meeting-prep-brief")?.settingsStepSummary, "3 steps: searchMemory -> summarize -> extractTasks")
        XCTAssertEqual(catalog.recipe(id: "request-to-recipe-draft")?.settingsStepSummary, "1 step: createRecipeDraft")
        XCTAssertEqual(catalog.recipe(id: "meeting-text-to-calendar-draft")?.settingsStepSummary, "1 step: createCalendarDraft")
        XCTAssertEqual(catalog.recipe(id: "email-draft-from-shared-text")?.settingsStepSummary, "1 step: createEmailDraft")
        XCTAssertTrue(dailyBriefing.settingsContractSummary.contains("Input: text, sourceName, variables"))
        XCTAssertTrue(dailyBriefing.settingsContractSummary.contains("Output: displayText, fields.briefing, fields.taskCount, tasks"))
        XCTAssertTrue(saveSharedText.settingsContractSummary.contains("fields.chainText"))
        XCTAssertTrue(emailTriage.settingsContractSummary.contains("Input: text, sourceName, variables, previousStepOutput"))
        XCTAssertTrue(emailTriage.settingsContractSummary.contains("Output: displayText, fields.summary, fields.chainText, fields.taskCount"))
        XCTAssertTrue(emailTriage.settingsContractSummary.contains("fields.replyDraft"))
        XCTAssertTrue(catalog.recipe(id: "message-reply-handoff")?.settingsContractSummary.contains("proposedActions") ?? false)
        XCTAssertTrue(catalog.recipe(id: "message-reply-handoff")?.settingsContractSummary.contains("fields.messageBodyInURL") ?? false)
        XCTAssertTrue(catalog.recipe(id: "web-search-handoff")?.settingsContractSummary.contains("webSearchDrafts") ?? false)
        XCTAssertTrue(catalog.recipe(id: "web-search-handoff")?.settingsContractSummary.contains("fields.webSearchRequiresConfirmation") ?? false)
        XCTAssertTrue(catalog.recipe(id: "contact-draft-from-shared-text")?.settingsContractSummary.contains("contactDrafts") ?? false)
        XCTAssertTrue(catalog.recipe(id: "contact-draft-from-shared-text")?.settingsContractSummary.contains("fields.contactRequiresConfirmation") ?? false)
        XCTAssertTrue(catalog.recipe(id: "request-to-recipe-draft")?.settingsContractSummary.contains("recipeDrafts") ?? false)
        XCTAssertTrue(catalog.recipe(id: "meeting-text-to-calendar-draft")?.settingsContractSummary.contains("calendarDrafts") ?? false)
        XCTAssertTrue(catalog.recipe(id: "email-draft-from-shared-text")?.settingsContractSummary.contains("emailDrafts") ?? false)
        XCTAssertTrue(saveSharedText.settingsSampleInputPreview.contains("User research note"))
        XCTAssertTrue(emailTriage.settingsSampleInputPreview.contains("Email from vendor"))
        XCTAssertTrue(catalog.recipe(id: "message-reply-handoff")?.settingsSampleInputPreview.contains("Please tell Alex") ?? false)
        XCTAssertTrue(catalog.recipe(id: "web-search-handoff")?.settingsSampleInputPreview.contains("SwiftUI App Intents examples") ?? false)
        XCTAssertTrue(catalog.recipe(id: "contact-draft-from-shared-text")?.settingsSampleInputPreview.contains("Alex Chen") ?? false)
        XCTAssertTrue(catalog.recipe(id: "meeting-prep-brief")?.settingsSampleInputPreview.contains("Kairo launch review") ?? false)
        XCTAssertTrue(catalog.recipe(id: "request-to-recipe-draft")?.settingsSampleInputPreview.contains("每天早上整理今天事情") ?? false)
        XCTAssertTrue(catalog.recipe(id: "meeting-text-to-calendar-draft")?.settingsSampleInputPreview.contains("Kairo roadmap review") ?? false)
        XCTAssertTrue(catalog.recipe(id: "email-draft-from-shared-text")?.settingsSampleInputPreview.contains("ops@example.com") ?? false)
    }

    func testShortcutDemoTaskNodesAdvertiseChainTextOutput() throws {
        let taskLikeSteps = ShortcutDemoCatalog.default.recipes
            .flatMap(\.steps)
            .filter { [.extractTasks, .createReminderDraft].contains($0.nodeKind) }

        XCTAssertFalse(taskLikeSteps.isEmpty)
        XCTAssertTrue(taskLikeSteps.allSatisfy { $0.outputContract.fields.contains("fields.chainText") })
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
            "email-triage-shortcut",
            "message-reply-handoff-shortcut",
            "phone-call-handoff-shortcut",
            "web-search-handoff-shortcut",
            "contact-draft-shortcut",
            "calendar-draft-shortcut",
            "email-draft-shortcut",
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

        let emailTriage = try XCTUnwrap(registry.template(id: "email-triage-shortcut"))
        XCTAssertEqual(emailTriage.category, .shareSheet)
        XCTAssertEqual(emailTriage.recommendedRecipeTemplateID, "email-triage")
        XCTAssertTrue(emailTriage.requiredIntentIdentifiers.contains("RunKairoShortcutNodeIntent"))
        XCTAssertTrue(emailTriage.setupInstructions.joined(separator: " ").contains("do not send email"))

        let messageHandoff = try XCTUnwrap(registry.template(id: "message-reply-handoff-shortcut"))
        XCTAssertEqual(messageHandoff.category, .shareSheet)
        XCTAssertEqual(messageHandoff.recommendedRecipeTemplateID, "message-reply-handoff")
        XCTAssertTrue(messageHandoff.requiredIntentIdentifiers.contains("PrepareMessageHandoffIntent"))
        XCTAssertTrue(messageHandoff.setupInstructions.joined(separator: " ").contains("do not send messages silently"))
        XCTAssertTrue(messageHandoff.setupInstructions.joined(separator: " ").contains("body remains in Kairo"))

        let phoneHandoff = try XCTUnwrap(registry.template(id: "phone-call-handoff-shortcut"))
        XCTAssertEqual(phoneHandoff.category, .shareSheet)
        XCTAssertEqual(phoneHandoff.recommendedRecipeTemplateID, "phone-call-handoff")
        XCTAssertTrue(phoneHandoff.requiredIntentIdentifiers.contains("PreparePhoneCallHandoffIntent"))
        XCTAssertTrue(phoneHandoff.setupInstructions.joined(separator: " ").contains("do not place calls silently"))
        XCTAssertTrue(phoneHandoff.setupInstructions.joined(separator: " ").contains("tel:"))

        let webSearchHandoff = try XCTUnwrap(registry.template(id: "web-search-handoff-shortcut"))
        XCTAssertEqual(webSearchHandoff.category, .shareSheet)
        XCTAssertEqual(webSearchHandoff.recommendedRecipeTemplateID, "web-search-handoff")
        XCTAssertTrue(webSearchHandoff.requiredIntentIdentifiers.contains("PrepareWebSearchHandoffIntent"))
        XCTAssertTrue(webSearchHandoff.setupInstructions.joined(separator: " ").contains("does not browse silently"))
        XCTAssertTrue(webSearchHandoff.setupInstructions.joined(separator: " ").contains("Safari"))

        let contactDraft = try XCTUnwrap(registry.template(id: "contact-draft-shortcut"))
        XCTAssertEqual(contactDraft.category, .shareSheet)
        XCTAssertEqual(contactDraft.recommendedRecipeTemplateID, "contact-draft-from-shared-text")
        XCTAssertTrue(contactDraft.requiredIntentIdentifiers.contains("CreateContactDraftsIntent"))
        XCTAssertTrue(contactDraft.setupInstructions.joined(separator: " ").contains("do not write Contacts silently"))
        XCTAssertTrue(contactDraft.setupInstructions.joined(separator: " ").contains("preview and confirmation"))

        let calendarDraft = try XCTUnwrap(registry.template(id: "calendar-draft-shortcut"))
        XCTAssertEqual(calendarDraft.category, .meetingPrep)
        XCTAssertEqual(calendarDraft.recommendedRecipeTemplateID, "meeting-text-to-calendar-draft")
        XCTAssertTrue(calendarDraft.requiredIntentIdentifiers.contains("CreateCalendarDraftsIntent"))
        XCTAssertTrue(calendarDraft.setupInstructions.joined(separator: " ").contains("before any EventKit calendar write"))

        let emailDraft = try XCTUnwrap(registry.template(id: "email-draft-shortcut"))
        XCTAssertEqual(emailDraft.category, .shareSheet)
        XCTAssertEqual(emailDraft.recommendedRecipeTemplateID, "email-draft-from-shared-text")
        XCTAssertTrue(emailDraft.requiredIntentIdentifiers.contains("CreateEmailDraftsIntent"))
        XCTAssertTrue(emailDraft.setupInstructions.joined(separator: " ").contains("do not send email automatically"))
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

    func testShortcutAskNodeReturnsMemoryBackedAnswerForAppIntentFlow() async throws {
        let memory = MemoryRecord(
            title: "Kairo Review Notes",
            summary: "Beta review focus is smoke tests, privacy copy, and confirmation safety.",
            content: "Prioritize smoke tests, privacy copy, and confirmation safety for beta review.",
            source: .appIntent
        )
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore(seed: [memory]))

        let output = try await runtime.run(.ask, input: ShortcutNodeInput(
            text: "privacy copy",
            sourceName: "Ask Kairo"
        ))

        XCTAssertEqual(output.kind, .ask)
        XCTAssertEqual(output.fields["answer"], memory.summary)
        XCTAssertEqual(output.memoryMatches.map(\.id), [memory.id])
        XCTAssertEqual(output.memoryMatches.first?.summary, memory.summary)
        XCTAssertEqual(output.displayText, memory.summary)
        XCTAssertTrue(output.proposedActions.isEmpty)
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
        XCTAssertEqual(output.fields["chainText"], input.text)
        XCTAssertEqual(output.tasks.map(\.title), ["Review HomeKit capability matrix", "Build OAuth login demo"])
        XCTAssertEqual(output.reminderDrafts.map(\.title), ["Review HomeKit capability matrix", "Build OAuth login demo"])
        XCTAssertTrue(output.proposedActions.isEmpty)
        XCTAssertTrue(output.displayText.contains("2 tasks"))
    }

    func testShortcutTaskAndReminderNodesReturnChainTextForDownstreamSteps() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let shortcutText = """
        Screenshot notes:
        Action: Review Shortcut output fields
        Reminder: Wire reminder draft node to next step
        """

        let taskOutput = try await runtime.run(.extractTasks, input: ShortcutNodeInput(text: shortcutText))
        let reminderOutput = try await runtime.run(.createReminderDraft, input: ShortcutNodeInput(text: shortcutText))

        XCTAssertEqual(taskOutput.fields["chainText"], shortcutText)
        XCTAssertEqual(reminderOutput.fields["chainText"], shortcutText)
        XCTAssertEqual(reminderOutput.fields["reminderDraftCount"], "2")
    }

    func testShortcutCreateCalendarDraftNodeBuildsDraftWithoutExecuting() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let input = ShortcutNodeInput(
            text: """
            Meeting: Kairo roadmap review
            Agenda: confirm Shortcut node outputs
            """,
            sourceName: "Meeting Text Shortcut",
            variables: [
                "shortcutRecipeID": "meeting-text-to-calendar-draft",
                "startDateISO": "2026-06-05T02:00:00Z",
                "endDateISO": "2026-06-05T02:30:00Z"
            ]
        )

        let output = try await runtime.run(.createCalendarDraft, input: input)
        let draft = try XCTUnwrap(output.calendarDrafts.first)
        let outputJSON = try output.encodedJSONString()

        XCTAssertEqual(output.kind, .createCalendarDraft)
        XCTAssertEqual(output.fields["shortcutRecipeID"], "meeting-text-to-calendar-draft")
        XCTAssertEqual(output.fields["calendarDraftCount"], "1")
        XCTAssertEqual(output.fields["calendarTitle"], "Kairo roadmap review")
        XCTAssertEqual(output.fields["calendarRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["calendarStartDate"], "2026-06-05T02:00:00Z")
        XCTAssertEqual(output.fields["calendarEndDate"], "2026-06-05T02:30:00Z")
        XCTAssertEqual(output.fields["chainText"], input.text)
        XCTAssertEqual(draft.title, "Kairo roadmap review")
        XCTAssertEqual(draft.notes, input.text)
        XCTAssertEqual(draft.startDate, ISO8601DateFormatter().date(from: "2026-06-05T02:00:00Z"))
        XCTAssertEqual(draft.endDate, ISO8601DateFormatter().date(from: "2026-06-05T02:30:00Z"))
        XCTAssertTrue(output.tasks.isEmpty)
        XCTAssertTrue(output.reminderDrafts.isEmpty)
        XCTAssertTrue(output.proposedActions.isEmpty)
        XCTAssertTrue(output.displayText.contains("Review before writing to EventKit"))
        XCTAssertTrue(outputJSON.contains(#""kind":"createCalendarDraft""#))
        XCTAssertTrue(outputJSON.contains(#""calendarDrafts""#))
    }

    func testShortcutCreateEmailDraftNodeBuildsDraftWithoutSending() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let input = ShortcutNodeInput(
            text: """
            To: ops@example.com; beta@example.com
            Subject: Kairo rollout check
            Please review the latest Shortcut node rollout and confirm blockers.
            """,
            sourceName: "Shared Text Shortcut",
            variables: ["shortcutRecipeID": "email-draft-from-shared-text"]
        )

        let output = try await runtime.run(.createEmailDraft, input: input)
        let draft = try XCTUnwrap(output.emailDrafts.first)
        let action = try XCTUnwrap(output.proposedActions.first)
        let outputJSON = try output.encodedJSONString()

        XCTAssertEqual(output.kind, .createEmailDraft)
        XCTAssertEqual(output.fields["shortcutRecipeID"], "email-draft-from-shared-text")
        XCTAssertEqual(output.fields["emailDraftCount"], "1")
        XCTAssertEqual(output.fields["emailSubject"], "Kairo rollout check")
        XCTAssertEqual(output.fields["emailRecipientCount"], "2")
        XCTAssertEqual(output.fields["emailRequiresConfirmation"], "true")
        XCTAssertEqual(draft.to, ["ops@example.com", "beta@example.com"])
        XCTAssertEqual(draft.subject, "Kairo rollout check")
        XCTAssertFalse(draft.body.contains("To:"))
        XCTAssertFalse(draft.body.contains("Subject:"))
        XCTAssertEqual(action.kind, .composeEmailDraft)
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        guard case let .email(actionDraft) = action.payload else {
            return XCTFail("Expected EmailDraft payload.")
        }
        XCTAssertEqual(actionDraft, draft)
        XCTAssertTrue(output.displayText.contains("Review before opening Mail or sending"))
        XCTAssertTrue(outputJSON.contains(#""emailDrafts""#))
        XCTAssertTrue(outputJSON.contains(#""composeEmailDraft""#))
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

    func testShortcutDemoRecipeRunnerExecutesReplyDraftSampleWithoutExternalWrite() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "reply-draft-from-shared-text"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "reply-draft-from-shared-text")
        XCTAssertEqual(run.steps.map(\.nodeKind), [.summarize, .draftReply])
        XCTAssertEqual(run.steps[1].input.variables["kairoInputSource"], "previousStepOutput")
        XCTAssertEqual(run.steps[1].output.kind, .draftReply)
        XCTAssertTrue(try XCTUnwrap(run.steps[1].output.fields["replyDraft"]).contains("Thanks"))
        XCTAssertTrue(run.steps[1].output.proposedActions.isEmpty)
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
    }

    func testShortcutDemoRecipeRunnerExecutesEmailTriageSampleWithTasksAndReplyDraft() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "email-triage"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "email-triage")
        XCTAssertEqual(run.steps.map(\.nodeKind), [.summarize, .extractTasks, .draftReply])
        XCTAssertEqual(run.steps[1].input.text, run.steps[0].output.fields["chainText"])
        XCTAssertEqual(run.steps[1].output.fields["taskCount"], "2")
        XCTAssertEqual(run.steps[2].input.text, run.steps[1].output.fields["chainText"])
        XCTAssertTrue(try XCTUnwrap(run.steps[2].output.fields["replyDraft"]).contains("No message has been sent automatically"))
        XCTAssertEqual(run.totalTaskCount, 2)
        XCTAssertEqual(run.totalReminderDraftCount, 2)
        XCTAssertTrue(run.steps[2].output.proposedActions.isEmpty)
    }

    func testShortcutDemoRecipeRunnerExecutesMessageHandoffSampleWithoutSending() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "message-reply-handoff"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)
        let output = run.steps[0].output
        let action = try XCTUnwrap(output.proposedActions.first)

        XCTAssertEqual(run.recipeID, "message-reply-handoff")
        XCTAssertEqual(run.steps.map(\.nodeKind.rawValue), ["prepareMessageHandoff"])
        XCTAssertEqual(output.fields["messageHandoffCount"], "1")
        XCTAssertEqual(output.fields["messageBodyInURL"], "false")
        XCTAssertEqual(output.fields["messageRequiresConfirmation"], "true")
        XCTAssertEqual(action.kind, .openMessageHandoff)
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(output.displayText.contains("No message has been sent"))
        XCTAssertFalse(try XCTUnwrap(output.fields["messageHandoffURL"]).contains(try XCTUnwrap(output.fields["messageBody"])))
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
    }

    func testShortcutHandoffDemoStepsResolveThroughAppIntegrationCatalog() async throws {
        let demoCatalog = ShortcutDemoCatalog.default
        let integrationCatalog = AppIntegrationSkillCatalog()
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let cases: [(recipeID: String, expectedSkillID: AppIntegrationSkillID)] = [
            ("message-reply-handoff", .appleMessagesHandoff),
            ("phone-call-handoff", .applePhoneHandoff),
            ("web-search-handoff", .safariWebSearchHandoff),
            ("email-draft-from-shared-text", .appleMailHandoff)
        ]

        for testCase in cases {
            let recipe = try XCTUnwrap(demoCatalog.recipe(id: testCase.recipeID))
            let step = try XCTUnwrap(recipe.steps.first)
            let skill = try XCTUnwrap(integrationCatalog.skill(for: step))

            XCTAssertEqual(step.integrationSkillID, testCase.expectedSkillID)
            XCTAssertEqual(step.sampleInput.variables["integrationSkillID"], testCase.expectedSkillID.rawValue)
            XCTAssertEqual(skill.id, testCase.expectedSkillID)
            XCTAssertEqual(skill.executionMode, .openURL)
            XCTAssertTrue(skill.requiresConfirmation)

            let run = try await runner.runSample(recipe)
            XCTAssertEqual(run.steps.first?.output.fields["integrationSkillID"], testCase.expectedSkillID.rawValue)
        }
    }

    func testShortcutDemoRecipeRunnerBlocksIntegrationStepMissingFromCatalog() async throws {
        let recipe = try XCTUnwrap(ShortcutDemoCatalog.default.recipe(id: "message-reply-handoff"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(
            runtime: runtime,
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )

        let run = try await runner.runSample(recipe)
        let output = try XCTUnwrap(run.steps.first?.output)

        XCTAssertEqual(output.fields["integrationSkillID"], AppIntegrationSkillID.appleMessagesHandoff.rawValue)
        XCTAssertEqual(output.fields["success"], "false")
        XCTAssertEqual(output.fields["integrationAvailability"], AppIntegrationSkillAvailabilityStatus.unsupported.rawValue)
        XCTAssertTrue(output.proposedActions.isEmpty)
    }

    func testShortcutDemoIntegrationGateUsesInjectedBlockedOutputBuilder() throws {
        let builder = StubShortcutIntegrationBlockedOutputBuilder()
        let gate = CatalogBackedShortcutDemoIntegrationGate(
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            outputBuilder: builder
        )
        let step = ShortcutDemoStep(
            shortcutActionTitle: "Prepare Message",
            nodeKind: .prepareMessageHandoff,
            integrationSkillID: .appleMessagesHandoff,
            inputContract: ShortcutNodeContract(requiredFields: ["text"], description: "Message input"),
            outputContract: ShortcutNodeContract(requiredFields: ["success"], description: "Blocked output"),
            sampleInput: ShortcutNodeInput(text: "Message Alex")
        )

        let output = try XCTUnwrap(gate.blockedOutput(for: step, input: step.sampleInput))

        XCTAssertEqual(output.fields["builder"], "stub")
        XCTAssertEqual(builder.receivedSkillIDs, [.appleMessagesHandoff])
        XCTAssertEqual(builder.receivedKinds, [.prepareMessageHandoff])
        XCTAssertEqual(builder.receivedSourceNamePolicies, [.includeEmptyWhenMissing])
    }

    func testShortcutDemoRecipeRunnerDoesNotExecuteOAuthMetadataIntegrationBinding() async throws {
        let recipe = ShortcutDemoRecipe(
            id: "gmail-oauth-metadata-only",
            title: "Gmail OAuth Metadata Only",
            summary: "OAuth integration binding must fail closed until setup is complete.",
            triggerSummary: "User asks for a Gmail draft.",
            setupNotes: [],
            steps: [
                ShortcutDemoStep(
                    shortcutActionTitle: "Prepare Gmail Draft",
                    nodeKind: .createEmailDraft,
                    integrationSkillID: .gmailDraftAPI,
                    inputContract: ShortcutNodeContract(requiredFields: ["text"], description: "Email draft request"),
                    outputContract: ShortcutNodeContract(requiredFields: ["integrationSkillID", "success"], description: "Blocked integration output"),
                    sampleInput: ShortcutNodeInput(
                        text: "to: user@example.com\nSubject: Follow up\nPlease review the notes.",
                        variables: ["integrationSkillID": AppIntegrationSkillID.gmailDraftAPI.rawValue]
                    )
                )
            ]
        )
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)
        let output = try XCTUnwrap(run.steps.first?.output)

        XCTAssertEqual(output.fields["integrationSkillID"], AppIntegrationSkillID.gmailDraftAPI.rawValue)
        XCTAssertEqual(output.fields["success"], "false")
        XCTAssertEqual(output.fields["integrationAvailability"], AppIntegrationSkillAvailabilityStatus.requiresOAuth.rawValue)
        XCTAssertEqual(output.fields["integrationExecutionMode"], AppIntegrationExecutionMode.apiCall.rawValue)
        XCTAssertTrue(output.proposedActions.isEmpty)
    }

    func testShortcutDemoRecipeRunnerExecutesPhoneCallHandoffSampleWithoutCalling() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "phone-call-handoff"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)
        let output = run.steps[0].output
        let action = try XCTUnwrap(output.proposedActions.first)

        XCTAssertEqual(run.recipeID, "phone-call-handoff")
        XCTAssertEqual(run.steps.map(\.nodeKind.rawValue), ["preparePhoneCallHandoff"])
        XCTAssertEqual(output.fields["phoneCallHandoffCount"], "1")
        XCTAssertEqual(output.fields["phoneCallRequiresConfirmation"], "true")
        XCTAssertEqual(output.fields["phoneCallURL"], "tel:+15550100")
        XCTAssertEqual(action.kind, .openPhoneCallHandoff)
        XCTAssertEqual(action.riskTier, .tier1Draft)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(output.displayText.contains("No call has been placed"))
        XCTAssertEqual(run.totalPhoneCallHandoffCount, 1)
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
    }

    func testShortcutDemoRecipeRunnerExecutesContactDraftSampleWithoutWritingContacts() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "contact-draft-from-shared-text"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)
        let output = run.steps[0].output
        let action = try XCTUnwrap(output.proposedActions.first)

        XCTAssertEqual(run.recipeID, "contact-draft-from-shared-text")
        XCTAssertEqual(run.steps.map(\.nodeKind.rawValue), ["createContactDraft"])
        XCTAssertEqual(output.fields["contactDraftCount"], "1")
        XCTAssertEqual(output.fields["contactRequiresConfirmation"], "true")
        XCTAssertEqual(output.contactDrafts.map(\.displayName), ["Alex Chen"])
        XCTAssertEqual(action.kind, .createContactDraft)
        XCTAssertEqual(action.riskTier, .tier2LowRiskWrite)
        XCTAssertTrue(action.requiresConfirmation)
        XCTAssertTrue(output.displayText.contains("Review before writing to Contacts"))
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
        XCTAssertEqual(run.totalContactDraftCount, 1)
        XCTAssertTrue(run.displaySummary.contains("1 contact drafts"))
    }

    func testShortcutDemoRecipeRunnerExecutesRecipeDraftSampleWithoutShortcutInstall() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "request-to-recipe-draft"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "request-to-recipe-draft")
        XCTAssertEqual(run.steps.map(\.nodeKind.rawValue), ["createRecipeDraft"])
        XCTAssertEqual(run.steps[0].output.fields["recipeID"], "daily-briefing")
        XCTAssertEqual(run.steps[0].output.fields["recipeRequiresReview"], "true")
        XCTAssertTrue(run.steps[0].output.displayText.contains("does not create Apple Shortcuts"))
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
        XCTAssertTrue(run.steps[0].output.proposedActions.isEmpty)
    }

    func testShortcutDemoRecipeRunnerExecutesCalendarDraftSampleWithoutEventKitWrite() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "meeting-text-to-calendar-draft"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "meeting-text-to-calendar-draft")
        XCTAssertEqual(run.steps.map(\.nodeKind), [.createCalendarDraft])
        XCTAssertEqual(run.steps[0].output.fields["calendarDraftCount"], "1")
        XCTAssertEqual(run.steps[0].output.calendarDrafts.map(\.title), ["Kairo roadmap review"])
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
        XCTAssertEqual(run.totalCalendarDraftCount, 1)
        XCTAssertTrue(run.steps[0].output.proposedActions.isEmpty)
        XCTAssertTrue(run.displaySummary.contains("1 calendar drafts"))
    }

    func testShortcutDemoRecipeRunnerExecutesEmailDraftSampleWithoutSending() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "email-draft-from-shared-text"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "email-draft-from-shared-text")
        XCTAssertEqual(run.steps.map(\.nodeKind), [.createEmailDraft])
        XCTAssertEqual(run.steps[0].output.emailDrafts.map(\.subject), ["Kairo rollout check"])
        XCTAssertEqual(run.steps[0].output.proposedActions.map(\.kind), [.composeEmailDraft])
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
        XCTAssertEqual(run.totalCalendarDraftCount, 0)
        XCTAssertEqual(run.totalEmailDraftCount, 1)
        XCTAssertTrue(run.displaySummary.contains("1 email drafts"))
    }

    func testShortcutDemoRecipeRunnerExecutesHomeActionPreviewWithoutExecuting() async throws {
        let catalog = ShortcutDemoCatalog.default
        let recipe = try XCTUnwrap(catalog.recipe(id: "home-action-preview"))
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let runner = ShortcutDemoRecipeRunner(runtime: runtime)

        let run = try await runner.runSample(recipe)

        XCTAssertEqual(run.recipeID, "home-action-preview")
        XCTAssertEqual(run.steps.map(\.nodeKind.rawValue), ["previewHomeAction"])
        XCTAssertEqual(run.steps[0].output.fields["homeActionCount"], "1")
        XCTAssertEqual(run.steps[0].output.fields["homeActionRequiresConfirmation"], "true")
        XCTAssertEqual(run.steps[0].output.proposedActions.map(\.kind), [.controlHome])
        XCTAssertEqual(run.totalTaskCount, 0)
        XCTAssertEqual(run.totalReminderDraftCount, 0)
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

#if canImport(AppIntents)
private struct StubShortcutNodeRuntimeProvider: ShortcutNodeRuntimeProviding {
    var runtime: ShortcutNodeRuntime

    func makeRuntime() async throws -> ShortcutNodeRuntime {
        runtime
    }
}
#endif

private struct ShortcutNodeRecipePlannerStub: KairoRecipePlanning {
    var recipes: [KairoRecipe]

    func suggestRecipes(for request: String, now: Date) -> [KairoRecipe] {
        recipes
    }
}

private final class StubShortcutIntegrationBlockedOutputBuilder: ShortcutIntegrationBlockedOutputBuilding, @unchecked Sendable {
    private(set) var receivedKinds: [ShortcutNodeKind] = []
    private(set) var receivedSkillIDs: [AppIntegrationSkillID] = []
    private(set) var receivedSourceNamePolicies: [ShortcutIntegrationBlockedOutputSourceNamePolicy] = []

    func blockedOutput(
        kind: ShortcutNodeKind,
        input: ShortcutNodeInput,
        skillID: AppIntegrationSkillID,
        displayText: String,
        fields: [String: String],
        sourceNamePolicy: ShortcutIntegrationBlockedOutputSourceNamePolicy
    ) -> ShortcutNodeOutput {
        receivedKinds.append(kind)
        receivedSkillIDs.append(skillID)
        receivedSourceNamePolicies.append(sourceNamePolicy)

        return ShortcutNodeOutput(
            kind: kind,
            displayText: displayText,
            fields: [
                "builder": "stub",
                ShortcutNodeInput.integrationSkillIDVariableKey: skillID.rawValue
            ]
        )
    }
}
