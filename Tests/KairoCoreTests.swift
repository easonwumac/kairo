import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KairoCore

final class KairoCoreTests: XCTestCase {
    func testMemoryStoreSearchesSavedMemory() async throws {
        let store = InMemoryMemoryStore()
        let memory = MemoryRecord(
            title: "Project Kairo",
            summary: "iOS agent with memory",
            content: "Kairo can remember user-approved content.",
            source: .manual
        )

        try await store.save(memory)
        let results = try await store.search(query: "agent", limit: 10)

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.id, memory.id)
    }

    func testAgentCorePrivateChatOmitsMemoryContextAndMemoryWrites() async throws {
        let store = InMemoryMemoryStore(seed: [
            MemoryRecord(
                title: "Launch secret",
                summary: "launch plan",
                content: "launch code alpha",
                source: .manual
            )
        ])
        let saveMemoryAction = AgentAction(
            kind: .saveMemory,
            title: "Save Memory",
            rationale: "Do not expose this in private chat.",
            payload: .text("launch code alpha"),
            riskTier: .tier2LowRiskWrite
        )
        let provider = CapturingAIProvider(response: AICompletionResponse(
            message: "Private response",
            proposedActions: [saveMemoryAction]
        ))
        let skillCatalog = AgentSkillCatalog(skills: [
            AgentSkill(
                id: "private-memory-writer",
                displayName: "Private Memory Writer",
                summary: "Should be filtered in private chat.",
                kind: .custom,
                source: .userCreated,
                installationStatus: .installed,
                requiredCapabilities: [.memory],
                action: saveMemoryAction
            )
        ])
        let agent = AgentCore(memoryStore: store, aiProvider: provider, skillCatalog: skillCatalog)

        let response = try await agent.respond(to: "remember launch code alpha", privacyMode: .privateChat)
        let request = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(request)

        XCTAssertEqual(capturedRequest.privacyMode, .privateChat)
        XCTAssertTrue(capturedRequest.memoryContext.isEmpty)
        XCTAssertFalse(response.proposedActions.contains { $0.kind == .saveMemory })
        XCTAssertTrue(response.toolCandidates.isEmpty)
    }

    func testAgentCoreStandardChatIncludesMemoryContext() async throws {
        let memory = MemoryRecord(
            title: "Project Kairo",
            summary: "launch plan",
            content: "launch code alpha",
            source: .manual
        )
        let store = InMemoryMemoryStore(seed: [memory])
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Standard response"))
        let agent = AgentCore(memoryStore: store, aiProvider: provider)

        let response = try await agent.respond(to: "launch")
        let request = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(request)

        XCTAssertEqual(capturedRequest.privacyMode, .standard)
        XCTAssertEqual(capturedRequest.memoryContext.map(\.id), [memory.id])
        XCTAssertEqual(response.memoryContextCount, 1)
    }

    func testAgentCoreUsesInjectedToolContextProvider() async throws {
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Context response"))
        let toolContextProvider = StubAgentCapabilityPromptContextProvider()
        let skillCatalog = AgentSkillCatalog(skills: [
            AgentSkill(
                id: "injected-tool-context-skill",
                displayName: "Injected Tool Context Skill",
                summary: "Used to verify tool context provider injection.",
                kind: .custom,
                source: .userCreated,
                installationStatus: .installed,
                requiredCapabilities: [.memory]
            )
        ])
        let agent = AgentCore(
            aiProvider: provider,
            skillCatalog: skillCatalog,
            toolContextProvider: toolContextProvider
        )

        _ = try await agent.respond(to: "hello")

        XCTAssertEqual(toolContextProvider.buildCount, 1)
        XCTAssertEqual(toolContextProvider.receivedSkillIDs, ["injected-tool-context-skill"])
    }

    func testAgentCoreUsesInjectedToolInvocationPlanner() async throws {
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Planner response"))
        let toolInvocationPlanner = StubAgentToolInvocationPlanner()
        let skillCatalog = AgentSkillCatalog(skills: [
            AgentSkill(
                id: "injected-tool-planner-skill",
                displayName: "Injected Tool Planner Skill",
                summary: "Used to verify planner provider injection.",
                kind: .custom,
                source: .userCreated,
                installationStatus: .installed,
                requiredCapabilities: [.memory]
            )
        ])
        let agent = AgentCore(
            aiProvider: provider,
            skillCatalog: skillCatalog,
            toolInvocationPlanner: toolInvocationPlanner
        )

        _ = try await agent.respond(to: "hello")

        XCTAssertEqual(toolInvocationPlanner.planCount, 1)
        XCTAssertEqual(toolInvocationPlanner.receivedSkillIDs, ["injected-tool-planner-skill"])
        XCTAssertEqual(toolInvocationPlanner.receivedAllowsToolUse, true)
    }

    func testAgentCoreDefaultToolPlannerUsesInjectedAppIntegrationSkillCatalog() async throws {
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Planner response"))
        let injectedCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .whatsappMessageHandoff))
        ])
        let agent = AgentCore(
            aiProvider: provider,
            skillCatalog: AgentSkillCatalog(skills: []),
            appIntegrationSkillCatalog: injectedCatalog
        )

        let response = try await agent.respond(to: "Send this update with WhatsApp")
        let candidate = try XCTUnwrap(response.toolCandidates.first { $0.integrationKey == "whatsapp" })

        XCTAssertEqual(candidate.source, .appIntegrationCatalog)
        XCTAssertNil(candidate.action)
        XCTAssertFalse(response.toolCandidates.contains { $0.integrationKey == "apple-mail" })
    }

    func testAgentCoreUsesInjectedToolPlanningRequestBuilder() async throws {
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Tool request builder response"))
        let toolInvocationPlanner = StubAgentToolInvocationPlanner()
        let toolPlanningRequestBuilder = StubAgentToolPlanningRequestBuilder(request: AgentToolInvocationRequest(
            userText: "builder-user-text",
            matchingText: "builder-matching-text",
            allowsToolUse: false
        ))
        let agent = AgentCore(
            aiProvider: provider,
            toolInvocationPlanner: toolInvocationPlanner,
            toolPlanningRequestBuilder: toolPlanningRequestBuilder
        )

        _ = try await agent.respond(
            to: "Original message",
            attachments: [ChatAttachment(kind: .text, displayName: "note.txt", textPreview: "Attachment body")],
            privacyMode: .privateChat
        )

        XCTAssertEqual(toolPlanningRequestBuilder.requestCount, 1)
        XCTAssertEqual(toolPlanningRequestBuilder.receivedAttachmentCount, 1)
        XCTAssertEqual(toolPlanningRequestBuilder.receivedPrivacyMode, ChatPrivacyMode.privateChat)
        XCTAssertEqual(toolInvocationPlanner.receivedUserText, "builder-user-text")
        XCTAssertEqual(toolInvocationPlanner.receivedMatchingText, "builder-matching-text")
        XCTAssertEqual(toolInvocationPlanner.receivedAllowsToolUse, false)
    }

    func testAgentCoreCanBeBuiltFromDependencyBundle() async throws {
        let memory = MemoryRecord(
            title: "Bundled Memory",
            summary: "Bundled summary",
            content: "Bundled content",
            source: .manual
        )
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Bundled response"))
        let memoryContextProvider = StubAgentMemoryContextProvider(context: AgentMemoryContext(
            relevantMemories: [memory],
            deduplicationContext: [memory]
        ))
        let completionRequestBuilder = StubAgentCompletionRequestBuilder()
        let agent = AgentCore(dependencies: AgentCoreDependencies(
            memoryContextProvider: memoryContextProvider,
            memoryWriter: StubAgentMemoryWriter(),
            aiProvider: provider,
            skillCatalogProvider: .constant(.default),
            toolContextProvider: StubAgentCapabilityPromptContextProvider(),
            toolInvocationPlanner: StubAgentToolInvocationPlanner(),
            toolPlanningRequestBuilder: DefaultAgentToolPlanningRequestBuilder(),
            responseActionPlanner: StubAgentResponseActionPlanner(plan: AgentResponseActionPlan(
                proposedActions: [],
                toolCandidates: []
            )),
            completionRequestBuilder: completionRequestBuilder
        ))

        let response = try await agent.respond(to: "Use bundled dependencies")

        XCTAssertEqual(response.message, "Bundled response")
        XCTAssertEqual(memoryContextProvider.requestCount, 1)
        XCTAssertEqual(completionRequestBuilder.requestCount, 1)
        XCTAssertEqual(completionRequestBuilder.receivedMemoryIDs, [memory.id])
    }

    func testAgentCoreUsesInjectedResponseActionPlanner() async throws {
        let injectedAction = AgentAction(
            kind: .openURL,
            title: "Injected action",
            rationale: "Response planner supplied this action.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )
        let injectedCandidate = AgentToolInvocationCandidate(
            id: "injected-response-candidate",
            title: "Injected candidate",
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: "Injected handoff",
            action: injectedAction
        )
        let responseActionPlanner = StubAgentResponseActionPlanner(plan: AgentResponseActionPlan(
            proposedActions: [injectedAction],
            toolCandidates: [injectedCandidate]
        ))
        let provider = CapturingAIProvider(response: AICompletionResponse(
            message: "Planner response",
            proposedActions: [
                AgentAction(
                    kind: .createReminderDraft,
                    title: "Provider action",
                    rationale: "Provider supplied this action.",
                    payload: .reminder(ReminderDraft(title: "Provider reminder", notes: nil, dueDate: nil)),
                    riskTier: .tier2LowRiskWrite
                )
            ]
        ))
        let agent = AgentCore(
            aiProvider: provider,
            responseActionPlanner: responseActionPlanner
        )

        let response = try await agent.respond(to: "Open example.com")

        XCTAssertEqual(responseActionPlanner.requestCount, 1)
        XCTAssertEqual(responseActionPlanner.receivedPrivacyMode, ChatPrivacyMode.standard)
        XCTAssertEqual(response.proposedActions.map { $0.id }, [injectedAction.id])
        XCTAssertEqual(response.toolCandidates.map { $0.id }, [injectedCandidate.id])
    }

    func testAgentCoreUsesInjectedCompletionRequestBuilder() async throws {
        let memory = MemoryRecord(
            title: "Builder Memory",
            summary: "Builder summary",
            content: "Builder content",
            source: .manual
        )
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Builder response"))
        let memoryContextProvider = StubAgentMemoryContextProvider(context: AgentMemoryContext(
            relevantMemories: [memory],
            deduplicationContext: [memory]
        ))
        let toolContextProvider = StubAgentCapabilityPromptContextProvider()
        let completionRequestBuilder = StubAgentCompletionRequestBuilder()
        let agent = AgentCore(
            aiProvider: provider,
            memoryContextProvider: memoryContextProvider,
            toolContextProvider: toolContextProvider,
            completionRequestBuilder: completionRequestBuilder
        )

        _ = try await agent.respond(to: "Build request", privacyMode: .privateChat)
        let captured = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(captured)

        XCTAssertEqual(completionRequestBuilder.requestCount, 1)
        XCTAssertEqual(completionRequestBuilder.receivedMemoryIDs, [memory.id])
        XCTAssertEqual(completionRequestBuilder.receivedPrivacyMode, ChatPrivacyMode.privateChat)
        XCTAssertEqual(capturedRequest.allowedCapabilities, [.calendar])
        XCTAssertEqual(capturedRequest.privacyMode, .privateChat)
    }

    func testCompletionRequestBuilderUsesInjectedCapabilityRegistryProvider() {
        let builder = DefaultAgentCompletionRequestBuilder(
            capabilityRegistry: FixedCapabilityRegistryProvider(capabilities: [
                Capability(
                    key: .calendar,
                    displayName: "Calendar",
                    description: "Calendar writes.",
                    permission: .runtimePrompt,
                    status: .available,
                    isMVP: true
                ),
                Capability(
                    key: .contacts,
                    displayName: "Contacts",
                    description: "Contacts writes.",
                    permission: .runtimePrompt,
                    status: .denied,
                    isMVP: false
                ),
                Capability(
                    key: .reminders,
                    displayName: "Reminders",
                    description: "Reminder writes.",
                    permission: .runtimePrompt,
                    status: .unknown,
                    isMVP: true
                )
            ])
        )

        let request = builder.buildCompletionRequest(
            message: "Build with injected capabilities",
            attachments: [],
            memoryContext: AgentMemoryContext(relevantMemories: [], deduplicationContext: []),
            toolContext: nil,
            privacyMode: .standard
        )

        XCTAssertEqual(request.allowedCapabilities, [.calendar, .reminders])
    }

    func testAgentCoreUsesInjectedMemoryContextProvider() async throws {
        let memory = MemoryRecord(
            title: "Injected Memory",
            summary: "Injected summary",
            content: "Injected content",
            source: .manual
        )
        let provider = CapturingAIProvider(response: AICompletionResponse(message: "Memory context response"))
        let memoryContextProvider = StubAgentMemoryContextProvider(context: AgentMemoryContext(
            relevantMemories: [memory],
            deduplicationContext: [memory]
        ))
        let agent = AgentCore(
            aiProvider: provider,
            memoryContextProvider: memoryContextProvider
        )

        let response = try await agent.respond(to: "hello")
        let captured = await provider.capturedRequest()
        let capturedRequest = try XCTUnwrap(captured)

        XCTAssertEqual(memoryContextProvider.requestCount, 1)
        XCTAssertEqual(memoryContextProvider.receivedPrivacyMode, .standard)
        XCTAssertEqual(capturedRequest.memoryContext.map(\.id), [memory.id])
        XCTAssertEqual(response.memoryContextCount, 1)
    }

    func testAgentCoreUsesInjectedMemoryWriter() async throws {
        let writer = StubAgentMemoryWriter()
        let agent = AgentCore(memoryWriter: writer)

        let memory = try await agent.remember("Injected memory writer content", title: "Injected title", source: .chat)

        XCTAssertEqual(writer.requestCount, 1)
        XCTAssertEqual(writer.receivedContent, "Injected memory writer content")
        XCTAssertEqual(writer.receivedTitle, "Injected title")
        XCTAssertEqual(writer.receivedSource, .chat)
        XCTAssertEqual(memory.title, "Injected title")
    }

    func testDefaultAgentMemoryWriterPersistsMemoryThroughStore() async throws {
        let store = InMemoryMemoryStore()
        let writer = DefaultAgentMemoryWriter(memoryStore: store)

        let memory = try await writer.remember("Kairo memory writer persists through store", title: nil, source: .chat)
        let saved = try await store.search(query: "writer persists", limit: 10)

        XCTAssertEqual(saved.map(\.id), [memory.id])
        XCTAssertEqual(saved.first?.source, .chat)
    }

    func testJSONFileMemoryStorePersistsSavedMemory() async throws {
        let fileURL = temporaryFileURL(named: "memory-store.json")
        let memory = MemoryRecord(
            title: "Persistent Memory",
            summary: "Stored on disk",
            content: "Kairo should preserve user-approved memory between launches.",
            source: .manual,
            tags: ["persistence"]
        )

        let firstStore = try await JSONFileMemoryStore(fileURL: fileURL)
        try await firstStore.save(memory)

        let secondStore = try await JSONFileMemoryStore(fileURL: fileURL)
        let results = try await secondStore.search(query: "preserve", limit: 10)

        XCTAssertEqual(results.map(\.id), [memory.id])
    }

    func testJSONFileMemoryStoreSoftDeletesMemory() async throws {
        let fileURL = temporaryFileURL(named: "memory-delete.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let memory = MemoryRecord(
            title: "Delete Me",
            summary: "Soft delete test",
            content: "This should disappear from active lists.",
            source: .manual
        )

        try await store.save(memory)
        try await store.delete(id: memory.id)

        let listed = try await store.list(limit: 10)
        let searched = try await store.search(query: "disappear", limit: 10)

        XCTAssertTrue(listed.isEmpty)
        XCTAssertTrue(searched.isEmpty)
        let rawData = try Data(contentsOf: fileURL)
        let rawText = String(data: rawData, encoding: .utf8) ?? ""
        XCTAssertTrue(rawText.contains(memory.id.uuidString))
        XCTAssertTrue(rawText.contains("deletedAt"))
    }

    func testSafetyPolicyRequiresConfirmationForWrites() {
        let engine = SafetyPolicyEngine()
        let action = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "User asked to remember this.",
            payload: .text("Remember this"),
            riskTier: .tier2LowRiskWrite
        )

        let decision = engine.evaluate(action)

        XCTAssertTrue(decision.allowed)
        XCTAssertTrue(decision.requiresConfirmation)
    }

    func testSandboxActionCatalogSeparatesSupportedAndUnsupportedActions() throws {
        let catalog = SandboxActionCatalog()

        XCTAssertEqual(catalog.descriptor(for: .saveMemory)?.supportStatus, .implemented)
        XCTAssertEqual(catalog.descriptor(for: .sendNotification)?.supportStatus, .scaffolded)
        XCTAssertEqual(catalog.descriptor(for: .createContactDraft)?.capability, .contacts)
        XCTAssertEqual(catalog.descriptor(for: .createContactDraft)?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(catalog.descriptor(for: .createContactDraft)?.riskTier, .tier2LowRiskWrite)
        let messageKind = try XCTUnwrap(AgentActionKind(rawValue: "openMessageHandoff"))
        XCTAssertEqual(catalog.descriptor(for: messageKind)?.capability.rawValue, "messages")
        XCTAssertEqual(catalog.descriptor(for: messageKind)?.permissionRequirement, .userInitiated)
        XCTAssertEqual(catalog.descriptor(for: messageKind)?.riskTier, .tier1Draft)
        XCTAssertEqual(catalog.descriptor(for: .unsupportedSandboxAction)?.supportStatus, .unsupportedBySandbox)
        XCTAssertTrue(catalog.supportedDescriptors.contains { $0.kind == .openURL })
        XCTAssertFalse(catalog.supportedDescriptors.contains { $0.kind == .unsupportedSandboxAction })
        XCTAssertTrue(catalog.unsupportedDescriptors.contains { $0.kind == .unsupportedSandboxAction })
    }

    func testBuiltInPhoneToolCatalogDefinesRequiredPhoneHarnessTools() throws {
        let catalog = BuiltInPhoneToolCatalog()
        let expectedIDs = Set(BuiltInPhoneToolID.allCases)

        XCTAssertEqual(Set(catalog.tools.map(\.id)), expectedIDs)
        XCTAssertEqual(catalog.tools.count, expectedIDs.count)

        for tool in catalog.tools {
            XCTAssertFalse(tool.displayName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tool.schema.input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tool.schema.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tool.lifecycle.previewRenderer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tool.lifecycle.executor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            XCTAssertFalse(tool.audit.capabilityKeys.isEmpty)
            XCTAssertEqual(tool.audit.sensitivePayloadPolicy, "redactedPayloadOnly")
            XCTAssertFalse(tool.fallback.safeAlternative.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    func testBuiltInPhoneToolCatalogCanBeBuiltFromInjectedSeedSource() throws {
        let injectedTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        let catalog = BuiltInPhoneToolCatalog(seedSource: StubBuiltInPhoneToolSeedSource(tools: [injectedTool]))

        XCTAssertEqual(catalog.tools.map(\.id), [.calendarWrite])
        XCTAssertEqual(catalog.tool(id: .calendarWrite), injectedTool)
        XCTAssertNil(catalog.tool(id: .memorySave))
        XCTAssertEqual(catalog.tool(for: AgentActionKind.createCalendarDraft)?.id, .calendarWrite)
        XCTAssertNil(catalog.tool(for: AgentActionKind.saveMemory))
    }

    func testBuiltInPhoneToolCatalogCentralizesExistingActionShortcutAndRecipeMappings() throws {
        let catalog = BuiltInPhoneToolCatalog()

        XCTAssertEqual(catalog.tool(for: AgentActionKind.saveMemory)?.id, .memorySave)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.createReminderDraft)?.id, .reminderWrite)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.createCalendarDraft)?.id, .calendarWrite)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.createContactDraft)?.id, .contactCreate)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.composeEmailDraft)?.id, .emailHandoff)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.openMessageHandoff)?.id, .messageHandoff)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.openPhoneCallHandoff)?.id, .phoneHandoff)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.openWebSearchHandoff)?.id, .webSearchHandoff)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.openMapDirections)?.id, .mapsDirectionsHandoff)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.sendNotification)?.id, .notificationSchedule)
        XCTAssertEqual(catalog.tool(for: AgentActionKind.controlHome)?.id, .homeKitPreview)

        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.saveMemory)?.id, .memorySave)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.searchMemory)?.id, .memorySearch)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.createReminderDraft)?.id, .reminderWrite)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.createCalendarDraft)?.id, .calendarWrite)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.createContactDraft)?.id, .contactCreate)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.createEmailDraft)?.id, .emailHandoff)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.prepareMessageHandoff)?.id, .messageHandoff)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.preparePhoneCallHandoff)?.id, .phoneHandoff)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.prepareWebSearchHandoff)?.id, .webSearchHandoff)
        XCTAssertEqual(catalog.tool(for: ShortcutNodeKind.previewHomeAction)?.id, .homeKitPreview)

        XCTAssertEqual(catalog.tool(for: KairoRecipeStepKind.saveMemory)?.id, .memorySave)
        XCTAssertEqual(catalog.tool(for: KairoRecipeStepKind.searchMemory)?.id, .memorySearch)
        XCTAssertEqual(catalog.tool(for: KairoRecipeStepKind.createReminderDraft)?.id, .reminderWrite)
        XCTAssertEqual(catalog.tool(for: KairoRecipeStepKind.createCalendarDraft)?.id, .calendarWrite)
        XCTAssertEqual(catalog.tool(for: KairoRecipeStepKind.sendLocalNotificationDraft)?.id, .notificationSchedule)
        XCTAssertEqual(catalog.tool(for: KairoRecipeStepKind.proposeHomeAction)?.id, .homeKitPreview)
    }

    func testBuiltInPhoneToolActionDescriptorProviderPrefersInjectedToolMetadata() throws {
        var calendarTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite))
        calendarTool.permissionRequirement = .oauth
        calendarTool.availabilityStatus = .unsupported
        calendarTool.riskTier = .tier3HighRiskExternal
        let provider = BuiltInPhoneToolActionDescriptorProvider(
            toolCatalog: BuiltInPhoneToolCatalog(tools: [calendarTool])
        )

        let descriptor = try XCTUnwrap(provider.descriptor(for: .createCalendarDraft))

        XCTAssertEqual(descriptor.kind, .createCalendarDraft)
        XCTAssertEqual(descriptor.permissionRequirement, .oauth)
        XCTAssertEqual(descriptor.riskTier, .tier3HighRiskExternal)
        XCTAssertEqual(descriptor.supportStatus, .unsupportedBySandbox)
        XCTAssertEqual(provider.descriptor(for: .answer)?.kind, .answer)
    }

    func testBuiltInPhoneToolCatalogEnforcesLifecycleSafetyMetadata() throws {
        let catalog = BuiltInPhoneToolCatalog()

        let riskyTools = catalog.tools.filter { $0.riskTier.requiresConfirmation }
        XCTAssertFalse(riskyTools.isEmpty)
        XCTAssertTrue(riskyTools.allSatisfy { $0.confirmationPolicy != .notRequired })

        let handoffTools = catalog.tools.filter { $0.executionKind == .visibleHandoff }
        XCTAssertEqual(Set(handoffTools.map(\.id)), [
            .emailHandoff,
            .messageHandoff,
            .phoneHandoff,
            .webSearchHandoff,
            .mapsDirectionsHandoff
        ])
        XCTAssertTrue(handoffTools.allSatisfy { $0.confirmationPolicy == .previewAndExplicitConfirmation })
        XCTAssertTrue(handoffTools.allSatisfy { $0.fallback.safeAlternative.localizedCaseInsensitiveContains("show") })

        let setupOnlyTool = try XCTUnwrap(catalog.tool(id: .oauthConnectorSetupStatus))
        XCTAssertEqual(setupOnlyTool.executionKind, .setupStatusOnly)
        XCTAssertFalse(setupOnlyTool.canBeSuggestedAsExecutable)

        let homeKitTool = try XCTUnwrap(catalog.tool(id: .homeKitPreview))
        XCTAssertEqual(homeKitTool.executionKind, .scaffoldPreviewOnly)
        XCTAssertEqual(homeKitTool.riskTier, .tier3HighRiskExternal)
        XCTAssertEqual(homeKitTool.confirmationPolicy, .previewAndExplicitConfirmation)
    }

    func testCapabilityPromptContextListsToolsAndUnsupportedBoundaries() {
        let context = CapabilityPromptContextBuilder().build()

        XCTAssertTrue(context.contains("Kairo tool/capability context"))
        XCTAssertTrue(context.contains("saveMemory"))
        XCTAssertTrue(context.contains("createReminderDraft"))
        XCTAssertTrue(context.contains("createContactDraft"))
        XCTAssertTrue(context.contains("composeEmailDraft"))
        XCTAssertTrue(context.contains("openMapDirections"))
        XCTAssertTrue(context.contains("openMessageHandoff"))
        XCTAssertTrue(context.contains("unsupportedSandboxAction"))
        XCTAssertTrue(context.contains("require visible user confirmation"))
        XCTAssertTrue(context.contains("Integration registry"))
        XCTAssertTrue(context.contains("apple-shortcuts"))
        XCTAssertTrue(context.contains("BGTaskScheduler"))
        XCTAssertTrue(context.contains("Local model fallback cannot use tools"))
        XCTAssertTrue(context.contains("homeKit"))
        XCTAssertTrue(context.contains("controlHome"))
        XCTAssertTrue(context.contains("HomeKit action metadata is preview/demo/test scaffolding"))
        XCTAssertTrue(context.contains("do not claim live HomeKit control"))
    }

    func testCapabilityPromptContextDefaultsToHarnessIntegrationRegistry() {
        let context = CapabilityPromptContextBuilder(skillCatalog: AgentSkillCatalog(skills: [])).build()
        let registrySection = contextSection(named: "Integration registry.", in: context)
        let catalogSection = contextSection(named: "App integration skill catalog.", in: context)

        XCTAssertFalse(registrySection.contains("gmail-google-workspace"))
        XCTAssertFalse(registrySection.contains("todoist"))
        XCTAssertFalse(registrySection.contains("notion"))
        XCTAssertTrue(registrySection.contains("github"))
        XCTAssertTrue(catalogSection.contains(AppIntegrationSkillID.gmailDraftAPI.rawValue))
        XCTAssertTrue(catalogSection.contains(AppIntegrationSkillID.todoistTaskAPI.rawValue))
        XCTAssertTrue(catalogSection.contains(AppIntegrationSkillID.notionPageAPI.rawValue))
    }

    func testCapabilityPromptContextIncludesInstalledSkillsAsToolOptions() {
        let context = CapabilityPromptContextBuilder(skillCatalog: .default).build()

        XCTAssertTrue(context.contains("Installed skills/tools the model may use"))
        XCTAssertTrue(context.contains("homekit-evening-scene"))
        XCTAssertFalse(context.contains("shortcut-save-shared-text"))
        XCTAssertTrue(context.contains("requiresConfirmation=true"))
    }

    func testCapabilityPromptContextUsesInjectedBuiltInPhoneToolCatalog() throws {
        let reminderTool = try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .reminderWrite))
        let context = CapabilityPromptContextBuilder(
            toolCatalog: BuiltInPhoneToolCatalog(tools: [reminderTool]),
            skillCatalog: AgentSkillCatalog(skills: [])
        ).build()

        XCTAssertTrue(context.contains(BuiltInPhoneToolID.reminderWrite.rawValue))
        XCTAssertTrue(context.contains(AgentActionKind.createReminderDraft.rawValue))
        XCTAssertFalse(context.contains(BuiltInPhoneToolID.calendarWrite.rawValue))
        XCTAssertFalse(context.contains(AgentActionKind.createCalendarDraft.rawValue))
        XCTAssertTrue(context.contains(AgentActionKind.unsupportedSandboxAction.rawValue))
    }

    func testCapabilityPromptContextUsesInjectedAppIntegrationSectionProvider() {
        let provider = StubAppIntegrationPromptContextProvider()
        _ = CapabilityPromptContextBuilder(
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: []),
            appIntegrationPromptSection: provider,
            skillCatalog: AgentSkillCatalog(skills: [])
        ).build()

        XCTAssertEqual(provider.buildCount, 1)
    }

    func testChatMessageDecodesMissingToolCandidatesAsEmptyForOldHistory() throws {
        let json = """
        {
          "id": "11111111-1111-4111-8111-111111111111",
          "role": "assistant",
          "text": "Old assistant message",
          "createdAt": 0,
          "proposedActions": [],
          "attachments": [],
          "status": "sent"
        }
        """

        let message = try JSONDecoder().decode(ChatMessage.self, from: Data(json.utf8))

        XCTAssertEqual(message.text, "Old assistant message")
        XCTAssertTrue(message.toolCandidates.isEmpty)
        XCTAssertEqual(message.memoryContextCount, 0)
    }

    func testIntegrationRegistryListsOAuthAndUserVisibleHandoffs() throws {
        let registry = IntegrationRegistry()

        let google = try XCTUnwrap(registry.integration(for: "gmail-google-workspace"))
        XCTAssertEqual(google.oauth?.providerKey, "google")
        XCTAssertTrue(google.oauth?.requiresBackendTokenExchange == true)
        XCTAssertTrue(google.sandboxNotes.contains("official APIs"))
        XCTAssertTrue(registry.integrations(for: .shortcuts).contains { $0.key == "apple-shortcuts" })
        XCTAssertTrue(registry.userVisibleHandoffs.contains { $0.key == "openai-codex" })
    }

    func testBackgroundTaskPolicySchedulesBoundedRefreshAndRejectsDaemonClaims() throws {
        let policy = BackgroundTaskPolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let scheduled = policy.plan(
            for: BackgroundTaskRequest(
                identifier: "com.kairo.app.refresh",
                trigger: .systemRefresh,
                estimatedDuration: 10
            ),
            now: now
        )
        XCTAssertEqual(scheduled.decision, .schedule)
        XCTAssertEqual(scheduled.earliestBeginDate, now.addingTimeInterval(15 * 60))
        XCTAssertTrue(scheduled.rationale.contains("BGTaskScheduler"))

        let daemon = policy.plan(
            for: BackgroundTaskRequest(
                identifier: "com.kairo.app.refresh",
                trigger: .systemRefresh,
                estimatedDuration: 10,
                requiresContinuousExecution: true
            ),
            now: now
        )
        XCTAssertEqual(daemon.decision, .reject)
        XCTAssertTrue(daemon.rationale.contains("continuous background daemon"))
    }

    func testBackgroundTaskPolicyDefersOversizedConnectorWork() {
        let policy = BackgroundTaskPolicy()
        let now = Date(timeIntervalSince1970: 2_000)

        let plan = policy.plan(
            for: BackgroundTaskRequest(
                identifier: "com.kairo.app.processing.connectors",
                trigger: .afterOAuthRefresh,
                estimatedDuration: 10 * 60
            ),
            now: now
        )

        XCTAssertEqual(plan.decision, .deferred)
        XCTAssertEqual(plan.earliestBeginDate, now.addingTimeInterval(60 * 60))
        XCTAssertTrue(plan.rationale.contains("bounded runtime budget"))
    }

    func testSandboxActionCatalogIncludesHomeKitControlWithRuntimePermission() {
        let catalog = SandboxActionCatalog()

        let descriptor = catalog.descriptor(for: .controlHome)

        XCTAssertEqual(descriptor?.capability, .homeKit)
        XCTAssertEqual(descriptor?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(descriptor?.riskTier, .tier3HighRiskExternal)
        XCTAssertEqual(descriptor?.supportStatus, .scaffolded)
    }

    func testHomeKitControlDemoCatalogBuildsConfirmedSceneAndAccessoryActions() throws {
        let catalog = HomeKitControlDemoCatalog.default
        let sceneRecipe = try XCTUnwrap(catalog.recipe(id: "evening-scene"))
        let accessoryRecipe = try XCTUnwrap(catalog.recipe(id: "desk-lamp"))
        let lockRecipe = try XCTUnwrap(catalog.recipe(id: "front-door-lock"))

        XCTAssertEqual(catalog.recipes.map(\.id), ["evening-scene", "desk-lamp", "front-door-lock"])
        XCTAssertEqual(sceneRecipe.action.kind, .controlHome)
        XCTAssertEqual(sceneRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Living Room",
            targetName: "Evening Wind Down",
            command: .runScene
        )))
        XCTAssertTrue(sceneRecipe.action.requiresConfirmation)
        XCTAssertEqual(accessoryRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Office",
            targetName: "Desk Lamp",
            command: .setPower,
            value: .bool(true)
        )))
        XCTAssertTrue(accessoryRecipe.action.requiresConfirmation)
        XCTAssertEqual(lockRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Entry",
            targetName: "Front Door Lock",
            command: .setPower,
            value: .bool(false)
        )))
        XCTAssertEqual(lockRecipe.action.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(lockRecipe.action.requiresConfirmation)
    }

    func testAgentSkillCatalogExposesBuiltInToolsAndDownloadableMarketplaceSkills() throws {
        let catalog = AgentSkillCatalog.default
        let homeKitSkill = try XCTUnwrap(catalog.skill(id: "homekit-evening-scene"))
        let lockSkill = try XCTUnwrap(catalog.skill(id: "homekit-front-door-lock"))
        let shortcutSkill = try XCTUnwrap(catalog.skill(id: "shortcut-daily-briefing"))
        let marketplaceSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Downloadable skill package that summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )

        XCTAssertEqual(catalog.installedSkills.map(\.id), [
            "homekit-evening-scene",
            "homekit-desk-lamp",
            "homekit-front-door-lock"
        ])
        XCTAssertEqual(homeKitSkill.kind, .homeKitControl)
        XCTAssertEqual(homeKitSkill.installationStatus, .installed)
        XCTAssertEqual(homeKitSkill.action?.kind, .controlHome)
        XCTAssertTrue(homeKitSkill.action?.requiresConfirmation == true)
        XCTAssertEqual(lockSkill.kind, .homeKitControl)
        XCTAssertEqual(lockSkill.action?.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(lockSkill.action?.requiresConfirmation == true)
        XCTAssertEqual(shortcutSkill.kind, .shortcutWorkflow)
        XCTAssertEqual(shortcutSkill.installationStatus, .available)
        XCTAssertTrue(marketplaceSkill.canDownload)
        XCTAssertEqual(marketplaceSkill.source, .marketplace)
    }

    func testAgentSkillCatalogExposesEveryShortcutDemoAsAvailableSkill() throws {
        let catalog = AgentSkillCatalog.default

        for recipe in ShortcutDemoCatalog.default.recipes {
            let skill = try XCTUnwrap(catalog.skill(id: "shortcut-\(recipe.id)"))
            XCTAssertEqual(skill.kind, .shortcutWorkflow)
            XCTAssertEqual(skill.source, .builtIn)
            XCTAssertEqual(skill.installationStatus, .available)
            XCTAssertEqual(skill.requiredCapabilities, [.appIntents])
            XCTAssertEqual(skill.shortcutRecipeID, recipe.id)
            XCTAssertEqual(skill.displayName, recipe.title)
        }
    }

    func testSkillMarketplaceWebsitePublishesSearchableStaticSite() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let html = try String(
            contentsOf: root.appendingPathComponent("Website/skills/index.html"),
            encoding: .utf8
        )

        XCTAssertTrue(html.contains("Kairo Skill Marketplace"))
        XCTAssertTrue(html.contains(#"id="skill-search""#))
        XCTAssertTrue(html.contains(#"data-skill-grid"#))
        XCTAssertTrue(html.contains("skills.json"))
        XCTAssertTrue(html.contains("Permissions"))
        XCTAssertTrue(html.contains("Risk"))
        XCTAssertTrue(html.contains("Changelog"))
        XCTAssertTrue(html.contains("manifestURL"))
        XCTAssertTrue(html.contains("Skill card artwork"))
    }

    func testModelCatalogWebsitePublishesDownloadableModelIndex() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let catalogURL = root.appendingPathComponent("Website/models/models.json")
        let catalog = try LocalModelCatalog.decode(Data(contentsOf: catalogURL))
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)
        let builtInIDs = LocalModelCatalog.kairoDefault
            .availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)
            .map(\.id)

        XCTAssertEqual(catalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(availableModels.map(\.id), builtInIDs)
        XCTAssertTrue(availableModels.allSatisfy { $0.runtime == .gguf })
        XCTAssertTrue(availableModels.allSatisfy { $0.downloadURL.scheme == "https" })
        XCTAssertTrue(availableModels.allSatisfy { $0.sha256.count == 64 })
        XCTAssertEqual(availableModels.count, 3)

        let qwenTiny = try XCTUnwrap(availableModels.first { $0.id == "qwen3-5-0-8b-q4-k-m" })
        let mlxBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .mlx })
        XCTAssertEqual(mlxBenchmark.artifactReference, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertFalse(mlxBenchmark.supportsInAppDownload)
        XCTAssertTrue(mlxBenchmark.isReferenceOnlyForIOS)
    }

    func testSandboxActionExecutorRequiresConfirmationBeforeHomeKitControl() async throws {
        let service = MockHomeControlService(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), homeControlService: service)
        let action = AgentAction(
            kind: .controlHome,
            title: "Turn on office scene",
            rationale: "User asked Kairo to run a HomeKit scene.",
            payload: .homeControl(HomeControlRequest(
                homeName: "Home",
                targetName: "Office Focus",
                command: .runScene,
                value: nil
            )),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: false)
        let requests = await service.requests

        XCTAssertFalse(result.completed)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.confirmationRequired"))
        XCTAssertTrue(requests.isEmpty)
    }

    func testSandboxActionExecutorRunsConfirmedHomeKitControlThroughInjectedService() async throws {
        let service = MockHomeControlService(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), homeControlService: service)
        let request = HomeControlRequest(
            homeName: "Home",
            roomName: "Office",
            targetName: "Desk Lamp",
            command: .setPower,
            value: .bool(true)
        )
        let action = AgentAction(
            kind: .controlHome,
            title: "Turn on desk lamp",
            rationale: "User confirmed a HomeKit accessory action.",
            payload: .homeControl(request),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: true)
        let requests = await service.requests

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.createdIdentifier, "home-control-id")
        XCTAssertEqual(requests, [request])
    }

    func testRootShellKeepsChatFirstForMobileUse() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)

        XCTAssertTrue(rootView.contains("private var selectedSection: RootSection = .chat"))
        XCTAssertTrue(rootView.contains("?? .chat"))
        XCTAssertTrue(rootView.contains(#""root.section.chat.subtitle""#))
        XCTAssertTrue(rootView.contains(#""root.section.access.title""#))
        XCTAssertFalse(rootView.contains(#""home.primary-actions""#))
        XCTAssertFalse(rootView.contains(#""home.ask-kairo""#))
        XCTAssertFalse(rootView.contains(#""home.review-drafts""#))
        XCTAssertFalse(rootView.contains(#""home.memory""#))
        XCTAssertFalse(rootView.contains("Ready when you are"))
        XCTAssertFalse(rootView.contains("Start with one request."))
        XCTAssertFalse(rootView.contains(#""home.review-queue""#))
        XCTAssertFalse(rootView.contains(#""home.access""#))
        XCTAssertFalse(rootView.contains(#""home.automations""#))
        XCTAssertFalse(rootView.contains(#""home.models""#))
        XCTAssertFalse(rootView.contains(#""home.safety-pills""#))
        XCTAssertFalse(rootView.contains(".font(.largeTitle.bold())"))
    }

    func testKairoActionRowsUseQuietNativeLineIcons() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let designSystem = try String(contentsOf: root.appendingPathComponent("Kairo/Views/KairoDesignSystem.swift"), encoding: .utf8)

        XCTAssertTrue(designSystem.contains(".symbolRenderingMode(.hierarchical)"))
        XCTAssertTrue(designSystem.contains(".frame(width: 28, height: 28)"))
        XCTAssertFalse(designSystem.contains(".background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))"))
    }

    func testAutomationsViewSurfacesShortcutDemoNodeContracts() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let automationsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/AutomationsView.swift"), encoding: .utf8)

        XCTAssertTrue(automationsView.contains("ShortcutDemoCatalog.default.recipes"))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demos""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).input""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).output""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).preview-sample""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-demo.\(recipe.id).preview-result""#))
        XCTAssertTrue(automationsView.contains("shortcutDemoPreviewMessages"))
        XCTAssertTrue(automationsView.contains("ShortcutDemoRecipeRunner"))
        XCTAssertTrue(automationsView.contains("previewShortcutDemo"))
        XCTAssertTrue(automationsView.contains("settingsInputSummary"))
        XCTAssertTrue(automationsView.contains("settingsOutputSummary"))
    }

    @MainActor
    func testChatViewModelLoadsProviderRouteStatusFromLocalModelSettings() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: makeKairoCoreChatAPI(),
            localModelSettingsService: service
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.providerRouteStatus.selectedOptionID, "local.qwen-small")
        XCTAssertEqual(viewModel.providerRouteStatus.options.map(\.id), ["cloud.openai", "local.qwen-small"])
        XCTAssertNotNil(viewModel.providerRouteStatus.warning)

        await viewModel.setProviderRoutePreference(.preferCloud)

        XCTAssertEqual(viewModel.providerRouteStatus.selectedOptionID, "cloud.openai")
        XCTAssertEqual(viewModel.providerRouteStatus.preference, .preferCloud)
        let persistedStatus = await service.status()
        XCTAssertEqual(persistedStatus.preference, .preferCloud)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testChatViewModelSelectsProviderRouteOptionByModelID() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferCloud,
            installedAndSelectedModelID: "qwen-small"
        )
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: makeKairoCoreChatAPI(),
            localModelSettingsService: service,
            localModelChatRuntimeAvailable: true
        )

        await viewModel.load()
        let localOption = try XCTUnwrap(viewModel.providerRouteStatus.options.first { $0.id == "local.qwen-small" })

        await viewModel.selectProviderRouteOption(localOption)

        XCTAssertEqual(viewModel.providerRouteStatus.selectedOptionID, "local.qwen-small")
        XCTAssertEqual(viewModel.providerRouteStatus.preference, .localOnly)
        let persistedStatus = await service.status()
        XCTAssertEqual(persistedStatus.selectedModelID, "qwen-small")
        XCTAssertEqual(persistedStatus.preference, .localOnly)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testChatViewModelComposesReplyReferenceWithoutPastingFullMessage() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            chatAPI: makeKairoCoreChatAPI()
        )
        let longMessage = ChatMessage(
            role: .assistant,
            text: String(repeating: "This is a long assistant answer. ", count: 12)
        )

        viewModel.replyToMessage(longMessage)
        viewModel.composerText = "I want to reply briefly."
        await viewModel.sendComposerMessage()

        let userMessage = try XCTUnwrap(viewModel.currentThread.messages.first { $0.role == .user })
        XCTAssertTrue(userMessage.text.contains(ChatViewModel.replyReferenceText(for: longMessage)))
        XCTAssertTrue(userMessage.text.contains("I want to reply briefly."))
        XCTAssertLessThan(userMessage.text.count, longMessage.text.count)
        XCTAssertNil(viewModel.replyTarget)
    }

    private func makeKairoCoreChatAPI() -> any KairoChatAPI {
        KairoChatBackendService(
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
        )
    }

    func testPermissionHubDefinesHomeKitDemoAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let permissionHubView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/PermissionHubView.swift"), encoding: .utf8)

        XCTAssertTrue(permissionHubView.contains(#""access.skills.manager.title""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manager""#))
        XCTAssertTrue(permissionHubView.contains("skillSearchText"))
        XCTAssertTrue(permissionHubView.contains("filteredSkills"))
        XCTAssertTrue(permissionHubView.contains("skillMatchesSearch"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.search""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.search.summary""#))
        XCTAssertTrue(permissionHubView.contains("isAdvancedSkillSetupExpanded"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.advanced.toggle""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.name""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.summary""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.capability""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.confirmation-policy""#))
        XCTAssertTrue(permissionHubView.contains("localSkillCapability"))
        XCTAssertTrue(permissionHubView.contains("localSkillConfirmationPolicy"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.local-create.button""#))
        XCTAssertTrue(permissionHubView.contains("createUserSkillDraft"))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id)""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).install""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).update""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.action.previewUpdate""#))
        XCTAssertTrue(permissionHubView.contains("skill.source == .marketplace"))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).remove""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-import""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-import.text""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-import.button""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.message""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.summary""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.version""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.changelog""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.compatibility""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.compatibility.\(issue.kind.rawValue)""#))
        XCTAssertFalse(permissionHubView.contains("if normalizedSkillSearchText.isEmpty, let manifestInstallPreview"))
        XCTAssertTrue(permissionHubView.contains("manifestInstallPreview.compatibilityReport.isInstallable"))
        XCTAssertTrue(permissionHubView.contains("AgentSkillInstallError.compatibilityBlocked"))
        XCTAssertTrue(permissionHubView.contains("AgentSkillManifestValidationError.revokedSigningKey"))
        XCTAssertTrue(permissionHubView.contains("AgentSkillManifestValidationError.signingKeyPendingPublication"))
        XCTAssertTrue(permissionHubView.contains("AgentSkillManifestValidationError.signingKeyNotYetValid"))
        XCTAssertTrue(permissionHubView.contains("AgentSkillManifestValidationError.signingKeyExpired"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.message.manifestRevokedKey""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.message.manifestPendingPublication""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.message.manifestKeyNotYetValid""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.message.manifestKeyExpired""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manifest-preview.confirm""#))
        XCTAssertTrue(permissionHubView.contains("try await skillManagerService.previewInstall(jsonString: manifestImportText)"))
        XCTAssertTrue(permissionHubView.contains("try await skillManagerService.install(manifest: manifestInstallPreview.manifest)"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.marketplace-refresh""#))
        XCTAssertTrue(permissionHubView.contains("try await marketplaceCatalogService.fetchCatalog()"))
        XCTAssertTrue(permissionHubView.contains("skillCatalog.mergingMarketplaceCatalog(remoteCatalog.catalog)"))
        XCTAssertTrue(permissionHubView.contains("try await marketplaceCatalogService.fetchManifest(for: skill)"))
        XCTAssertTrue(permissionHubView.contains("try await skillManagerService.previewInstall(manifest: manifest)"))
        XCTAssertTrue(permissionHubView.contains(#""access.homekit.demos""#))
        XCTAssertTrue(permissionHubView.contains(#""access.homekit.demo.\(recipe.id)""#))
        XCTAssertTrue(permissionHubView.contains(#""access.homekit.demo.\(recipe.id).confirm""#))
    }

    func testKairoEnvironmentProvidesDeterministicUITestingSkillManagerAndMarketplace() async throws {
        let environment = try await KairoEnvironment.uiTesting(resetPersistentState: true)
        let skillManagerService = try XCTUnwrap(environment.agentSkillManagerService)
        let marketplaceCatalogService = try XCTUnwrap(environment.agentSkillMarketplaceCatalogService)
        let modelCatalogService = try XCTUnwrap(environment.localModelCatalogService)

        var catalog = try await skillManagerService.catalog()
        XCTAssertEqual(catalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .available)

        let installed = try await skillManagerService.enableSkill(id: "shortcut-save-shared-text")
        XCTAssertEqual(installed?.installationStatus, .installed)

        let reloadedEnvironment = try await KairoEnvironment.uiTesting(resetPersistentState: false)
        let reloadedSkillManagerService = try XCTUnwrap(reloadedEnvironment.agentSkillManagerService)
        catalog = try await reloadedSkillManagerService.catalog()
        XCTAssertEqual(catalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .installed)
        let reloadedRecipes = try await reloadedEnvironment.kairoRecipeStore.listRecipes()
        XCTAssertTrue(reloadedRecipes.isEmpty)

        let remoteCatalog = try await marketplaceCatalogService.fetchCatalog()
        let weatherSkill = try XCTUnwrap(remoteCatalog.catalog.skill(id: "marketplace-weather-briefing"))
        let manifest = try await marketplaceCatalogService.fetchManifest(for: weatherSkill)
        let preview = try await skillManagerService.previewInstall(manifest: manifest)
        let qwenWorkflowSkill = try XCTUnwrap(remoteCatalog.catalog.skill(id: "marketplace-qwen-oauth-workflow"))
        let qwenWorkflowManifest = try await marketplaceCatalogService.fetchManifest(for: qwenWorkflowSkill)
        let qwenWorkflowPreview = try await skillManagerService.previewInstall(manifest: qwenWorkflowManifest)

        XCTAssertEqual(remoteCatalog.sourceRepository.absoluteString, "https://github.com/easonwumac/kairo-skills")
        XCTAssertEqual(weatherSkill.downloadURL?.absoluteString, "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json")
        XCTAssertEqual(preview.summary, "Install Weather Briefing 2.1.0.")
        XCTAssertEqual(qwenWorkflowPreview.compatibilityReport.blockingIssues.map(\.kind), [.missingOAuthProvider, .missingLocalModel])
        XCTAssertTrue(qwenWorkflowPreview.summary.contains("Blocked Qwen OAuth Workflow"))

        let modelCatalog = try await modelCatalogService.fetchCatalog()
        XCTAssertEqual(modelCatalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(
            modelCatalog.availableModels(minimumSafetyPolicyVersion: modelCatalog.minimumSafetyPolicyVersion).count,
            LocalModelCatalog.kairoDefault.availableModels(
                minimumSafetyPolicyVersion: LocalModelCatalog.kairoDefault.minimumSafetyPolicyVersion
            ).count
        )

        let expandedEnvironment = try await KairoEnvironment.uiTesting(
            resetPersistentState: true,
            seedExpandedLocalModelCatalog: true
        )
        XCTAssertEqual(expandedEnvironment.localModelCatalog.availableModels(
            minimumSafetyPolicyVersion: expandedEnvironment.localModelCatalog.minimumSafetyPolicyVersion
        ).map(\.id), [
            "qwen3-5-0-8b-q4-k-m",
            "qwen3-5-2b-q4-k-m",
            "qwen2-5-vl-3b-instruct-q4-k-m",
            "remote-catalog-test-model-q4-k-m"
        ])
    }

    func testKairoPathsBuildsApplicationSupportMemoryURL() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.memoryStoreURL.lastPathComponent, "memory-store.json")
        XCTAssertEqual(paths.memoryStoreURL.deletingLastPathComponent().lastPathComponent, "KairoTests")
        XCTAssertEqual(paths.shareIngestionQueueURL.lastPathComponent, "share-ingestion-queue.json")
        XCTAssertEqual(paths.sharedFilesDirectory.lastPathComponent, "SharedFiles")
        XCTAssertEqual(paths.localModelsDirectory.lastPathComponent, "LocalModels")
        XCTAssertEqual(paths.localModelInstallRegistryURL.lastPathComponent, "install-registry.json")
        XCTAssertEqual(paths.localModelSettingsURL.lastPathComponent, "settings.json")
        XCTAssertEqual(paths.agentSkillStoreURL.lastPathComponent, "agent-skills.json")
        XCTAssertEqual(paths.agentSkillStoreURL.deletingLastPathComponent().lastPathComponent, "Skills")
        XCTAssertEqual(paths.kairoRecipeStoreURL.lastPathComponent, "kairo-recipes.json")
        XCTAssertEqual(paths.kairoRecipeStoreURL.deletingLastPathComponent().lastPathComponent, "Recipes")
        XCTAssertFalse(paths.usesAppGroup)
    }

    func testKairoPathsUsesInjectedAppGroupContainerWhenAvailable() {
        let groupRoot = FileManager.default.temporaryDirectory.appendingPathComponent("KairoGroup", isDirectory: true)
        let paths = KairoPaths(
            appName: "KairoTests",
            appGroupIdentifier: "group.app.kairo.shared",
            appGroupContainerProvider: { identifier in
                identifier == "group.app.kairo.shared" ? groupRoot : nil
            }
        )

        XCTAssertTrue(paths.usesAppGroup)
        XCTAssertEqual(paths.applicationSupportDirectory, groupRoot.appendingPathComponent("KairoTests", isDirectory: true))
        XCTAssertEqual(paths.shareIngestionQueueURL.deletingLastPathComponent(), paths.applicationSupportDirectory)
    }

    func testKairoSharedAppStorageBuildsCanonicalAppGroupPaths() {
        let groupRoot = FileManager.default.temporaryDirectory.appendingPathComponent("KairoSharedGroup", isDirectory: true)
        let paths = KairoSharedAppStorage.paths(appGroupContainerProvider: { identifier in
            identifier == KairoSharedAppStorage.appGroupIdentifier ? groupRoot : nil
        })

        XCTAssertEqual(KairoSharedAppStorage.appGroupIdentifier, "group.app.kairo.shared")
        XCTAssertTrue(paths.usesAppGroup)
        XCTAssertEqual(paths.applicationSupportDirectory, groupRoot.appendingPathComponent("Kairo", isDirectory: true))
        XCTAssertEqual(paths.shareIngestionQueueURL, groupRoot.appendingPathComponent("Kairo", isDirectory: true).appendingPathComponent("share-ingestion-queue.json"))
        XCTAssertEqual(paths.sharedFilesDirectory, groupRoot.appendingPathComponent("Kairo", isDirectory: true).appendingPathComponent("SharedFiles", isDirectory: true))
    }

    func testUITestScenarioCatalogCoversCoreAppSmokeFlows() {
        let catalog = UITestScenarioCatalog.default

        XCTAssertEqual(catalog.scenarios.map(\.id), [
            "launch-drawer",
            "chat-send",
            "chat-message-copy-reply",
            "chat-tool-preview",
            "chat-shortcut-tool-candidate",
            "chat-notification-confirmation",
            "chat-reminder-confirmation",
            "chat-calendar-confirmation",
            "chat-contact-confirmation",
            "chat-email-draft-confirmation",
            "chat-map-directions-confirmation",
            "chat-messages-handoff-confirmation",
            "chat-phone-handoff-confirmation",
            "automations-recipe-center",
            "automations-shortcut-templates",
            "automations-shortcut-demo-io",
            "settings-api-key-status",
            "settings-oauth-connectors",
            "settings-local-model-benchmark",
            "settings-local-model-expanded-catalog",
            "settings-shortcut-demo-io",
            "access-homekit-demos"
        ])
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.safe-area-header") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.toggle") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.chat") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.memory") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.shortcuts") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.access") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.models") == true)
        XCTAssertTrue(catalog.scenario(id: "launch-drawer")?.requiredAccessibilityIdentifiers.contains("root.drawer.settings") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.history.thread") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.tools.menu") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.composer.text") == true)
        let chatCopyReplyScenarioIdentifiers = catalog.scenario(id: "chat-message-copy-reply")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(chatCopyReplyScenarioIdentifiers.contains("chat.message.copy."))
        XCTAssertTrue(chatCopyReplyScenarioIdentifiers.contains("chat.message.reply."))
        XCTAssertTrue(chatCopyReplyScenarioIdentifiers.contains("chat.reply-preview"))
        XCTAssertTrue(catalog.scenario(id: "chat-tool-preview")?.requiredAccessibilityIdentifiers.contains("chat.proposed-actions") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-tool-preview")?.requiredAccessibilityIdentifiers.contains("chat.proposed-action.controlHome") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-tool-preview")?.requiredAccessibilityIdentifiers.contains("chat.proposed-action.controlHome.risk") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidates") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidate.shortcut-save-shared-text") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidate.shortcut-save-shared-text.summary") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-shortcut-tool-candidate")?.requiredAccessibilityIdentifiers.contains("chat.tool-candidate.shortcut-save-shared-text.risk") == true)
        let notificationScenarioIdentifiers = catalog.scenario(id: "chat-notification-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.proposed-action.sendNotification"))
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(notificationScenarioIdentifiers.contains("chat.action-result"))
        let reminderScenarioIdentifiers = catalog.scenario(id: "chat-reminder-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.proposed-action.createReminderDraft"))
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(reminderScenarioIdentifiers.contains("chat.action-result"))
        let calendarScenarioIdentifiers = catalog.scenario(id: "chat-calendar-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.proposed-action.createCalendarDraft"))
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(calendarScenarioIdentifiers.contains("chat.action-result"))
        let contactScenarioIdentifiers = catalog.scenario(id: "chat-contact-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.proposed-action.createContactDraft"))
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(contactScenarioIdentifiers.contains("chat.action-result"))
        let emailScenarioIdentifiers = catalog.scenario(id: "chat-email-draft-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.proposed-action.composeEmailDraft"))
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(emailScenarioIdentifiers.contains("chat.action-result"))
        let mapScenarioIdentifiers = catalog.scenario(id: "chat-map-directions-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.proposed-action.openMapDirections"))
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(mapScenarioIdentifiers.contains("chat.action-result"))
        let messageScenarioIdentifiers = catalog.scenario(id: "chat-messages-handoff-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.proposed-action.openMessageHandoff"))
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(messageScenarioIdentifiers.contains("chat.action-result"))
        let phoneScenarioIdentifiers = catalog.scenario(id: "chat-phone-handoff-confirmation")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.proposed-action.openPhoneCallHandoff"))
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.action-preview"))
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.action.confirm"))
        XCTAssertTrue(phoneScenarioIdentifiers.contains("chat.action-result"))
        let automationsScenarioIdentifiers = catalog.scenario(id: "automations-recipe-center")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(automationsScenarioIdentifiers.contains("root.drawer.shortcuts"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe-center"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.seed-samples"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.list"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing.preview"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing.run"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.recipe.daily-briefing.toggle"))
        XCTAssertTrue(automationsScenarioIdentifiers.contains("automations.message"))
        let automationsShortcutScenarioIdentifiers = catalog.scenario(id: "automations-shortcut-templates")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("root.drawer.shortcuts"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-templates"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-template.disclaimer"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-template.run-kairo-recipe-shortcut"))
        XCTAssertTrue(automationsShortcutScenarioIdentifiers.contains("automations.shortcut-template.run-kairo-recipe-shortcut.instructions"))
        let automationsShortcutDemoScenarioIdentifiers = catalog.scenario(id: "automations-shortcut-demo-io")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("root.drawer.shortcuts"))
        XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demos"))
        for recipe in ShortcutDemoCatalog.default.recipes {
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id)"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).input"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).output"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).sample"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).preview-sample"), recipe.id)
            XCTAssertTrue(automationsShortcutDemoScenarioIdentifiers.contains("automations.shortcut-demo.\(recipe.id).preview-result"), recipe.id)
        }
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.openai.api-key-status") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.openai.dry-run-api-key") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.openai.delete-api-key") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.openai.status-message") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.oauth.connectors") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.shortcuts.demos") == true)
        let oauthScenarioIdentifiers = catalog.scenario(id: "settings-oauth-connectors")?.requiredAccessibilityIdentifiers ?? []
        for providerKey in ["google", "microsoft", "notion", "slack", "openai-codex", "github"] {
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).row"), providerKey)
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).name"), providerKey)
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).status"), providerKey)
            XCTAssertTrue(oauthScenarioIdentifiers.contains("settings.oauth.\(providerKey).detail"), providerKey)
        }
        let benchmarkScenarioIdentifiers = catalog.scenario(id: "settings-local-model-benchmark")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.local"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.benchmark"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.download-preview"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.download-confirm"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.download-cancel"))
        XCTAssertTrue(benchmarkScenarioIdentifiers.contains("settings.models.benchmark-message"))
        let expandedModelsScenarioIdentifiers = catalog.scenario(id: "settings-local-model-expanded-catalog")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(expandedModelsScenarioIdentifiers.contains("settings.models.qwen2-5-vl-3b-instruct-q4-k-m.name"))
        XCTAssertTrue(expandedModelsScenarioIdentifiers.contains("settings.models.trimmed-note"))
        let shortcutDemoScenarioIdentifiers = catalog.scenario(id: "settings-shortcut-demo-io")?.requiredAccessibilityIdentifiers ?? []
        for recipe in ShortcutDemoCatalog.default.recipes {
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id)"), recipe.id)
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id).input"), recipe.id)
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id).output"), recipe.id)
            XCTAssertTrue(shortcutDemoScenarioIdentifiers.contains("settings.shortcuts.demo.\(recipe.id).sample"), recipe.id)
        }
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manager") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.advanced.toggle") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.search") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.search.summary") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-screenshot-to-reminders") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-reply-draft-from-shared-text") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-email-triage") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-meeting-prep-brief") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-generic-node-runner") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.marketplace-weather-briefing.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.marketplace-qwen-oauth-workflow.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.message") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview.compatibility") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview.confirm") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demos") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.evening-scene") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.front-door-lock") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.front-door-lock.confirm") == true)
    }

    func testXcodeProjectDefinesKairoUITestTargetAndSmokeTestFile() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let projectYAML = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let appInfoPlist = try String(contentsOf: root.appendingPathComponent("Config/KairoApp-Info.plist"), encoding: .utf8)
        let smokeTestURL = root.appendingPathComponent("KairoUITests/KairoAppSmokeUITests.swift")
        let helperTestURL = root.appendingPathComponent("KairoUITests/KairoAppSmokeUITests+Helpers.swift")
        let smokeTest = try String(contentsOf: smokeTestURL, encoding: .utf8)
        let helperTest = try String(contentsOf: helperTestURL, encoding: .utf8)
        let uiTestSources = smokeTest + "\n" + helperTest
        let actionPreviewView = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/ActionPreviewView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(projectYAML.contains("KairoUITests:"))
        XCTAssertTrue(projectYAML.contains("type: bundle.ui-testing"))
        XCTAssertTrue(projectYAML.contains("GENERATE_INFOPLIST_FILE"))
        XCTAssertTrue(projectYAML.contains("target: KairoApp"))
        XCTAssertTrue(appInfoPlist.contains("<key>CFBundleURLTypes</key>"))
        XCTAssertTrue(appInfoPlist.contains("<key>UILaunchScreen</key>"))
        XCTAssertTrue(appInfoPlist.contains("<string>kairo</string>"))
        XCTAssertTrue(appInfoPlist.contains("<key>NSCalendarsFullAccessUsageDescription</key>"))
        XCTAssertTrue(appInfoPlist.contains("<key>NSRemindersFullAccessUsageDescription</key>"))
        XCTAssertTrue(appInfoPlist.contains("<key>NSContactsUsageDescription</key>"))
        XCTAssertTrue(uiTestSources.contains("KairoAppSmokeUITests"))
        XCTAssertTrue(helperTest.contains("extension KairoAppSmokeUITests"))
        XCTAssertTrue(uiTestSources.contains("testSettingsLocalModelCatalogListsDownloadableModels"))
        XCTAssertTrue(uiTestSources.contains("testSettingsLocalModelAddStartsDownloadFlow"))
        XCTAssertTrue(uiTestSources.contains("testCategoriesUseBuiltInPresetsOnly"))
        XCTAssertTrue(uiTestSources.contains("testSettingsExpandedModelCatalogKeepsPopularStarterRowsVisible"))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsQwenBenchmarkFlowRequiresDownload"))
        XCTAssertTrue(uiTestSources.contains("testSettingsRunsQwen35BenchmarkThroughEmbeddedLlamaRuntime"))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run""#))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-settings-shortcut-demos-only"))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.models.show-more").exists)"#))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.models.remote-catalog-test-model-q4-k-m.name").exists)"#))
        XCTAssertTrue(uiTestSources.contains(#"message.label.contains("Download Qwen3.5 0.8B Q4_K_M")"#))
        XCTAssertTrue(uiTestSources.contains(#"message.label.localizedCaseInsensitiveContains("benchmark")"#))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-installed-local-model"))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-expanded-local-model-catalog"))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsOAuthConnectorReadinessAndBoundaries"))
        XCTAssertTrue(uiTestSources.contains("testSettingsKeepsOAuthCallbackPreviewOutOfPrimaryUI"))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmNotificationAction"))
        XCTAssertTrue(uiTestSources.contains("Control Home"))
        XCTAssertTrue(uiTestSources.contains("Shortcut"))
        XCTAssertTrue(uiTestSources.contains("Will ask first"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.sendNotification""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.action-preview""#))
        XCTAssertTrue(uiTestSources.contains(#"findButton("chat.action.confirm""#))
        XCTAssertTrue(actionPreviewView.contains(#""chat.action.confirm""#))
        XCTAssertTrue(uiTestSources.contains(#""chat.action-result""#))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmReminderAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.createReminderDraft""#))
        XCTAssertTrue(uiTestSources.contains("Created reminder:"))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmCalendarAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.createCalendarDraft""#))
        XCTAssertTrue(uiTestSources.contains("Created calendar event:"))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmContactAction"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.createContactDraft""#))
        XCTAssertTrue(uiTestSources.contains("Created contact."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmEmailDraftHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.composeEmailDraft""#))
        XCTAssertTrue(uiTestSources.contains("Opened visible Mail draft handoff. No email has been sent."))
        XCTAssertTrue(actionPreviewView.contains(#""chat.action.preview.phoneVisibleHandoff""#))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmMapDirectionsHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openMapDirections""#))
        XCTAssertTrue(uiTestSources.contains("Opened visible Apple Maps handoff. Navigation still requires user action in Maps."))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmMessagesHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openMessageHandoff""#))
        XCTAssertTrue(uiTestSources.contains("Opened visible Messages recipient handoff. No message has been sent"))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmPhoneCallHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openPhoneCallHandoff""#))
        XCTAssertTrue(uiTestSources.contains("Opened visible Phone handoff. No call has been placed"))
        XCTAssertTrue(actionPreviewView.contains(#""chat.action.preview.webVisibleHandoff""#))
        XCTAssertTrue(uiTestSources.contains("testChatCanPreviewAndConfirmWebSearchHandoff"))
        XCTAssertTrue(uiTestSources.contains(#""chat.proposed-action.openWebSearchHandoff""#))
        XCTAssertTrue(uiTestSources.contains("Opened visible Safari web search handoff. No browsing has happened inside Kairo."))
        XCTAssertTrue(uiTestSources.contains("testAutomationsRecipeCenterPreviewsInternalRecipeAndShowsActionsDirectly"))
        XCTAssertTrue(uiTestSources.contains("testAutomationsShowsShortcutTemplatesRequireUserApproval"))
        XCTAssertTrue(uiTestSources.contains(#""root.drawer.models""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.seed-samples""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe.daily-briefing.preview""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe.daily-briefing.run""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe.daily-briefing.toggle""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.shortcut-templates""#))
        XCTAssertTrue(uiTestSources.contains("Apple Shortcuts installation requires user approval"))
        XCTAssertTrue(uiTestSources.contains("Run Kairo Recipe Shortcut"))
        XCTAssertTrue(uiTestSources.contains("Recipe ID"))
        XCTAssertTrue(uiTestSources.contains(#""automations.details.toggle""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.recipe-center.boundary""#))
        XCTAssertTrue(uiTestSources.contains("testSettingsKeepsOAuthCallbackPreviewOutOfPrimaryUI"))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.oauth.callback-url").exists)"#))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.oauth.preview-callback").exists)"#))
        XCTAssertTrue(uiTestSources.contains("sample-sensitive-code"))
        XCTAssertTrue(uiTestSources.contains(#"providerKey: "google""#))
        XCTAssertTrue(uiTestSources.contains("Gmail / Google Workspace"))
        XCTAssertTrue(uiTestSources.contains(#"providerKey: "openai-codex""#))
        XCTAssertTrue(uiTestSources.contains("Client configuration required"))
        XCTAssertTrue(uiTestSources.contains("Requires backend token exchange."))
        XCTAssertTrue(uiTestSources.contains("Only pages/databases selected during Notion authorization may be read or written."))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsShortcutDemoInputOutputContracts"))
        let settingsShortcutDemoStart = try XCTUnwrap(
            smokeTest.range(of: "func testSettingsShowsShortcutDemoInputOutputContracts()")?.lowerBound
        )
        let settingsShortcutDemoEnd = try XCTUnwrap(
            smokeTest.range(
                of: "func testShortcutsSurfaceShowsNodeDemoContracts()",
                range: settingsShortcutDemoStart..<smokeTest.endIndex
            )?.lowerBound
        )
        let settingsShortcutDemoTest = String(smokeTest[settingsShortcutDemoStart..<settingsShortcutDemoEnd])
        XCTAssertTrue(settingsShortcutDemoTest.contains(#"relaunchForUITesting(initialSection: "settings", settingsShortcutDemosOnly: true)"#))
        XCTAssertTrue(settingsShortcutDemoTest.contains(#"id: "phone-call-handoff""#))
        XCTAssertFalse(settingsShortcutDemoTest.contains("assertPrimaryDrawerItemsExist()"))
        XCTAssertFalse(settingsShortcutDemoTest.contains(#"selectDrawerSection(identifier: "root.drawer.settings""#))

        let shortcutsSurfaceStart = try XCTUnwrap(
            smokeTest.range(of: "func testShortcutsSurfaceShowsNodeDemoContracts()")?.lowerBound
        )
        let shortcutsSurfaceEnd = try XCTUnwrap(
            smokeTest.range(
                of: "func testSettingsShowsOAuthConnectorReadinessAndBoundaries()",
                range: shortcutsSurfaceStart..<smokeTest.endIndex
            )?.lowerBound
        )
        let shortcutsSurfaceTest = String(smokeTest[shortcutsSurfaceStart..<shortcutsSurfaceEnd])
        XCTAssertTrue(shortcutsSurfaceTest.contains(#"relaunchForUITesting(initialSection: "shortcuts")"#))
        XCTAssertFalse(shortcutsSurfaceTest.contains("assertPrimaryDrawerItemsExist()"))
        XCTAssertFalse(shortcutsSurfaceTest.contains(#"selectDrawerSection(identifier: "root.drawer.shortcuts""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.shortcut-demo.generic-node-runner.preview-sample""#))
        XCTAssertTrue(uiTestSources.contains(#""automations.shortcut-demo.generic-node-runner.preview-result""#))
        XCTAssertTrue(uiTestSources.contains("Daily Briefing"))
        XCTAssertTrue(uiTestSources.contains("Save Shared Text"))
        XCTAssertTrue(uiTestSources.contains("Phone Call Handoff"))
        XCTAssertTrue(uiTestSources.contains("Generic Node Runner"))
        XCTAssertTrue(uiTestSources.contains("1 step: preparePhoneCallHandoff"))
        XCTAssertTrue(uiTestSources.contains("Output: fields.phoneCallHandoffCount, fields.phoneCallNumber, fields.phoneCallRequiresConfirmation"))
        XCTAssertTrue(uiTestSources.contains("Input: nodeKind, inputJSON"))
        XCTAssertTrue(uiTestSources.contains("Output: outputJSON, displayText, fields.taskCount, fields.chainText"))
        XCTAssertTrue(uiTestSources.contains("Input: text, sourceName, variables"))
        XCTAssertTrue(uiTestSources.contains("Output: memoryID, fields.taskCount, tasks, fields.chainText"))
        XCTAssertTrue(uiTestSources.contains("settings.models.refresh-catalog"))
        XCTAssertTrue(uiTestSources.contains("github.com/easonwumac/kairo-models"))
        XCTAssertTrue(uiTestSources.contains("chat.history.thread"))
        XCTAssertTrue(uiTestSources.contains("testChatMessageReplyPreviewAndCopyControlsExist"))
        XCTAssertTrue(uiTestSources.contains(#""chat.tools.menu""#))
        XCTAssertTrue(uiTestSources.contains("chat.composer.text"))
        XCTAssertTrue(uiTestSources.contains("chat.reply-preview"))
        XCTAssertTrue(uiTestSources.contains("chat.message.copy."))
        XCTAssertTrue(uiTestSources.contains("chat.message.reply."))
        XCTAssertTrue(uiTestSources.contains("testAccessShowsHomeKitSecurityDevicePreview"))
        XCTAssertTrue(uiTestSources.contains(#""access.homekit.demo.front-door-lock.confirm""#))
        XCTAssertTrue(uiTestSources.contains("settings.openai.api-key-status"))
        XCTAssertTrue(uiTestSources.contains("testSettingsCanSaveDryRunAndDeleteOpenAIAPIKey"))
        XCTAssertTrue(uiTestSources.contains("settings.openai.dry-run-api-key"))
        XCTAssertTrue(uiTestSources.contains("settings.openai.delete-api-key"))
        XCTAssertTrue(uiTestSources.contains("settings.openai.status-message"))
        XCTAssertTrue(uiTestSources.contains("settings.oauth.connectors"))
        XCTAssertTrue(uiTestSources.contains("settings.shortcuts.demos"))
        XCTAssertTrue(uiTestSources.contains("settings.models.local"))
        for displayName in [
            "Qwen3.5 0.8B Q4_K_M",
            "Qwen3.5 2B Q4_K_M",
            "Qwen2.5-VL 3B Instruct Q4_K_M"
        ] {
            XCTAssertTrue(uiTestSources.contains(displayName), displayName)
        }
        XCTAssertTrue(uiTestSources.contains(#"downloadIdentifier: "settings.models.\(localModel.0).download""#))
        XCTAssertTrue(uiTestSources.contains("Downloadable"))
        XCTAssertTrue(uiTestSources.contains("Download"))
        XCTAssertTrue(uiTestSources.contains("access.skills.marketplace-refresh"))
        XCTAssertTrue(uiTestSources.contains("access.skills.manifest-import"))
        XCTAssertTrue(uiTestSources.contains("access.skills.manifest-import.text"))
        XCTAssertTrue(uiTestSources.contains("access.skills.manifest-import.button"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-save-shared-text"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-screenshot-to-reminders"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-reply-draft-from-shared-text"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-email-triage"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-meeting-prep-brief"))
        XCTAssertTrue(uiTestSources.contains("access.skill.shortcut-generic-node-runner"))
        XCTAssertTrue(uiTestSources.contains("verifySkillManagerInteractionFlow()"))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerCreatesLocalUserSkillDraft"))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerSearchFiltersSkills"))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.search""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.search.summary""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.local-create.name""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.local-create.summary""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.local-create.button""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.user-ui-created-skill.install""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.shortcut-save-shared-text.install""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.marketplace-weather-briefing.install""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.marketplace-weather-briefing.update""#))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-installed-weather-skill"))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerPreviewsSignedMarketplaceSkillUpdate"))
        XCTAssertTrue(uiTestSources.contains("Installed 2.0.0 -> Incoming 2.1.0"))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.manifest-preview.version""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.manifest-preview.changelog""#))
        XCTAssertTrue(uiTestSources.contains("testAccessSkillManagerBlocksIncompatibleMarketplaceSkillInstall"))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.marketplace-qwen-oauth-workflow.install""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.message""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.manifest-preview.compatibility""#))
        XCTAssertTrue(uiTestSources.contains("Connect OAuth provider google"))
        XCTAssertTrue(uiTestSources.contains("Download local model qwen3-5-0-8b-q4-k-m"))
        XCTAssertTrue(uiTestSources.contains(#""access.skills.manifest-preview.confirm""#))
        XCTAssertTrue(uiTestSources.contains(#""access.homekit.demo.evening-scene.confirm""#))
        XCTAssertTrue(uiTestSources.contains("access.homekit.demos"))
    }

    func testMemoryCenterViewDefinesManualSaveAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let memoryView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/MemoryCenterView.swift"), encoding: .utf8)

        XCTAssertTrue(memoryView.contains(#""memory.add.text""#))
        XCTAssertTrue(memoryView.contains(#""memory.add.save""#))
        XCTAssertTrue(memoryView.contains(#""memory.error""#))
        XCTAssertTrue(memoryView.contains(#""memory.list""#))
        XCTAssertTrue(memoryView.contains(#""memory.empty""#))
        XCTAssertTrue(memoryView.contains(#""memory.record""#))
        XCTAssertTrue(memoryView.contains(#""memory.export.share""#))
        XCTAssertTrue(memoryView.contains(#""memory.record.delete""#))
    }

    func testOpenAIProviderThrowsWhenCredentialIsMissing() async throws {
        let provider = OpenAIProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: MockHTTPClient(statusCode: 200, body: #"{"output_text":"unused"}"#)
        )

        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))
            XCTFail("Expected missingCredential error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .missingCredential)
        }
    }

    func testOpenAIProviderBuildsAuthorizedResponsesRequestAndParsesOutputText() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let httpClient = MockHTTPClient(statusCode: 200, body: #"{"output_text":"Hello from Kairo"}"#)
        let provider = OpenAIProvider(credentialStore: credentials, httpClient: httpClient)

        let response = try await provider.complete(
            AICompletionRequest(
                systemPrompt: "system",
                userPrompt: "hello",
                memoryContext: [
                    MemoryRecord(title: "Preference", summary: "Likes concise answers", content: "", source: .manual)
                ],
                allowedCapabilities: [.memory, .reminders]
            )
        )

        XCTAssertEqual(response.message, "Hello from Kairo")
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-api-key")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
        XCTAssertEqual(request.httpMethod, "POST")

        let body = try XCTUnwrap(request.httpBody)
        let bodyObject = try JSONSerialization.jsonObject(with: body) as? [String: Any]
        XCTAssertEqual(bodyObject?["model"] as? String, "gpt-4.1")
        XCTAssertNotNil(bodyObject?["input"])
    }

    func testOpenAIProviderParsesNestedResponsesOutput() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let body = #"{"output":[{"content":[{"text":"Nested"},{"text":"response"}]}]}"#
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(statusCode: 200, body: body)
        )

        let response = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))

        XCTAssertEqual(response.message, "Nested\nresponse")
    }

    func testOpenAIProviderEmbedsText() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(statusCode: 200, body: #"{"data":[{"embedding":[0.1,0.2,0.3]}]}"#)
        )

        let response = try await provider.embed(AIEmbeddingRequest(input: "hello"))

        XCTAssertEqual(response.vector, [0.1, 0.2, 0.3])
    }

    func testOpenAIProviderSanitizesErrorResponses() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("test-api-key", for: CredentialKey.openAIAPIKey)
        let provider = OpenAIProvider(
            credentialStore: credentials,
            httpClient: MockHTTPClient(
                statusCode: 429,
                body: #"{"error":{"message":"raw prompt secret should not leak","type":"rate_limit_error"}}"#
            )
        )

        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "hello"))
            XCTFail("Expected requestFailed error")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .requestFailed(KairoL10n.string(
                "chat.provider.openAI.requestFailedStatus",
                429,
                KairoL10n.string("chat.provider.openAI.errorType", "rate_limit_error")
            )))
        }
    }

    func testJSONFileChatHistoryStorePersistsAndSoftDeletesThreads() async throws {
        let fileURL = temporaryFileURL(named: "chat-history.json")
        let thread = ChatThread(
            title: "Plan UI",
            createdAt: Date(timeIntervalSince1970: 10),
            updatedAt: Date(timeIntervalSince1970: 10),
            messages: [
                ChatMessage(role: .user, text: "Improve the chat UI", createdAt: Date(timeIntervalSince1970: 10)),
                ChatMessage(role: .assistant, text: "Let's add history.", createdAt: Date(timeIntervalSince1970: 11))
            ]
        )

        let firstStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        try await firstStore.saveThread(thread)

        let secondStore = try await JSONFileChatHistoryStore(fileURL: fileURL)
        let loaded = try await secondStore.thread(id: thread.id)
        let listed = try await secondStore.listThreads(limit: 10)

        XCTAssertEqual(loaded?.messages.map(\.text), ["Improve the chat UI", "Let's add history."])
        XCTAssertEqual(listed.map(\.id), [thread.id])

        try await secondStore.deleteThread(id: thread.id)
        let deletedThread = try await secondStore.thread(id: thread.id)
        let threadsAfterDelete = try await secondStore.listThreads(limit: 10)
        XCTAssertNil(deletedThread)
        XCTAssertTrue(threadsAfterDelete.isEmpty)

        let rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(thread.id.uuidString))
        XCTAssertTrue(rawText.contains("deletedAt"))
    }

    func testChatThreadDerivesTitleFromFirstUserMessage() {
        var thread = ChatThread()
        let message = ChatMessage(role: .user, text: "  Please remember my meeting notes and summarize them later  ")

        thread.append(message, now: message.createdAt)

        XCTAssertEqual(thread.title, "Please remember my meeting notes and summa")
        XCTAssertEqual(thread.lastMessagePreview, "Please remember my meeting notes and summarize them later")
    }

    func testChatAttachmentBuildsPromptSummaryAndSharePrompt() {
        let attachment = ChatAttachment(
            kind: .pdf,
            displayName: "Deck.pdf",
            uniformTypeIdentifier: "com.adobe.pdf",
            byteCount: 4096,
            textPreview: "Quarterly plan",
            source: .shareExtension
        )
        let item = ShareIngestionItem(attachments: [attachment])

        XCTAssertTrue(attachment.promptSummary.contains("Deck.pdf"))
        XCTAssertTrue(attachment.promptSummary.contains("Quarterly plan"))
        XCTAssertEqual(item.suggestedPrompt, KairoL10n.string("chat.share.prompt.summarizeNamed", "Deck.pdf"))
    }

    func testJSONFileShareIngestionQueuePersistsPendingItems() async throws {
        let fileURL = temporaryFileURL(named: "share-ingestion.json")
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [builder.text("Shared article text", displayName: "Article")],
            sourceApplication: "Safari",
            receivedAt: Date(timeIntervalSince1970: 42)
        )

        let firstQueue = try await JSONFileShareIngestionQueue(fileURL: fileURL)
        try await firstQueue.enqueue(item)

        let secondQueue = try await JSONFileShareIngestionQueue(fileURL: fileURL)
        let pending = try await secondQueue.pendingItems(limit: 10)
        XCTAssertEqual(pending.map(\.id), [item.id])
        XCTAssertEqual(pending.first?.attachments.first?.textPreview, "Shared article text")

        try await secondQueue.markImported(id: item.id)
        let afterImport = try await secondQueue.pendingItems(limit: 10)
        XCTAssertTrue(afterImport.isEmpty)
    }

    func testSharedFileIngestionStoreCopiesFilesIntoDurableSharedDirectory() throws {
        let sourceURL = temporaryFileURL(named: "notes.txt")
        try FileManager.default.createDirectory(at: sourceURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try "shared notes".write(to: sourceURL, atomically: true, encoding: .utf8)
        let sharedDirectory = temporaryFileURL(named: "SharedFiles")
        let store = SharedFileIngestionStore(
            sharedFilesDirectory: sharedDirectory,
            fileNameGenerator: { _ in "copied-notes.txt" }
        )

        let attachment = try store.copyFile(from: sourceURL, uniformTypeIdentifier: "public.plain-text")

        let copiedURL = try XCTUnwrap(attachment.fileURL)
        XCTAssertEqual(copiedURL, sharedDirectory.appendingPathComponent("copied-notes.txt"))
        XCTAssertNotEqual(copiedURL, sourceURL)
        XCTAssertEqual(try String(contentsOf: copiedURL, encoding: .utf8), "shared notes")
        XCTAssertEqual(attachment.displayName, "notes.txt")
        XCTAssertEqual(attachment.kind, .text)
        XCTAssertEqual(attachment.byteCount, Int64("shared notes".utf8.count))
        XCTAssertEqual(attachment.source, .shareExtension)
    }

    func testKairoPathsBuildsApplicationSupportChatHistoryURL() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.chatHistoryStoreURL.lastPathComponent, "chat-history.json")
        XCTAssertEqual(paths.chatHistoryStoreURL.deletingLastPathComponent().lastPathComponent, "KairoTests")
    }

    func testSandboxActionCatalogDescribesSupportedIOSActions() {
        let catalog = SandboxActionCatalog()

        XCTAssertEqual(catalog.descriptor(for: .saveMemory)?.supportStatus, .implemented)
        XCTAssertEqual(catalog.descriptor(for: .createReminderDraft)?.permissionRequirement, .runtimePrompt)
        XCTAssertEqual(catalog.descriptor(for: .externalAPIRequest)?.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(catalog.supportedDescriptors.map(\.kind).contains(.openURL))
    }

    func testSandboxActionExecutorRequiresConfirmationBeforeSavingMemory() async throws {
        let memoryStore = InMemoryMemoryStore()
        let executor = SandboxActionExecutor(memoryStore: memoryStore)
        let action = AgentAction(
            kind: .saveMemory,
            title: "Remember",
            rationale: "User asked Kairo to remember this.",
            payload: .text("Remember that Kairo can operate sandboxed iOS capabilities."),
            riskTier: .tier2LowRiskWrite
        )

        let unconfirmed = try await executor.execute(action, confirmed: false)
        let memoriesBeforeConfirmation = try await memoryStore.list(limit: 10)
        XCTAssertFalse(unconfirmed.completed)
        XCTAssertTrue(memoriesBeforeConfirmation.isEmpty)

        let confirmed = try await executor.execute(action, confirmed: true)
        let memories = try await memoryStore.search(query: "sandboxed", limit: 10)
        XCTAssertTrue(confirmed.completed)
        XCTAssertEqual(memories.count, 1)
    }

    func testSandboxActionExecutorReturnsScaffoldedResultForOpenURL() async throws {
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        let action = AgentAction(
            kind: .openURL,
            title: "Open URL",
            rationale: "User wants to open a URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertFalse(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        XCTAssertEqual(result.message, KairoL10n.string("chat.action.executor.openURLFailed"))
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func makeLocalModelSettingsService(
        preference: ProviderRoutePreference,
        installedAndSelectedModelID: String?
    ) async throws -> LocalModelSettingsService {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.1")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        if let modelID = installedAndSelectedModelID {
            try await registry.upsert(LocalModelInstallRecord(
                modelID: modelID,
                version: "1.0",
                status: .installed,
                fileURL: registryURL.deletingLastPathComponent().appendingPathComponent("\(modelID).gguf"),
                installedSizeBytes: 1024,
                sha256: "abc123"
            ))
            try await service.selectModel(id: modelID)
        }
        try await service.setPreference(preference)
        return service
    }

    private func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ errorHandler: (Error) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected async expression to throw.", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    private func makeLocalModelManifest(
        id: String,
        version: String = "1.0",
        safetyPolicyVersion: String = "2026.1",
        deprecated: Bool = false,
        sha256: String = "abc123"
    ) -> LocalModelManifest {
        LocalModelManifest(
            id: id,
            displayName: "Qwen Small Test",
            family: "Qwen",
            version: version,
            parameterCount: "0.8B",
            quantization: "Q4",
            fileSizeBytes: 512,
            installedSizeBytes: 1024,
            contextWindow: 2048,
            tokenizerID: "qwen-test-tokenizer",
            licenseName: "Apache-2.0",
            licenseURL: URL(string: "https://example.com/license")!,
            minOSVersion: "17.0",
            minDeviceClass: "A15",
            minRAMGB: 4,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: URL(string: "https://example.com/model.gguf")!,
            sha256: sha256,
            safetyPolicyVersion: safetyPolicyVersion,
            deprecated: deprecated
        )
    }

}

private actor MockHTTPClient: HTTPClient {
    private let statusCode: Int
    private let body: String
    private var capturedRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }

    func lastRequest() throws -> URLRequest {
        guard let capturedRequest else {
            throw MockHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private enum MockHTTPClientError: Error {
    case missingRequest
}

private func contextSection(named heading: String, in context: String) -> String {
    guard let headingRange = context.range(of: heading) else {
        return ""
    }
    let sectionStart = headingRange.upperBound
    guard let nextSectionRange = context[sectionStart...].range(of: "\n\n") else {
        return String(context[sectionStart...])
    }
    return String(context[sectionStart..<nextSectionRange.lowerBound])
}

private final class StubAppIntegrationPromptContextProvider: AppIntegrationPromptContextProviding, @unchecked Sendable {
    private(set) var buildCount = 0

    func buildAppIntegrationSection() -> String {
        buildCount += 1
        return ""
    }
}

private final class StubAgentCapabilityPromptContextProvider: AgentCapabilityPromptContextProviding, @unchecked Sendable {
    private(set) var buildCount = 0
    private(set) var receivedSkillIDs: [String] = []

    func buildToolContext(skillCatalog: AgentSkillCatalog) -> String {
        buildCount += 1
        receivedSkillIDs = skillCatalog.installedSkills.map(\.id)
        return ""
    }
}

private final class StubAgentToolInvocationPlanner: AgentToolInvocationPlanning, @unchecked Sendable {
    private(set) var planCount = 0
    private(set) var receivedSkillIDs: [String] = []
    private(set) var receivedUserText: String?
    private(set) var receivedMatchingText: String?
    private(set) var receivedAllowsToolUse: Bool?

    func plan(
        for request: AgentToolInvocationRequest,
        skillCatalog: AgentSkillCatalog
    ) -> AgentToolInvocationPlan {
        planCount += 1
        receivedSkillIDs = skillCatalog.installedSkills.map(\.id)
        receivedUserText = request.userText
        receivedMatchingText = request.matchingText
        receivedAllowsToolUse = request.allowsToolUse
        return AgentToolInvocationPlan(candidates: [])
    }
}

private final class StubAgentToolPlanningRequestBuilder: AgentToolPlanningRequestBuilding, @unchecked Sendable {
    private let suppliedRequest: AgentToolInvocationRequest
    private(set) var requestCount = 0
    private(set) var receivedAttachmentCount = 0
    private(set) var receivedPrivacyMode: ChatPrivacyMode?

    init(request: AgentToolInvocationRequest) {
        self.suppliedRequest = request
    }

    func buildToolPlanningRequest(
        message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) -> AgentToolInvocationRequest {
        requestCount += 1
        receivedAttachmentCount = attachments.count
        receivedPrivacyMode = privacyMode
        return suppliedRequest
    }
}

private final class StubAgentResponseActionPlanner: AgentResponseActionPlanning, @unchecked Sendable {
    private let suppliedPlan: AgentResponseActionPlan
    private(set) var requestCount = 0
    private(set) var receivedPrivacyMode: ChatPrivacyMode?

    init(plan: AgentResponseActionPlan) {
        self.suppliedPlan = plan
    }

    func planActions(for request: AgentResponseActionPlanningRequest) -> AgentResponseActionPlan {
        requestCount += 1
        receivedPrivacyMode = request.privacyMode
        return suppliedPlan
    }
}

private final class StubAgentCompletionRequestBuilder: AgentCompletionRequestBuilding, @unchecked Sendable {
    private(set) var requestCount = 0
    private(set) var receivedMemoryIDs: [UUID] = []
    private(set) var receivedPrivacyMode: ChatPrivacyMode?

    func buildCompletionRequest(
        message: String,
        attachments: [ChatAttachment],
        memoryContext: AgentMemoryContext,
        toolContext: String?,
        privacyMode: ChatPrivacyMode
    ) -> AICompletionRequest {
        requestCount += 1
        receivedMemoryIDs = memoryContext.relevantMemories.map { $0.id }
        receivedPrivacyMode = privacyMode
        return AICompletionRequest(
            systemPrompt: "stub",
            userPrompt: message,
            memoryContext: [],
            allowedCapabilities: [.calendar],
            attachmentContext: attachments,
            toolContext: toolContext,
            privacyMode: privacyMode
        )
    }
}

private struct FixedCapabilityRegistryProvider: CapabilityRegistryProviding {
    var capabilities: [Capability]
}

private final class StubAgentMemoryContextProvider: AgentMemoryContextProviding, @unchecked Sendable {
    private let suppliedContext: AgentMemoryContext
    private(set) var requestCount = 0
    private(set) var receivedPrivacyMode: ChatPrivacyMode?

    init(context: AgentMemoryContext) {
        self.suppliedContext = context
    }

    func context(
        for message: String,
        privacyMode: ChatPrivacyMode
    ) async throws -> AgentMemoryContext {
        requestCount += 1
        receivedPrivacyMode = privacyMode
        return suppliedContext
    }
}

private final class StubAgentMemoryWriter: AgentMemoryWriting, @unchecked Sendable {
    private(set) var requestCount = 0
    private(set) var receivedContent: String?
    private(set) var receivedTitle: String?
    private(set) var receivedSource: MemorySource?

    func remember(
        _ content: String,
        title: String?,
        source: MemorySource
    ) async throws -> MemoryRecord {
        requestCount += 1
        receivedContent = content
        receivedTitle = title
        receivedSource = source
        return MemoryRecord(
            title: title ?? String(content.prefix(40)),
            summary: content,
            content: content,
            source: source
        )
    }
}

private actor CapturingAIProvider: AIProvider {
    private(set) var lastRequest: AICompletionRequest?
    private let response: AICompletionResponse

    init(response: AICompletionResponse) {
        self.response = response
    }

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        lastRequest = request
        return response
    }

    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        AIEmbeddingResponse(vector: [])
    }

    func capturedRequest() -> AICompletionRequest? {
        lastRequest
    }
}

private actor MockHomeControlService: HomeControlService {
    private(set) var requests: [HomeControlRequest] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAuthorization() async throws -> Bool {
        granted
    }

    func execute(_ request: HomeControlRequest) async throws -> String {
        requests.append(request)
        return "home-control-id"
    }
}

private struct StubBuiltInPhoneToolSeedSource: BuiltInPhoneToolSeeding {
    var tools: [BuiltInPhoneToolDefinition]
}
