import XCTest

final class KairoAppSmokeUITests: XCTestCase {
    enum SearchDirection: Equatable {
        case down
        case up
        case both
    }

    var app: XCUIApplication!
    let localModelExpectations = [
        ("qwen3-5-0-8b-q4-k-m", "Qwen3.5 0.8B Q4_K_M"),
        ("llama3-2-1b-instruct-q4-k-m", "Llama 3.2 1B Instruct Q4_K_M")
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--reset-ui-testing-data")
        app.launch()
    }

    func testLaunchDrawerChatAndSettingsSmokeFlow() throws {
        assertPrimaryDrawerItemsExist()
        sendChatMessage()
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")
        scrollTowardTop()
        XCTAssertTrue(findButton("access.skills.marketplace-refresh", direction: .down, maxSwipes: 6).exists)
        XCTAssertTrue(findElement("access.skill.homekit-evening-scene", direction: .down, maxSwipes: 8).exists)
        openSettingsAndVerifyAPIKeyStatus(verifyAllLocalModels: false)
    }

    func testSettingsLocalModelCatalogListsDownloadableModels() throws {
        relaunchForUITesting(initialSection: "models")
        openModelsAndVerifyLocalModelCatalog(verifyAllLocalModels: false, selectFromDrawer: false)
        XCTAssertTrue(anyElement("settings.models.llama3-2-1b-instruct-q4-k-m.name").exists)
        XCTAssertFalse(anyElement("settings.models.show-more").exists)
    }

    func testSettingsLocalModelDownloadRequiresConfirmationPreview() throws {
        relaunchForUITesting(initialSection: "models")

        let modelID = "qwen3-5-0-8b-q4-k-m"
        let download = findButton("settings.models.\(modelID).download", direction: .down, maxSwipes: 1)
        XCTAssertTrue(download.waitForExistence(timeout: 5))
        download.tap()

        XCTAssertTrue(findElement("settings.models.\(modelID).download-preview", direction: .both, maxSwipes: 1).waitForExistence(timeout: 3))
        XCTAssertTrue(findStaticText(containing: "Download requires explicit approval.", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Apache-2.0", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("settings.models.\(modelID).download-confirm", direction: .both, maxSwipes: 1).exists)

        let cancel = findButton("settings.models.\(modelID).download-cancel", direction: .both, maxSwipes: 1)
        XCTAssertTrue(cancel.exists)
        cancel.tap()
        XCTAssertFalse(anyElement("settings.models.\(modelID).download-preview").exists)
    }

    func testSettingsExpandedModelCatalogKeepsPopularStarterRowsVisible() throws {
        relaunchForUITesting(initialSection: "models", seedExpandedLocalModelCatalog: true)

        XCTAssertTrue(anyElement("settings.models.screen").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("settings.models.qwen3-5-0-8b-q4-k-m.name").exists)
        XCTAssertTrue(anyElement("settings.models.llama3-2-1b-instruct-q4-k-m.name").exists)
        XCTAssertTrue(findElement("settings.models.trimmed-note", direction: .down, maxSwipes: 2).waitForExistence(timeout: 3))
        XCTAssertFalse(anyElement("settings.models.remote-catalog-test-model-q4-k-m.name").exists)
        XCTAssertFalse(anyElement("settings.models.show-more").exists)
    }

    func testChatComposerSurfaceIsTappableAndSends() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()

        XCTAssertTrue(findButton("chat.tools.menu", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(anyElement("chat.composer.surface").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.composer.input-shell").exists)

        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.exists)
        composer.tap()
        composer.typeText("Run the polished composer e2e check")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.user").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
    }

    func testChatMessageReplyPreviewAndCopyControlsExist() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()

        let copyButton = firstHittableButtonIdentifier(beginningWith: "chat.message.copy.")
        XCTAssertTrue(copyButton.waitForExistence(timeout: 5))

        let replyButton = firstHittableButtonIdentifier(beginningWith: "chat.message.reply.")
        XCTAssertTrue(replyButton.exists)
        replyButton.tap()

        XCTAssertTrue(anyElement("chat.reply-preview").waitForExistence(timeout: 3))
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.exists)
        composer.tap()
        composer.typeText("Reply smoke check")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(findStaticText(containing: "Replying to", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
    }

    func testSettingsShowsQwenBenchmarkFlowRequiresDownload() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.models", label: "Models")

        XCTAssertTrue(findElement("settings.models.local", direction: .down).exists)
        XCTAssertTrue(findElement("settings.models.qwen3-5-0-8b-q4-k-m.name", direction: .down, maxSwipes: 8).exists)
        XCTAssertTrue(findElement("settings.models.qwen3-5-0-8b-q4-k-m.benchmark", direction: .down, maxSwipes: 2).exists)
        XCTAssertTrue(findStaticText(containing: "MLX ref", direction: .both).exists)
        XCTAssertTrue(findStaticText(containing: "iPhone not verified", direction: .both).exists)

        let benchmarkButton = findButton("settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run", direction: .down, maxSwipes: 2)
        XCTAssertTrue(benchmarkButton.exists)
        benchmarkButton.tap()

        XCTAssertTrue(findElement("settings.models.benchmark-message", direction: .both, maxSwipes: 2).exists)
        XCTAssertTrue(findStaticText(containing: "請先下載 Qwen3.5 0.8B Q4_K_M 後再跑 benchmark。", direction: .both, maxSwipes: 2).exists)
    }

    func testSettingsRunsInstalledLocalModelReplyCheck() throws {
        relaunchWithInstalledLocalModelForTesting(initialSection: "models")

        XCTAssertTrue(findElement("settings.models.local", direction: .down).exists)
        XCTAssertTrue(findElement("settings.models.qwen3-5-0-8b-q4-k-m.name", direction: .down, maxSwipes: 8).exists)
        let replyCheckButton = findButton("settings.models.qwen3-5-0-8b-q4-k-m.reply-check", direction: .down, maxSwipes: 2)
        XCTAssertTrue(replyCheckButton.exists)
        replyCheckButton.tap()

        let message = findElement("settings.models.benchmark-message", direction: .both, maxSwipes: 2)
        XCTAssertTrue(message.exists)
        XCTAssertTrue(findStaticText(containing: "Local model reply is alive.", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "38.5 gen tok/s", direction: .both, maxSwipes: 1).exists)
    }

    func testSettingsShowsShortcutDemoInputOutputContracts() throws {
        relaunchForUITesting(initialSection: "settings", settingsShortcutDemosOnly: true)

        XCTAssertTrue(findElement("settings.shortcuts.demos", direction: .down).exists)
        verifyShortcutDemoContract(
            id: "daily-briefing",
            titleText: "Daily Briefing",
            stepText: "1 step: dailyBriefing",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: displayText, fields.briefing, fields.taskCount, tasks",
            sampleText: "Today's agenda"
        )
        verifyShortcutDemoContract(
            id: "save-shared-text",
            titleText: "Save Shared Text",
            stepText: "2 steps: saveMemory -> extractTasks",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: memoryID, fields.taskCount, tasks, fields.chainText, reminderDrafts",
            sampleText: "User research note"
        )
        verifyShortcutDemoContract(
            id: "phone-call-handoff",
            titleText: "Phone Call Handoff",
            stepText: "1 step: preparePhoneCallHandoff",
            inputText: "Input: text, sourceName, variables.phoneNumber, variables.label",
            outputText: "Output: fields.phoneCallHandoffCount, fields.phoneCallNumber, fields.phoneCallRequiresConfirmation",
            sampleText: "Call Alex"
        )
    }

    func testShortcutsSurfaceShowsNodeDemoContracts() throws {
        relaunchForUITesting(initialSection: "shortcuts")

        XCTAssertTrue(findElement("automations.shortcut-demos", direction: .down).exists)
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "request-to-recipe-draft",
            titleText: "Request to Recipe Draft",
            stepText: "1 step: createRecipeDraft",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: fields.recipeID, fields.recipeTitle, fields.recipeStepCount",
            sampleText: "每天早上整理今天事情"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "meeting-text-to-calendar-draft",
            titleText: "Meeting Text to Calendar Draft",
            stepText: "1 step: createCalendarDraft",
            inputText: "Input: text, sourceName, variables.startDateISO, variables.endDateISO",
            outputText: "Output: fields.calendarDraftCount, fields.calendarTitle, fields.calendarRequiresConfirmation",
            sampleText: "Kairo roadmap review"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "email-draft-from-shared-text",
            titleText: "Email Draft from Shared Text",
            stepText: "1 step: createEmailDraft",
            inputText: "Input: text, sourceName, variables.recipient, variables.subject",
            outputText: "Output: fields.emailDraftCount, fields.emailSubject, fields.emailRequiresConfirmation",
            sampleText: "ops@example.com"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "message-reply-handoff",
            titleText: "Message Reply Handoff",
            stepText: "1 step: prepareMessageHandoff",
            inputText: "Input: text, sourceName, variables.recipient, variables.body",
            outputText: "Output: fields.messageHandoffCount, fields.messageBodyInURL, fields.messageRequiresConfirmation",
            sampleText: "Please tell Alex"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "phone-call-handoff",
            titleText: "Phone Call Handoff",
            stepText: "1 step: preparePhoneCallHandoff",
            inputText: "Input: text, sourceName, variables.phoneNumber, variables.label",
            outputText: "Output: fields.phoneCallHandoffCount, fields.phoneCallNumber, fields.phoneCallRequiresConfirmation",
            sampleText: "Call Alex"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "web-search-handoff",
            titleText: "Web Search Handoff",
            stepText: "1 step: prepareWebSearchHandoff",
            inputText: "Input: text, sourceName, variables.query",
            outputText: "Output: fields.webSearchHandoffCount, fields.webSearchQuery, fields.webSearchRequiresConfirmation",
            sampleText: "SwiftUI App Intents examples"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "contact-draft-from-shared-text",
            titleText: "Contact Draft from Shared Text",
            stepText: "1 step: createContactDraft",
            inputText: "Input: text, sourceName, variables.name, variables.phone, variables.email, variables.notes",
            outputText: "Output: fields.contactDraftCount, fields.contactDisplayName, fields.contactRequiresConfirmation",
            sampleText: "Alex Chen"
        )
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "generic-node-runner",
            titleText: "Generic Node Runner",
            stepText: "2 steps: summarize -> extractTasks",
            inputText: "Input: nodeKind, inputJSON",
            outputText: "Output: outputJSON, displayText, fields.taskCount, fields.chainText",
            sampleText: "Shortcut dictionary"
        )

        let previewSample = findButton("automations.shortcut-demo.generic-node-runner.preview-sample", direction: .both, maxSwipes: 2)
        XCTAssertTrue(previewSample.exists)
        previewSample.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.generic-node-runner.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Sample Generic Node Runner", direction: .both, maxSwipes: 2).exists)

        let calendarPreview = findButton("automations.shortcut-demo.meeting-text-to-calendar-draft.preview-sample", direction: .both, maxSwipes: 4)
        XCTAssertTrue(calendarPreview.exists)
        calendarPreview.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.meeting-text-to-calendar-draft.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "1 calendar drafts", direction: .both, maxSwipes: 2).exists)

        let emailPreview = findButton("automations.shortcut-demo.email-draft-from-shared-text.preview-sample", direction: .both, maxSwipes: 3)
        XCTAssertTrue(emailPreview.exists)
        emailPreview.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.email-draft-from-shared-text.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "1 email drafts", direction: .both, maxSwipes: 2).exists)

        let messagePreview = findButton("automations.shortcut-demo.message-reply-handoff.preview-sample", direction: .both, maxSwipes: 3)
        XCTAssertTrue(messagePreview.exists)
        messagePreview.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.message-reply-handoff.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Messages handoff ready", direction: .both, maxSwipes: 2).exists)

        let phonePreview = findButton("automations.shortcut-demo.phone-call-handoff.preview-sample", direction: .both, maxSwipes: 3)
        XCTAssertTrue(phonePreview.exists)
        phonePreview.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.phone-call-handoff.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "No call has been placed", direction: .both, maxSwipes: 2).exists)

        let webSearchPreview = findButton("automations.shortcut-demo.web-search-handoff.preview-sample", direction: .both, maxSwipes: 3)
        XCTAssertTrue(webSearchPreview.exists)
        webSearchPreview.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.web-search-handoff.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "No browsing has happened", direction: .both, maxSwipes: 2).exists)

        let contactPreview = findButton("automations.shortcut-demo.contact-draft-from-shared-text.preview-sample", direction: .both, maxSwipes: 3)
        XCTAssertTrue(contactPreview.exists)
        contactPreview.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.contact-draft-from-shared-text.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Review before writing to Contacts", direction: .both, maxSwipes: 2).exists)
    }

    func testSettingsShowsOAuthConnectorReadinessAndBoundaries() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.settings", label: "Settings")

        XCTAssertTrue(findElement("settings.oauth.connectors", direction: .down).exists)
        verifyOAuthConnector(
            providerKey: "google",
            displayName: "Gmail / Google Workspace",
            detailText: "預設 scopes: openid, email, profile, https://www.googleapis.com/auth/gmail.readonly",
            expectsBackendExchange: true
        )
        verifyOAuthConnector(
            providerKey: "microsoft",
            displayName: "Microsoft 365 / Outlook",
            detailText: "預設 scopes: openid, profile, offline_access, User.Read, Mail.Read, Calendars.ReadWrite",
            expectsBackendExchange: true
        )
        verifyOAuthConnector(
            providerKey: "notion",
            displayName: "Notion",
            detailText: "Only pages/databases selected during Notion authorization may be read or written.",
            expectsBackendExchange: true
        )
        verifyOAuthConnector(
            providerKey: "slack",
            displayName: "Slack",
            detailText: "預設 scopes: channels:history, chat:write",
            expectsBackendExchange: true
        )
        verifyOAuthConnector(
            providerKey: "chatgpt",
            displayName: "ChatGPT",
            detailText: "預設 scopes: openid, profile, email",
            expectsBackendExchange: false
        )
        verifyOAuthConnector(
            providerKey: "github",
            displayName: "GitHub",
            detailText: "預設 scopes: read:user, repo",
            expectsBackendExchange: true
        )
    }

    func testSettingsPreviewsOAuthCallbackWithoutLeakingCode() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.settings", label: "Settings")

        let callbackField = findElement("settings.oauth.callback-url", direction: .down, maxSwipes: 4)
        XCTAssertTrue(callbackField.exists)
        callbackField.tap()
        callbackField.typeText("kairo://oauth/google/callback?code=sample-sensitive-code&state=ui-state")

        let previewButton = findButton("settings.oauth.preview-callback", direction: .both, maxSwipes: 1)
        XCTAssertTrue(previewButton.exists)
        previewButton.tap()

        XCTAssertTrue(findElement("settings.oauth.callback-message", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "authorization code received", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "backend token exchange", direction: .both, maxSwipes: 1).exists)
        XCTAssertFalse(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "sample-sensitive-code")).firstMatch.exists)
    }

    func testAutomationsRecipeCenterPreviewsRunsAndTogglesInternalRecipe() throws {
        relaunchForUITesting(initialSection: "shortcuts")

        XCTAssertTrue(findElement("automations.recipe-center").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Kairo internal recipe", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "does not create Apple Shortcuts", direction: .both, maxSwipes: 1).exists)

        scrollTowardTop(maxSwipes: 2)
        let identifiedSeedSamples = app.buttons["automations.seed-samples"]
        let seedSamples = identifiedSeedSamples.exists
            ? identifiedSeedSamples
            : findButton(labeled: "Add Sample Recipes", direction: .both, maxSwipes: 2)
        XCTAssertTrue(seedSamples.exists)
        seedSamples.tap()

        XCTAssertTrue(findElement("automations.recipe.daily-briefing", direction: .down, maxSwipes: 10).exists)
        XCTAssertTrue(findStaticText(containing: "Daily Briefing", direction: .both, maxSwipes: 1).exists)

        let previewButton = findButton("automations.recipe.daily-briefing.preview", direction: .both, maxSwipes: 1)
        XCTAssertTrue(previewButton.exists)
        previewButton.tap()
        XCTAssertTrue(findElement("automations.message", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Preview Daily Briefing", direction: .both, maxSwipes: 1).exists)

        let runButton = findButton("automations.recipe.daily-briefing.run", direction: .both, maxSwipes: 1)
        XCTAssertTrue(runButton.exists)
        runButton.tap()
        XCTAssertTrue(findStaticText(containing: "Ran Daily Briefing", direction: .both, maxSwipes: 1).exists)

        let toggleButton = findButton("automations.recipe.daily-briefing.toggle", direction: .both, maxSwipes: 1)
        XCTAssertTrue(toggleButton.exists)
        toggleButton.tap()
        XCTAssertTrue(findStaticText(containing: "Disabled Daily Briefing", direction: .both, maxSwipes: 1).exists)
    }

    func testAutomationsShowsShortcutTemplatesRequireUserApproval() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.shortcuts", label: "Shortcuts")

        XCTAssertTrue(findElement("automations.shortcut-templates", direction: .down, maxSwipes: 3).exists)
        XCTAssertTrue(findStaticText(containing: "Apple Shortcuts installation requires user approval", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Run Kairo Recipe Shortcut", direction: .down, maxSwipes: 8).exists)
        XCTAssertTrue(findStaticText(containing: "Run Kairo Recipe", direction: .both, maxSwipes: 2).exists)
        XCTAssertTrue(findStaticText(containing: "Recipe ID", direction: .both, maxSwipes: 2).exists)
    }

    func testAccessSkillManagerBlocksIncompatibleMarketplaceSkillInstall() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")

        let refreshMarketplace = findButton("access.skills.marketplace-refresh")
        XCTAssertTrue(refreshMarketplace.exists)
        refreshMarketplace.tap()

        XCTAssertTrue(findElement("access.skill.shortcut-email-triage", direction: .down).exists)

        let installQwenWorkflow = findButton("access.skill.marketplace-qwen-oauth-workflow.install", direction: .down, maxSwipes: 8)
        XCTAssertTrue(installQwenWorkflow.exists)
        installQwenWorkflow.tap()

        XCTAssertTrue(findElement("access.skills.manifest-preview", direction: .both, maxSwipes: 2).exists)
        XCTAssertTrue(findElement("access.skills.manifest-preview.compatibility", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Blocked Qwen OAuth Workflow", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Connect OAuth provider google", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Download local model qwen3-5-0-8b-q4-k-m", direction: .both, maxSwipes: 1).exists)

        let confirmInstall = findButton("access.skills.manifest-preview.confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirmInstall.exists)
        XCTAssertFalse(confirmInstall.isEnabled)
    }

    func testAccessSkillManagerCreatesLocalUserSkillDraft() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")

        let nameField = findElement("access.skills.local-create.name", direction: .down)
        XCTAssertTrue(nameField.exists)
        nameField.tap()
        nameField.typeText("UI Created Skill")
        let returnKey = app.keyboards.buttons["Return"]
        if returnKey.exists {
            returnKey.tap()
        }

        let summaryField = findElement("access.skills.local-create.summary", direction: .both)
        XCTAssertTrue(summaryField.exists)
        XCTAssertTrue(findElement("access.skills.local-create.capability", direction: .both).exists)
        XCTAssertTrue(findElement("access.skills.local-create.confirmation-policy", direction: .both).exists)
        dismissKeyboardIfPresent()

        let createButton = findButton("access.skills.local-create.button", direction: .both)
        XCTAssertTrue(createButton.exists)
        createButton.tap()

        let createMessage = findElement("access.skills.message", direction: .both, maxSwipes: 4)
        XCTAssertTrue(createMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(findElement("access.skill.user-ui-created-skill", direction: .both, maxSwipes: 10).exists)

        let enableDraft = findButton("access.skill.user-ui-created-skill.enable", direction: .both, maxSwipes: 10)
        XCTAssertTrue(enableDraft.exists)
        enableDraft.tap()
        XCTAssertTrue(findButton("access.skill.user-ui-created-skill.disable", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
    }

    func testAccessSkillManagerSearchFiltersSkills() throws {
        relaunchForUITesting(initialSection: "access")

        let searchField = findElement("access.skills.search", direction: .down, maxSwipes: 3)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("weather")
        dismissKeyboardIfPresent()

        let summary = findElement("access.skills.search.summary", direction: .both, maxSwipes: 2)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        let visibleLabels = app.staticTexts.allElementsBoundByIndex.map(\.label)
        XCTAssertTrue(visibleLabels.contains { $0.contains("Showing 1 of") }, visibleLabels.joined(separator: " | "))
        XCTAssertTrue(visibleLabels.contains { $0.contains("Weather Briefing") }, visibleLabels.joined(separator: " | "))
        XCTAssertTrue(findElement("access.skill.marketplace-weather-briefing", direction: .down, maxSwipes: 4).exists)
        XCTAssertFalse(anyElement("access.skill.shortcut-save-shared-text").exists)
    }

    func testAccessShowsHomeKitSecurityDevicePreview() throws {
        relaunchForUITesting(initialSection: "access")

        XCTAssertTrue(findElement("access.skill.homekit-front-door-lock", direction: .down, maxSwipes: 8).exists)
        XCTAssertTrue(findButton("access.skill.homekit-front-door-lock.manage", direction: .down, maxSwipes: 2).exists)
        XCTAssertTrue(findElement("access.homekit.demo.front-door-lock", direction: .down, maxSwipes: 8).exists)

        let previewLock = findButton("access.homekit.demo.front-door-lock.confirm", direction: .both, maxSwipes: 2)
        XCTAssertTrue(previewLock.exists)
        previewLock.tap()

        XCTAssertTrue(findStaticText(containing: "Confirm in Kairo before any HomeKit security-device write.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatShowsHomeKitToolPreviewAction() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Turn on the desk lamp")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        XCTAssertTrue(findElement("chat.proposed-actions", direction: .down).exists)
        XCTAssertTrue(findElement("chat.proposed-action.controlHome", direction: .down).exists)
        XCTAssertTrue(findElement("chat.proposed-action.controlHome.risk", direction: .down).exists)
        XCTAssertTrue(findStaticText(containing: "Control Home", direction: .down).exists)
        XCTAssertTrue(findStaticText(containing: "Will ask first", direction: .down).exists)
    }

    func testChatShowsShortcutToolCandidatePreview() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Turn this shared text into todo tasks")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        XCTAssertTrue(findElement("chat.tool-candidates", direction: .down).exists)
        XCTAssertTrue(findElement("chat.tool-candidate.shortcut-save-shared-text", direction: .down).exists)
        XCTAssertTrue(findElement("chat.tool-candidate.shortcut-save-shared-text.summary", direction: .down).exists)
        XCTAssertTrue(findElement("chat.tool-candidate.shortcut-save-shared-text.risk", direction: .down).exists)
        XCTAssertTrue(findStaticText(containing: "Shortcut", direction: .down).exists)
        XCTAssertTrue(findStaticText(containing: "Will ask first", direction: .down).exists)
    }

    func testChatCanPreviewAndConfirmNotificationAction() throws {
        verifyChatActionPreview(
            prompt: "通知我喝水",
            actionIdentifier: "chat.proposed-action.sendNotification",
            previewContains: ["Schedule Local Notification"],
            resultText: "Scheduled notification."
        )
    }

    func testChatCanPreviewAndConfirmReminderAction() throws {
        verifyChatActionPreview(
            prompt: "建立提醒事項：下班前整理 Kairo model list",
            actionIdentifier: "chat.proposed-action.createReminderDraft",
            previewContains: ["Create Reminder"],
            resultText: "Created reminder."
        )
    }

    func testChatCanPreviewAndConfirmCalendarAction() throws {
        verifyChatActionPreview(
            prompt: "建立行程：週五 10:00 Kairo roadmap review",
            actionIdentifier: "chat.proposed-action.createCalendarDraft",
            previewContains: ["Create Calendar Event"],
            resultText: "Created calendar event."
        )
    }

    func testChatCanPreviewAndConfirmContactAction() throws {
        verifyChatActionPreview(
            prompt: "建立聯絡人：王小明 0912-345-678 ming@example.com",
            actionIdentifier: "chat.proposed-action.createContactDraft",
            previewContains: ["Create Contact", "0912-345-678"],
            resultText: "Created contact."
        )
    }

    func testChatCanPreviewAndConfirmEmailDraftHandoff() throws {
        verifyChatActionPreview(
            prompt: "Draft an email to alex@example.com subject Kairo update body Please review the roadmap.",
            actionIdentifier: "chat.proposed-action.composeEmailDraft",
            previewContains: ["Compose Email Draft", "alex@example.com", "Kairo update"],
            resultText: "Prepared email draft handoff."
        )
    }

    func testChatCanPreviewAndConfirmMapDirectionsHandoff() throws {
        verifyChatActionPreview(
            prompt: "Drive to Apple Park",
            actionIdentifier: "chat.proposed-action.openMapDirections",
            previewContains: ["Open Apple Maps Directions", "Apple Park"],
            resultText: "Prepared Apple Maps directions handoff."
        )
    }

    func testChatCanPreviewAndConfirmMessagesHandoff() throws {
        verifyChatActionPreview(
            prompt: "Text 0912-345-678 body I am running late.",
            actionIdentifier: "chat.proposed-action.openMessageHandoff",
            previewContains: ["Open Messages Handoff", "0912-345-678", "I am running late.", "Body stays in Kairo preview"],
            resultText: "Prepared Messages handoff."
        )
    }

    func testChatCanPreviewAndConfirmPhoneCallHandoff() throws {
        verifyChatActionPreview(
            prompt: "Call 0912-345-678",
            actionIdentifier: "chat.proposed-action.openPhoneCallHandoff",
            previewContains: ["Phone Handoff", "0912-345-678", "tel: opens Phone visibly"],
            resultText: "Prepared phone call handoff."
        )
    }

    func testChatCanPreviewAndConfirmWebSearchHandoff() throws {
        verifyChatActionPreview(
            prompt: "Search web for SwiftUI App Intents examples",
            actionIdentifier: "chat.proposed-action.openWebSearchHandoff",
            previewContains: ["Web Search Handoff", "SwiftUI App Intents examples", "Safari opens visibly"],
            resultText: "Prepared Safari web search handoff."
        )
    }

}
