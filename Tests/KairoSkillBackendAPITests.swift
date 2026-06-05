import XCTest
@testable import KairoCore

final class KairoSkillBackendAPITests: XCTestCase {
    func testSkillBackendAPIForwardsLifecycleThroughSkillManager() async throws {
        let service = try await makeBackendTestAgentSkillManagerService()
        let api = KairoSkillBackendService(agentSkillManagerService: service)
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")
        let manifestJSON = try encodeBackendTestManifestJSON(manifest)

        let preview = try await api.previewInstall(jsonString: manifestJSON)
        XCTAssertEqual(preview.skillID, "marketplace-weather-briefing")
        XCTAssertEqual(preview.installationChange, AgentSkillInstallationChange.install)
        XCTAssertTrue(preview.compatibilityReport.isInstallable)

        let installed = try await api.installManifest(jsonString: manifestJSON)
        XCTAssertEqual(installed.installationStatus, AgentSkillInstallationStatus.installed)
        var catalog = try await api.catalog()
        XCTAssertTrue(catalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        let disabled = try await api.disableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(disabled?.installationStatus, AgentSkillInstallationStatus.disabled)
        var effectiveCatalog = try await api.effectiveCatalog()
        XCTAssertFalse(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        let enabled = try await api.enableSkill(id: "marketplace-weather-briefing")
        XCTAssertEqual(enabled?.installationStatus, AgentSkillInstallationStatus.installed)
        effectiveCatalog = try await api.effectiveCatalog()
        XCTAssertTrue(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-weather-briefing"))

        try await api.removeSkill(id: "marketplace-weather-briefing")
        catalog = try await api.catalog()
        XCTAssertNil(catalog.skill(id: "marketplace-weather-briefing"))
    }

    func testSkillBackendAPIRequiresExplicitUserDraftCapabilityAndConfirmationPolicy() async throws {
        let service = try await makeBackendTestAgentSkillManagerService()
        let api = KairoSkillBackendService(agentSkillManagerService: service)

        let draft = try await api.createUserSkillDraft(AgentSkillDraftRequest(
            displayName: "Kairo Inbox Triage",
            summary: "Drafts a visible inbox triage plan from approved OAuth connector data.",
            kind: .custom,
            requiredCapabilities: [.externalConnectors],
            confirmationPolicy: .previewRequired,
            compatibilityRequirements: AgentSkillCompatibilityRequirements(requiredOAuthProviderKeys: ["google"])
        ))

        XCTAssertEqual(draft.id, "user-kairo-inbox-triage")
        XCTAssertEqual(draft.source, .userCreated)
        XCTAssertEqual(draft.installationStatus, .disabled)
        XCTAssertEqual(draft.requiredCapabilities, [.externalConnectors])
        XCTAssertEqual(draft.confirmationPolicy, .previewRequired)

        do {
            _ = try await api.createUserSkillDraft(AgentSkillDraftRequest(
                displayName: "Missing Capability",
                summary: "Should fail closed.",
                kind: .custom,
                requiredCapabilities: [],
                confirmationPolicy: .previewRequired
            ))
            XCTFail("Expected skill draft without explicit capabilities to fail closed.")
        } catch {
            XCTAssertEqual(error as? AgentSkillDraftError, .missingCapabilitySelection)
        }

        do {
            _ = try await api.createUserSkillDraft(AgentSkillDraftRequest(
                displayName: "Missing Confirmation",
                summary: "Should fail closed.",
                kind: .custom,
                requiredCapabilities: [.appIntents],
                confirmationPolicy: nil
            ))
            XCTFail("Expected skill draft without confirmation policy to fail closed.")
        } catch {
            XCTAssertEqual(error as? AgentSkillDraftError, .missingConfirmationPolicy)
        }
    }

    func testSkillBackendAPIBlocksIncompatibleMarketplaceSkillsFromExecutableCatalog() async throws {
        let service = try await makeBackendTestAgentSkillManagerService(runtimeContext: AgentSkillRuntimeContext(
            iosVersion: "17.0",
            grantedEntitlements: [],
            connectedOAuthProviderKeys: [],
            installedLocalModelIDs: []
        ))
        let api = KairoSkillBackendService(agentSkillManagerService: service)
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires both a connected OAuth provider and a local model.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/qwen-oauth-workflow.json")!,
            kind: .localModel
        )
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")
        let manifestJSON = try encodeBackendTestManifestJSON(manifest)

        let preview = try await api.previewInstall(jsonString: manifestJSON)
        XCTAssertFalse(preview.compatibilityReport.isInstallable)
        let blockingKinds = preview.compatibilityReport.blockingIssues.map { issue in issue.kind }
        XCTAssertEqual(blockingKinds, [.missingOAuthProvider, .missingLocalModel])

        do {
            _ = try await api.installManifest(jsonString: manifestJSON)
            XCTFail("Expected compatibility-blocked skill install to fail closed.")
        } catch let error as AgentSkillInstallError {
            guard case .compatibilityBlocked(let skillID, _) = error else {
                return XCTFail("Expected compatibilityBlocked, got \(error)")
            }
            XCTAssertEqual(skillID, "marketplace-qwen-oauth-workflow")
        }

        let effectiveCatalog = try await api.effectiveCatalog()
        XCTAssertFalse(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-qwen-oauth-workflow"))
    }

    func testLiveAccessFactoryBuildsSkillManagerWithOAuthAndLocalModelRuntimeContext() async throws {
        let rootDirectory = temporaryDirectory(named: "KairoLiveAccessFactory")
        let paths = KairoPaths(
            appName: "KairoLiveAccessFactoryTests",
            appGroupIdentifier: "group.kairo.tests"
        ) { _ in rootDirectory }
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret(
            OAuthTokenSet(accessToken: "google-token", scopes: ["profile"]).encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "google")
        )
        let store = try await FileBackedAgentSkillStore(fileURL: paths.agentSkillStoreURL)
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires both a connected OAuth provider and a local model.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/qwen-oauth-workflow.json")!,
            kind: .localModel
        )
        skill.installationStatus = .installed
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        try await store.upsert(skill)

        let components = try await KairoLiveAccessFactory(
            paths: paths,
            credentialStore: credentials,
            installedLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"],
            oauthClientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        ).makeComponents()
        let callbackPreview = OAuthConnectorCallbackPreview(
            providerKey: "google",
            integrationKey: "google-calendar",
            state: "state",
            authorizationCodeLength: 12,
            requiresBackendTokenExchange: false
        )
        try await components.oauthCallbackStore.save(callbackPreview)
        let effectiveCatalog = try await components.skillManagerService.effectiveCatalog()
        let storedPreview = await components.oauthCallbackStore.latestPreview(for: "google")

        XCTAssertTrue(effectiveCatalog.installedSkills.map(\.id).contains("marketplace-qwen-oauth-workflow"))
        XCTAssertEqual(components.oauthClientConfigurations["google"]?.clientID, "google-client")
        XCTAssertEqual(storedPreview?.integrationKey, "google-calendar")
    }

    func testLiveEnvironmentComposerBuildsUsableBackendEnvironment() async throws {
        let rootDirectory = temporaryDirectory(named: "KairoLiveEnvironmentComposer")
        let paths = KairoPaths(
            appName: "KairoLiveEnvironmentComposerTests",
            appGroupIdentifier: "group.kairo.tests"
        ) { _ in rootDirectory }
        let environment = try await KairoLiveEnvironmentComposer(
            paths: paths,
            credentialStore: InMemoryCredentialStore()
        ).makeEnvironment()
        let memory = MemoryRecord(
            title: "Composer memory",
            summary: "Composer can persist through the composed environment.",
            content: "The live composer wires file stores and the action executor together.",
            source: .manual
        )

        try await environment.memoryStore.save(memory)
        let storedMemories = try await environment.memoryStore.search(query: "composer", limit: 10)
        let result = try await environment.actionExecutor.execute(AgentAction(
            kind: .saveMemory,
            title: "Save via action executor",
            rationale: "Exercise the composed action boundary.",
            payload: .text("Action executor writes through the composed memory store."),
            riskTier: .tier0ReadOnly
        ), confirmed: false)
        let auditEvents = try await environment.auditLogger.list(limit: 10)

        XCTAssertEqual(storedMemories.map(\.id), [memory.id])
        XCTAssertTrue(result.completed)
        XCTAssertEqual(auditEvents.map(\.actionKind), [.saveMemory])
    }

    func testSkillBackendAPIFailsClosedWhenServiceIsUnavailable() async throws {
        let api = KairoSkillBackendService(agentSkillManagerService: nil)

        do {
            _ = try await api.catalog()
            XCTFail("Expected skill API catalog to fail closed without a configured service.")
        } catch let error as KairoSkillAPIError {
            XCTAssertEqual(error, .unavailable)
        }

        do {
            try await api.removeSkill(id: "marketplace-weather-briefing")
            XCTFail("Expected skill API remove to fail closed without a configured service.")
        } catch let error as KairoSkillAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }
}
