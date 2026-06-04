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
            options: [.skipsHiddenFiles]
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
            options: [.skipsHiddenFiles]
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

    func testSandboxActionSupportStaysSplitAcrossFocusedFiles() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let splitFiles = [
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
            XCTAssertLessThan(source.split(separator: "\n").count, 320, fileName)
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
        let privacyLabelsChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/PRIVACY_LABELS_CHECKLIST.md"),
            encoding: .utf8
        )
        let reviewNotes = try String(
            contentsOf: root.appendingPathComponent("docs/APP_REVIEW_NOTES.md"),
            encoding: .utf8
        )

        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertTrue((manifest["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
        XCTAssertTrue((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)

        let accessedAPITypes = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        XCTAssertEqual(accessedAPITypes.count, 1)
        XCTAssertEqual(accessedAPITypes.first?["NSPrivacyAccessedAPIType"] as? String, "NSPrivacyAccessedAPICategoryUserDefaults")
        XCTAssertEqual(accessedAPITypes.first?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
        XCTAssertTrue(privacyLabelsChecklist.contains("Tracking: No."))
        XCTAssertTrue(privacyLabelsChecklist.contains("Data collected: No collected data."))
        XCTAssertTrue(privacyLabelsChecklist.contains("Tracking domains: None."))
        XCTAssertTrue(privacyLabelsChecklist.contains("Required Reason API usage: UserDefaults only, reason `CA92.1`."))
        XCTAssertTrue(privacyLabelsChecklist.contains("no analytics SDK"))
        XCTAssertTrue(privacyLabelsChecklist.contains("no backend account"))
        XCTAssertTrue(privacyLabelsChecklist.contains("docs/REAL_DEVICE_BETA_SIGNOFF.md"))
        let privacyChangeTriggers = [
            "no analytics SDK",
            "no backend account",
            "no cloud memory sync",
            "no crash/telemetry collection provider",
            "no provider-side sync beyond explicit user-configured API calls"
        ]
        for trigger in privacyChangeTriggers {
            XCTAssertTrue(reviewNotes.contains(trigger), trigger)
        }
        XCTAssertFalse(privacyLabelsChecklist.localizedCaseInsensitiveContains("tracking: yes"))
        XCTAssertFalse(privacyLabelsChecklist.localizedCaseInsensitiveContains("data collected: yes"))
    }

    func testBetaInfoPlistPurposeStringsMatchEnabledCapabilities() throws {
        let root = packageRootURL()
        let appInfoPlistURL = root.appendingPathComponent("Config/KairoApp-Info.plist")
        let data = try Data(contentsOf: appInfoPlistURL)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any]
        )
        let privacyLabelsChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/PRIVACY_LABELS_CHECKLIST.md"),
            encoding: .utf8
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
        XCTAssertTrue(privacyLabelsChecklist.contains("NSCalendarsFullAccessUsageDescription"))
        XCTAssertTrue(privacyLabelsChecklist.contains("NSUserNotificationsUsageDescription"))
        XCTAssertTrue(privacyLabelsChecklist.contains("NSContactsUsageDescription"))
        XCTAssertTrue(privacyLabelsChecklist.contains("Future-only purpose strings must remain absent from the beta plist"))
        XCTAssertTrue(privacyLabelsChecklist.contains("NSHomeKitUsageDescription"))
        XCTAssertTrue(privacyLabelsChecklist.contains("NSLocationWhenInUseUsageDescription"))
        XCTAssertTrue(privacyLabelsChecklist.contains("NSPhotoLibraryUsageDescription"))
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
        let entitlements = try String(
            contentsOf: root.appendingPathComponent("Config/KairoApp.entitlements"),
            encoding: .utf8
        )
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

        XCTAssertTrue(entitlements.contains("com.apple.security.application-groups"))
        XCTAssertFalse(entitlements.contains("com.apple.developer.homekit"))
        XCTAssertTrue(readiness.contains("Privacy Labels scope"))
        XCTAssertTrue(readiness.contains("docs/PRIVACY_LABELS_CHECKLIST.md"))
        XCTAssertTrue(readiness.contains("docs/APP_REVIEW_NOTES.md"))
        XCTAssertTrue(readiness.contains("no collected data"))
        XCTAssertTrue(readiness.contains("no tracking"))
        XCTAssertTrue(readiness.contains("[x] HomeKit live control intentionally remains disabled for beta"))
        XCTAssertTrue(readiness.contains("beta plist omits `NSHomeKitUsageDescription`"))
        XCTAssertFalse(readiness.contains("[ ] HomeKit live control remains disabled for beta"))

        let requiredReviewBoundaries = [
            "Kairo does not read other apps' private containers, control arbitrary app UI, or bypass iOS permissions.",
            "On-device deletion is user-triggered for chat history, memory JSON/export content, downloaded local models, saved API keys, OAuth tokens, and metadata-only audit logs.",
            "For the current beta, App Privacy Labels should remain no tracking and no collected data.",
            "The submitted binary has no analytics SDK, no backend account, no cloud memory sync, no crash/telemetry collection provider, and no provider-side sync beyond explicit user-configured API calls.",
            "Local model catalog/download/select/delete are present, but iOS production local inference is not complete.",
            "macOS/dev reply checks and benchmark numbers are not iPhone runtime proof.",
            "HomeKit is limited to preview/demo/test scaffolding in this beta.",
            "Kairo does not create, edit, install, or reorder Apple Shortcuts silently."
        ]
        for boundary in requiredReviewBoundaries {
            XCTAssertTrue(readiness.contains(boundary), boundary)
            XCTAssertTrue(reviewNotes.contains(boundary), boundary)
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
        XCTAssertTrue(readme.contains("progress/cancel UI, and runtime-unavailable handling are in the beta path"))
        XCTAssertTrue(readme.contains("remaining blockers are production signed catalog/public-key publication and real-device runtime proof"))
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
        XCTAssertTrue(skillManagement.contains("Publish the production marketplace trust-store key material"))
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
        XCTAssertTrue(readiness.contains("Skill marketplace and local model release keys must remain `publicationStatus=pendingPublication`"))
        XCTAssertTrue(readiness.contains("Marketplace trust store supports key rotation, publication, and revocation metadata"))
    }

    func testAppStoreSubmissionChecklistGatesReleaseEvidence() throws {
        let root = packageRootURL()
        let submissionChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_SUBMISSION_CHECKLIST.md"),
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

        XCTAssertTrue(readiness.contains("docs/APP_STORE_SUBMISSION_CHECKLIST.md"))
        XCTAssertTrue(nextSteps.contains("docs/APP_STORE_SUBMISSION_CHECKLIST.md"))

        let requiredDocuments = [
            "docs/APP_STORE_READINESS.md",
            "docs/APP_REVIEW_NOTES.md",
            "docs/PRIVACY_LABELS_CHECKLIST.md",
            "docs/REAL_DEVICE_BETA_SIGNOFF.md",
            "docs/IOS_TARGET_READINESS.md",
            "docs/CATALOG_RELEASE_CHECKLIST.md",
            "docs/TRUST_STORE_RUNBOOK.md"
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
        XCTAssertFalse(submissionChecklist.localizedCaseInsensitiveContains("production local inference is complete"))
        XCTAssertFalse(submissionChecklist.localizedCaseInsensitiveContains("live HomeKit control is complete"))
        XCTAssertFalse(submissionChecklist.localizedCaseInsensitiveContains("silently creates Apple Shortcuts"))

        XCTAssertTrue(iosTargetReadiness.contains("## Release evidence boundary"))
        XCTAssertTrue(iosTargetReadiness.contains("all listed physical devices were `unavailable`"))
        XCTAssertTrue(iosTargetReadiness.contains("requires Apple Developer team signing evidence"))
        XCTAssertTrue(iosTargetReadiness.contains("requires signed physical-device runtime evidence"))
        XCTAssertTrue(iosTargetReadiness.contains("requires physical-device permission prompts"))
        XCTAssertTrue(iosTargetReadiness.contains("requires inspection of the signed app bundle/archive"))
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

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        return url.deletingLastPathComponent()
    }
}
