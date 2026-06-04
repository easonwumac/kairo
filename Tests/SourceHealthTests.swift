import XCTest

final class SourceHealthTests: XCTestCase {
    func testSwiftTestWorkflowUsesSelfHostedMacRunner() throws {
        let root = packageRootURL()
        let workflow = try String(
            contentsOf: root.appendingPathComponent(".github/workflows/swift-test.yml"),
            encoding: .utf8
        )

        XCTAssertTrue(workflow.contains("runs-on: [self-hosted, macOS]"))
        XCTAssertFalse(workflow.contains("runs-on: macos-15"))
        XCTAssertTrue(workflow.contains("uses: actions/checkout@v5"))
        XCTAssertFalse(workflow.contains("uses: actions/checkout@v4"))
    }

    func testRepositoryDoesNotContainModelArtifactsOrCaches() throws {
        let root = packageRootURL()
        let skippedDirectoryNames: Set<String> = [
            ".git",
            ".build",
            ".swiftpm",
            "DerivedData",
            "Kairo.xcodeproj",
            "tmp"
        ]
        let forbiddenExtensions: Set<String> = [
            "bin",
            "ggml",
            "gguf",
            "mlmodelc",
            "mlpackage",
            "onnx",
            "safetensors"
        ]
        let forbiddenNameFragments = [
            "model-cache",
            "tokenizer"
        ]

        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        )
        var matches: [String] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true, skippedDirectoryNames.contains(fileURL.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }
            guard values.isRegularFile == true else { continue }

            let lowercasedName = fileURL.lastPathComponent.lowercased()
            let lowercasedExtension = fileURL.pathExtension.lowercased()
            if forbiddenExtensions.contains(lowercasedExtension)
                || forbiddenNameFragments.contains(where: lowercasedName.contains) {
                matches.append(fileURL.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }

        XCTAssertTrue(
            matches.isEmpty,
            "Do not commit model weights, tokenizer blobs, generated model packages, or model caches: \(matches.joined(separator: ", "))"
        )
    }

    func testRepositoryDoesNotContainHighConfidenceSecrets() throws {
        let root = packageRootURL()
        let skippedDirectoryNames: Set<String> = [
            ".git",
            ".build",
            ".swiftpm",
            "DerivedData",
            "Kairo.xcodeproj",
            "tmp"
        ]
        let privateKeyMarkers = [
            "-----BEGIN " + "PRIVATE " + "KEY-----",
            "-----BEGIN " + "RSA " + "PRIVATE " + "KEY-----",
            "-----BEGIN " + "EC " + "PRIVATE " + "KEY-----",
            "-----BEGIN " + "OPENSSH " + "PRIVATE " + "KEY-----"
        ]
        let tokenPatterns = [
            #"sk-[A-Za-z0-9_-]{20,}"#,
            #"ghp_[A-Za-z0-9_]{20,}"#,
            #"github_pat_[A-Za-z0-9_]{20,}"#,
            #"AKIA[0-9A-Z]{16}"#
        ].map { try! NSRegularExpression(pattern: $0) }

        let keys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey, .fileSizeKey]
        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: []
        )
        var matches: [String] = []

        while let fileURL = enumerator?.nextObject() as? URL {
            let values = try fileURL.resourceValues(forKeys: Set(keys))
            if values.isDirectory == true, skippedDirectoryNames.contains(fileURL.lastPathComponent) {
                enumerator?.skipDescendants()
                continue
            }
            guard values.isRegularFile == true else { continue }
            if let fileSize = values.fileSize, fileSize > 2_000_000 { continue }

            let data = try Data(contentsOf: fileURL)
            guard let text = String(data: data, encoding: .utf8) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if privateKeyMarkers.contains(where: text.contains)
                || tokenPatterns.contains(where: { $0.firstMatch(in: text, range: range) != nil }) {
                matches.append(fileURL.path.replacingOccurrences(of: root.path + "/", with: ""))
            }
        }

        XCTAssertTrue(
            matches.isEmpty,
            "Do not commit high-confidence secrets, access tokens, or private keys: \(matches.joined(separator: ", "))"
        )
    }

    func testLocalModelCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/LocalModelFeatureTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Local model tests should live in Tests/LocalModelFeatureTests.swift instead of the KairoCoreTests monolith."
        )

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        XCTAssertFalse(coreTests.contains("testDefaultLocalModelCatalogExposesPopularStarterModelsForSettings"))
        XCTAssertFalse(coreTests.contains("testVerifiedLocalModelDownloaderInstallsModelAndUpdatesRegistry"))
        XCTAssertFalse(coreTests.contains("testLocalModelRoutingAIProviderUsesSelectedLocalModelForEligiblePreferLocalWork"))
    }

    func testAgentSkillMarketplaceCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/AgentSkillFeatureTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Skill marketplace tests should live in Tests/AgentSkillFeatureTests.swift instead of the KairoCoreTests monolith."
        )

        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        XCTAssertTrue(focusedTests.contains("testSkillMarketplaceIndexListsDownloadableSkillsWithSafetyMetadata"))
        XCTAssertTrue(focusedTests.contains("testSkillMarketplaceManifestIsImportableBySkillManager"))
        XCTAssertTrue(focusedTests.contains("testAgentSkillMarketplaceCatalogServiceFetchesStandaloneRepoCatalog"))
        XCTAssertTrue(focusedTests.contains("testAgentSkillCatalogMergesRemoteMarketplaceWithoutReplacingInstalledSkills"))
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 320)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        XCTAssertFalse(coreTests.contains("testSkillMarketplaceIndexListsDownloadableSkillsWithSafetyMetadata"))
        XCTAssertFalse(coreTests.contains("testAgentSkillMarketplaceCatalogServiceFetchesStandaloneRepoCatalog"))
    }

    func testAgentSkillManifestTrustCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/AgentSkillManifestTrustTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Skill manifest trust-store tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testAgentSkillManifestRequiresSignatureAndVerifiesChecksum",
            "testAgentSkillManifestTrustStoreVerifiesPublicKeySignatureAndRejectsUnknownKeys",
            "testAgentSkillManifestTrustStoreRejectsRevokedAndOutOfWindowKeys",
            "testAgentSkillManifestTrustStoreRejectsPendingPublicationSigningKeys",
            "testAgentSkillTrustStoreDecodesISO8601RotationMetadata",
            "testAgentSkillManagerUsesTrustStoreWhenProvided",
            "testAgentSkillManagerBuildsSignedManifestUpdatePreviewWithChangelog",
            "testAgentSkillManagerBuildsDowngradeBlockedPreviewFromManifestJSONString"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 460)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testAgentSkillManagerLifecycleCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/AgentSkillManagerLifecycleTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Skill Manager lifecycle tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testAgentSkillCompatibilityEvaluatorReportsMissingRuntimeRequirements",
            "testAgentSkillManagerBlocksInstallWhenCompatibilityRequirementsAreMissing",
            "testAgentSkillManagerInstallsWhenCompatibilityRequirementsAreSatisfied",
            "testAgentSkillManagerCreatesDisabledUserSkillDraftsWithStableIDs",
            "testAgentSkillManagerCreatesUniqueUserSkillDraftIDsForDuplicateNames",
            "testAgentSkillManagerRequiresUserDraftCapabilitySelection",
            "testAgentSkillManagerRequiresUserDraftConfirmationPolicy",
            "testFileBackedAgentSkillManagerPersistsInstallDisableEnableAndRemoveLifecycle",
            "testFileBackedAgentSkillManagerPersistsBuiltInShortcutSkillStatus"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 360)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testProviderCredentialSafetyCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/ProviderCredentialSafetyTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Provider credential safety tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testOpenAISettingsServiceSavesAndDeletesAPIKey",
            "testOpenAISettingsServiceDryRunRedactsProvidedKeyWithoutSaving",
            "testOpenAISettingsServiceDryRunUsesSavedKeyWhenInputIsEmpty",
            "testOAuthConnectorReadinessProvidesSettingsCopyAndActionState",
            "testChatGPTOAuthServiceBuildsPKCEAuthorizationURL",
            "testOAuthConnectorLoginCenterDisconnectDeletesStoredTokensAndResetsReadiness",
            "testOAuthConnectorCallbackPreviewRedactsAuthorizationCodeAndPersistsStatus",
            "testKairoEnvironmentConnectedOAuthProviderKeysIgnoreMalformedStoredTokens"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 420)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testChatActionConfirmationCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/ChatActionConfirmationTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Chat action confirmation tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testChatViewModelConfirmsNotificationActionThroughInjectedExecutor",
            "testChatViewModelConfirmsReminderActionThroughInjectedExecutor",
            "testChatViewModelConfirmsCalendarActionThroughInjectedExecutor",
            "testChatViewModelConfirmsContactActionThroughInjectedExecutor",
            "testChatViewModelConfirmsEmailDraftHandoffThroughInjectedExecutor",
            "testChatViewModelConfirmsMessageHandoffThroughInjectedExecutor",
            "testChatViewModelConfirmsPhoneCallHandoffThroughInjectedExecutor",
            "testChatViewModelConfirmsWebSearchHandoffThroughInjectedExecutor"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 240)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }

        let shareToChatAuditTestsURL = root.appendingPathComponent("Tests/ShareToChatActionAuditTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: shareToChatAuditTestsURL.path),
            "Share-to-Chat action audit coverage should live in its own focused test file."
        )
        let shareToChatAuditTests = try String(contentsOf: shareToChatAuditTestsURL, encoding: .utf8)
        XCTAssertTrue(shareToChatAuditTests.contains("testShareTextToChatReminderConfirmationRecordsAuditEvent"))
        XCTAssertLessThan(shareToChatAuditTests.split(separator: "\n").count, 90)

        let chatHandoffAuditTestsURL = root.appendingPathComponent("Tests/ChatHandoffActionAuditTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: chatHandoffAuditTestsURL.path),
            "Chat handoff action audit coverage should live in its own focused test file."
        )
        let chatHandoffAuditTests = try String(contentsOf: chatHandoffAuditTestsURL, encoding: .utf8)
        XCTAssertTrue(chatHandoffAuditTests.contains("testChatConfirmedEmailMessagePhoneWebAndMapsHandoffsOpenVisibleURLsAndRecordAudit"))
        XCTAssertLessThan(chatHandoffAuditTests.split(separator: "\n").count, 110)
    }

    func testAgentCoreActionPreviewCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/AgentCoreActionPreviewTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "AgentCore action preview tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testAgentCoreAddsDeterministicHomeKitPreviewAction",
            "testAgentCoreReturnsShortcutToolCandidateWithoutActionExecution",
            "testAgentCoreAddsDeterministicNotificationPreviewAction",
            "testAgentCoreAddsDeterministicReminderPreviewAction",
            "testAgentCoreAddsDeterministicCalendarPreviewAction",
            "testAgentCoreAddsDeterministicContactPreviewAction",
            "testAgentCoreAddsDeterministicEmailDraftPreviewAction",
            "testAgentCoreAddsDeterministicMessagePreviewAction",
            "testAgentCoreAddsDeterministicPhoneCallPreviewAction",
            "testAgentCoreAddsDeterministicWebSearchPreviewAction"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 180)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testAgentToolInvocationPlannerCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/AgentToolInvocationPlannerTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Agent tool invocation planner tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testAgentToolInvocationPlannerSuggestsInstalledShortcutSkillForTaskExtraction",
            "testAgentToolInvocationPlannerSuggestsReplyDraftAndMeetingPrepShortcutSkills",
            "testAgentToolInvocationPlannerSuggestsHomeKitActionWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsOAuthConnectorWithoutPrivateAppClaims",
            "testAgentToolInvocationPlannerSuggestsNotificationActionWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsReminderActionWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsCalendarActionWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsContactActionWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsEmailDraftHandoffWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsMapDirectionsHandoffWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsMessageHandoffWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsPhoneCallHandoffWithConfirmation",
            "testAgentToolInvocationPlannerSuggestsWebSearchHandoffWithConfirmation",
            "testAgentToolInvocationPlannerRefusesToolUseWhenDisabled",
            "testAgentToolInvocationPlannerIgnoresDisabledSkills"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 380)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testKairoRecipeLifecycleCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/KairoRecipeLifecycleTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Kairo-owned internal recipe lifecycle tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testKairoRecipeTemplateFactoryProvidesInternalSampleRecipes",
            "testFileBackedKairoRecipeStorePersistsAndTogglesInternalRecipes",
            "testKairoRecipeRunnerRequiresConfirmationBeforeLowRiskWrites",
            "testKairoRecipeRunnerExtractsTasksAndCreatesDraftsDeterministically",
            "testKairoRecipeEngineStaysSplitAcrossSupportFiles"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 190)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testSandboxActionExecutorCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/SandboxActionExecutorTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "SandboxActionExecutor behavior tests should live in a focused test file instead of the KairoCoreTests monolith."
        )

        let requiredFocusedTests = [
            "testSandboxActionExecutorSavesConfirmedMemory",
            "testSandboxActionExecutorReportsUnsupportedSandboxActionWithoutExecuting",
            "testSandboxActionExecutorOpensURLThroughInjectedOpener",
            "testSandboxActionExecutorOpensConfirmedShortcutHandoffURLThroughInjectedOpener",
            "testSandboxActionExecutorOpensEmailDraftHandoffThroughInjectedOpener",
            "testSandboxActionExecutorOpensMapDirectionsHandoffThroughInjectedOpener",
            "testSandboxActionExecutorOpensMessageHandoffThroughInjectedOpenerWithoutBodyInURL",
            "testSandboxActionExecutorOpensPhoneCallHandoffThroughInjectedOpenerWithoutCallingSilently",
            "testSandboxActionExecutorOpensWebSearchHandoffThroughInjectedOpenerWithoutBrowsingSilently",
            "testSandboxActionExecutorSchedulesNotificationThroughInjectedScheduler",
            "testSandboxActionExecutorCreatesReminderThroughInjectedScheduler",
            "testSandboxActionExecutorRecordsAuditEventAfterConfirmedReminderCreation",
            "testSandboxActionExecutorRecordsRejectedAuditEventForUnconfirmedWrite",
            "testSandboxActionExecutorRecordsFailedAuditEventForPermissionDeniedWrite",
            "testKairoEnvironmentDefaultActionExecutorUsesInjectedAuditLogger",
            "testKairoEnvironmentUITestingActionExecutorUsesEnvironmentAuditLogger",
            "testSandboxActionExecutorCreatesCalendarEventThroughInjectedScheduler",
            "testSandboxActionExecutorReportsCalendarPermissionDenied",
            "testSandboxActionExecutorCreatesContactThroughInjectedScheduler",
            "testSandboxActionExecutorReportsContactPermissionDenied"
        ]
        let focusedTests = try String(contentsOf: focusedTestsURL, encoding: .utf8)
        for testName in requiredFocusedTests {
            XCTAssertTrue(focusedTests.contains(testName), testName)
        }
        XCTAssertLessThan(focusedTests.split(separator: "\n").count, 620)

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        for testName in requiredFocusedTests {
            XCTAssertFalse(coreTests.contains(testName), testName)
        }
    }

    func testSandboxActionSupportStaysSplitAcrossFocusedFiles() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let splitFiles = [
            "SandboxActionAuditSupport.swift": "extension SandboxActionExecutor",
            "SandboxActionCatalog.swift": "public struct SandboxActionCatalog",
            "HomeKitControlDemoCatalog.swift": "public struct HomeKitControlDemoCatalog",
            "SandboxActionScheduling.swift": "public protocol NotificationScheduling",
            "SandboxActionExecutor.swift": "public actor SandboxActionExecutor"
        ]

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: services.appendingPathComponent("SandboxActionSupport.swift").path),
            "Sandbox action support should stay split instead of returning to one monolithic file."
        )

        for (fileName, requiredSymbol) in splitFiles {
            let sourceURL = services.appendingPathComponent(fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), fileName)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            XCTAssertTrue(source.contains(requiredSymbol), fileName)
            XCTAssertLessThan(source.split(separator: "\n").count, 420, fileName)
        }
    }

    func testBackendAPIFacadesStaySplitAcrossFocusedFiles() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let splitFiles = [
            "KairoBackendAPI.swift": "public struct KairoBackendAPI",
            "KairoBackendModuleRegistry.swift": "public struct KairoBackendModuleRegistry",
            "KairoEnvironment+BackendAPI.swift": "var backendAPI: KairoBackendAPI",
            "KairoChatBackendAPI.swift": "public protocol KairoChatAPI",
            "KairoMemoryBackendAPI.swift": "public protocol KairoMemoryAPI",
            "KairoRecipeBackendAPI.swift": "public protocol KairoRecipeAPI",
            "KairoShareImportBackendAPI.swift": "public protocol KairoShareImportAPI",
            "KairoDeletionBackendAPI.swift": "public protocol KairoDeletionAPI",
            "KairoLocalModelBackendAPI.swift": "public protocol KairoLocalModelAPI",
            "KairoSkillBackendAPI.swift": "public protocol KairoSkillAPI",
            "KairoSettingsBackendAPI.swift": "public protocol KairoSettingsAPI",
            "KairoAccessBackendAPI.swift": "public protocol KairoAccessAPI"
        ]

        for (fileName, requiredSymbol) in splitFiles {
            let sourceURL = services.appendingPathComponent(fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), fileName)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            XCTAssertTrue(source.contains(requiredSymbol), fileName)
            XCTAssertLessThan(source.split(separator: "\n").count, 140, fileName)
        }

        let backendAPI = try String(contentsOf: services.appendingPathComponent("KairoBackendAPI.swift"), encoding: .utf8)
        XCTAssertFalse(backendAPI.contains("public struct KairoChatBackendService"))
        XCTAssertFalse(backendAPI.contains("public struct KairoSettingsBackendService"))
        XCTAssertFalse(backendAPI.contains("public extension KairoEnvironment"))
    }

    func testBackendAPICoverageStaysSplitAcrossFocusedTestFiles() throws {
        let root = packageRootURL()
        let backendTestsURL = root.appendingPathComponent("Tests/KairoBackendAPITests.swift")
        let chatTestsURL = root.appendingPathComponent("Tests/KairoChatBackendAPITests.swift")
        let memoryTestsURL = root.appendingPathComponent("Tests/KairoMemoryBackendAPITests.swift")
        let recipeTestsURL = root.appendingPathComponent("Tests/KairoRecipeBackendAPITests.swift")
        let shareImportTestsURL = root.appendingPathComponent("Tests/KairoShareImportBackendAPITests.swift")
        let accessTestsURL = root.appendingPathComponent("Tests/KairoAccessBackendAPITests.swift")
        let settingsTestsURL = root.appendingPathComponent("Tests/KairoSettingsBackendAPITests.swift")
        let skillTestsURL = root.appendingPathComponent("Tests/KairoSkillBackendAPITests.swift")
        let localModelTestsURL = root.appendingPathComponent("Tests/KairoLocalModelBackendAPITests.swift")
        let deletionTestsURL = root.appendingPathComponent("Tests/KairoDeletionBackendAPITests.swift")
        let backendTestSupportURL = root.appendingPathComponent("Tests/KairoBackendTestSupport.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: backendTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: chatTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: memoryTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: recipeTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: shareImportTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: accessTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: settingsTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: skillTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: localModelTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: deletionTestsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: backendTestSupportURL.path))

        let backendTests = try String(contentsOf: backendTestsURL, encoding: .utf8)
        let chatTests = try String(contentsOf: chatTestsURL, encoding: .utf8)
        let memoryTests = try String(contentsOf: memoryTestsURL, encoding: .utf8)
        let recipeTests = try String(contentsOf: recipeTestsURL, encoding: .utf8)
        let shareImportTests = try String(contentsOf: shareImportTestsURL, encoding: .utf8)
        let accessTests = try String(contentsOf: accessTestsURL, encoding: .utf8)
        let settingsTests = try String(contentsOf: settingsTestsURL, encoding: .utf8)
        let skillTests = try String(contentsOf: skillTestsURL, encoding: .utf8)
        let localModelTests = try String(contentsOf: localModelTestsURL, encoding: .utf8)
        let deletionTests = try String(contentsOf: deletionTestsURL, encoding: .utf8)
        let backendTestSupport = try String(contentsOf: backendTestSupportURL, encoding: .utf8)

        XCTAssertTrue(chatTests.contains("final class KairoChatBackendAPITests"))
        XCTAssertTrue(chatTests.contains("testChatBackendAPIForwardsPrivacyModeThroughAgentCore"))
        XCTAssertTrue(memoryTests.contains("final class KairoMemoryBackendAPITests"))
        XCTAssertTrue(memoryTests.contains("testMemoryBackendAPIForwardsLifecycleAndExportThroughStore"))
        XCTAssertTrue(recipeTests.contains("final class KairoRecipeBackendAPITests"))
        XCTAssertTrue(recipeTests.contains("testRecipeBackendAPIForwardsLifecycleAndRunThroughInternalRecipeStore"))
        XCTAssertTrue(recipeTests.contains("testRecipeBackendAPISeedsKairoOwnedSamplesWithoutAppleShortcutSideEffects"))
        XCTAssertTrue(shareImportTests.contains("final class KairoShareImportBackendAPITests"))
        XCTAssertTrue(shareImportTests.contains("testShareImportBackendAPIImportsPendingItemsAndMarksThemImported"))
        XCTAssertTrue(accessTests.contains("final class KairoAccessBackendAPITests"))
        XCTAssertTrue(accessTests.contains("testAccessBackendAPIResolvesPermissionStatusesWithoutRequestingPrompts"))
        XCTAssertTrue(accessTests.contains("testAccessBackendAPIForwardsExplicitPermissionRequests"))
        XCTAssertTrue(settingsTests.contains("final class KairoSettingsBackendAPITests"))
        XCTAssertTrue(settingsTests.contains("testSettingsBackendAPIManagesOpenAIKeyWithoutLeakingSecrets"))
        XCTAssertTrue(settingsTests.contains("testSettingsBackendAPIManagesOAuthLoginWithoutPersistingAuthorizationCode"))
        XCTAssertTrue(skillTests.contains("final class KairoSkillBackendAPITests"))
        XCTAssertTrue(skillTests.contains("testSkillBackendAPIForwardsLifecycleThroughSkillManager"))
        XCTAssertTrue(skillTests.contains("testSkillBackendAPIRequiresExplicitUserDraftCapabilityAndConfirmationPolicy"))
        XCTAssertTrue(skillTests.contains("testSkillBackendAPIBlocksIncompatibleMarketplaceSkillsFromExecutableCatalog"))
        XCTAssertTrue(skillTests.contains("testSkillBackendAPIFailsClosedWhenServiceIsUnavailable"))
        XCTAssertTrue(localModelTests.contains("final class KairoLocalModelBackendAPITests"))
        XCTAssertTrue(localModelTests.contains("testLocalModelBackendAPIForwardsManagementCallsThroughCoreService"))
        XCTAssertTrue(localModelTests.contains("testLocalModelBackendAPIFailsClosedWhenServiceIsUnavailable"))
        XCTAssertTrue(localModelTests.contains("testEnvironmentBackendAPIExposesLocalModelManagementFacade"))
        XCTAssertTrue(deletionTests.contains("final class KairoDeletionBackendAPITests"))
        XCTAssertTrue(deletionTests.contains("testDeletionBackendAPIDeletesOnDevicePrivacyDataThroughCoreInterfaces"))
        XCTAssertTrue(deletionTests.contains("testDeletionBackendAPIFailsClosedWhenLocalModelServiceIsUnavailable"))
        XCTAssertTrue(backendTestSupport.contains("BackendAPICapturingAIProvider"))
        XCTAssertTrue(backendTestSupport.contains("makeBackendTestAgentSkillManagerService"))
        XCTAssertTrue(backendTestSupport.contains("makeBackendTestLocalModelSettingsService"))
        XCTAssertFalse(backendTests.contains("testChatBackendAPIForwardsPrivacyModeThroughAgentCore"))
        XCTAssertFalse(backendTests.contains("testMemoryBackendAPIForwardsLifecycleAndExportThroughStore"))
        XCTAssertFalse(backendTests.contains("testRecipeBackendAPIForwardsLifecycleAndRunThroughInternalRecipeStore"))
        XCTAssertFalse(backendTests.contains("testShareImportBackendAPIImportsPendingItemsAndMarksThemImported"))
        XCTAssertFalse(backendTests.contains("testAccessBackendAPIResolvesPermissionStatusesWithoutRequestingPrompts"))
        XCTAssertFalse(backendTests.contains("testSettingsBackendAPIManagesOpenAIKeyWithoutLeakingSecrets"))
        XCTAssertFalse(backendTests.contains("testSkillBackendAPIForwardsLifecycleThroughSkillManager"))
        XCTAssertFalse(backendTests.contains("testSkillBackendAPIBlocksIncompatibleMarketplaceSkillsFromExecutableCatalog"))
        XCTAssertFalse(backendTests.contains("testLocalModelBackendAPIForwardsManagementCallsThroughCoreService"))
        XCTAssertFalse(backendTests.contains("testEnvironmentBackendAPIExposesLocalModelManagementFacade"))
        XCTAssertFalse(backendTests.contains("testDeletionBackendAPIDeletesOnDevicePrivacyDataThroughCoreInterfaces"))
        XCTAssertLessThan(backendTests.split(separator: "\n").count, 720)
        XCTAssertLessThan(chatTests.split(separator: "\n").count, 120)
        XCTAssertLessThan(memoryTests.split(separator: "\n").count, 120)
        XCTAssertLessThan(recipeTests.split(separator: "\n").count, 120)
        XCTAssertLessThan(shareImportTests.split(separator: "\n").count, 120)
        XCTAssertLessThan(accessTests.split(separator: "\n").count, 180)
        XCTAssertLessThan(settingsTests.split(separator: "\n").count, 180)
        XCTAssertLessThan(skillTests.split(separator: "\n").count, 240)
        XCTAssertLessThan(localModelTests.split(separator: "\n").count, 160)
        XCTAssertLessThan(deletionTests.split(separator: "\n").count, 160)
        XCTAssertLessThan(backendTestSupport.split(separator: "\n").count, 140)
    }

    func testUITestHelpersStaySplitFromSmokeScenarios() throws {
        let root = packageRootURL()
        let uiTests = root.appendingPathComponent("KairoUITests", isDirectory: true)
        let smokeURL = uiTests.appendingPathComponent("KairoAppSmokeUITests.swift")
        let helpersURL = uiTests.appendingPathComponent("KairoAppSmokeUITests+Helpers.swift")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: helpersURL.path),
            "Reusable UI navigation/search helpers should live outside the smoke scenario file."
        )

        let smokeSource = try String(contentsOf: smokeURL, encoding: .utf8)
        let helperSource = try String(contentsOf: helpersURL, encoding: .utf8)
        XCTAssertLessThan(smokeSource.split(separator: "\n").count, 720, "Keep smoke scenarios readable.")
        XCTAssertTrue(helperSource.contains("extension KairoAppSmokeUITests"))
        XCTAssertTrue(helperSource.contains("func openAccessAndVerifyHomeKitDemos()"))
        XCTAssertTrue(helperSource.contains("func findStaticText("))
        XCTAssertTrue(helperSource.contains("func relaunchForUITesting("))
    }

    func testRootShellIsChatFirstInsteadOfBriefingInboxFirst() throws {
        let root = packageRootURL()
        let rootViewSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(rootViewSource.contains("private var selectedSection: RootSection = .chat"))
        XCTAssertTrue(rootViewSource.contains("?? .chat"))
        XCTAssertFalse(rootViewSource.contains("BriefingInboxView"))
        XCTAssertTrue(rootViewSource.contains("Back to Chat"))
        XCTAssertTrue(rootViewSource.contains("Tell Kairo what to do on this phone"))
    }

    func testChatSurfaceOwnsToolsAndHidesRouteComplexity() throws {
        let root = packageRootURL()
        let chatViewSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/ChatView.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(chatViewSource.contains("chat.tools.menu"))
        XCTAssertTrue(chatViewSource.contains("Ask Kairo to act"))
        XCTAssertTrue(chatViewSource.contains("Phone tools"))
        XCTAssertFalse(chatViewSource.contains("chat.session-controls"))
        XCTAssertFalse(chatViewSource.contains("ChatProviderRouteBar("))
        XCTAssertFalse(chatViewSource.contains("chatTopControls"))
    }

    func testRootShellLetsKeyboardLiftChatComposer() throws {
        let root = packageRootURL()
        let rootViewSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/RootView.swift"),
            encoding: .utf8
        )

        XCTAssertFalse(rootViewSource.contains(".ignoresSafeArea(.keyboard, edges: .bottom)"))
    }

    func testChatActionCopyUsesPlainLanguageRiskLabels() throws {
        let root = packageRootURL()
        let actionStripSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Views/ChatActionStrips.swift"),
            encoding: .utf8
        )

        XCTAssertTrue(actionStripSource.contains("Read only"))
        XCTAssertTrue(actionStripSource.contains("Draft only"))
        XCTAssertTrue(actionStripSource.contains("Will ask first"))
        XCTAssertFalse(actionStripSource.contains("Tier 0"))
        XCTAssertFalse(actionStripSource.contains("Tier 1"))
        XCTAssertFalse(actionStripSource.contains("No write"))
    }

    func testPrivacyManifestMatchesNoCollectionNoTrackingBetaClaim() throws {
        let root = packageRootURL()
        let privacyManifestURL = root.appendingPathComponent("Kairo/Resources/PrivacyInfo.xcprivacy")
        let data = try Data(contentsOf: privacyManifestURL)
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertTrue((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        XCTAssertTrue((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)

        let accessedAPITypes = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(accessedAPITypes.count, 1)
        XCTAssertEqual(accessedAPITypes.first?["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(accessedAPITypes.first?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
    }

    func testPrivacyLabelsChecklistMatchesCurrentBetaBoundaries() throws {
        let root = packageRootURL()
        let checklist = try String(
            contentsOf: root.appendingPathComponent("docs/PRIVACY_LABELS_CHECKLIST.md"),
            encoding: .utf8
        )
        let reviewNotes = try String(
            contentsOf: root.appendingPathComponent("docs/APP_REVIEW_NOTES.md"),
            encoding: .utf8
        )
        let privacyManifest = try propertyListDictionary(at: root.appendingPathComponent("Kairo/Resources/PrivacyInfo.xcprivacy"))
        let appInfoPlist = try propertyListDictionary(at: root.appendingPathComponent("Config/KairoApp-Info.plist"))

        XCTAssertEqual(privacyManifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertTrue((privacyManifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        XCTAssertTrue((privacyManifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
        XCTAssertTrue(checklist.contains("- Tracking: No."))
        XCTAssertTrue(checklist.contains("- Data collected: No collected data."))
        XCTAssertTrue(checklist.contains("- Tracking domains: None."))
        XCTAssertTrue(checklist.contains("Required Reason API usage: UserDefaults only, reason `CA92.1`"))

        let currentPurposeStrings = [
            "NSCalendarsUsageDescription",
            "NSCalendarsFullAccessUsageDescription",
            "NSRemindersUsageDescription",
            "NSRemindersFullAccessUsageDescription",
            "NSUserNotificationsUsageDescription",
            "NSContactsUsageDescription"
        ]
        for purposeString in currentPurposeStrings {
            XCTAssertNotNil(appInfoPlist[purposeString], purposeString)
            XCTAssertTrue(checklist.contains("- `\(purposeString)`"), purposeString)
        }

        let futureOnlyPurposeStrings = [
            "NSHomeKitUsageDescription",
            "NSLocationWhenInUseUsageDescription",
            "NSPhotoLibraryUsageDescription"
        ]
        for purposeString in futureOnlyPurposeStrings {
            XCTAssertNil(appInfoPlist[purposeString], purposeString)
            XCTAssertTrue(checklist.contains("- `\(purposeString)`"), purposeString)
        }

        for boundary in [
            "no analytics SDK",
            "no backend account",
            "no cloud memory sync",
            "no crash/telemetry collection provider",
            "no provider-side sync beyond explicit user-configured API calls"
        ] {
            XCTAssertTrue(checklist.contains(boundary), boundary)
            XCTAssertTrue(reviewNotes.contains(boundary), boundary)
        }

        XCTAssertTrue(checklist.contains("Backend account deletion: not applicable in the current beta"))
        XCTAssertTrue(reviewNotes.contains("Backend account deletion: not applicable in the current beta"))
        XCTAssertTrue(checklist.contains("Audit logs: Settings / Privacy exposes Clear Audit Log"))
        XCTAssertTrue(reviewNotes.contains("metadata-only audit log"))
        XCTAssertTrue(checklist.contains("privacy labels do not prove runtime behavior"))
        XCTAssertFalse(checklist.localizedCaseInsensitiveContains("backend account deletion is available"))
        XCTAssertFalse(checklist.localizedCaseInsensitiveContains("cloud-sync deletion is available"))
    }

    func testBetaInfoPlistPurposeStringsMatchEnabledCapabilities() throws {
        let root = packageRootURL()
        let appInfoPlistURL = root.appendingPathComponent("Config/KairoApp-Info.plist")
        let data = try Data(contentsOf: appInfoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        XCTAssertEqual(
            plist["NSCalendarsFullAccessUsageDescription"] as? String,
            "Kairo 需要完整行事曆權限，才能在你確認後透過 EventKit 建立行事曆事件。"
        )
        XCTAssertEqual(
            plist["NSCalendarsUsageDescription"] as? String,
            "Kairo 需要行事曆權限，才能在你確認後建立或整理行事曆草稿。"
        )
        XCTAssertEqual(
            plist["NSRemindersFullAccessUsageDescription"] as? String,
            "Kairo 需要提醒事項完整權限，才能在你確認後透過 EventKit 建立提醒事項。"
        )
        XCTAssertEqual(
            plist["NSRemindersUsageDescription"] as? String,
            "Kairo 需要提醒事項權限，才能在你確認後建立與整理待辦提醒。"
        )
        XCTAssertEqual(
            plist["NSContactsUsageDescription"] as? String,
            "Kairo 只會在你明確要求並確認後，透過 Contacts.framework 建立聯絡人。"
        )
        XCTAssertEqual(
            plist["NSUserNotificationsUsageDescription"] as? String,
            "Kairo 會用通知提醒你 briefing、待確認動作與重要待辦。"
        )
        XCTAssertNil(plist["NSHomeKitUsageDescription"])
        XCTAssertNil(plist["NSLocationWhenInUseUsageDescription"])
        XCTAssertNil(plist["NSPhotoLibraryUsageDescription"])
    }

    func testBetaProjectTargetsDoNotAddDeferredSurfaces() throws {
        let root = packageRootURL()
        let project = try String(contentsOf: root.appendingPathComponent("project.yml"), encoding: .utf8)
        let appEntitlements = try String(
            contentsOf: root.appendingPathComponent("Config/KairoApp.entitlements"),
            encoding: .utf8
        )
        let shareEntitlements = try String(
            contentsOf: root.appendingPathComponent("Config/KairoShareExtension.entitlements"),
            encoding: .utf8
        )

        XCTAssertTrue(project.contains("  KairoApp:"))
        XCTAssertTrue(project.contains("  KairoShareExtension:"))
        XCTAssertTrue(project.contains("  KairoCoreTests:"))
        XCTAssertTrue(project.contains("  KairoUITests:"))
        XCTAssertFalse(project.contains("Keyboard"))
        XCTAssertFalse(project.contains("Widget"))
        XCTAssertFalse(project.localizedCaseInsensitiveContains("carplay"))
        XCTAssertFalse(project.contains("com.apple.developer.homekit"))
        XCTAssertFalse(project.contains("com.apple.developer.carplay"))

        for entitlements in [appEntitlements, shareEntitlements] {
            XCTAssertTrue(entitlements.contains("com.apple.security.application-groups"))
            XCTAssertFalse(entitlements.contains("com.apple.developer.homekit"))
            XCTAssertFalse(entitlements.contains("com.apple.developer.carplay"))
        }
    }

    func testBackgroundTaskIdentifiersMatchInfoPlist() throws {
        let root = packageRootURL()
        let appInfoPlistURL = root.appendingPathComponent("Config/KairoApp-Info.plist")
        let plistData = try Data(contentsOf: appInfoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: plistData, options: [], format: nil) as? [String: Any]
        )
        let plistIdentifiers = try XCTUnwrap(plist["BGTaskSchedulerPermittedIdentifiers"] as? [String])
        let policySource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/BackgroundTaskPolicy.swift"),
            encoding: .utf8
        )
        let backgroundDocs = try String(
            contentsOf: root.appendingPathComponent("docs/BACKGROUND_TASKS.md"),
            encoding: .utf8
        )

        XCTAssertEqual(
            Set(plistIdentifiers),
            [
                "com.kairo.app.refresh",
                "com.kairo.app.processing.local-model",
                "com.kairo.app.processing.connectors"
            ]
        )
        for identifier in plistIdentifiers {
            XCTAssertTrue(policySource.contains(#"identifier: "\#(identifier)""#))
            XCTAssertTrue(backgroundDocs.contains(identifier))
        }
        XCTAssertTrue(backgroundDocs.contains("BGTaskSchedulerPermittedIdentifiers"))
        XCTAssertTrue(backgroundDocs.contains("BackgroundTaskPolicy.defaultTasks"))
        XCTAssertTrue(backgroundDocs.contains("Widget snapshot must stay future-only until a Widget target ships."))
        XCTAssertTrue(backgroundDocs.contains("高風險 action 只能走前景 preview + explicit confirmation"))
        XCTAssertTrue(backgroundDocs.contains("physical-device sign-off"))
        XCTAssertFalse(backgroundDocs.contains("- [ ]"))
        XCTAssertFalse(backgroundDocs.contains("app.kairo.refresh"))
    }

    func testAppReviewCopyAndEntitlementsStayWithinBetaClaims() throws {
        let root = packageRootURL()
        let entitlements = try propertyListDictionary(at: root.appendingPathComponent("Config/KairoApp.entitlements"))
        let infoPlist = try propertyListDictionary(at: root.appendingPathComponent("Config/KairoApp-Info.plist"))
        let privacyManifest = try propertyListDictionary(at: root.appendingPathComponent("Kairo/Resources/PrivacyInfo.xcprivacy"))
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )
        let reviewNotes = try String(
            contentsOf: root.appendingPathComponent("docs/APP_REVIEW_NOTES.md"),
            encoding: .utf8
        )
        let nextSteps = try String(
            contentsOf: root.appendingPathComponent("NEXT_STEPS.md"),
            encoding: .utf8
        )
        let applicationGroups = try XCTUnwrap(entitlements["com.apple.security.application-groups"] as? [String])
        XCTAssertEqual(applicationGroups, ["group.app.kairo.shared"])
        XCTAssertNil(entitlements["com.apple.developer.homekit"])

        let collectedDataTypes = try XCTUnwrap(privacyManifest["NSPrivacyCollectedDataTypes"] as? [Any])
        let trackingDomains = try XCTUnwrap(privacyManifest["NSPrivacyTrackingDomains"] as? [Any])
        XCTAssertEqual(privacyManifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertTrue(collectedDataTypes.isEmpty)
        XCTAssertTrue(trackingDomains.isEmpty)

        for requiredPurposeString in [
            "NSCalendarsUsageDescription",
            "NSCalendarsFullAccessUsageDescription",
            "NSRemindersUsageDescription",
            "NSRemindersFullAccessUsageDescription",
            "NSContactsUsageDescription",
            "NSUserNotificationsUsageDescription"
        ] {
            XCTAssertNotNil(infoPlist[requiredPurposeString], requiredPurposeString)
        }
        for deferredPurposeString in [
            "NSHomeKitUsageDescription",
            "NSLocationWhenInUseUsageDescription",
            "NSPhotoLibraryUsageDescription",
            "NSCameraUsageDescription",
            "NSMicrophoneUsageDescription"
        ] {
            XCTAssertNil(infoPlist[deferredPurposeString], deferredPurposeString)
        }

        let forbiddenReviewClaims = [
            "iOS production local inference is complete",
            "live HomeKit control is complete",
            "reads all apps",
            "controls arbitrary app UI",
            "ChatGPT web-session reuse",
            "silently creates Apple Shortcuts"
        ]
        let reviewCopySources = [readiness, reviewNotes, nextSteps]
        for claim in forbiddenReviewClaims {
            for source in reviewCopySources {
                XCTAssertFalse(source.localizedCaseInsensitiveContains(claim), claim)
            }
        }
    }

    func testLocalModelDocsKeepRuntimeProofBoundaryExplicit() throws {
        let root = packageRootURL()
        let localModelFallback = try String(
            contentsOf: root.appendingPathComponent("docs/LOCAL_MODEL_FALLBACK.md"),
            encoding: .utf8
        )
        let readme = try String(
            contentsOf: root.appendingPathComponent("README.md"),
            encoding: .utf8
        )
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )

        XCTAssertTrue(localModelFallback.contains("## Current beta boundary"))
        XCTAssertTrue(localModelFallback.contains("catalog, explicit user-triggered download, select, delete, progress/cancel UI, checksum verification, trust-store verification"))
        XCTAssertTrue(localModelFallback.contains("does not yet ship an App Store-compatible iPhone production inference runtime"))
        XCTAssertTrue(localModelFallback.contains("not iPhone runtime proof"))
        XCTAssertTrue(localModelFallback.contains("pending-publication"))
        XCTAssertTrue(readiness.contains("| iOS production local model inference runtime | Planned |"))
        XCTAssertTrue(readiness.contains("macOS/dev reply checks and benchmark numbers are not iPhone runtime proof"))
        XCTAssertTrue(readiness.contains("iOS live wiring keeps the local-model reply check and benchmark runtime fail-closed until an App Store-compatible inference engine is implemented."))
        XCTAssertTrue(localModelFallback.contains("iOS live wiring keeps reply checks and benchmarks on the unavailable-runtime path until an App Store-compatible engine is explicitly implemented and verified on device."))
        XCTAssertTrue(readiness.contains("unknown/revoked/pending-publication/invalid signing keys"))
        XCTAssertTrue(readiness.contains("unknown, revoked, pending-publication, out-of-window, unsupported, or invalid P-256 signing keys"))
        XCTAssertTrue(readiness.contains("unknown/revoked/pending-publication/out-of-window/invalid signing-key gating"))
        XCTAssertTrue(localModelFallback.contains("unknown, revoked, pending-publication, out-of-window, unsupported, or invalid signing keys"))
        XCTAssertTrue(localModelFallback.contains("production key material is absent, unpublished, or mismatched"))
        XCTAssertTrue(readme.contains("| Local model catalog/download/select/delete | Scaffolded |"))
        XCTAssertTrue(readme.contains("progress/cancel UI, license approval, cleanup, checksum, and trust-store verification exist"))
        XCTAssertTrue(readme.contains("remaining blockers are production signed catalog/public-key publication and real-device runtime proof"))
        XCTAssertTrue(readme.contains("These simulator/package checks are not real-device sign-off."))
        XCTAssertTrue(readme.contains("Finish real-device beta sign-off before release"))
        XCTAssertFalse(readme.contains("| Local model catalog/download/select/delete | Implemented |"))
        XCTAssertFalse(readme.contains("remaining gaps are progress/cancel UI"))
    }

    func testRealDeviceSignOffDocsRequirePhysicalDeviceEvidence() throws {
        let root = packageRootURL()
        let signOff = try String(
            contentsOf: root.appendingPathComponent("docs/REAL_DEVICE_BETA_SIGNOFF.md"),
            encoding: .utf8
        )
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )
        let nextSteps = try String(
            contentsOf: root.appendingPathComponent("NEXT_STEPS.md"),
            encoding: .utf8
        )

        XCTAssertTrue(readiness.contains("docs/REAL_DEVICE_BETA_SIGNOFF.md"))
        XCTAssertTrue(nextSteps.contains("docs/REAL_DEVICE_BETA_SIGNOFF.md"))
        XCTAssertTrue(signOff.contains("Do not mark any item as passed from simulator runs, package tests, source-health tests, screenshots from `tmp/`, or code inspection alone."))
        XCTAssertTrue(signOff.contains("Required evidence must come from a reachable physical iPhone or iPad"))
        XCTAssertTrue(signOff.contains("Simulator, package-test, and XCUITest evidence may be linked as supporting coverage only; it is not real-device sign-off."))
        XCTAssertTrue(signOff.contains("## Install and launch proof chain"))
        XCTAssertTrue(signOff.contains("xcodebuild -destination 'id=<device-id>'"))
        XCTAssertTrue(signOff.contains("xcrun devicectl device install app --device <device-id> <path-to-app>"))
        XCTAssertTrue(signOff.contains("xcrun devicectl device info apps --device <device-id>"))
        XCTAssertTrue(signOff.contains("xcrun devicectl device process launch --device <device-id> app.kairo.ios"))
        XCTAssertTrue(signOff.contains("Do not treat a successful build, simulator install, TestFlight upload, or `xcodebuild` destination listing as proof"))
        XCTAssertTrue(signOff.contains("Blocked - device unavailable"))
        XCTAssertTrue(signOff.contains("Chat history restart persistence"))
        XCTAssertTrue(signOff.contains("App Intents Ask"))
        XCTAssertTrue(signOff.contains("App Intents Save"))
        XCTAssertTrue(signOff.contains("App Intents Search"))
        XCTAssertTrue(signOff.contains("Share Extension import"))
        XCTAssertTrue(signOff.contains("Local notification preview + confirm"))
        XCTAssertTrue(signOff.contains("Email handoff preview + confirm"))
        XCTAssertFalse(signOff.contains("| Pass |"))
    }

    func testIOSLiveEnvironmentDoesNotWireExternalCommandLocalModelRuntime() throws {
        let root = packageRootURL()
        let environmentSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/KairoEnvironment.swift"),
            encoding: .utf8
        )

        let macOSRuntimeStart = try XCTUnwrap(environmentSource.range(of: "#if os(macOS)"))
        let fallbackStart = try XCTUnwrap(environmentSource.range(of: "#else", range: macOSRuntimeStart.upperBound..<environmentSource.endIndex))
        let conditionalEnd = try XCTUnwrap(environmentSource.range(of: "#endif", range: fallbackStart.upperBound..<environmentSource.endIndex))
        let macOSRuntimeBlock = String(environmentSource[macOSRuntimeStart.upperBound..<fallbackStart.lowerBound])
        let nonMacOSRuntimeBlock = String(environmentSource[fallbackStart.upperBound..<conditionalEnd.lowerBound])

        XCTAssertTrue(macOSRuntimeBlock.contains("LocalModelExternalCommandRuntime"))
        XCTAssertTrue(macOSRuntimeBlock.contains("ProcessLocalModelCommandRunner()"))
        XCTAssertTrue(nonMacOSRuntimeBlock.contains("LocalModelBenchmarkService("))
        XCTAssertTrue(nonMacOSRuntimeBlock.contains("LocalModelReplyCheckService("))
        XCTAssertFalse(nonMacOSRuntimeBlock.contains("LocalModelExternalCommandRuntime"))
        XCTAssertFalse(nonMacOSRuntimeBlock.contains("ProcessLocalModelCommandRunner()"))
    }

    func testTrustStoreRunbookDocumentsRotationWithoutPrivateArtifacts() throws {
        let root = packageRootURL()
        let runbook = try String(
            contentsOf: root.appendingPathComponent("docs/TRUST_STORE_RUNBOOK.md"),
            encoding: .utf8
        )

        XCTAssertTrue(runbook.contains("AgentSkillManifestTrustStore"))
        XCTAssertTrue(runbook.contains("LocalModelCatalogTrustStore"))
        XCTAssertTrue(runbook.contains("Planned Rotation"))
        XCTAssertTrue(runbook.contains("Emergency Revocation"))
        XCTAssertTrue(runbook.contains("Release Gate"))
        XCTAssertTrue(runbook.contains("validUntil"))
        XCTAssertTrue(runbook.contains("out-of-window keys"))
        XCTAssertTrue(runbook.contains("revokedAt"))
        XCTAssertTrue(runbook.contains("publicationStatus"))
        XCTAssertTrue(runbook.contains("pendingPublication"))
        XCTAssertTrue(runbook.contains("pending-publication keys"))
        XCTAssertTrue(runbook.contains("Real-device evidence is still required for runtime claims"))
        XCTAssertTrue(runbook.contains("must not contain private signing keys"))
        XCTAssertTrue(runbook.contains(".gguf"))
        XCTAssertFalse(runbook.contains("-----BEGIN"))
        XCTAssertFalse(runbook.localizedCaseInsensitiveContains("private signing key:"))
        XCTAssertFalse(runbook.localizedCaseInsensitiveContains("api token:"))
    }

    func testTrustStoreRunbookIsReferencedByReleaseHardeningDocs() throws {
        let root = packageRootURL()
        let skillManagement = try String(
            contentsOf: root.appendingPathComponent("docs/SKILL_MANAGEMENT.md"),
            encoding: .utf8
        )
        let localModelFallback = try String(
            contentsOf: root.appendingPathComponent("docs/LOCAL_MODEL_FALLBACK.md"),
            encoding: .utf8
        )
        let nextSteps = try String(
            contentsOf: root.appendingPathComponent("NEXT_STEPS.md"),
            encoding: .utf8
        )
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )
        let catalogReleaseChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/CATALOG_RELEASE_CHECKLIST.md"),
            encoding: .utf8
        )

        for source in [skillManagement, localModelFallback, nextSteps, readiness] {
            XCTAssertTrue(source.contains("docs/TRUST_STORE_RUNBOOK.md"))
            XCTAssertTrue(source.contains("docs/CATALOG_RELEASE_CHECKLIST.md"))
        }
        XCTAssertTrue(skillManagement.contains("Publish the production signed `skills.json` catalog"))
        XCTAssertTrue(skillManagement.contains("marketplace trust-store key material from the standalone repo"))
        XCTAssertTrue(skillManagement.contains("catalogSignatureStatus=referenceUnsigned"))
        XCTAssertTrue(skillManagement.contains("must not be treated as production signed catalog evidence"))
        XCTAssertTrue(skillManagement.contains("app-side trust keys now fail closed while `publicationStatus=pendingPublication`"))
        XCTAssertTrue(skillManagement.contains("blocking `pendingPublication` release keys until standalone marketplace publication is complete"))
        XCTAssertTrue(skillManagement.contains("publicationStatus"))
        XCTAssertTrue(skillManagement.contains("pendingPublication"))
        XCTAssertTrue(skillManagement.contains("Static marketplace seed entries and signed manifests carry compatibility requirements"))
        XCTAssertTrue(skillManagement.contains("OAuth/provider readiness, HomeKit entitlement, and minimum iOS version"))
        XCTAssertTrue(skillManagement.contains("package tests cover prompt-context availability through the live effective catalog"))
        XCTAssertTrue(skillManagement.contains("Run real-device Access sign-off before App Review"))
        XCTAssertTrue(skillManagement.contains("Simulator UI smoke and package tests remain support evidence only"))
        XCTAssertTrue(localModelFallback.contains("production signed catalog publication"))
        XCTAssertTrue(localModelFallback.contains("實機 iPhone runtime proof"))
        XCTAssertTrue(catalogReleaseChecklist.contains("easonwumac/kairo-skills"))
        XCTAssertTrue(catalogReleaseChecklist.contains("easonwumac/kairo-models"))
        XCTAssertTrue(catalogReleaseChecklist.contains("publicKeyBase64"))
        XCTAssertTrue(catalogReleaseChecklist.contains("publicationStatus"))
        XCTAssertTrue(catalogReleaseChecklist.contains("publicationStatus=pendingPublication"))
        XCTAssertTrue(catalogReleaseChecklist.contains("catalogSignatureStatus=referenceUnsigned"))
        XCTAssertTrue(catalogReleaseChecklist.contains("not production signed catalog evidence"))
        XCTAssertTrue(catalogReleaseChecklist.contains("Keep default app-side marketplace release keys at `publicationStatus=pendingPublication`"))
        XCTAssertTrue(catalogReleaseChecklist.contains("pending-publication-key"))
        XCTAssertTrue(catalogReleaseChecklist.contains("compatibility-blocked skills remain preview-only"))
        XCTAssertTrue(catalogReleaseChecklist.contains("App-side trust-store validation is not proof that production catalogs have been published."))
        XCTAssertTrue(catalogReleaseChecklist.contains("Signed catalog validation is not proof of iPhone local inference."))
        XCTAssertTrue(catalogReleaseChecklist.contains("must not contain private signing keys"))
        XCTAssertTrue(catalogReleaseChecklist.contains(".gguf"))
        XCTAssertFalse(catalogReleaseChecklist.contains("-----BEGIN"))
        XCTAssertFalse(catalogReleaseChecklist.localizedCaseInsensitiveContains("private signing key:"))
        XCTAssertFalse(catalogReleaseChecklist.localizedCaseInsensitiveContains("api token:"))
    }

    func testAppStoreSubmissionChecklistGatesReleaseEvidence() throws {
        let root = packageRootURL()
        let submissionChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_SUBMISSION_CHECKLIST.md"),
            encoding: .utf8
        )
        let releaseHygiene = try String(
            contentsOf: root.appendingPathComponent("docs/RELEASE_HYGIENE.md"),
            encoding: .utf8
        )
        let iosTargetReadiness = try String(
            contentsOf: root.appendingPathComponent("docs/IOS_TARGET_READINESS.md"),
            encoding: .utf8
        )
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )
        let nextSteps = try String(
            contentsOf: root.appendingPathComponent("NEXT_STEPS.md"),
            encoding: .utf8
        )
        let githubPublishing = try String(
            contentsOf: root.appendingPathComponent("docs/GITHUB_PUBLISHING.md"),
            encoding: .utf8
        )

        XCTAssertTrue(readiness.contains("docs/APP_STORE_SUBMISSION_CHECKLIST.md"))
        XCTAssertTrue(nextSteps.contains("docs/APP_STORE_SUBMISSION_CHECKLIST.md"))
        XCTAssertTrue(nextSteps.contains("docs/RELEASE_HYGIENE.md"))

        let requiredDocuments = [
            "docs/APP_STORE_READINESS.md",
            "docs/APP_REVIEW_NOTES.md",
            "docs/PRIVACY_LABELS_CHECKLIST.md",
            "docs/REAL_DEVICE_BETA_SIGNOFF.md",
            "docs/IOS_TARGET_READINESS.md",
            "docs/CATALOG_RELEASE_CHECKLIST.md",
            "docs/TRUST_STORE_RUNBOOK.md",
            "docs/RELEASE_HYGIENE.md"
        ]
        for document in requiredDocuments {
            XCTAssertTrue(submissionChecklist.contains(document), document)
        }

        let requiredGates = [
            "Real-device sign-off has no `Blocked - device unavailable` rows",
            "App Review notes do not claim iOS production local inference",
            "Privacy labels match `Kairo/Resources/PrivacyInfo.xcprivacy`",
            "Privacy-label change triggers are still absent from the submitted binary",
            "Purpose strings match current beta capabilities",
            "iOS target readiness has signed-build evidence for Apple Developer entitlement resolution",
            "iOS production inference runtime, which remains Planned",
            "standalone signed catalogs and public trust-store metadata",
            "Focused scans find no secrets, tokens, private keys, generated credentials, model weights, `.gguf`, tokenizer blobs, model packages, or downloaded caches",
            "Latest `main` GitHub Actions run for `swift test` is successful for the submitted commit",
            "`git status --short --branch` is clean for tracked files before handoff"
        ]
        for gate in requiredGates {
            XCTAssertTrue(submissionChecklist.contains(gate), gate)
        }

        XCTAssertTrue(submissionChecklist.contains("Simulator UI smoke, package tests, source-health tests, and screenshots from `tmp/` are support evidence only."))
        XCTAssertTrue(submissionChecklist.contains("App-side signature verification proves fail-closed validation behavior, not that production catalogs have been published."))
        XCTAssertTrue(submissionChecklist.contains("macOS/dev local-model reply checks and benchmark adapters are not iPhone runtime proof."))
        XCTAssertTrue(submissionChecklist.contains("Current deletion proof is on-device only"))
        XCTAssertTrue(submissionChecklist.contains("GitHub Actions success must match the submitted commit `HEAD`"))
        XCTAssertFalse(submissionChecklist.localizedCaseInsensitiveContains("production local inference is complete"))
        XCTAssertFalse(submissionChecklist.localizedCaseInsensitiveContains("live HomeKit control is complete"))
        XCTAssertFalse(submissionChecklist.localizedCaseInsensitiveContains("silently creates Apple Shortcuts"))

        XCTAssertTrue(releaseHygiene.contains("swift test"))
        XCTAssertTrue(releaseHygiene.contains("xcodegen generate"))
        XCTAssertTrue(releaseHygiene.contains("git diff --check"))
        XCTAssertTrue(releaseHygiene.contains("AKIA[0-9A-Z]{16}"))
        XCTAssertTrue(releaseHygiene.contains("AIza[0-9A-Za-z_-]{35}"))
        XCTAssertTrue(releaseHygiene.contains("github_pat_"))
        XCTAssertTrue(releaseHygiene.contains("client[_-]secret"))
        XCTAssertTrue(releaseHygiene.contains("tokenizer.json"))
        XCTAssertTrue(releaseHygiene.contains("tokenizer.model"))
        XCTAssertTrue(releaseHygiene.contains("*.gguf"))
        XCTAssertTrue(releaseHygiene.contains("*.safetensors"))
        XCTAssertTrue(releaseHygiene.contains("*.mlmodel"))
        XCTAssertTrue(releaseHygiene.contains("*.pt"))
        XCTAssertTrue(releaseHygiene.contains("*.pth"))
        XCTAssertTrue(releaseHygiene.contains("`headSha` must equal `HEAD`"))
        XCTAssertTrue(releaseHygiene.contains("Do not stage `tmp/` screenshots as release evidence."))
        XCTAssertTrue(releaseHygiene.contains("known false-positive OAuth token endpoint URL fragment"))
        XCTAssertTrue(githubPublishing.contains("This repository is already published"))
        XCTAssertTrue(githubPublishing.contains("docs/RELEASE_HYGIENE.md"))
        XCTAssertTrue(githubPublishing.contains("docs/APP_STORE_SUBMISSION_CHECKLIST.md"))
        XCTAssertTrue(githubPublishing.contains("headSha` equals `HEAD`"))
        XCTAssertTrue(githubPublishing.contains("Do not submit or cite `tmp/` screenshots as physical-device evidence."))
        XCTAssertFalse(githubPublishing.contains("git init"))
        XCTAssertFalse(githubPublishing.contains("gh repo create"))

        XCTAssertTrue(iosTargetReadiness.contains("## Release evidence boundary"))
        XCTAssertTrue(iosTargetReadiness.contains("all listed physical devices were `unavailable`"))
        XCTAssertTrue(iosTargetReadiness.contains("requires Apple Developer team signing evidence"))
        XCTAssertTrue(iosTargetReadiness.contains("requires signed physical-device runtime evidence"))
        XCTAssertTrue(iosTargetReadiness.contains("requires physical-device permission prompts"))
        XCTAssertTrue(iosTargetReadiness.contains("requires inspection of the signed app bundle/archive"))
        XCTAssertTrue(iosTargetReadiness.contains("signed `xcodebuild` for `id=<device-id>`"))
        XCTAssertTrue(iosTargetReadiness.contains("built `.app` exists in derived data"))
        XCTAssertTrue(iosTargetReadiness.contains("xcrun devicectl device install app"))
        XCTAssertTrue(iosTargetReadiness.contains("xcrun devicectl device info apps --device <device-id>` lists `app.kairo.ios`"))
        XCTAssertTrue(iosTargetReadiness.contains("xcrun devicectl device process launch --device <device-id> app.kairo.ios"))
        XCTAssertTrue(iosTargetReadiness.contains("simulator build evidence only"))
    }

    func testRoadmapKeepsReleaseBlockingBoundariesCurrent() throws {
        let root = packageRootURL()
        let roadmap = try String(
            contentsOf: root.appendingPathComponent("docs/ROADMAP.md"),
            encoding: .utf8
        )

        XCTAssertTrue(roadmap.contains("Local model catalog/download/select/delete | Scaffolded"))
        XCTAssertTrue(roadmap.contains("production signed catalog publication and real-device iOS runtime proof remain release blockers"))
        XCTAssertTrue(roadmap.contains("publicationStatus=pendingPublication"))
        XCTAssertTrue(roadmap.contains("Real-device smoke checks for Chat, Memory, Access, Settings, Share Extension, App Intents Ask/Save/Search"))
        XCTAssertTrue(roadmap.contains("Production signed skill and model catalog publication from standalone repositories"))
        XCTAssertTrue(roadmap.contains("Published production skill catalog key material after `pendingPublication` keys are promoted"))
        XCTAssertTrue(roadmap.contains("Published production model catalog with device gating, rollout metadata, and real-device iPhone runtime proof"))
        XCTAssertFalse(roadmap.contains("| Local model catalog/download/select/delete | Implemented |"))
        XCTAssertFalse(roadmap.contains("Signed production skill catalog key rotation/revocation."))
    }

    func testCapabilityMatrixKeepsReleaseBlockingBoundariesCurrent() throws {
        let root = packageRootURL()
        let capabilityMatrix = try String(
            contentsOf: root.appendingPathComponent("docs/CAPABILITY_MATRIX.md"),
            encoding: .utf8
        )

        XCTAssertTrue(capabilityMatrix.contains("| Local model catalog | Scaffolded |"))
        XCTAssertTrue(capabilityMatrix.contains("| Local model download/select/delete | Scaffolded |"))
        XCTAssertTrue(capabilityMatrix.contains("production signed catalog/public-key publication remains release-blocking"))
        XCTAssertTrue(capabilityMatrix.contains("default release keys must stay `publicationStatus=pendingPublication`"))
        XCTAssertTrue(capabilityMatrix.contains("real-device iOS runtime proof remains release-blocking"))
        XCTAssertTrue(capabilityMatrix.contains("catalog/download/select/delete 目前是 beta scaffolded path，不是 iPhone production inference proof"))
        XCTAssertTrue(capabilityMatrix.contains("source/package validation 只能證明 fail-closed behavior"))
        XCTAssertTrue(capabilityMatrix.contains("不能取代 production publication 或真機 runtime sign-off"))
        XCTAssertFalse(capabilityMatrix.contains("| Local model catalog | Implemented |"))
        XCTAssertFalse(capabilityMatrix.contains("| Local model download/select/delete | Implemented |"))
    }

    func testShortcutDemoCatalogStaysSplitAcrossFocusedFiles() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let splitFiles = [
            "ShortcutDemoCatalog.swift": "public struct ShortcutDemoCatalog",
            "ShortcutDemoRecipeDefinitions.swift": "static let officialRecipes",
            "ShortcutDemoEmailDefinitions.swift": "static let communicationRecipes",
            "ShortcutDemoPhoneDefinitions.swift": "static let phoneRecipes",
            "ShortcutDemoWebDefinitions.swift": "static let webRecipes",
            "ShortcutDemoContactDefinitions.swift": "static let contactRecipes",
            "ShortcutDemoHomeDefinitions.swift": "static let homeRecipes",
            "ShortcutDemoModels.swift": "public struct ShortcutDemoRecipe",
            "ShortcutDemoRecipeRunner.swift": "public actor ShortcutDemoRecipeRunner"
        ]

        for (fileName, requiredSymbol) in splitFiles {
            let sourceURL = services.appendingPathComponent(fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), fileName)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            XCTAssertTrue(source.contains(requiredSymbol), fileName)
        }

        let catalogSource = try String(
            contentsOf: services.appendingPathComponent("ShortcutDemoCatalog.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(catalogSource.contains("daily-briefing"))

        let lineBudgets = [
            "ShortcutDemoCatalog.swift": 80,
            "ShortcutDemoModels.swift": 220,
            "ShortcutDemoRecipeDefinitions.swift": 500,
            "ShortcutDemoEmailDefinitions.swift": 260,
            "ShortcutDemoPhoneDefinitions.swift": 100,
            "ShortcutDemoWebDefinitions.swift": 120,
            "ShortcutDemoContactDefinitions.swift": 100,
            "ShortcutDemoHomeDefinitions.swift": 140,
            "ShortcutDemoRecipeRunner.swift": 120
        ]
        for (fileName, maxLines) in lineBudgets {
            let source = try String(contentsOf: services.appendingPathComponent(fileName), encoding: .utf8)
            XCTAssertLessThan(source.split(separator: "\n").count, maxLines, fileName)
        }
    }

    func testShortcutNodeRuntimeModelsStaySplit() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let runtimeURL = services.appendingPathComponent("ShortcutNodeRuntime.swift")
        let modelsURL = services.appendingPathComponent("ShortcutNodeModels.swift")

        XCTAssertTrue(FileManager.default.fileExists(atPath: runtimeURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: modelsURL.path))

        let runtimeSource = try String(contentsOf: runtimeURL, encoding: .utf8)
        let modelsSource = try String(contentsOf: modelsURL, encoding: .utf8)

        XCTAssertTrue(runtimeSource.contains("public actor ShortcutNodeRuntime"))
        XCTAssertFalse(runtimeSource.contains("public enum ShortcutNodeKind"))
        XCTAssertFalse(runtimeSource.contains("public struct ShortcutNodeOutput"))
        XCTAssertTrue(modelsSource.contains("public enum ShortcutNodeKind"))
        XCTAssertTrue(modelsSource.contains("public struct ShortcutNodeInput"))
        XCTAssertTrue(modelsSource.contains("public struct ShortcutNodeOutput"))
        XCTAssertTrue(modelsSource.contains("public enum ShortcutNodeRuntimeError"))
        XCTAssertLessThan(runtimeSource.split(separator: "\n").count, 900)
        XCTAssertLessThan(modelsSource.split(separator: "\n").count, 220)
    }

    private func propertyListDictionary(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        let propertyList = try PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        return try XCTUnwrap(propertyList as? [String: Any], url.path)
    }

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        return url.deletingLastPathComponent()
    }
}
