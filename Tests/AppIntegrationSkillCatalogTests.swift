import XCTest
@testable import KairoCore

final class AppIntegrationSkillCatalogTests: XCTestCase {
    func testCatalogIncludesExistingVisibleHandoffSkills() throws {
        let catalog = AppIntegrationSkillCatalog()

        let handoffIDs: Set<AppIntegrationSkillID> = [
            .appleMailHandoff,
            .appleMessagesHandoff,
            .applePhoneHandoff,
            .safariWebSearchHandoff,
            .appleMapsDirectionsHandoff
        ]

        for id in handoffIDs {
            let skill = try XCTUnwrap(catalog.skill(id: id))
            XCTAssertEqual(skill.executionMode, .openURL)
            XCTAssertEqual(skill.availabilityStatus, .available)
            XCTAssertEqual(skill.confirmationPolicy, .previewAndExplicitConfirmation)
            XCTAssertEqual(skill.riskTier, .tier1Draft)
            XCTAssertTrue(skill.canBeSuggestedAsExecutable)
            XCTAssertFalse(skill.endpoints.isEmpty)
        }
    }

    func testThirdPartySeedsDoNotClaimSilentExecution() throws {
        let catalog = AppIntegrationSkillCatalog()
        let seedIDs: Set<AppIntegrationSkillID> = [
            .googleMapsDirectionsHandoff,
            .gmailDraftAPI,
            .whatsappMessageHandoff,
            .lineShareHandoff,
            .slackOpenHandoff,
            .notionPageAPI,
            .todoistTaskAPI,
            .draftsCreateHandoff
        ]

        for id in seedIDs {
            let skill = try XCTUnwrap(catalog.skill(id: id))
            XCTAssertNotEqual(skill.executionMode, .previewOnly)
            XCTAssertNotEqual(skill.confirmationPolicy, .notRequired)
            XCTAssertFalse(skill.supportedSurfaces.contains(.appShortcut))
        }
    }

    func testCatalogSkillsExposeExamplePromptMetadataForIntegrationConsole() {
        let catalog = AppIntegrationSkillCatalog()

        XCTAssertEqual(Set(catalog.skills.map(\.id)), Set(AppIntegrationSkillID.allCases))
        XCTAssertTrue(catalog.skills.allSatisfy { !$0.examplePromptKey.isEmpty })
    }

    func testDefaultCatalogSkillsProvideCompleteHarnessMetadata() {
        let catalog = AppIntegrationSkillCatalog()
        let integrationKeys = catalog.skills.map(\.integrationKey)

        XCTAssertEqual(Set(catalog.skills.map(\.id)), Set(AppIntegrationSkillID.allCases))
        XCTAssertEqual(Set(integrationKeys).count, integrationKeys.count)

        for skill in catalog.skills {
            XCTAssertFalse(skill.supportedSurfaces.isEmpty)
            XCTAssertFalse(skill.audit.capabilityKeys.isEmpty)
            XCTAssertNotEqual(skill.confirmationPolicy, .notRequired)

            switch skill.executionMode {
            case .openURL, .runUserShortcut:
                XCTAssertFalse(skill.endpoints.isEmpty)
                XCTAssertTrue(skill.permissionRequirement == .userInitiated || skill.permissionRequirement == .unsupported)
            case .apiCall:
                XCTAssertNotNil(skill.oauth)
                XCTAssertFalse(skill.endpoints.isEmpty)
                XCTAssertEqual(skill.setupRequirement, .connectOAuth)
                XCTAssertEqual(skill.permissionRequirement, .oauth)
                XCTAssertFalse(skill.canBeSuggestedAsExecutable)
            case .draftOnly, .previewOnly:
                XCTAssertFalse(skill.canBeSuggestedAsExecutable)
            }
        }
    }

    func testDefaultCatalogCoversRequiredAppIntegrationHarnessSeeds() throws {
        let catalog = AppIntegrationSkillCatalog()
        let expectedSeeds: [CatalogSeedExpectation] = [
            CatalogSeedExpectation(
                id: .appleMailHandoff,
                integrationKey: "apple-mail",
                appName: "Mail",
                surfaces: [.urlScheme],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.mail],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .appleMessagesHandoff,
                integrationKey: "apple-messages",
                appName: "Messages",
                surfaces: [.urlScheme],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.messages],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .applePhoneHandoff,
                integrationKey: "apple-phone",
                appName: "Phone",
                surfaces: [.urlScheme],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.phone],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .safariWebSearchHandoff,
                integrationKey: "safari-web-search",
                appName: "Safari",
                surfaces: [.universalLink],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.web],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .appleMapsDirectionsHandoff,
                integrationKey: "apple-maps",
                appName: "Apple Maps",
                surfaces: [.universalLink],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.location],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .googleMapsDirectionsHandoff,
                integrationKey: "google-maps",
                appName: "Google Maps",
                surfaces: [.universalLink, .urlScheme],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.location],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .gmailDraftAPI,
                integrationKey: "gmail-google-workspace",
                appName: "Gmail",
                surfaces: [.oauthAPI, .webAPI],
                setupRequirement: .connectOAuth,
                availabilityStatus: .requiresOAuth,
                executionMode: .apiCall,
                riskTier: .tier3HighRiskExternal,
                confirmationPolicy: .manualSetupOnly,
                permissionRequirement: .oauth,
                capabilityKeys: [.mail, .externalConnectors],
                requiresOAuth: true
            ),
            CatalogSeedExpectation(
                id: .whatsappMessageHandoff,
                integrationKey: "whatsapp",
                appName: "WhatsApp",
                surfaces: [.universalLink],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.messages],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .lineShareHandoff,
                integrationKey: "line",
                appName: "LINE",
                surfaces: [.universalLink],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.messages],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .slackOpenHandoff,
                integrationKey: "slack",
                appName: "Slack",
                surfaces: [.universalLink, .urlScheme],
                setupRequirement: .none,
                availabilityStatus: .available,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.externalConnectors],
                requiresOAuth: false
            ),
            CatalogSeedExpectation(
                id: .notionPageAPI,
                integrationKey: "notion",
                appName: "Notion",
                surfaces: [.oauthAPI, .webAPI],
                setupRequirement: .connectOAuth,
                availabilityStatus: .requiresOAuth,
                executionMode: .apiCall,
                riskTier: .tier3HighRiskExternal,
                confirmationPolicy: .manualSetupOnly,
                permissionRequirement: .oauth,
                capabilityKeys: [.externalConnectors],
                requiresOAuth: true
            ),
            CatalogSeedExpectation(
                id: .todoistTaskAPI,
                integrationKey: "todoist",
                appName: "Todoist",
                surfaces: [.oauthAPI, .webAPI],
                setupRequirement: .connectOAuth,
                availabilityStatus: .requiresOAuth,
                executionMode: .apiCall,
                riskTier: .tier3HighRiskExternal,
                confirmationPolicy: .manualSetupOnly,
                permissionRequirement: .oauth,
                capabilityKeys: [.externalConnectors],
                requiresOAuth: true
            ),
            CatalogSeedExpectation(
                id: .draftsCreateHandoff,
                integrationKey: "drafts",
                appName: "Drafts",
                surfaces: [.urlScheme],
                setupRequirement: .installApp,
                availabilityStatus: .requiresInstalledApp,
                executionMode: .openURL,
                riskTier: .tier1Draft,
                confirmationPolicy: .previewAndExplicitConfirmation,
                permissionRequirement: .userInitiated,
                capabilityKeys: [.documents],
                requiresOAuth: false
            )
        ]

        XCTAssertEqual(expectedSeeds.map(\.id), AppIntegrationSkillID.allCases)

        for expected in expectedSeeds {
            let skill = try XCTUnwrap(catalog.skill(id: expected.id))
            XCTAssertEqual(skill.integrationKey, expected.integrationKey)
            XCTAssertEqual(skill.appName, expected.appName)
            XCTAssertEqual(skill.supportedSurfaces, expected.surfaces)
            XCTAssertEqual(skill.setupRequirement, expected.setupRequirement)
            XCTAssertEqual(skill.availabilityStatus, expected.availabilityStatus)
            XCTAssertEqual(skill.executionMode, expected.executionMode)
            XCTAssertEqual(skill.riskTier, expected.riskTier)
            XCTAssertEqual(skill.confirmationPolicy, expected.confirmationPolicy)
            XCTAssertEqual(skill.permissionRequirement, expected.permissionRequirement)
            XCTAssertEqual(skill.audit.capabilityKeys, expected.capabilityKeys)
            XCTAssertEqual(skill.oauth != nil, expected.requiresOAuth)
            XCTAssertEqual(skill.audit.payloadPolicy, "redactedPayloadOnly")
            XCTAssertEqual(skill.audit.externalSideEffectPolicy, "visibleUserInitiatedOnly")
            XCTAssertFalse(skill.fallback.reasonKey.isEmpty)
            XCTAssertFalse(skill.fallback.safeAlternativeKey.isEmpty)
            XCTAssertFalse(skill.previewTextKey.isEmpty)
            XCTAssertFalse(skill.examplePromptKey.isEmpty)
            XCTAssertFalse(skill.sourceReference.isEmpty)
        }
    }

    func testLegacyIntegrationRegistryExcludesCatalogMigratedKeys() {
        let catalog = AppIntegrationSkillCatalog()
        let registry = IntegrationRegistry()
        let migratedKeys = Set(catalog.skills.map(\.integrationKey))
        let gmailKey = catalog.skill(id: .gmailDraftAPI)?.integrationKey
        let notionKey = catalog.skill(id: .notionPageAPI)?.integrationKey
        let slackKey = catalog.skill(id: .slackOpenHandoff)?.integrationKey
        let legacyIntegrations = registry.integrationsNotMigrated(to: catalog)
        let legacyOAuthConnectors = registry.oauthConnectorsNotMigrated(to: catalog)

        XCTAssertTrue(legacyIntegrations.allSatisfy { !migratedKeys.contains($0.key) })
        XCTAssertTrue(legacyOAuthConnectors.allSatisfy { !migratedKeys.contains($0.key) })
        XCTAssertTrue(legacyOAuthConnectors.allSatisfy { $0.oauth != nil })
        XCTAssertFalse(legacyIntegrations.contains { $0.key == gmailKey })
        XCTAssertFalse(legacyIntegrations.contains { $0.key == notionKey })
        XCTAssertFalse(legacyIntegrations.contains { $0.key == slackKey })
        XCTAssertTrue(legacyIntegrations.contains { $0.key == "github" })
    }

    func testHarnessRegistryUsesCatalogOAuthConnectorsAndUnmigratedLegacyOnly() throws {
        let catalog = AppIntegrationSkillCatalog()
        let registry = IntegrationRegistry.appIntegrationHarnessRegistry(catalog: catalog)
        let oauthConnectors = Dictionary(uniqueKeysWithValues: registry.oauthConnectors.map { ($0.key, $0) })

        XCTAssertEqual(oauthConnectors["gmail-google-workspace"]?.oauth?.providerKey, "google")
        XCTAssertEqual(oauthConnectors["notion"]?.oauth?.providerKey, "notion")
        XCTAssertEqual(oauthConnectors["todoist"]?.oauth?.providerKey, "todoist")
        XCTAssertEqual(oauthConnectors["github"]?.oauth?.providerKey, "github")
        XCTAssertNil(oauthConnectors["slack"])

        let todoist = try XCTUnwrap(oauthConnectors["todoist"])
        XCTAssertEqual(todoist.surfaces, [.oauthAPI])
        XCTAssertEqual(todoist.requiredCapabilities, [.externalConnectors])
        XCTAssertEqual(todoist.status, .requiresBackend)
    }

    func testCatalogOAuthConnectorIntegrationsPreserveProviderKeysAndScopes() throws {
        let catalog = AppIntegrationSkillCatalog()
        let connectors = Dictionary(uniqueKeysWithValues: catalog.oauthConnectorIntegrations.map { ($0.key, $0) })
        let expectedSkills: [AppIntegrationSkillID] = [.gmailDraftAPI, .notionPageAPI, .todoistTaskAPI]

        XCTAssertEqual(Set(connectors.keys), Set(expectedSkills.compactMap { catalog.skill(id: $0)?.integrationKey }))

        for skillID in expectedSkills {
            let skill = try XCTUnwrap(catalog.skill(id: skillID))
            let connector = try XCTUnwrap(connectors[skill.integrationKey])

            XCTAssertEqual(connector.oauth?.providerKey, skill.oauth?.providerKey)
            XCTAssertEqual(connector.oauth?.defaultScopes, skill.oauth?.requiredScopes)
            XCTAssertEqual(connector.oauth?.authorizationEndpoint, skill.oauth?.authorizationEndpoint)
            XCTAssertEqual(connector.oauth?.tokenEndpoint, skill.oauth?.tokenEndpoint)
        }
    }

    func testCatalogSkillsExposeShortcutNodeBindingsForExecutableFirstPartyHandoffs() throws {
        let catalog = AppIntegrationSkillCatalog()
        let expectedBindings: [AppIntegrationSkillID: ShortcutNodeKind] = [
            .appleMailHandoff: .createEmailDraft,
            .appleMessagesHandoff: .prepareMessageHandoff,
            .applePhoneHandoff: .preparePhoneCallHandoff,
            .safariWebSearchHandoff: .prepareWebSearchHandoff
        ]

        for (skillID, nodeKind) in expectedBindings {
            let skill = try XCTUnwrap(catalog.skill(id: skillID))

            XCTAssertEqual(skill.shortcutNodeKind, nodeKind)
            XCTAssertTrue(skill.canBeSuggestedAsExecutable)
        }

        let setupOnlySkillIDs = Set(AppIntegrationSkillID.allCases).subtracting(expectedBindings.keys)
        for skillID in setupOnlySkillIDs {
            XCTAssertNil(catalog.skill(id: skillID)?.shortcutNodeKind)
        }
    }

    func testRecipeStepCanBindToCatalogIntegrationSkillID() throws {
        let catalog = AppIntegrationSkillCatalog()
        let step = KairoRecipeStep(
            id: "google-maps-handoff",
            title: "Prepare Maps Handoff",
            kind: .enqueueActionDraft,
            input: .previousStepOutput,
            integrationSkillID: .googleMapsDirectionsHandoff
        )

        let skill = try XCTUnwrap(catalog.skill(for: step))

        XCTAssertEqual(skill.id, .googleMapsDirectionsHandoff)
        XCTAssertEqual(skill.executionMode, .openURL)
        XCTAssertEqual(skill.confirmationPolicy, .previewAndExplicitConfirmation)
    }

    func testCatalogResolvesIntegrationReferencesStructurally() throws {
        let referencedStep = KairoRecipeStep(
            id: "mail-handoff",
            title: "Prepare Mail Handoff",
            kind: .enqueueActionDraft,
            integrationSkillID: .appleMailHandoff
        )
        let unreferencedStep = KairoRecipeStep(
            id: "internal-draft",
            title: "Internal Draft",
            kind: .enqueueActionDraft
        )

        let resolved = AppIntegrationSkillCatalog().resolveSkill(for: referencedStep)
        let missing = AppIntegrationSkillCatalog(skills: []).resolveSkill(for: referencedStep)
        let notReferenced = AppIntegrationSkillCatalog().resolveSkill(for: unreferencedStep)

        guard case .resolved(let skill) = resolved else {
            return XCTFail("Expected referenced recipe step to resolve through the catalog.")
        }
        guard case .missing(let missingSkillID) = missing else {
            return XCTFail("Expected missing catalog skill to preserve the requested skill id.")
        }

        XCTAssertEqual(skill.id, .appleMailHandoff)
        XCTAssertEqual(missingSkillID, .appleMailHandoff)
        XCTAssertEqual(notReferenced, .notReferenced)
        XCTAssertEqual(missing.skillID, .appleMailHandoff)
        XCTAssertFalse(missing.blockedExecutionFields.isEmpty)
    }

    func testURLSchemeSkillsOnlyUseVisibleOpenURLHandoff() {
        let catalog = AppIntegrationSkillCatalog()
        let urlSchemeSkills = catalog.skills.filter { $0.supportedSurfaces.contains(.urlScheme) }

        XCTAssertFalse(urlSchemeSkills.isEmpty)
        for skill in urlSchemeSkills {
            XCTAssertEqual(skill.executionMode, .openURL)
            XCTAssertEqual(skill.permissionRequirement, .userInitiated)
            XCTAssertEqual(skill.confirmationPolicy, .previewAndExplicitConfirmation)
            XCTAssertTrue(skill.requiresConfirmation)
            XCTAssertFalse(skill.endpoints.filter { $0.scheme != nil }.isEmpty)
        }
    }

    func testURLSchemeOnlyThirdPartyAppRequiresInstallBeforeExecutableSuggestion() throws {
        let catalog = AppIntegrationSkillCatalog()

        let drafts = try XCTUnwrap(catalog.skill(id: .draftsCreateHandoff))

        XCTAssertEqual(drafts.supportedSurfaces, [.urlScheme])
        XCTAssertEqual(drafts.setupRequirement, .installApp)
        XCTAssertEqual(drafts.installedAppRequirement, .required)
        XCTAssertEqual(drafts.availabilityStatus, .requiresInstalledApp)
        XCTAssertFalse(drafts.canBeSuggestedAsExecutable)
    }

    func testUserShortcutSkillCannotUseNonShortcutExecution() {
        let shortcutSkill = AppIntegrationSkill(
            id: .draftsCreateHandoff,
            appName: "User Shortcut",
            integrationKey: "user-shortcut-example",
            category: .productivity,
            supportedSurfaces: [.userShortcut],
            schema: AppIntegrationSkillSchema(input: "ShortcutInput", output: "VisibleShortcutHandoff"),
            setupRequirement: .createUserShortcut,
            installedAppRequirement: .none,
            permissionRequirement: .userInitiated,
            availabilityStatus: .requiresUserShortcut,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            previewTextKey: "appIntegration.userShortcut.preview",
            executionMode: .runUserShortcut,
            endpoints: [AppIntegrationSkillEndpoint(scheme: "shortcuts", exampleURLTemplate: "shortcuts://run-shortcut?name={shortcutName}")],
            fallback: AppIntegrationFallback(
                reasonKey: "appIntegration.userShortcut.fallback.reason",
                safeAlternativeKey: "appIntegration.userShortcut.fallback.safeAlternative"
            ),
            audit: AppIntegrationAuditMetadata(capabilityKeys: [.appIntents]),
            sourceReference: "public-url-scheme:shortcuts"
        )

        XCTAssertEqual(shortcutSkill.executionMode, .runUserShortcut)
        XCTAssertEqual(shortcutSkill.setupRequirement, .createUserShortcut)
        XCTAssertFalse(shortcutSkill.canBeSuggestedAsExecutable)
        XCTAssertTrue(shortcutSkill.endpoints.contains { $0.scheme == "shortcuts" })
    }

    func testOAuthSkillsRequireSetupBeforeExecutableSuggestion() {
        let catalog = AppIntegrationSkillCatalog()
        let oauthSkills = catalog.skills.filter { $0.supportedSurfaces.contains(.oauthAPI) }

        XCTAssertFalse(oauthSkills.isEmpty)
        for skill in oauthSkills {
            XCTAssertEqual(skill.executionMode, .apiCall)
            XCTAssertEqual(skill.setupRequirement, .connectOAuth)
            XCTAssertEqual(skill.permissionRequirement, .oauth)
            XCTAssertEqual(skill.availabilityStatus, .requiresOAuth)
            XCTAssertEqual(skill.confirmationPolicy, .manualSetupOnly)
            XCTAssertNotNil(skill.oauth)
            XCTAssertFalse(skill.canBeSuggestedAsExecutable)
        }
    }

    func testDisabledAndUnsupportedIntegrationsAreNeverExecutable() {
        let disabled = catalogSkill(id: .slackOpenHandoff, availabilityStatus: .disabled, executionMode: .openURL)
        let unsupported = catalogSkill(id: .lineShareHandoff, availabilityStatus: .unsupported, executionMode: .previewOnly)

        XCTAssertFalse(disabled.canBeSuggestedAsExecutable)
        XCTAssertFalse(unsupported.canBeSuggestedAsExecutable)
        XCTAssertEqual(unsupported.setupRequirement, .unsupported)
        XCTAssertFalse(unsupported.fallback.reasonKey.isEmpty)
        XCTAssertFalse(unsupported.fallback.safeAlternativeKey.isEmpty)
    }

    private func catalogSkill(
        id: AppIntegrationSkillID,
        availabilityStatus: AppIntegrationSkillAvailabilityStatus,
        executionMode: AppIntegrationExecutionMode
    ) -> AppIntegrationSkill {
        AppIntegrationSkill(
            id: id,
            appName: "Example",
            integrationKey: "example",
            category: .communication,
            supportedSurfaces: [.universalLink],
            schema: AppIntegrationSkillSchema(input: "Input", output: "Output"),
            setupRequirement: availabilityStatus == .unsupported ? .unsupported : .none,
            installedAppRequirement: .none,
            permissionRequirement: availabilityStatus == .unsupported ? .unsupported : .userInitiated,
            availabilityStatus: availabilityStatus,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            previewTextKey: "appIntegration.example.preview",
            executionMode: executionMode,
            endpoints: [AppIntegrationSkillEndpoint(universalLinkHost: "example.com")],
            fallback: AppIntegrationFallback(
                reasonKey: "appIntegration.example.fallback.reason",
                safeAlternativeKey: "appIntegration.example.fallback.safeAlternative"
            ),
            audit: AppIntegrationAuditMetadata(capabilityKeys: [.externalConnectors]),
            sourceReference: "test"
        )
    }
}

private struct CatalogSeedExpectation {
    var id: AppIntegrationSkillID
    var integrationKey: String
    var appName: String
    var surfaces: [AppIntegrationSkillSurface]
    var setupRequirement: AppIntegrationSkillSetupRequirement
    var availabilityStatus: AppIntegrationSkillAvailabilityStatus
    var executionMode: AppIntegrationExecutionMode
    var riskTier: ActionRiskTier
    var confirmationPolicy: BuiltInPhoneToolConfirmationPolicy
    var permissionRequirement: PermissionRequirement
    var capabilityKeys: [CapabilityKey]
    var requiresOAuth: Bool
}
