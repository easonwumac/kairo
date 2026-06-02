import XCTest
import Foundation
import CryptoKit
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

    func testSandboxActionCatalogSeparatesSupportedAndUnsupportedActions() {
        let catalog = SandboxActionCatalog()

        XCTAssertEqual(catalog.descriptor(for: .saveMemory)?.supportStatus, .implemented)
        XCTAssertEqual(catalog.descriptor(for: .sendNotification)?.supportStatus, .scaffolded)
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
        XCTAssertTrue(context.contains("unsupportedSandboxAction"))
        XCTAssertTrue(context.contains("require visible user confirmation"))
        XCTAssertTrue(context.contains("Integration registry"))
        XCTAssertTrue(context.contains("apple-shortcuts"))
        XCTAssertTrue(context.contains("BGTaskScheduler"))
        XCTAssertTrue(context.contains("Local model fallback cannot use tools"))
        XCTAssertTrue(context.contains("homeKit"))
        XCTAssertTrue(context.contains("controlHome"))
    }

    func testCapabilityPromptContextIncludesInstalledSkillsAsToolOptions() {
        let context = CapabilityPromptContextBuilder(skillCatalog: .default).build()

        XCTAssertTrue(context.contains("Installed skills/tools the model may use"))
        XCTAssertTrue(context.contains("homekit-evening-scene"))
        XCTAssertTrue(context.contains("shortcut-daily-briefing"))
        XCTAssertTrue(context.contains("requiresConfirmation=true"))
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

    func testSandboxActionExecutorSavesConfirmedMemory() async throws {
        let store = InMemoryMemoryStore()
        let executor = SandboxActionExecutor(memoryStore: store)
        let action = AgentAction(
            kind: .saveMemory,
            title: "Save memory",
            rationale: "User asked Kairo to remember this.",
            payload: .text("Remember that Kairo must not overclaim sandbox access."),
            riskTier: .tier2LowRiskWrite
        )

        let unconfirmed = try await executor.execute(action, confirmed: false)
        XCTAssertFalse(unconfirmed.completed)

        let confirmed = try await executor.execute(action, confirmed: true)
        XCTAssertTrue(confirmed.completed)
        XCTAssertNotNil(confirmed.createdIdentifier)

        let memories = try await store.search(query: "overclaim", limit: 10)
        XCTAssertEqual(memories.count, 1)
    }

    func testSandboxActionExecutorReportsUnsupportedSandboxActionWithoutExecuting() async throws {
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore())
        let action = AgentAction(
            kind: .unsupportedSandboxAction,
            title: "Read another app",
            rationale: "The user asked for cross-app data access.",
            payload: .unsupported(UnsupportedActionExplanation(
                requestedAction: "Read messages from another app",
                reason: "iOS does not expose another app's private container to Kairo",
                safeAlternative: "Ask the user to share the content into Kairo"
            )),
            riskTier: .tier3HighRiskExternal
        )

        let result = try await executor.execute(action, confirmed: false)

        XCTAssertFalse(result.completed)
        XCTAssertTrue(result.message.contains("Unsupported by iOS sandbox"))
        XCTAssertTrue(result.message.contains("share the content"))
    }

    func testSandboxActionExecutorOpensURLThroughInjectedOpener() async throws {
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openURL,
            title: "Open website",
            rationale: "User asked to open a visible URL.",
            payload: .url("https://example.com"),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        let openedURLs = await opener.openedURLs
        XCTAssertEqual(openedURLs, [URL(string: "https://example.com")!])
    }

    func testSandboxActionExecutorOpensConfirmedShortcutHandoffURLThroughInjectedOpener() async throws {
        let handoffURL = try ShortcutHandoffService().runShortcutURL(for: ShortcutHandoffRequest(
            shortcutName: "Kairo Daily Briefing",
            input: ShortcutNodeInput(text: "Action: Review Shortcut handoff"),
            callbackBaseURL: URL(string: "kairo://shortcuts/callback")!,
            requestID: "handoff-123"
        ))
        let opener = MockURLOpener()
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), urlOpener: opener)
        let action = AgentAction(
            kind: .openURL,
            title: "Run Shortcut",
            rationale: "User confirmed a visible Shortcuts handoff.",
            payload: .url(handoffURL.absoluteString),
            riskTier: .tier1Draft
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertTrue(result.requiresExternalUI)
        let openedURLs = await opener.openedURLs
        XCTAssertEqual(openedURLs, [handoffURL])
    }

    func testSandboxActionExecutorSchedulesNotificationThroughInjectedScheduler() async throws {
        let scheduler = MockNotificationScheduler(granted: true)
        let executor = SandboxActionExecutor(memoryStore: InMemoryMemoryStore(), notificationScheduler: scheduler)
        let action = AgentAction(
            kind: .sendNotification,
            title: "Notify",
            rationale: "User asked for a local notification.",
            payload: .notification(NotificationDraft(title: "Kairo", body: "Time to review")),
            riskTier: .tier2LowRiskWrite
        )

        let result = try await executor.execute(action, confirmed: true)

        XCTAssertTrue(result.completed)
        XCTAssertEqual(result.createdIdentifier, "notification-id")
        let scheduledTitles = await scheduler.scheduledDrafts.map(\.title)
        XCTAssertEqual(scheduledTitles, ["Kairo"])
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

        XCTAssertEqual(catalog.recipes.map(\.id), ["evening-scene", "desk-lamp"])
        XCTAssertEqual(sceneRecipe.action.kind, .controlHome)
        XCTAssertEqual(sceneRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Living Room",
            targetName: "Evening Wind Down",
            command: .runScene
        )))
        XCTAssertTrue(sceneRecipe.action.requiresConfirmation)
        XCTAssertEqual(sceneRecipe.confirmationSummary, "Confirm before Kairo runs the HomeKit scene.")
        XCTAssertEqual(accessoryRecipe.action.payload, .homeControl(HomeControlRequest(
            homeName: "Home",
            roomName: "Office",
            targetName: "Desk Lamp",
            command: .setPower,
            value: .bool(true)
        )))
        XCTAssertTrue(accessoryRecipe.sandboxNotes.contains("HomeKit entitlement"))
    }

    func testAgentSkillCatalogExposesInstalledToolsAndDownloadableMarketplaceSkills() throws {
        let catalog = AgentSkillCatalog.default
        let homeKitSkill = try XCTUnwrap(catalog.skill(id: "homekit-evening-scene"))
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
            "shortcut-daily-briefing"
        ])
        XCTAssertEqual(homeKitSkill.kind, .homeKitControl)
        XCTAssertEqual(homeKitSkill.installationStatus, .installed)
        XCTAssertEqual(homeKitSkill.action?.kind, .controlHome)
        XCTAssertTrue(homeKitSkill.managementSummary.contains("Requires confirmation"))
        XCTAssertEqual(shortcutSkill.kind, .shortcutWorkflow)
        XCTAssertTrue(marketplaceSkill.canDownload)
        XCTAssertEqual(marketplaceSkill.source, .marketplace)
    }

    func testAgentSkillManifestRequiresSignatureAndVerifiesChecksum() throws {
        let downloadableSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let checksum = try AgentSkillManifest.sha256Hex(for: downloadableSkill)
        let manifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: checksum,
            signature: AgentSkillManifestSignature(
                keyID: "kairo-marketplace-2026",
                algorithm: .ed25519,
                value: "signed-weather-briefing"
            )
        )

        XCTAssertNoThrow(try manifest.validateForInstall())
        XCTAssertEqual(manifest.installableSkill.installationStatus, .installed)
        XCTAssertEqual(manifest.installableSkill.source, .marketplace)
        XCTAssertEqual(manifest.installableSkill.version, "1.0")

        let tamperedManifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: "invalid-checksum",
            signature: manifest.signature
        )
        XCTAssertThrowsError(try tamperedManifest.validateForInstall()) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .checksumMismatch)
        }

        let unsignedManifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: checksum,
            signature: nil
        )
        XCTAssertThrowsError(try unsignedManifest.validateForInstall()) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .missingSignature)
        }
    }

    func testAgentSkillManifestTrustStoreVerifiesPublicKeySignatureAndRejectsUnknownKeys() throws {
        let downloadableSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        var manifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: try AgentSkillManifest.sha256Hex(for: downloadableSkill),
            signature: nil
        )
        let signingKey = P256.Signing.PrivateKey()
        let signature = try signingKey.signature(for: manifest.signingPayloadData())
        manifest.signature = AgentSkillManifestSignature(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            value: signature.derRepresentation.base64EncodedString()
        )
        let trustedKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
        )
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [trustedKey])

        XCTAssertNoThrow(try manifest.validateForInstall(trustStore: trustStore))

        let emptyTrustStore = AgentSkillManifestTrustStore(trustedKeys: [])
        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: emptyTrustStore)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .unknownSigningKey("kairo-marketplace-2026"))
        }

        manifest.signature?.value = Data("tampered-signature".utf8).base64EncodedString()
        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: trustStore)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .invalidSignature)
        }
    }

    func testAgentSkillManagerUsesTrustStoreWhenProvided() async throws {
        let storeURL = temporaryFileURL(named: "trusted-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.installationStatus, .installed)

        let untrustedKey = P256.Signing.PrivateKey()
        let untrustedManifest = try AgentSkillManifest.signedForTesting(
            skill: AgentSkill.marketplaceTemplate(
                id: "marketplace-untrusted",
                displayName: "Untrusted Skill",
                summary: "A marketplace skill signed by an unknown key.",
                requiredCapabilities: [.externalConnectors],
                downloadURL: URL(string: "https://skills.kairo.app/untrusted.json")!
            ),
            packageVersion: "2026.6",
            keyID: "unknown-key",
            signingKey: untrustedKey
        )
        await XCTAssertThrowsErrorAsync(try await service.install(manifest: untrustedManifest)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .unknownSigningKey("unknown-key"))
        }
    }

    func testFileBackedAgentSkillManagerPersistsInstallDisableEnableAndRemoveLifecycle() async throws {
        let storeURL = temporaryFileURL(named: "agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.installationStatus, .installed)
        XCTAssertEqual(installed.source, .marketplace)

        var catalog = try await service.catalog()
        XCTAssertTrue(catalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        let disabled = try await service.disableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(disabled?.installationStatus, .disabled)
        catalog = try await service.catalog()
        XCTAssertFalse(catalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))
        XCTAssertEqual(catalog.skill(id: "marketplace-weather-briefing")?.installationStatus, .disabled)

        let enabled = try await service.enableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(enabled?.installationStatus, .installed)

        let reloadedStore = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let reloadedService = AgentSkillManagerService(store: reloadedStore, builtInCatalog: .default)
        let reloadedCatalog = try await reloadedService.catalog()
        XCTAssertEqual(reloadedCatalog.skill(id: "marketplace-weather-briefing")?.installationStatus, .installed)

        try await reloadedService.removeSkill(id: "marketplace-weather-briefing")
        let removedCatalog = try await reloadedService.catalog()
        XCTAssertNil(removedCatalog.skill(id: "marketplace-weather-briefing"))
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
        XCTAssertEqual(result.message, "Action requires user confirmation.")
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

    func testOpenAISettingsServiceSavesAndDeletesAPIKey() async throws {
        let credentials = InMemoryCredentialStore()
        let service = OpenAISettingsService(credentialStore: credentials)

        let initialStatus = try await service.status()
        XCTAssertFalse(initialStatus.hasAPIKey)

        try await service.saveAPIKey("  test-key  ")
        let savedStatus = try await service.status()
        let savedSecret = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertTrue(savedStatus.hasAPIKey)
        XCTAssertEqual(savedSecret, "test-key")

        try await service.deleteAPIKey()
        let deletedStatus = try await service.status()
        XCTAssertFalse(deletedStatus.hasAPIKey)
    }

    func testOAuthConnectorReadinessProvidesSettingsCopyAndActionState() {
        XCTAssertEqual(OAuthConnectorLoginReadiness.connected.settingsStatusText, "已連線")
        XCTAssertEqual(OAuthConnectorLoginReadiness.readyToAuthorize.settingsStatusText, "可授權")
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsClientConfiguration.settingsStatusText, "需要 Client 設定")
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsReauthorization.settingsStatusText, "需要重新授權")

        let readyOption = OAuthConnectorLoginOption(
            integrationKey: "gmail-google-workspace",
            displayName: "Gmail / Google Workspace",
            providerKey: "google",
            readiness: .readyToAuthorize,
            defaultScopes: ["openid"],
            requiresBackendTokenExchange: true,
            accountDataBoundary: "Google scopes only."
        )
        let connectedOption = OAuthConnectorLoginOption(
            integrationKey: "github",
            displayName: "GitHub",
            providerKey: "github",
            readiness: .connected,
            defaultScopes: ["repo"],
            grantedScopes: ["repo"],
            requiresBackendTokenExchange: true,
            accountDataBoundary: "GitHub scopes only."
        )

        XCTAssertTrue(readyOption.canStartAuthorization)
        XCTAssertFalse(connectedOption.canStartAuthorization)
        XCTAssertEqual(connectedOption.settingsDetailText, "已授權 scopes: repo")
    }

    func testSettingsViewDefinesOAuthConnectorSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains("OAuth Connectors"))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.connectors""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).status""#))
        XCTAssertTrue(settingsView.contains(#""settings.oauth.\(option.providerKey).authorize""#))
    }

    func testSettingsViewDefinesShortcutDemoSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains("Shortcut Demos"))
        XCTAssertTrue(settingsView.contains(#""settings.shortcuts.demos""#))
        XCTAssertTrue(settingsView.contains(#""settings.shortcuts.demo.\(recipe.id)""#))
        XCTAssertTrue(settingsView.contains(#""settings.shortcuts.demo.\(recipe.id).input""#))
        XCTAssertTrue(settingsView.contains(#""settings.shortcuts.demo.\(recipe.id).output""#))
    }

    func testSettingsViewDefinesLocalModelSectionAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let settingsView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/SettingsView.swift"), encoding: .utf8)

        XCTAssertTrue(settingsView.contains("Local Models"))
        XCTAssertTrue(settingsView.contains(#""settings.models.local""#))
        XCTAssertTrue(settingsView.contains("Route Preference"))
        XCTAssertTrue(settingsView.contains(#""settings.models.preference""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.preference.\(preference.rawValue)""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).status""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).download""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).select""#))
        XCTAssertTrue(settingsView.contains(#""settings.models.\(row.modelID).delete""#))
    }

    func testPermissionHubDefinesHomeKitDemoAccessibilityIdentifiers() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let permissionHubView = try String(contentsOf: root.appendingPathComponent("Kairo/Views/PermissionHubView.swift"), encoding: .utf8)

        XCTAssertTrue(permissionHubView.contains("Skill Manager"))
        XCTAssertTrue(permissionHubView.contains(#""access.skills.manager""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id)""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).manage""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).install""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).disable""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).enable""#))
        XCTAssertTrue(permissionHubView.contains(#""access.skill.\(skill.id).remove""#))
        XCTAssertTrue(permissionHubView.contains("HomeKit Control Demos"))
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
        XCTAssertTrue(environmentSource.contains("FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)"))
        XCTAssertTrue(environmentSource.contains("AgentSkillManagerService("))
        XCTAssertTrue(environmentSource.contains("store: agentSkillStore"))
        XCTAssertTrue(rootViewSource.contains("PermissionHubView(skillManagerService: environment.agentSkillManagerService)"))
        XCTAssertTrue(permissionHubSource.contains("private let skillManagerService: AgentSkillManagerService?"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.catalog()"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.disableSkill(id: skill.id)"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.enableSkill(id: skill.id)"))
        XCTAssertTrue(permissionHubSource.contains("try await skillManagerService.removeSkill(id: skill.id)"))
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
            "launch-tabs",
            "chat-send",
            "settings-api-key-status",
            "access-homekit-demos"
        ])
        XCTAssertTrue(catalog.scenario(id: "launch-tabs")?.requiredAccessibilityIdentifiers.contains("root.tab.chat") == true)
        XCTAssertTrue(catalog.scenario(id: "chat-send")?.requiredAccessibilityIdentifiers.contains("chat.composer.text") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.openai.api-key-status") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.oauth.connectors") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.shortcuts.demos") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.models.local") == true)
        XCTAssertTrue(catalog.scenario(id: "settings-api-key-status")?.requiredAccessibilityIdentifiers.contains("settings.models.preference") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.skills.manager") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demos") == true)
        XCTAssertTrue(catalog.scenario(id: "access-homekit-demos")?.requiredAccessibilityIdentifiers.contains("access.homekit.demo.evening-scene") == true)
    }

    func testXcodeProjectDefinesKairoUITestTargetAndSmokeTestFile() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let projectYAML = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let smokeTestURL = root.appendingPathComponent("KairoUITests/KairoAppSmokeUITests.swift")
        let smokeTest = try String(contentsOf: smokeTestURL, encoding: .utf8)

        XCTAssertTrue(projectYAML.contains("KairoUITests:"))
        XCTAssertTrue(projectYAML.contains("type: bundle.ui-testing"))
        XCTAssertTrue(projectYAML.contains("target: KairoApp"))
        XCTAssertTrue(smokeTest.contains("KairoAppSmokeUITests"))
        XCTAssertTrue(smokeTest.contains("chat.composer.text"))
        XCTAssertTrue(smokeTest.contains("settings.openai.api-key-status"))
        XCTAssertTrue(smokeTest.contains("settings.oauth.connectors"))
        XCTAssertTrue(smokeTest.contains("settings.shortcuts.demos"))
        XCTAssertTrue(smokeTest.contains("settings.models.local"))
        XCTAssertTrue(smokeTest.contains("settings.models.preference"))
        XCTAssertTrue(smokeTest.contains("access.skills.manager"))
        XCTAssertTrue(smokeTest.contains("access.homekit.demos"))
    }

    func testLocalModelCatalogFiltersDeprecatedAndOldSafetyPolicyModels() throws {
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "available", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "old-policy", safetyPolicyVersion: "2025.9"),
                makeLocalModelManifest(id: "deprecated", safetyPolicyVersion: "2026.2", deprecated: true)
            ]
        )

        let encoded = try catalog.encoded()
        let decoded = try LocalModelCatalog.decode(encoded)
        let available = decoded.availableModels(minimumSafetyPolicyVersion: "2026.1")

        XCTAssertEqual(available.map(\.id), ["available"])
    }

    func testDefaultLocalModelCatalogExposesDraftModelForSettings() {
        let catalog = LocalModelCatalog.kairoDefault
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)

        XCTAssertEqual(availableModels.map(\.id), ["kairo-draft-tiny"])
        XCTAssertEqual(availableModels.first?.displayName, "Kairo Draft Local")
        XCTAssertTrue(availableModels.first?.capabilities.contains(.offlineChat) == true)
        XCTAssertTrue(availableModels.first?.disallowedCapabilities.contains(.webCurrentInfo) == true)
    }

    func testFileBackedLocalModelInstallRegistryPersistsInstalledRecords() async throws {
        let fileURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = fileURL.deletingLastPathComponent().appendingPathComponent("model.gguf")
        let record = LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        )

        let firstRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        try await firstRegistry.upsert(record)

        let secondRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        let persisted = await secondRegistry.record(for: "qwen-small")
        let installedRecords = await secondRegistry.installedRecords()

        XCTAssertEqual(persisted?.modelID, record.modelID)
        XCTAssertEqual(persisted?.version, record.version)
        XCTAssertEqual(persisted?.status, .installed)
        XCTAssertEqual(persisted?.fileURL, record.fileURL)
        XCTAssertEqual(persisted?.installedSizeBytes, record.installedSizeBytes)
        XCTAssertEqual(persisted?.sha256, record.sha256)
        XCTAssertEqual(installedRecords.map(\.modelID), [record.modelID])
    }

    func testFileBackedLocalModelSettingsStorePersistsSelectedModelAndPreference() async throws {
        let fileURL = temporaryFileURL(named: "local-model-settings.json")
        let firstStore = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let initialSettings = await firstStore.settings()
        XCTAssertNil(initialSettings.selectedModelID)
        XCTAssertEqual(initialSettings.preference, .automatic)

        try await firstStore.save(LocalModelSettings(
            selectedModelID: "qwen-small",
            preference: .preferLocal
        ))

        let secondStore = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let persisted = await secondStore.settings()
        XCTAssertEqual(persisted.selectedModelID, "qwen-small")
        XCTAssertEqual(persisted.preference, .preferLocal)
    }

    func testProviderRoutePreferenceBuildsSettingsCopyAndOrdering() {
        XCTAssertEqual(ProviderRoutePreference.settingsChoices, [
            .automatic,
            .preferLocal,
            .preferCloud,
            .localOnly
        ])
        XCTAssertEqual(ProviderRoutePreference.automatic.settingsTitle, "Automatic")
        XCTAssertEqual(ProviderRoutePreference.preferLocal.settingsTitle, "Prefer Local")
        XCTAssertEqual(ProviderRoutePreference.preferCloud.settingsTitle, "Prefer Cloud")
        XCTAssertEqual(ProviderRoutePreference.localOnly.settingsTitle, "Local Only")
        XCTAssertTrue(ProviderRoutePreference.localOnly.settingsDetailText.contains("Never routes"))
        XCTAssertTrue(ProviderRoutePreference.preferLocal.settingsDetailText.contains("eligible"))
    }

    func testLocalModelSettingsServiceSelectsInstalledModelAndBuildsRoutingContext() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-small.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "old-policy", safetyPolicyVersion: "2025.9")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        try await service.setPreference(.preferLocal)
        try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertEqual(status.selectedModelID, "qwen-small")
        XCTAssertEqual(status.selectedModel?.id, "qwen-small")
        XCTAssertEqual(status.installedRecord?.fileURL, modelURL)
        XCTAssertEqual(status.installedModels.map(\.modelID), ["qwen-small"])
        XCTAssertEqual(status.availableModels.map(\.id), ["qwen-small"])

        let context = await service.routingContext(
            taskClass: .summarization,
            networkAvailable: false,
            minimumSafetyPolicyVersion: "2026.1"
        )
        XCTAssertEqual(context.preference, .preferLocal)
        XCTAssertFalse(context.networkAvailable)
        XCTAssertEqual(context.taskClass, .summarization)
        XCTAssertTrue(context.localModelInstalled)
        XCTAssertEqual(context.localContextWindow, 2048)
    }

    func testLocalModelSettingsServiceDeletesInstalledModelFileRecordAndSelection() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-small.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
            ]
        )
        try FileManager.default.createDirectory(at: modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("model-bytes".utf8).write(to: modelURL)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)
        try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")

        try await service.deleteModel(id: "qwen-small")

        XCTAssertFalse(FileManager.default.fileExists(atPath: modelURL.path))
        let deletedRecord = await registry.record(for: "qwen-small")
        XCTAssertNil(deletedRecord)
        let settings = await store.settings()
        XCTAssertNil(settings.selectedModelID)
        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.localModelInstalled)
    }

    func testLocalModelSettingsServiceRejectsUninstalledOrUnavailableSelections() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "deprecated", safetyPolicyVersion: "2026.2", deprecated: true)
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        do {
            try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")
            XCTFail("Expected uninstalled model selection to fail")
        } catch let error as LocalModelSelectionError {
            XCTAssertEqual(error, .modelNotInstalled("qwen-small"))
        }

        do {
            try await service.selectModel(id: "deprecated", minimumSafetyPolicyVersion: "2026.1")
            XCTFail("Expected unavailable model selection to fail")
        } catch let error as LocalModelSelectionError {
            XCTAssertEqual(error, .modelUnavailable("deprecated"))
        }

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.localModelInstalled)
    }

    func testLocalModelSettingsStatusBuildsSettingsRowsForDownloadSelectAndSelected() throws {
        let selectedManifest = makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
        let downloadableManifest = makeLocalModelManifest(id: "llama-draft", safetyPolicyVersion: "2026.2")
        let installedRecord = LocalModelInstallRecord(
            modelID: selectedManifest.id,
            version: selectedManifest.version,
            status: .installed,
            fileURL: URL(fileURLWithPath: "/tmp/qwen-small.gguf"),
            installedSizeBytes: selectedManifest.installedSizeBytes,
            sha256: selectedManifest.sha256
        )
        let status = LocalModelSettingsStatus(
            selectedModelID: selectedManifest.id,
            selectedModel: selectedManifest,
            installedRecord: installedRecord,
            preference: .preferLocal,
            availableModels: [selectedManifest, downloadableManifest],
            installedModels: [installedRecord]
        )

        let rows = status.settingsRows
        let selectedRow = try XCTUnwrap(rows.first { $0.modelID == selectedManifest.id })
        let downloadableRow = try XCTUnwrap(rows.first { $0.modelID == downloadableManifest.id })

        XCTAssertEqual(rows.map(\.modelID), [downloadableManifest.id, selectedManifest.id])
        XCTAssertEqual(selectedRow.statusText, "已選用")
        XCTAssertEqual(selectedRow.primaryAction, .selected)
        XCTAssertEqual(downloadableRow.statusText, "可下載")
        XCTAssertEqual(downloadableRow.primaryAction, .download)
        XCTAssertTrue(selectedRow.canDelete)
        XCTAssertFalse(downloadableRow.canDelete)
        XCTAssertTrue(selectedRow.detailText.contains("0.8B"))
        XCTAssertTrue(selectedRow.detailText.contains("Q4"))
        XCTAssertTrue(selectedRow.detailText.contains("2K context"))
    }

    func testVerifiedLocalModelDownloaderInstallsModelAndUpdatesRegistry() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let httpClient = MockHTTPClient(statusCode: 200, body: "model-bytes")
        let downloader = VerifiedLocalModelDownloader(
            httpClient: httpClient,
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let installedURL = try await downloader.download(manifest, progress: nil)

        XCTAssertEqual(installedURL.lastPathComponent, "qwen-small-1.0.gguf")
        XCTAssertEqual(try String(contentsOf: installedURL, encoding: .utf8), "model-bytes")
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.url, manifest.downloadURL)
        let record = await registry.record(for: manifest.id)
        XCTAssertEqual(record?.status, .installed)
        XCTAssertEqual(record?.fileURL, installedURL)
        XCTAssertEqual(record?.installedSizeBytes, Int64("model-bytes".utf8.count))
        XCTAssertEqual(record?.sha256, manifest.sha256)
        XCTAssertNotNil(record?.lastVerifiedAt)
    }

    func testVerifiedLocalModelDownloaderFailsClosedWhenChecksumDoesNotMatch() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: MockHTTPClient(statusCode: 200, body: "wrong-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        do {
            _ = try await downloader.download(manifest, progress: nil)
            XCTFail("Expected checksum mismatch")
        } catch let error as LocalModelDownloadError {
            XCTAssertEqual(
                error,
                .checksumMismatch(
                    expected: manifest.sha256,
                    actual: "7c1d387f892b3c965dfc1951e2a92a2149cd103cef25c8ba5d0cc30a3a21063f"
                )
            )
        }

        let record = await registry.record(for: manifest.id)
        XCTAssertEqual(record?.status, .failed)
        XCTAssertTrue(record?.failureReason?.contains("Checksum mismatch") == true)
        XCTAssertTrue((try? FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil))?.isEmpty ?? true)
    }

    func testLocalFallbackProviderReturnsPlaceholderWithoutActions() async throws {
        let provider = LocalFallbackProvider(installedModelID: "qwen-small")

        let response = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "Draft a note"))

        XCTAssertTrue(response.message.contains("Local fallback (qwen-small)"))
        XCTAssertTrue(response.message.contains("cannot browse the web"))
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testProviderRouterUsesInstalledLocalModelForOfflineEligiblePrompt() async throws {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "Summarize this note")
        let context = ProviderRoutingContext(
            networkAvailable: false,
            taskClass: .summarization,
            localModelInstalled: true
        )

        let decision = router.decision(for: request, context: context)
        let response = try await router.complete(request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .local, reason: .cloudUnavailable))
        XCTAssertTrue(response.message.contains("Local fallback"))
    }

    func testProviderRouterBlocksLocalForToolUseInOfflineMode() async throws {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "Create a calendar event")
        let context = ProviderRoutingContext(
            networkAvailable: false,
            offlineModeEnabled: true,
            taskClass: .toolUse,
            requiresToolUse: true,
            localModelInstalled: true
        )

        let decision = router.decision(for: request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .unavailable, reason: .toolRequired))
        do {
            _ = try await router.complete(request, context: context)
            XCTFail("Expected unsupported route")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .unsupported)
        }
    }

    func testProviderRouterRoutesCurrentInfoToCloudWhenAvailable() {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "What happened today?")
        let context = ProviderRoutingContext(
            networkAvailable: true,
            taskClass: .webCurrentInfo,
            requiresCurrentInfo: true,
            localModelInstalled: true
        )

        let decision = router.decision(for: request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .cloud, reason: .localIncapable))
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
            XCTAssertEqual(error, .requestFailed("OpenAI request failed with status 429 type=rate_limit_error."))
        }
    }

    func testChatGPTOAuthServiceBuildsPKCEAuthorizationURL() async throws {
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid", "profile"],
                audience: "chatgpt"
            ),
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/callback")
        XCTAssertEqual(query["scope"], "openid profile")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
        XCTAssertEqual(query["audience"], "chatgpt")
    }

    func testOAuthConnectorAuthorizationServiceBuildsPKCEAuthorizationURLFromRegistryMetadata() async throws {
        let google = try XCTUnwrap(IntegrationRegistry().integration(for: "gmail-google-workspace")?.oauth)
        let service = OAuthConnectorAuthorizationService(
            metadata: google,
            clientID: "ios-client-id",
            redirectURI: "kairo://oauth/google/callback",
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(session.providerKey, "google")
        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "ios-client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/google/callback")
        XCTAssertEqual(query["scope"], "openid email profile https://www.googleapis.com/auth/gmail.readonly")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
    }

    func testOAuthConnectorLoginCenterReportsStatusesForRegistryConnectors() async throws {
        let registry = IntegrationRegistry()
        let github = try XCTUnwrap(registry.integration(for: "github")?.oauth)
        let credentials = InMemoryCredentialStore()
        let githubAuth = OAuthConnectorAuthorizationService(
            metadata: github,
            clientID: "github-client",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials
        )
        try await githubAuth.storeTokens(OAuthTokenSet(accessToken: "github-token", scopes: ["repo"]))

        let center = OAuthConnectorLoginCenter(
            registry: registry,
            credentialStore: credentials,
            clientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        )

        let options = try await center.loginOptions()
        let google = try XCTUnwrap(options.first { $0.providerKey == "google" })
        let microsoft = try XCTUnwrap(options.first { $0.providerKey == "microsoft" })
        let connectedGitHub = try XCTUnwrap(options.first { $0.providerKey == "github" })

        XCTAssertEqual(options.map(\.providerKey), ["google", "microsoft", "notion", "slack", "chatgpt", "github"])
        XCTAssertEqual(google.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(google.readiness, .readyToAuthorize)
        XCTAssertEqual(microsoft.readiness, .needsClientConfiguration)
        XCTAssertEqual(connectedGitHub.readiness, .connected)
        XCTAssertEqual(connectedGitHub.grantedScopes, ["repo"])
        XCTAssertTrue(connectedGitHub.requiresBackendTokenExchange)
    }

    func testOAuthConnectorLoginCenterBuildsAuthorizationSessionFromClientConfiguration() async throws {
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: InMemoryCredentialStore(),
            clientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback",
                    scopes: ["openid", "email"]
                )
            ]
        )

        let session = try await center.makeAuthorizationSession(
            for: "gmail-google-workspace",
            state: "state-123",
            codeVerifier: "verifier-123"
        )
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(session.providerKey, "google")
        XCTAssertEqual(query["client_id"], "google-client")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/google/callback")
        XCTAssertEqual(query["scope"], "openid email")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
    }

    func testOAuthConnectorAuthorizationServiceHandlesNonPKCEConnectorsAndStoresNamespacedTokens() async throws {
        let github = try XCTUnwrap(IntegrationRegistry().integration(for: "github")?.oauth)
        let credentials = InMemoryCredentialStore()
        let service = OAuthConnectorAuthorizationService(
            metadata: github,
            clientID: "github-client-id",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials
        )

        let session = try await service.makeAuthorizationSession(state: "github-state", codeVerifier: "ignored-verifier")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let queryNames = Set((components.queryItems ?? []).map(\.name))

        XCTAssertEqual(session.providerKey, "github")
        XCTAssertFalse(queryNames.contains("code_challenge"))
        XCTAssertFalse(queryNames.contains("code_challenge_method"))
        let authorizationCode = try await service.validateCallback(
            URL(string: "kairo://oauth/github/callback?code=abc&state=github-state")!,
            expectedState: "github-state"
        )
        XCTAssertEqual(authorizationCode, "abc")

        let tokens = OAuthTokenSet(accessToken: "github-access", refreshToken: "github-refresh", scopes: ["repo"])
        try await service.storeTokens(tokens)
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "github"))
        let loaded = try await service.loadTokens()

        XCTAssertNotNil(storedRaw)
        XCTAssertEqual(loaded, tokens)

        try await service.signOut()
        let tokensAfterSignOut = try await service.loadTokens()
        XCTAssertNil(tokensAfterSignOut)
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
        XCTAssertEqual(item.suggestedPrompt, "Review this shared content: Deck.pdf")
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
        XCTAssertTrue(result.message.contains("UI opener"))
    }

    func testChatGPTOAuthServiceValidatesCallbackAndStoresTokens() async throws {
        let credentials = InMemoryCredentialStore()
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid"]
            ),
            credentialStore: credentials
        )

        let code = try await service.validateCallback(URL(string: "kairo://oauth/callback?code=abc&state=expected")!, expectedState: "expected")
        XCTAssertEqual(code, "abc")

        try await service.storeTokens(OAuthTokenSet(accessToken: "access", refreshToken: "refresh", scopes: ["openid"]))
        let tokens = try await service.loadTokens()
        XCTAssertEqual(tokens?.accessToken, "access")
        XCTAssertEqual(tokens?.refreshToken, "refresh")

        try await service.signOut()
        let signedOutTokens = try await service.loadTokens()
        XCTAssertNil(signedOutTokens)
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
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

private actor MockURLOpener: URLOpener {
    private(set) var openedURLs: [URL] = []
    private let result: Bool

    init(result: Bool = true) {
        self.result = result
    }

    func open(_ url: URL) async -> Bool {
        openedURLs.append(url)
        return result
    }
}

private actor MockNotificationScheduler: NotificationScheduling {
    private(set) var scheduledDrafts: [NotificationDraft] = []
    private let granted: Bool

    init(granted: Bool) {
        self.granted = granted
    }

    func requestAuthorization() async throws -> Bool {
        granted
    }

    func schedule(_ draft: NotificationDraft) async throws -> String {
        scheduledDrafts.append(draft)
        return "notification-id"
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
