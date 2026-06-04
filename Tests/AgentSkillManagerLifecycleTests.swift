import XCTest
import CryptoKit
@testable import KairoCore

final class AgentSkillManagerLifecycleTests: XCTestCase {
    func testAgentSkillCompatibilityEvaluatorReportsMissingRuntimeRequirements() {
        let skill = AgentSkill(
            id: "marketplace-local-oauth-homekit",
            displayName: "Local OAuth HomeKit Skill",
            summary: "Requires a newer device context, HomeKit, OAuth, and a downloaded local model.",
            kind: .custom,
            source: .marketplace,
            installationStatus: .available,
            requiredCapabilities: [.homeKit, .externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/local-oauth-homekit.json")!,
            compatibilityRequirements: AgentSkillCompatibilityRequirements(
                minimumIOSVersion: "18.0",
                requiredEntitlements: ["com.apple.developer.homekit"],
                requiredOAuthProviderKeys: ["google"],
                requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
            )
        )
        let context = AgentSkillRuntimeContext(
            iosVersion: "17.0",
            grantedEntitlements: [],
            connectedOAuthProviderKeys: [],
            installedLocalModelIDs: []
        )

        let report = AgentSkillCompatibilityEvaluator(context: context).evaluate(skill)

        XCTAssertFalse(report.isInstallable)
        XCTAssertEqual(report.blockingIssues.map(\.kind), [
            .minimumIOSVersion,
            .missingEntitlement,
            .missingOAuthProvider,
            .missingLocalModel
        ])
        XCTAssertTrue(report.summary.contains("Requires iOS 18.0 or later"))
        XCTAssertTrue(report.summary.contains("Missing entitlement com.apple.developer.homekit"))
        XCTAssertTrue(report.summary.contains("Connect OAuth provider google"))
        XCTAssertTrue(report.summary.contains("Download local model qwen3-5-0-8b-q4-k-m"))
    }

    func testAgentSkillManagerBlocksInstallWhenCompatibilityRequirementsAreMissing() async throws {
        let storeURL = temporaryFileURL(named: "compatibility-blocked-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = trustStore(for: signingKey)
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-qwen-oauth-workflow",
            displayName: "Qwen OAuth Workflow",
            summary: "Requires Google OAuth and a downloaded Qwen model before install.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/qwen-oauth-workflow.json")!
        )
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            requiredOAuthProviderKeys: ["google"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.0",
                grantedEntitlements: [],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: []
            )
        )

        let preview = try await service.previewInstall(manifest: manifest)
        XCTAssertEqual(preview.compatibilityReport.blockingIssues.map(\.kind), [
            .missingOAuthProvider,
            .missingLocalModel
        ])
        XCTAssertTrue(preview.summary.contains("Blocked"))

        await XCTAssertThrowsErrorAsync(try await service.install(manifest: manifest)) { error in
            guard case AgentSkillInstallError.compatibilityBlocked(let skillID, let issues) = error else {
                return XCTFail("Expected compatibilityBlocked, got \(error)")
            }
            XCTAssertEqual(skillID, "marketplace-qwen-oauth-workflow")
            XCTAssertEqual(issues.map(\.kind), [.missingOAuthProvider, .missingLocalModel])
        }
    }

    func testAgentSkillManagerInstallsWhenCompatibilityRequirementsAreSatisfied() async throws {
        let storeURL = temporaryFileURL(named: "compatibility-allowed-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let trustStore = trustStore(for: signingKey)
        var skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-homekit-qwen",
            displayName: "HomeKit Qwen Skill",
            summary: "Requires HomeKit entitlement and a downloaded Qwen model.",
            requiredCapabilities: [.homeKit],
            downloadURL: URL(string: "https://skills.kairo.app/homekit-qwen.json")!,
            kind: .homeKitControl
        )
        skill.compatibilityRequirements = AgentSkillCompatibilityRequirements(
            minimumIOSVersion: "17.0",
            requiredEntitlements: ["com.apple.developer.homekit"],
            requiredLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
        )
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore,
            runtimeContext: AgentSkillRuntimeContext(
                iosVersion: "17.2",
                grantedEntitlements: ["com.apple.developer.homekit"],
                connectedOAuthProviderKeys: [],
                installedLocalModelIDs: ["qwen3-5-0-8b-q4-k-m"]
            )
        )

        let preview = try await service.previewInstall(manifest: manifest)
        XCTAssertTrue(preview.compatibilityReport.isInstallable)
        XCTAssertTrue(preview.compatibilityReport.blockingIssues.isEmpty)

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.id, "marketplace-homekit-qwen")
        XCTAssertEqual(installed.installationStatus, .installed)
    }

    func testAgentSkillManagerCreatesDisabledUserSkillDraftsWithStableIDs() async throws {
        let storeURL = temporaryFileURL(named: "user-created-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        let draft = try await service.createUserSkillDraft(AgentSkillDraftRequest(
            displayName: "Kairo Inbox Triage",
            summary: "Drafts a visible inbox triage plan from approved OAuth connector data.",
            kind: .custom,
            requiredCapabilities: [.externalConnectors],
            confirmationPolicy: .previewRequired,
            compatibilityRequirements: AgentSkillCompatibilityRequirements(
                requiredOAuthProviderKeys: ["google"]
            )
        ))

        XCTAssertEqual(draft.id, "user-kairo-inbox-triage")
        XCTAssertEqual(draft.source, .userCreated)
        XCTAssertEqual(draft.installationStatus, .disabled)
        XCTAssertEqual(draft.requiredCapabilities, [.externalConnectors])
        XCTAssertEqual(draft.confirmationPolicy, .previewRequired)
        XCTAssertEqual(draft.compatibilityRequirements.requiredOAuthProviderKeys, ["google"])

        let catalog = try await service.catalog()
        XCTAssertEqual(catalog.skill(id: "user-kairo-inbox-triage"), draft)

        let reloadedStore = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let reloadedService = AgentSkillManagerService(store: reloadedStore, builtInCatalog: .default)
        let reloadedCatalog = try await reloadedService.catalog()

        XCTAssertEqual(reloadedCatalog.skill(id: "user-kairo-inbox-triage")?.source, .userCreated)
        XCTAssertEqual(reloadedCatalog.skill(id: "user-kairo-inbox-triage")?.installationStatus, .disabled)
    }

    func testAgentSkillManagerCreatesUniqueUserSkillDraftIDsForDuplicateNames() async throws {
        let storeURL = temporaryFileURL(named: "duplicate-user-created-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)
        let request = AgentSkillDraftRequest(
            displayName: "Daily Skill",
            summary: "A user-created local skill draft.",
            kind: .custom,
            requiredCapabilities: [.appIntents],
            confirmationPolicy: .previewRequired
        )

        let first = try await service.createUserSkillDraft(request)
        let second = try await service.createUserSkillDraft(request)

        XCTAssertEqual(first.id, "user-daily-skill")
        XCTAssertEqual(second.id, "user-daily-skill-2")
        let catalog = try await service.catalog()
        XCTAssertEqual(catalog.disabledSkills.filter { $0.source == .userCreated }.map(\.id), [
            "user-daily-skill",
            "user-daily-skill-2"
        ])
    }

    func testAgentSkillManagerRequiresUserDraftCapabilitySelection() async throws {
        let storeURL = temporaryFileURL(named: "missing-user-skill-capabilities.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        let request = AgentSkillDraftRequest(
            displayName: "Unsafe Empty Capability Skill",
            summary: "Should not be saved without explicit capability selection.",
            kind: .custom,
            requiredCapabilities: [],
            confirmationPolicy: .previewRequired
        )

        do {
            _ = try await service.createUserSkillDraft(request)
            XCTFail("Expected user-created skill draft without capabilities to be rejected.")
        } catch {
            XCTAssertEqual(error as? AgentSkillDraftError, .missingCapabilitySelection)
        }

        let catalog = try await service.catalog()
        XCTAssertFalse(catalog.skills.contains { $0.displayName == "Unsafe Empty Capability Skill" })
    }

    func testAgentSkillManagerRequiresUserDraftConfirmationPolicy() async throws {
        let storeURL = temporaryFileURL(named: "missing-user-skill-confirmation-policy.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        let request = AgentSkillDraftRequest(
            displayName: "Missing Confirmation Policy Skill",
            summary: "Should not be saved without explicit confirmation policy.",
            kind: .custom,
            requiredCapabilities: [.appIntents],
            confirmationPolicy: nil
        )

        do {
            _ = try await service.createUserSkillDraft(request)
            XCTFail("Expected user-created skill draft without confirmation policy to be rejected.")
        } catch {
            XCTAssertEqual(error as? AgentSkillDraftError, .missingConfirmationPolicy)
        }

        let catalog = try await service.catalog()
        XCTAssertFalse(catalog.skills.contains { $0.displayName == "Missing Confirmation Policy Skill" })
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

    func testFileBackedAgentSkillManagerPersistsBuiltInShortcutSkillStatus() async throws {
        let storeURL = temporaryFileURL(named: "built-in-shortcut-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        let disabled = try await service.disableSkill(id: "shortcut-save-shared-text")
        XCTAssertEqual(disabled?.source, .builtIn)
        XCTAssertEqual(disabled?.shortcutRecipeID, "save-shared-text")
        XCTAssertEqual(disabled?.installationStatus, .disabled)

        let reloadedStore = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let reloadedService = AgentSkillManagerService(store: reloadedStore, builtInCatalog: .default)
        let reloadedCatalog = try await reloadedService.catalog()

        XCTAssertEqual(reloadedCatalog.skill(id: "shortcut-save-shared-text")?.installationStatus, .disabled)
        XCTAssertFalse(reloadedCatalog.installedSkills.map(\.id).contains("shortcut-save-shared-text"))
        XCTAssertTrue(reloadedCatalog.installedSkills.map(\.id).contains("shortcut-screenshot-to-reminders"))
    }

    private func trustStore(for signingKey: P256.Signing.PrivateKey) -> AgentSkillManifestTrustStore {
        AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
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
}
