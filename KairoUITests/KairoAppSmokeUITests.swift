import XCTest

final class KairoAppSmokeUITests: XCTestCase {
    private enum SearchDirection: Equatable {
        case down
        case up
        case both
    }

    private var app: XCUIApplication!
    private let localModelExpectations = [
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
        openAccessAndVerifyHomeKitDemos()
        verifySkillManagerInteractionFlow()
        openSettingsAndVerifyAPIKeyStatus(verifyAllLocalModels: false)
    }

    func testSettingsLocalModelCatalogListsDownloadableModels() throws {
        relaunchForUITesting(initialSection: "models")
        openModelsAndVerifyLocalModelCatalog(verifyAllLocalModels: true, selectFromDrawer: false)
    }

    func testChatComposerSurfaceIsTappableAndSends() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()

        XCTAssertTrue(anyElement("chat.provider-route").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.provider-route.title").exists)
        XCTAssertTrue(anyElement("chat.provider-route.detail").exists)
        XCTAssertTrue(anyElement("chat.provider-route.badge").exists)
        XCTAssertTrue(findStaticText(containing: "Route: Automatic", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(anyElement("chat.provider-route.preference").exists)
        let cloudRoute = findButton("chat.provider-route.preference.preferCloud", direction: .both, maxSwipes: 1)
        XCTAssertTrue(cloudRoute.exists)
        cloudRoute.tap()
        XCTAssertTrue(findStaticText(containing: "Route: Prefer Cloud", direction: .both, maxSwipes: 1).waitForExistence(timeout: 3))

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
        relaunchForUITesting(initialSection: "settings")

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
            outputText: "Output: memoryID, fields.taskCount, tasks, reminderDrafts",
            sampleText: "User research note"
        )
        verifyShortcutDemoContract(
            id: "screenshot-to-reminders",
            titleText: "Screenshot to Reminders",
            stepText: "2 steps: extractTasks -> createReminderDraft",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: fields.taskCount, tasks, reminderDrafts, fields.reminderDraftCount",
            sampleText: "Screenshot OCR"
        )
        verifyShortcutDemoContract(
            id: "reply-draft-from-shared-text",
            titleText: "Reply Draft from Shared Text",
            stepText: "2 steps: summarize -> draftReply",
            inputText: "Input: text, sourceName, variables, previousStepOutput",
            outputText: "Output: displayText, fields.summary, fields.chainText, fields.replyDraft",
            sampleText: "Customer email"
        )
        verifyShortcutDemoContract(
            id: "meeting-prep-brief",
            titleText: "Meeting Prep Brief",
            stepText: "3 steps: searchMemory -> summarize -> extractTasks",
            inputText: "Input: query, limit, text, sourceName, variables, previousStepOutput",
            outputText: "Output: fields.matchCount, memoryMatches, displayText, fields.summary",
            sampleText: "Kairo launch review"
        )
        verifyShortcutDemoContract(
            id: "generic-node-runner",
            titleText: "Generic Node Runner",
            stepText: "2 steps: summarize -> extractTasks",
            inputText: "Input: nodeKind, inputJSON",
            outputText: "Output: outputJSON, displayText, fields.taskCount, tasks",
            sampleText: "Shortcut dictionary"
        )
    }

    func testShortcutsSurfaceShowsNodeDemoContracts() throws {
        relaunchForUITesting(initialSection: "shortcuts")

        XCTAssertTrue(findElement("automations.shortcut-demos", direction: .down).exists)
        verifyShortcutDemoContract(
            namespace: "automations.shortcut-demo",
            id: "generic-node-runner",
            titleText: "Generic Node Runner",
            stepText: "2 steps: summarize -> extractTasks",
            inputText: "Input: nodeKind, inputJSON",
            outputText: "Output: outputJSON, displayText, fields.taskCount, tasks",
            sampleText: "Shortcut dictionary"
        )

        let previewSample = findButton("automations.shortcut-demo.generic-node-runner.preview-sample", direction: .both, maxSwipes: 2)
        XCTAssertTrue(previewSample.exists)
        previewSample.tap()

        XCTAssertTrue(findElement("automations.shortcut-demo.generic-node-runner.preview-result", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Sample Generic Node Runner", direction: .both, maxSwipes: 2).exists)
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
        XCTAssertTrue(findStaticText(containing: "Control Home", direction: .down).exists)
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
        XCTAssertTrue(findStaticText(containing: "Shortcut", direction: .down).exists)
    }

    func testChatCanPreviewAndConfirmNotificationAction() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("通知我喝水")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let notificationAction = findButton("chat.proposed-action.sendNotification", direction: .down)
        XCTAssertTrue(notificationAction.exists)
        notificationAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Schedule Local Notification", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Scheduled notification.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmReminderAction() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("建立提醒事項：下班前整理 Kairo model list")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let reminderAction = findButton("chat.proposed-action.createReminderDraft", direction: .down)
        XCTAssertTrue(reminderAction.exists)
        reminderAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Create Reminder", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Created reminder.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmCalendarAction() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("建立行程：週五 10:00 Kairo roadmap review")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let calendarAction = findButton("chat.proposed-action.createCalendarDraft", direction: .down)
        XCTAssertTrue(calendarAction.exists)
        calendarAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Create Calendar Event", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Created calendar event.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmContactAction() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("建立聯絡人：王小明 0912-345-678 ming@example.com")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let contactAction = findButton("chat.proposed-action.createContactDraft", direction: .down)
        XCTAssertTrue(contactAction.exists)
        contactAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Create Contact", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "0912-345-678", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Created contact.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmEmailDraftHandoff() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Draft an email to alex@example.com subject Kairo update body Please review the roadmap.")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let emailAction = findButton("chat.proposed-action.composeEmailDraft", direction: .down)
        XCTAssertTrue(emailAction.exists)
        emailAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Compose Email Draft", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "alex@example.com", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Kairo update", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Prepared email draft handoff.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmMapDirectionsHandoff() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Drive to Apple Park")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let mapAction = findButton("chat.proposed-action.openMapDirections", direction: .down)
        XCTAssertTrue(mapAction.exists)
        mapAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Open Apple Maps Directions", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Apple Park", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Prepared Apple Maps directions handoff.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmMessagesHandoff() throws {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Text 0912-345-678 body I am running late.")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let messageAction = findButton("chat.proposed-action.openMessageHandoff", direction: .down)
        XCTAssertTrue(messageAction.exists)
        messageAction.tap()

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Open Messages Handoff", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "0912-345-678", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "I am running late.", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Body stays in Kairo preview", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton(labeled: "Confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        confirm.tap()

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Prepared Messages handoff.", direction: .both, maxSwipes: 1).exists)
    }

    private func assertPrimaryDrawerItemsExist() {
        XCTAssertTrue(anyElement("root.safe-area-header").waitForExistence(timeout: 5))
        let menuButton = findButton("root.drawer.toggle", direction: .both, maxSwipes: 1)
        XCTAssertTrue(menuButton.exists)
        XCTAssertGreaterThan(menuButton.frame.minY, 20)

        openDrawer()
        XCTAssertTrue(findButton("root.drawer.chat", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.skills", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.shortcuts", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.access", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.models", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.settings", direction: .both, maxSwipes: 1).exists)
        let closeButton = findButton("root.drawer.close", direction: .both, maxSwipes: 1)
        XCTAssertTrue(closeButton.exists)
        XCTAssertGreaterThan(closeButton.frame.minY, 20)
        closeDrawerIfOpen()
    }

    private func sendChatMessage() {
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        XCTAssertTrue(anyElement("chat.composer.surface").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.composer.input-shell").exists)
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Run the Kairo UI smoke test")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.user").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        dismissKeyboardIfPresent()
    }

    private func openAccessAndVerifyHomeKitDemos() {
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")
        scrollTowardTop()
        XCTAssertTrue(findButton("access.skills.marketplace-refresh", direction: .down).exists)
        XCTAssertTrue(findElement("access.skills.manifest-import", direction: .down).exists)
        XCTAssertTrue(findElement("access.skills.manifest-import.text", direction: .down).exists)
        XCTAssertTrue(findButton("access.skills.manifest-import.button", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.homekit-evening-scene", direction: .down).exists)
        XCTAssertTrue(findButton("access.skill.homekit-evening-scene.manage", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-save-shared-text", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-screenshot-to-reminders", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-reply-draft-from-shared-text", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-meeting-prep-brief", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-generic-node-runner", direction: .down).exists)
        XCTAssertTrue(findElement("access.homekit.demos", direction: .down).exists)
        XCTAssertTrue(findElement("access.homekit.demo.evening-scene", direction: .down).exists)
        XCTAssertTrue(findButton("access.homekit.demo.evening-scene.confirm", direction: .down).exists)
    }

    private func verifySkillManagerInteractionFlow() {
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")

        let refreshMarketplace = findButton("access.skills.marketplace-refresh")
        XCTAssertTrue(refreshMarketplace.exists)
        refreshMarketplace.tap()

        let disableShortcut = findButton("access.skill.shortcut-save-shared-text.disable")
        XCTAssertTrue(disableShortcut.exists)
        disableShortcut.tap()
        XCTAssertTrue(findButton("access.skill.shortcut-save-shared-text.enable").waitForExistence(timeout: 5))

        let enableShortcut = findButton("access.skill.shortcut-save-shared-text.enable")
        XCTAssertTrue(enableShortcut.exists)
        enableShortcut.tap()
        XCTAssertTrue(findButton("access.skill.shortcut-save-shared-text.disable").waitForExistence(timeout: 5))

        let installWeather = findButton("access.skill.marketplace-weather-briefing.install")
        XCTAssertTrue(installWeather.exists)
        installWeather.tap()
        XCTAssertTrue(findElement("access.skills.message").exists)
        XCTAssertTrue(findElement("access.skills.manifest-preview").exists)
        XCTAssertTrue(findStaticText(containing: "Install Weather Briefing 2.1.0.").exists)

        let confirmInstall = findButton("access.skills.manifest-preview.confirm")
        XCTAssertTrue(confirmInstall.exists)
        confirmInstall.tap()
        XCTAssertTrue(findButton("access.skill.marketplace-weather-briefing.disable").waitForExistence(timeout: 5))

        let previewHomeKit = findButton("access.homekit.demo.evening-scene.confirm")
        XCTAssertTrue(previewHomeKit.exists)
        previewHomeKit.tap()
        XCTAssertTrue(findStaticText(containing: "Confirm before Kairo runs the HomeKit scene.").exists)
    }

    private func openSettingsAndVerifyAPIKeyStatus(verifyAllLocalModels: Bool) {
        selectDrawerSection(identifier: "root.drawer.settings", label: "Settings")
        XCTAssertTrue(findElement("settings.openai.api-key-status").exists)
        XCTAssertTrue(anyElement("settings.openai.api-key-field").exists)
        XCTAssertTrue(findButton("settings.openai.save-api-key").exists)
        XCTAssertTrue(findElement("settings.oauth.connectors", direction: .down).exists)
        if verifyAllLocalModels {
            openModelsAndVerifyLocalModelCatalog(verifyAllLocalModels: true)
        }
    }

    private func openModelsAndVerifyLocalModelCatalog(verifyAllLocalModels: Bool, selectFromDrawer: Bool = true) {
        if selectFromDrawer {
            selectDrawerSection(identifier: "root.drawer.models", label: "Models")
        }
        XCTAssertTrue(anyElement("settings.models.screen").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("settings.models.local").exists)
        let catalogSource = anyElement("settings.models.catalog-source")
        XCTAssertTrue(catalogSource.exists)
        XCTAssertTrue(catalogSource.label.contains("github.com/easonwumac/kairo-models"))
        XCTAssertTrue(findStaticText(containing: "No downloaded model selected yet.", direction: .both).exists)
        XCTAssertTrue(app.buttons["settings.models.refresh-catalog"].exists)
        let localModelsToVerify = verifyAllLocalModels
            ? localModelExpectations
            : Array(localModelExpectations.prefix(2))
        XCTAssertTrue(app.staticTexts["settings.models.\(localModelsToVerify[0].0).status"].label.contains("可下載"))
        XCTAssertTrue(app.buttons["settings.models.\(localModelsToVerify[0].0).download"].exists)
        for localModel in localModelsToVerify {
            verifyDownloadableLocalModel(
                id: localModel.0,
                displayName: localModel.1,
                downloadIdentifier: "settings.models.\(localModel.0).download"
            )
        }
    }

    private func verifyDownloadableLocalModel(id: String, displayName: String, downloadIdentifier: String) {
        XCTAssertFalse(displayName.isEmpty)
        XCTAssertTrue(anyElement("settings.models.\(id).name").exists, id)
        if id == "qwen3-5-0-8b-q4-k-m" {
            let benchmark = anyElement("settings.models.\(id).benchmark")
            XCTAssertTrue(benchmark.exists)
            XCTAssertTrue(benchmark.label.contains("MLX ref"))
            XCTAssertTrue(benchmark.label.contains("iPhone not verified"))

            let manifest = anyElement("settings.models.\(id).manifest")
            XCTAssertTrue(manifest.exists)
            XCTAssertTrue(manifest.label.contains("huggingface.co"))
            XCTAssertTrue(manifest.label.contains("GGUF"))
            XCTAssertTrue(manifest.label.contains("Apache-2.0"))
            XCTAssertTrue(manifest.label.contains("SHA e8e3882"))
        }
        let downloadButton = app.buttons[downloadIdentifier]
        if !downloadButton.exists {
            scrollDown()
        }
        XCTAssertTrue(downloadButton.exists, downloadIdentifier)
    }

    private func verifyShortcutDemoContract(
        namespace: String = "settings.shortcuts.demo",
        id: String,
        titleText: String,
        stepText: String,
        inputText: String,
        outputText: String,
        sampleText: String
    ) {
        XCTAssertTrue(findStaticText(containing: titleText, direction: .both, maxSwipes: 10).exists)
        assertShortcutDemoField(namespace: namespace, id: id, suffix: "steps", contains: stepText)
        assertShortcutDemoField(namespace: namespace, id: id, suffix: "input", contains: inputText)
        assertShortcutDemoField(namespace: namespace, id: id, suffix: "output", contains: outputText)
        assertShortcutDemoField(namespace: namespace, id: id, suffix: "sample", contains: sampleText)
    }

    private func assertShortcutDemoField(namespace: String = "settings.shortcuts.demo", id: String, suffix: String, contains expectedText: String) {
        let element = findElement("\(namespace).\(id).\(suffix)", direction: .both, maxSwipes: 2)
        XCTAssertTrue(element.exists)
        XCTAssertTrue(element.label.contains(expectedText))
    }

    private func verifyOAuthConnector(
        providerKey: String,
        displayName: String,
        detailText: String,
        expectsBackendExchange: Bool
    ) {
        XCTAssertFalse(providerKey.isEmpty)
        XCTAssertTrue(findStaticText(containing: displayName, direction: .both, maxSwipes: 6).exists)
        XCTAssertTrue(findStaticText(containing: "需要 Client 設定", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: detailText, direction: .both, maxSwipes: 2).exists)

        if expectsBackendExchange {
            XCTAssertTrue(findStaticText(containing: "需要後端 token exchange。", direction: .both, maxSwipes: 1).exists)
        }
    }

    private func selectDrawerSection(identifier: String, label: String) {
        dismissKeyboardIfPresent()
        openDrawer()
        let button = drawerButton(identifier: identifier, label: label)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func openDrawer() {
        if anyElement("root.drawer").waitForExistence(timeout: 0.5) {
            return
        }

        let toggle = anyElement("root.drawer.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(anyElement("root.drawer").waitForExistence(timeout: 5))
    }

    private func closeDrawerIfOpen() {
        guard anyElement("root.drawer").exists else {
            return
        }

        let close = app.buttons["root.drawer.close"]
        if close.exists {
            close.tap()
        } else {
            anyElement("root.drawer.toggle").tap()
        }
        _ = anyElement("root.drawer").waitForNonExistence(timeout: 3)
    }

    private func drawerButton(identifier: String, label: String) -> XCUIElement {
        let identifiedButton = app.buttons[identifier]
        if identifiedButton.exists {
            return identifiedButton
        }

        return app.buttons[label]
    }

    private func openCurrentThreadIfNeeded() {
        if anyElement("chat.composer.text").waitForExistence(timeout: 1) {
            return
        }

        let historyThread = anyElement("chat.history.thread")
        if historyThread.waitForExistence(timeout: 2) {
            historyThread.tap()
            return
        }

        let newChat = anyElement("chat.new")
        if newChat.waitForExistence(timeout: 2) {
            newChat.tap()
        }
    }

    private func findButton(
        _ identifier: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let button = app.buttons[identifier]
        return find(button, direction: direction, maxSwipes: maxSwipes)
    }

    private func findElement(
        _ identifier: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let element = anyElement(identifier)
        return find(element, direction: direction, maxSwipes: maxSwipes)
    }

    private func findButton(
        labeled label: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let button = app.buttons[label]
        return find(button, direction: direction, maxSwipes: maxSwipes)
    }

    private func findStaticText(
        containing text: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let staticText = app.staticTexts.containing(predicate).firstMatch
        return find(staticText, direction: direction, maxSwipes: maxSwipes)
    }

    private func firstHittableButtonIdentifier(beginningWith prefix: String) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        let hittable = query.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
        return hittable ?? query.firstMatch
    }

    private func relaunchWithInstalledLocalModelForTesting(initialSection: String? = nil) {
        relaunchForUITesting(initialSection: initialSection, seedInstalledLocalModel: true)
    }

    private func relaunchForUITesting(initialSection: String? = nil, seedInstalledLocalModel: Bool = false) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--reset-ui-testing-data")
        if seedInstalledLocalModel {
            app.launchArguments.append("--ui-testing-installed-local-model")
        }
        if let initialSection {
            app.launchArguments.append("--ui-testing-root-section=\(initialSection)")
        }
        app.launch()
    }

    private func find(
        _ element: XCUIElement,
        direction: SearchDirection,
        maxSwipes: Int
    ) -> XCUIElement {
        if element.waitForExistence(timeout: 0.3) {
            return element
        }

        if direction == .down || direction == .both {
            for _ in 0..<maxSwipes {
                scrollDown()
                if element.waitForExistence(timeout: 0.3) {
                    return element
                }
            }
        }

        if direction == .up || direction == .both {
            for _ in 0..<maxSwipes {
                scrollUp()
                if element.waitForExistence(timeout: 0.3) {
                    return element
                }
            }
        }

        return element
    }

    private func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    private func scrollTowardTop(maxSwipes: Int = 4) {
        for _ in 0..<maxSwipes {
            scrollUp()
        }
    }

    private func dismissKeyboardIfPresent() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else {
            return
        }

        app.swipeDown()
        _ = keyboard.waitForNonExistence(timeout: 3)
    }

    private func scrollDown() {
        scrollingSurface().swipeUp()
    }

    private func scrollUp() {
        scrollingSurface().swipeDown()
    }

    private func scrollingSurface() -> XCUIElement {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            return collectionView
        }

        let scrollView = app.scrollViews.firstMatch
        if scrollView.exists {
            return scrollView
        }

        return app
    }
}
