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
