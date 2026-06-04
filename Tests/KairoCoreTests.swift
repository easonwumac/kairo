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

    func testCapabilityPromptContextIncludesInstalledSkillsAsToolOptions() {
        let context = CapabilityPromptContextBuilder(skillCatalog: .default).build()

        XCTAssertTrue(context.contains("Installed skills/tools the model may use"))
        XCTAssertTrue(context.contains("homekit-evening-scene"))
        XCTAssertTrue(context.contains("shortcut-daily-briefing"))
        XCTAssertTrue(context.contains("shortcut-save-shared-text"))
        XCTAssertTrue(context.contains("shortcut-screenshot-to-reminders"))
        XCTAssertTrue(context.contains("shortcut-reply-draft-from-shared-text"))
        XCTAssertTrue(context.contains("shortcut-email-triage"))
        XCTAssertTrue(context.contains("shortcut-email-draft-from-shared-text"))
        XCTAssertTrue(context.contains("shortcut-contact-draft-from-shared-text"))
        XCTAssertTrue(context.contains("shortcut-meeting-prep-brief"))
        XCTAssertTrue(context.contains("requiresConfirmation=true"))
    }

    func testAgentToolInvocationPlannerStaysSplitAcrossSupportFiles() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let plannerSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationPlanner.swift"),
            encoding: .utf8
        )
        let modelsSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationModels.swift"),
            encoding: .utf8
        )
        let matchingSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationSkillMatching.swift"),
            encoding: .utf8
        )
        let actionSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationActionCandidates.swift"),
            encoding: .utf8
        )
        let parsingSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/AgentToolInvocationParsing.swift"),
            encoding: .utf8
        )

        XCTAssertLessThan(plannerSource.split(separator: "\n").count, 120)
        XCTAssertTrue(plannerSource.contains("public func plan(for request: AgentToolInvocationRequest)"))
        XCTAssertTrue(modelsSource.contains("public struct AgentToolInvocationCandidate"))
        XCTAssertTrue(matchingSource.contains("func candidate(for skill: AgentSkill"))
        XCTAssertTrue(matchingSource.contains("func candidate(for integration: AppIntegration"))
        XCTAssertTrue(actionSource.contains("func notificationActionCandidate"))
        XCTAssertTrue(actionSource.contains("func emailActionCandidate"))
        XCTAssertTrue(actionSource.contains("func phoneCallHandoffActionCandidate"))
        XCTAssertTrue(actionSource.contains("func webSearchHandoffActionCandidate"))
        XCTAssertTrue(parsingSource.contains("func calendarTitle(from userText: String)"))
        XCTAssertTrue(parsingSource.contains("func isPhoneCallHandoffRequest"))
        XCTAssertTrue(parsingSource.contains("func isWebSearchHandoffRequest"))
        XCTAssertTrue(parsingSource.contains("func uniqueCandidates"))
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
        XCTAssertTrue(registry.userVisibleHandoffs.contains { $0.key == "chatgpt" })
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

    func testAgentSkillCatalogExposesInstalledToolsAndDownloadableMarketplaceSkills() throws {
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
            "homekit-front-door-lock",
            "shortcut-daily-briefing",
            "shortcut-save-shared-text",
            "shortcut-screenshot-to-reminders",
            "shortcut-reply-draft-from-shared-text",
            "shortcut-message-reply-handoff",
            "shortcut-email-triage",
            "shortcut-email-draft-from-shared-text",
            "shortcut-phone-call-handoff",
            "shortcut-web-search-handoff",
            "shortcut-contact-draft-from-shared-text",
            "shortcut-meeting-prep-brief",
            "shortcut-request-to-recipe-draft",
            "shortcut-meeting-text-to-calendar-draft",
            "shortcut-generic-node-runner",
            "shortcut-home-action-preview"
        ])
        XCTAssertEqual(homeKitSkill.kind, .homeKitControl)
        XCTAssertEqual(homeKitSkill.installationStatus, .installed)
        XCTAssertEqual(homeKitSkill.action?.kind, .controlHome)
        XCTAssertTrue(homeKitSkill.action?.requiresConfirmation == true)
        XCTAssertEqual(lockSkill.kind, .homeKitControl)
        XCTAssertEqual(lockSkill.action?.riskTier, .tier3HighRiskExternal)
        XCTAssertTrue(lockSkill.action?.requiresConfirmation == true)
        XCTAssertEqual(shortcutSkill.kind, .shortcutWorkflow)
        XCTAssertTrue(marketplaceSkill.canDownload)
        XCTAssertEqual(marketplaceSkill.source, .marketplace)
    }

    func testAgentSkillCatalogExposesEveryShortcutDemoAsInstalledSkill() throws {
        let catalog = AgentSkillCatalog.default

        for recipe in ShortcutDemoCatalog.default.recipes {
            let skill = try XCTUnwrap(catalog.skill(id: "shortcut-\(recipe.id)"))
            XCTAssertEqual(skill.kind, .shortcutWorkflow)
            XCTAssertEqual(skill.source, .builtIn)
            XCTAssertEqual(skill.installationStatus, .installed)
            XCTAssertEqual(skill.requiredCapabilities, [.appIntents])
            XCTAssertEqual(skill.shortcutRecipeID, recipe.id)
            XCTAssertTrue(skill.summary.contains(recipe.title))
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
        XCTAssertEqual(availableModels.count, 2)

        let qwenTiny = try XCTUnwrap(availableModels.first { $0.id == "qwen3-5-0-8b-q4-k-m" })
        let mlxBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .mlx })
        XCTAssertEqual(mlxBenchmark.artifactReference, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertFalse(mlxBenchmark.supportsInAppDownload)
        XCTAssertTrue(mlxBenchmark.isReferenceOnlyForIOS)
    }

    func testModelCatalogWebsiteDocumentsNoWeightsPolicy() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let indexHTML = try String(contentsOf: root.appendingPathComponent("Website/models/index.html"), encoding: .utf8)
        let readme = try String(contentsOf: root.appendingPathComponent("Website/models/README.md"), encoding: .utf8)
        let rootReadme = try String(contentsOf: root.appendingPathComponent("README.md"), encoding: .utf8)

        XCTAssertTrue(indexHTML.contains("Kairo Model Catalog"))
        XCTAssertTrue(indexHTML.contains("models.json"))
        XCTAssertTrue(indexHTML.contains("compact starter pair: Qwen3.5 0.8B and Llama 3.2 1B"))
        XCTAssertTrue(indexHTML.contains("Llama 3.2 1B"))
        XCTAssertFalse(indexHTML.contains("Gemma 3 1B"))
        XCTAssertFalse(indexHTML.contains("SmolLM2 1.7B"))
        XCTAssertTrue(indexHTML.contains("font-size: 9px"))
        XCTAssertTrue(indexHTML.contains("benchmark profiles"))
        XCTAssertTrue(readme.contains("Do not commit model weights"))
        XCTAssertTrue(readme.contains("kairo-models"))
        XCTAssertTrue(readme.contains("runtime benchmark profiles"))
        XCTAssertTrue(rootReadme.contains("currently Qwen3.5 0.8B and Llama 3.2 1B"))
        XCTAssertFalse(rootReadme.contains("DeepSeek R1 Distill Qwen"))
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

    func testSettingsViewDefinesOAuthConnectorSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains(#""settings.oauth.section""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.connectors""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).disconnect""#))
        XCTAssertTrue(settingsView.contains("disconnectConnector(option)"))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).row""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).name""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).status""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).detail""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).backend-exchange""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).authorize""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.callback-url""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.preview-callback""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.callback-message""#))
        XCTAssertTrue(settingsView.contains("previewOAuthCallback"))
    }

    func testSettingsViewDefinesPrivacyDeletionControls() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains(#""settings.privacy.clearAuditLog""#))
        XCTAssertTrue(settingsView.contains("clearAuditLog()"))
        XCTAssertTrue(settingsView.contains("deletionAPI.clearAuditLog()"))
        XCTAssertTrue(settingsView.contains(#""settings.privacy.clear-audit-log""#))
        XCTAssertTrue(settingsView.contains(#""settings.privacy.audit-log-detail""#))
        XCTAssertTrue(settingsView.contains(#""settings.privacy.status""#))
        XCTAssertTrue(settingsView.contains(#""settings.privacy.auditLogDetail""#))
        XCTAssertTrue(rootView.contains("deletionAPI: environment.backendAPI.deletion"))
    }

    func testSettingsViewDefinesShortcutDemoSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)
        let shortcutDemosSection = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/SettingsShortcutDemosSection.swift"),
            encoding: .utf8
        )

        XCTAssertLessThan(settingsView.split(separator: "\n").count, 1_100)
        XCTAssertTrue(settingsView.contains("SettingsShortcutDemosSection("))
        XCTAssertFalse(settingsView.contains("private func shortcutDemoRow"))
        XCTAssertTrue(shortcutDemosSection.contains("struct SettingsShortcutDemosSection"))
        XCTAssertTrue(shortcutDemosSection.contains("ShortcutDemoCatalog.default.recipes"))
        XCTAssertTrue(shortcutDemosSection.contains("Shortcut Demos"))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demos""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id)""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id).input""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id).output""#))
        XCTAssertTrue(shortcutDemosSection.contains(#""settings.shortcuts.demo.\(recipe.id).sample""#))
    }

    func testSettingsViewDefinesLocalModelSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)
        let settingsLocalModels = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView+LocalModels.swift"),
            encoding: .utf8
        )
        let settingsSources = settingsView + "\n" + settingsLocalModels
        let compactView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/LocalModelsCompactView.swift"), encoding: .utf8)
        let progressView = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/LocalModelDownloadProgressInlineView.swift"),
            encoding: .utf8
        )
        let settingsModelSources = settingsSources + "\n" + compactView

        XCTAssertTrue(settingsView.contains("case .modelsOnly"))
        XCTAssertTrue(settingsView.contains("LocalModelsCompactView("))
        XCTAssertTrue(compactView.contains(#""settings.models.section""#))
        XCTAssertTrue(compactView.contains(#""settings.models.local""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.routePreference""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.preference""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.preference.\(preference.rawValue)""#))
        XCTAssertTrue(settingsModelSources.contains(".accessibilityElement(children: .contain)"))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).row""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).status""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).download""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).select""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).delete""#))
        XCTAssertTrue(settingsModelSources.contains("LocalModelDownloadProgressState"))
        XCTAssertTrue(settingsModelSources.contains("localModelDownloadProgress"))
        XCTAssertTrue(settingsModelSources.contains("localModelDownloadTask"))
        XCTAssertTrue(settingsModelSources.contains("cancelLocalModelDownload(row)"))
        XCTAssertTrue(settingsModelSources.contains("LocalModelDownloadProgressInlineView("))
        XCTAssertTrue(settingsSources.contains("localModelDownloadTask == nil"))
        XCTAssertTrue(settingsSources.contains("cleanupStaleDownloadingRecords()"))
        XCTAssertTrue(progressView.contains(#""settings.models.\(modelID).download-progress""#))
        XCTAssertTrue(progressView.contains(#""settings.models.\(modelID).download-active-cancel""#))
        XCTAssertTrue(settingsSources.contains("localModelDownloader.download(row.manifest) { fractionCompleted in"))
        XCTAssertTrue(settingsModelSources.contains("row.benchmarkSummaryText"))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).benchmark""#))
        XCTAssertTrue(settingsSources.contains("let localModelBenchmarkService: LocalModelBenchmarkService?"))
        XCTAssertTrue(settingsSources.contains("runLocalModelBenchmark(row)"))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).benchmark-run""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.\(row.modelID).reply-check""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.benchmark-message""#))
        XCTAssertTrue(settingsSources.contains("runLocalModelReplyCheck(row)"))
        XCTAssertTrue(settingsSources.contains(#""settings.models.message.benchmarkNeedsDownload""#))
        XCTAssertTrue(settingsSources.contains("refreshLocalModelCatalog"))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.refresh-catalog""#))
        XCTAssertTrue(settingsModelSources.contains(#""settings.models.catalog-source""#))
    }

    func testSettingsViewDelegatesCompactModelsOnlyLayout() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsViewURL = root.appendingPathComponent("Kairo/Views/SettingsView.swift")
        let compactViewURL = root.appendingPathComponent("Kairo/Views/LocalModelsCompactView.swift")
        let settingsView = try String(contentsOf: settingsViewURL, encoding: .utf8)
        let compactView = try String(contentsOf: compactViewURL, encoding: .utf8)

        XCTAssertTrue(settingsView.contains("case .modelsOnly"))
        XCTAssertTrue(settingsView.contains("case .shortcutDemosOnly"))
        XCTAssertTrue(settingsView.contains("LocalModelsCompactView("))
        XCTAssertTrue(settingsView.contains("SettingsShortcutDemosSection()"))
        XCTAssertLessThan(settingsView.split(separator: "\n").count, 1_050)
        XCTAssertTrue(compactView.contains("struct LocalModelsCompactView"))
        XCTAssertTrue(compactView.contains(#""settings.models.screen""#))
        XCTAssertFalse(compactView.contains(#""settings.models.compact-list""#))
        XCTAssertTrue(compactView.contains(#""settings.models.selected-summary""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).manifest""#))
        XCTAssertTrue(compactView.contains("row.runtimeFitText"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).runtime-fit""#))
        XCTAssertTrue(compactView.contains("runtimePills(for: row)"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).runtime-pill.\(index)""#))
        XCTAssertTrue(compactView.contains("private let starterModelIDs = LocalModelCatalog.kairoStarterModelIDs"))
        XCTAssertFalse(compactView.contains("@State private var showsAllModelRows"))
        XCTAssertTrue(compactView.contains("@State private var pendingDownloadModelID: String?"))
        XCTAssertTrue(compactView.contains("downloadPreview(for: row)"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).download-preview""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).download-confirm""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).download-cancel""#))
        XCTAssertTrue(compactView.contains("localModelDownloadProgress"))
        XCTAssertTrue(compactView.contains("downloadProgressView(progress, row: row)"))
        XCTAssertTrue(compactView.contains("cancelLocalModelDownload"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(progress.modelID).download-progress""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(progress.modelID).download-progress-bar""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(progress.modelID).download-progress-text""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(progress.modelID).download-cancel-note""#))
        XCTAssertTrue(compactView.contains(#""settings.models.\(progress.modelID).download-active-cancel""#))
        XCTAssertTrue(compactView.contains(#""settings.models.download.approvalRequired""#))
        XCTAssertTrue(compactView.contains("ForEach(visibleModelRows)"))
        XCTAssertFalse(compactView.contains("ForEach(localModelStatus.settingsRows)"))
        XCTAssertTrue(compactView.contains("let starterIDs = Set(starterModelIDs)"))
        XCTAssertTrue(compactView.contains("localModelStatus.settingsRows.filter { starterIDs.contains($0.modelID) }"))
        XCTAssertTrue(compactView.contains("if trimmedModelRowCount > 0"))
        XCTAssertTrue(compactView.contains(#""settings.models.trimmed-note""#))
        XCTAssertFalse(compactView.contains(#""settings.models.show-more""#))
        XCTAssertFalse(compactView.contains("modelListToggleTitle"))
        XCTAssertTrue(compactView.contains("row.manifestTransparencyText"))
        XCTAssertTrue(compactView.contains("row.licenseApprovalText"))
        XCTAssertTrue(compactView.contains(#""settings.models.\(row.modelID).license-approval""#))
        XCTAssertTrue(compactView.contains("selectedModelSummaryText"))
        XCTAssertTrue(compactView.contains("downloadedModel"))
        XCTAssertTrue(compactView.contains(#""settings.models.compact.downloadedSelectForRouting""#))
        XCTAssertTrue(compactView.contains("compactRoutePreferenceMenu"))
        XCTAssertFalse(compactView.contains("Picker(\"Route Preference\""))
        XCTAssertTrue(compactView.contains("private var compactSectionTitleFont: Font { .title3.weight(.semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactSectionHeadingFont: Font { .subheadline.weight(.semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactModelNameFont: Font { .subheadline.weight(.semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactModelMetadataFont: Font { .caption }"))
        XCTAssertTrue(compactView.contains("private var compactModelStatusFont: Font { .caption2.weight(.semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactButtonLabelFont: Font { .caption.weight(.semibold) }"))
        XCTAssertTrue(compactView.contains("private var compactControlValueFont: Font { .subheadline.weight(.semibold) }"))
        XCTAssertTrue(compactView.contains(#""settings.models.reply""#))
        XCTAssertFalse(compactView.contains(#""Reply Check""#))
        XCTAssertTrue(compactView.contains("GridItem(.adaptive(minimum: 108)"))
        XCTAssertTrue(compactView.contains(".lineLimit(1)"))
        XCTAssertTrue(compactView.contains(".lineLimit(2)"))
        XCTAssertTrue(compactView.contains(".imageScale(.small)"))
        XCTAssertTrue(compactView.contains(".background(tint.opacity(0.07), in: RoundedRectangle(cornerRadius: 7))"))
        XCTAssertTrue(compactView.contains(".font(compactModelNameFont)"))
        XCTAssertTrue(compactView.contains(".font(compactModelMetadataFont)"))
        XCTAssertTrue(compactView.contains(".buttonStyle(.plain)"))
    }

    func testRootViewDefinesAutomationsRecipeCenterAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let automationsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/AutomationsView.swift"), encoding: .utf8)

        XCTAssertFalse(rootView.contains("TabView"))
        XCTAssertTrue(rootView.contains("GeometryReader"))
        XCTAssertTrue(rootView.contains("let safeAreaInsets = proxy.safeAreaInsets"))
        XCTAssertTrue(rootView.contains(#""root.shell""#))
        XCTAssertTrue(rootView.contains(#""root.safe-area-header""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.toggle""#))
        XCTAssertTrue(rootView.contains(#""root.drawer""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.close""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.\(section.rawValue)""#))
        XCTAssertTrue(rootView.contains("rootHeader(topInset: safeAreaInsets.top)"))
        XCTAssertTrue(rootView.contains("navigationMenu(safeAreaInsets: safeAreaInsets)"))
        XCTAssertFalse(rootView.contains("BriefingInboxView("))
        XCTAssertTrue(rootView.contains("MemoryCenterView(memoryAPI: environment.backendAPI.memory)"))
        XCTAssertTrue(rootView.contains(".presentationDetents([.medium, .large])"))
        XCTAssertTrue(rootView.contains(".padding(.top, max(topInset, 0)"))
        XCTAssertTrue(rootView.contains(".ignoresSafeArea(edges: .top)"))
        XCTAssertTrue(rootView.contains(#""root.menu.sheet""#))
        XCTAssertFalse(rootView.contains(".ignoresSafeArea(edges: .vertical)"))
        XCTAssertFalse(rootView.contains("case home"))
        XCTAssertTrue(rootView.contains("case chat"))
        XCTAssertTrue(rootView.contains("case memory"))
        XCTAssertFalse(rootView.contains("case skills"))
        XCTAssertTrue(rootView.contains("case shortcuts"))
        XCTAssertTrue(rootView.contains("case access"))
        XCTAssertTrue(rootView.contains("case models"))
        XCTAssertTrue(rootView.contains("case settings"))
        XCTAssertTrue(rootView.contains("AutomationsView("))
        XCTAssertTrue(rootView.contains("recipeAPI: environment.backendAPI.recipes"))
        XCTAssertTrue(automationsView.contains(#""automations.recipe-center""#))
        XCTAssertTrue(automationsView.contains(#""automations.list""#))
        XCTAssertTrue(automationsView.contains(#""automations.seed-samples""#))
        XCTAssertTrue(automationsView.contains(#""automations.message""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id)""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id).preview""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id).run""#))
        XCTAssertTrue(automationsView.contains(#""automations.recipe.\(recipe.id).toggle""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcutTemplates.section""#))
        XCTAssertTrue(automationsView.contains("ShortcutTemplateRegistry.default"))
        XCTAssertTrue(automationsView.contains("shortcutTemplateRegistry.manualInstallDisclaimer"))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-templates""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-template.disclaimer""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-template.\(template.identifier)""#))
        XCTAssertTrue(automationsView.contains(#""automations.shortcut-template.\(template.identifier).instructions""#))
    }

    func testStageOneProductRedesignDefinesMobileNativeShellContract() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let designSystem = try String(contentsOf: root.appendingPathComponent("Kairo/Views/KairoDesignSystem.swift"), encoding: .utf8)
        let actionPreview = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ActionPreviewView.swift"), encoding: .utf8)
        let chatView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatView.swift"), encoding: .utf8)

        XCTAssertTrue(designSystem.contains("enum KairoDesign"))
        XCTAssertTrue(designSystem.contains("struct KairoMark"))
        XCTAssertTrue(designSystem.contains("struct KairoStatusPill"))
        XCTAssertTrue(designSystem.contains("struct KairoActionRow"))
        XCTAssertTrue(rootView.contains("private var selectedSection: RootSection = .chat"))
        XCTAssertFalse(rootView.contains("BriefingInboxView("))
        XCTAssertTrue(rootView.contains("KairoMark(size:"))
        XCTAssertTrue(rootView.contains(#""root.menu.sheet""#))
        XCTAssertTrue(rootView.contains(#""root.drawer.toggle""#))
        XCTAssertTrue(rootView.contains("presentationDetents([.medium, .large])"))
        XCTAssertFalse(rootView.contains("case home"))
        XCTAssertTrue(rootView.contains("case memory"))
        XCTAssertFalse(rootView.contains("TabView"))
        XCTAssertFalse(chatView.contains("KairoBriefingStrip()"))
        XCTAssertTrue(actionPreview.contains(#""chat.action.preview.title""#))
        XCTAssertTrue(actionPreview.contains(#""chat.action.preview.safetyNote""#))
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

    func testChatScreenKeepsMobileNavigationAndContextSimple() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let rootView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let chatView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatView.swift"), encoding: .utf8)
        let routeBarView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatProviderRouteBar.swift"), encoding: .utf8)

        XCTAssertTrue(rootView.contains(#""root.back-to-chat""#))
        XCTAssertTrue(rootView.contains("selectedSection = .chat"))
        XCTAssertTrue(rootView.contains(#""root.backToChat""#))
        XCTAssertFalse(rootView.contains(#"KairoStatusPill(title: "Auto""#))
        XCTAssertTrue(chatView.contains(#""chat.tools.menu""#))
        XCTAssertFalse(chatView.contains(#""chat.session-controls""#))
        XCTAssertTrue(chatView.contains("ChatProviderRouteBar("))
        XCTAssertFalse(chatView.contains("privateModeButton"))
        XCTAssertFalse(chatView.contains("NavigationStack {"))
        XCTAssertFalse(chatView.contains("KairoBriefingStrip()"))
        XCTAssertTrue(routeBarView.contains("Menu {"))
        XCTAssertTrue(routeBarView.contains(#""chat.mode.standard""#))
        XCTAssertTrue(routeBarView.contains(#""chat.private-chat.toggle""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.preference""#))
        XCTAssertFalse(routeBarView.contains("routePreferenceControls"))
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

    func testAutomationsViewUsesCompactFullScreenScrollLayout() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let automationsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/AutomationsView.swift"), encoding: .utf8)

        XCTAssertTrue(automationsView.contains("ScrollView"))
        XCTAssertTrue(automationsView.contains("automationSectionHeader"))
        XCTAssertTrue(automationsView.contains("automationSection("))
        XCTAssertTrue(automationsView.contains(".scrollIndicators(.hidden)"))
        XCTAssertTrue(automationsView.contains("Color(.sRGB, white: 0.98, opacity: 1).ignoresSafeArea()"))
        XCTAssertFalse(automationsView.contains("Form {"))
        XCTAssertFalse(automationsView.contains("automationPanel"))
    }

    func testChatViewDefinesPolishedComposerAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let chatView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatView.swift"), encoding: .utf8)
        let chatBubbleView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatBubble.swift"), encoding: .utf8)
        let chatActionStripsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatActionStrips.swift"), encoding: .utf8)
        let routeBarView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/ChatProviderRouteBar.swift"), encoding: .utf8)

        XCTAssertTrue(chatView.contains(#""chat.composer.surface""#))
        XCTAssertTrue(chatView.contains(#""chat.tools.menu""#))
        XCTAssertTrue(chatView.contains(#""chat.composer.placeholder""#))
        XCTAssertTrue(chatView.contains("ChatProviderRouteBar("))
        XCTAssertLessThan(chatView.split(separator: "\n").count, 520)
        XCTAssertFalse(chatView.contains("struct ProposedActionsStrip"))
        XCTAssertFalse(chatView.contains("struct ToolCandidatesStrip"))
        XCTAssertTrue(chatActionStripsView.contains("struct ProposedActionsStrip"))
        XCTAssertTrue(chatActionStripsView.contains("struct ToolCandidatesStrip"))
        XCTAssertTrue(routeBarView.contains("struct ChatProviderRouteBar"))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.title""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.warning""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.preference""#))
        XCTAssertTrue(routeBarView.contains(#""chat.provider-route.preference.\(preference.rawValue)""#))
        XCTAssertTrue(routeBarView.contains(#""chat.mode.accessibilityStatus""#))
        XCTAssertTrue(routeBarView.contains(#""chat.private-chat.toggle""#))
        XCTAssertTrue(routeBarView.contains("preference.chatControlTitle"))
        XCTAssertTrue(routeBarView.contains("Menu {"))
        XCTAssertFalse(chatView.contains("privateModeButton"))
        XCTAssertTrue(chatView.contains(#""chat.composer.input-shell""#))
        XCTAssertTrue(chatView.contains(#""chat.composer.text""#))
        XCTAssertTrue(chatView.contains(#""chat.composer.send""#))
        XCTAssertTrue(chatView.contains("minHeight: 52"))
        XCTAssertTrue(chatView.contains("RoundedRectangle(cornerRadius: 22"))
        XCTAssertTrue(chatView.contains("shadow(color:"))
        XCTAssertTrue(chatBubbleView.contains("struct ChatBubble"))
        XCTAssertLessThan(chatBubbleView.split(separator: "\n").count, 120)
        XCTAssertTrue(chatBubbleView.contains(".textSelection(.enabled)"))
        XCTAssertTrue(chatBubbleView.contains(#""chat.message.copy.\(message.id.uuidString)""#))
        XCTAssertTrue(chatBubbleView.contains(#""chat.message.reply.\(message.id.uuidString)""#))
        XCTAssertTrue(chatView.contains(#""chat.reply-preview""#))
        XCTAssertTrue(chatView.contains("replyToMessage"))
        XCTAssertTrue(chatActionStripsView.contains("actionRiskSummary(for: action)"))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.proposed-action.\(action.kind.rawValue).risk""#))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.action.confirmation.willAskFirst""#))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.action.risk.draftOnly""#))
        XCTAssertTrue(chatActionStripsView.contains("candidate.handoffSummary"))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).summary""#))
        XCTAssertTrue(chatActionStripsView.contains("toolRiskSummary(for: candidate)"))
        XCTAssertTrue(chatActionStripsView.contains(#""chat.tool-candidate.\(candidate.skillID ?? candidate.integrationKey ?? candidate.id).risk""#))
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
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider()),
            localModelSettingsService: service
        )

        await viewModel.load()

        XCTAssertEqual(
            viewModel.providerRouteStatus.title,
            KairoL10n.string("chat.provider.route.title", KairoL10n.string("chat.provider.route.local"))
        )
        XCTAssertTrue(viewModel.providerRouteStatus.detail.contains("Qwen Small Test"))
        XCTAssertNil(viewModel.providerRouteStatus.warning)

        await viewModel.setProviderRoutePreference(.preferCloud)

        XCTAssertEqual(
            viewModel.providerRouteStatus.title,
            KairoL10n.string("chat.provider.route.title", KairoL10n.string("chat.provider.route.cloud"))
        )
        XCTAssertEqual(viewModel.providerRouteStatus.badge, KairoL10n.string("chat.provider.route.cloud"))
        XCTAssertEqual(viewModel.providerRouteStatus.preference, .preferCloud)
        let persistedStatus = await service.status()
        XCTAssertEqual(persistedStatus.preference, .preferCloud)
        XCTAssertNil(viewModel.errorMessage)
    }

    @MainActor
    func testChatViewModelComposesReplyReferenceWithoutPastingFullMessage() async throws {
        let viewModel = ChatViewModel(
            historyStore: InMemoryChatHistoryStore(),
            shareIngestionQueue: InMemoryShareIngestionQueue(),
            agent: AgentCore(memoryStore: InMemoryMemoryStore(), aiProvider: MockAIProvider())
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
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).manage""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).install""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).update""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.action.previewUpdate""#))
        XCTAssertTrue(permissionHubView.contains("skill.source == .marketplace"))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).disable""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).enable""#))
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

    func testKairoEnvironmentWiresFileBackedSkillManagerIntoAccessSurface() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let environmentSource = try String(contentsOf: root.appendingPathComponent("Kairo/Services/KairoEnvironment.swift"), encoding: .utf8)
        let rootViewSource = try String(contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"), encoding: .utf8)
        let permissionHubSource = try String(contentsOf: root.appendingPathComponent("Kairo/Views/PermissionHubView.swift"), encoding: .utf8)

        XCTAssertTrue(environmentSource.contains("agentSkillManagerService: AgentSkillManagerService?"))
        XCTAssertTrue(environmentSource.contains("kairoRecipeStore: any KairoRecipeStore"))
        XCTAssertTrue(environmentSource.contains("FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)"))
        XCTAssertTrue(environmentSource.contains("FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)"))
        XCTAssertTrue(environmentSource.contains("AgentSkillManagerService("))
        XCTAssertTrue(environmentSource.contains("store: agentSkillStore"))
        XCTAssertTrue(environmentSource.contains("AgentSkillMarketplaceCatalogService.defaultStandaloneRepository"))
        XCTAssertTrue(rootViewSource.contains("AutomationsView("))
        XCTAssertTrue(rootViewSource.contains("recipeAPI: environment.backendAPI.recipes"))
        XCTAssertTrue(rootViewSource.contains("PermissionHubView("))
        XCTAssertTrue(rootViewSource.contains("skillManagerService: environment.agentSkillManagerService"))
        XCTAssertTrue(rootViewSource.contains("marketplaceCatalogService: environment.agentSkillMarketplaceCatalogService"))
        XCTAssertTrue(environmentSource.contains("localModelCatalogService"))
        XCTAssertTrue(environmentSource.contains("LocalModelCatalogService.defaultStandaloneRepository"))
        XCTAssertTrue(rootViewSource.contains("localModelCatalogService: environment.localModelCatalogService"))
        XCTAssertTrue(environmentSource.contains("localModelBenchmarkService"))
        XCTAssertTrue(environmentSource.contains("FileBackedLocalModelBenchmarkStore(fileURL: paths.localModelBenchmarkResultsURL)"))
        XCTAssertTrue(rootViewSource.contains("localModelBenchmarkService: environment.localModelBenchmarkService"))
        XCTAssertTrue(environmentSource.contains("localModelReplyCheckService"))
        XCTAssertTrue(environmentSource.contains("LocalModelReplyCheckService("))
        XCTAssertTrue(rootViewSource.contains("localModelReplyCheckService: environment.localModelReplyCheckService"))
        XCTAssertTrue(environmentSource.contains("LocalModelRoutingAIProvider("))
        XCTAssertTrue(environmentSource.contains("localModelSettingsService: localModelSettingsService"))
        XCTAssertTrue(rootViewSource.contains("mode: .modelsOnly"))
        XCTAssertTrue(rootViewSource.contains("settingsMode: SettingsViewMode = .all"))
        XCTAssertTrue(permissionHubSource.contains("private let skillManagerService: AgentSkillManagerService?"))
        XCTAssertTrue(permissionHubSource.contains("private let marketplaceCatalogService: AgentSkillMarketplaceCatalogService?"))
        XCTAssertTrue(permissionHubSource.contains("capability.status.accessFallbackMessage"))
        XCTAssertTrue(permissionHubSource.contains(#""access.capability.\(capability.key.rawValue).status-fallback""#))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.catalog()"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.disableSkill(id: skill.id)"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.enableSkill(id: skill.id)"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.removeSkill(id: skill.id)"))
    }

    func testKairoEnvironmentProvidesDeterministicUITestingSkillManagerAndMarketplace() async throws {
        let environment = try await KairoEnvironment.uiTesting(resetPersistentState: true)
        let skillManagerService = try XCTUnwrap(environment.agentSkillManagerService)
        let marketplaceCatalogService = try XCTUnwrap(environment.agentSkillMarketplaceCatalogService)
        let modelCatalogService = try XCTUnwrap(environment.localModelCatalogService)

        var catalog = try await skillManagerService.catalog()
        XCTAssertEqual(catalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .installed)

        let disabled = try await skillManagerService.disableSkill(id: "shortcut-save-shared-text")
        XCTAssertEqual(disabled?.installationStatus, .disabled)

        let reloadedEnvironment = try await KairoEnvironment.uiTesting(resetPersistentState: false)
        let reloadedSkillManagerService = try XCTUnwrap(reloadedEnvironment.agentSkillManagerService)
        catalog = try await reloadedSkillManagerService.catalog()
        XCTAssertEqual(catalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .disabled)
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
            "llama3-2-1b-instruct-q4-k-m",
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
            "settings-local-model-reply-check",
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
        for providerKey in ["google", "microsoft", "notion", "slack", "chatgpt", "github"] {
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
        XCTAssertTrue(expandedModelsScenarioIdentifiers.contains("settings.models.llama3-2-1b-instruct-q4-k-m.name"))
        XCTAssertTrue(expandedModelsScenarioIdentifiers.contains("settings.models.trimmed-note"))
        let replyCheckScenarioIdentifiers = catalog.scenario(id: "settings-local-model-reply-check")?.requiredAccessibilityIdentifiers ?? []
        XCTAssertTrue(replyCheckScenarioIdentifiers.contains("settings.models.local"))
        XCTAssertTrue(replyCheckScenarioIdentifiers.contains("settings.models.qwen3-5-0-8b-q4-k-m.reply-check"))
        XCTAssertTrue(replyCheckScenarioIdentifiers.contains("settings.models.benchmark-message"))
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
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text.disable") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.shortcut-save-shared-text.enable") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.marketplace-weather-briefing.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.marketplace-qwen-oauth-workflow.install") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.message") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview.compatibility") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manifest-preview.confirm") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.homekit-front-door-lock") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skill.homekit-front-door-lock.manage") == true)
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
        XCTAssertTrue(uiTestSources.contains("testSettingsLocalModelDownloadRequiresConfirmationPreview"))
        XCTAssertTrue(uiTestSources.contains("testSettingsExpandedModelCatalogKeepsPopularStarterRowsVisible"))
        XCTAssertTrue(uiTestSources.contains("testSettingsShowsQwenBenchmarkFlowRequiresDownload"))
        XCTAssertTrue(uiTestSources.contains("testSettingsRunsInstalledLocalModelReplyCheck"))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.\(modelID).download-preview""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.\(modelID).download-confirm""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.\(modelID).download-cancel""#))
        XCTAssertTrue(uiTestSources.contains(#""settings.models.qwen3-5-0-8b-q4-k-m.reply-check""#))
        XCTAssertTrue(uiTestSources.contains("--ui-testing-settings-shortcut-demos-only"))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.models.show-more").exists)"#))
        XCTAssertTrue(uiTestSources.contains(#"XCTAssertFalse(anyElement("settings.models.remote-catalog-test-model-q4-k-m.name").exists)"#))
        XCTAssertTrue(uiTestSources.contains(#"message.label.contains("Download Qwen3.5 0.8B Q4_K_M")"#))
        XCTAssertTrue(uiTestSources.contains(#"message.label.localizedCaseInsensitiveContains("benchmark")"#))
        XCTAssertTrue(uiTestSources.contains("Local model reply is alive."))
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
        XCTAssertTrue(uiTestSources.contains(#""root.drawer.shortcuts""#))
        XCTAssertTrue(uiTestSources.contains(#""root.drawer.memory""#))
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
        XCTAssertTrue(uiTestSources.contains(#"providerKey: "chatgpt""#))
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
        XCTAssertTrue(uiTestSources.contains("no network request was sent"))
        XCTAssertTrue(uiTestSources.contains("settings.oauth.connectors"))
        XCTAssertTrue(uiTestSources.contains("settings.shortcuts.demos"))
        XCTAssertTrue(uiTestSources.contains("settings.models.local"))
        for displayName in [
            "Qwen3.5 0.8B Q4_K_M",
            "Llama 3.2 1B Instruct Q4_K_M"
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
        XCTAssertTrue(uiTestSources.contains(#""access.skill.user-ui-created-skill.enable""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.shortcut-save-shared-text.disable""#))
        XCTAssertTrue(uiTestSources.contains(#""access.skill.shortcut-save-shared-text.enable""#))
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

    func testLiveEnvironmentSourceUsesKeychainCredentialStoreForProviderSecrets() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let environmentSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoEnvironment.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(environmentSource.contains("let credentialStore = KeychainCredentialStore()"))
        XCTAssertTrue(environmentSource.contains("OpenAIProvider(credentialStore: credentialStore)"))
        XCTAssertTrue(environmentSource.contains("connectedOAuthProviderKeys(credentialStore: credentialStore)"))
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
