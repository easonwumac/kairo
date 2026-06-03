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
        openAccessAndVerifyHomeKitDemos()
        verifySkillManagerInteractionFlow()
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
        XCTAssertFalse(findElement("settings.models.smollm2-1-7b-instruct-q4-k-m.name", direction: .down, maxSwipes: 2).waitForExistence(timeout: 1))
        XCTAssertFalse(anyElement("settings.models.show-more").exists)
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
            outputText: "Output: memoryID, fields.taskCount, tasks, fields.chainText, reminderDrafts",
            sampleText: "User research note"
        )
        verifyShortcutDemoContract(
            id: "screenshot-to-reminders",
            titleText: "Screenshot to Reminders",
            stepText: "2 steps: extractTasks -> createReminderDraft",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: fields.taskCount, fields.chainText, tasks, reminderDrafts, fields.reminderDraftCount",
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
            id: "email-triage",
            titleText: "Email Triage",
            stepText: "3 steps: summarize -> extractTasks -> draftReply",
            inputText: "Input: text, sourceName, variables, previousStepOutput",
            outputText: "Output: displayText, fields.summary, fields.chainText, fields.taskCount, tasks, reminderDrafts, fields.replyDraft",
            sampleText: "Email from vendor"
        )
        verifyShortcutDemoContract(
            id: "meeting-prep-brief",
            titleText: "Meeting Prep Brief",
            stepText: "3 steps: searchMemory -> summarize -> extractTasks",
            inputText: "Input: query, limit, text, sourceName, variables, previousStepOutput",
            outputText: "Output: fields.matchCount, memoryMatches, displayText, fields.summary, fields.chainText",
            sampleText: "Kairo launch review"
        )
        verifyShortcutDemoContract(
            id: "request-to-recipe-draft",
            titleText: "Request to Recipe Draft",
            stepText: "1 step: createRecipeDraft",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: fields.recipeID, fields.recipeTitle, fields.recipeStepCount",
            sampleText: "每天早上整理今天事情"
        )
        verifyShortcutDemoContract(
            id: "meeting-text-to-calendar-draft",
            titleText: "Meeting Text to Calendar Draft",
            stepText: "1 step: createCalendarDraft",
            inputText: "Input: text, sourceName, variables.startDateISO, variables.endDateISO",
            outputText: "Output: fields.calendarDraftCount, fields.calendarTitle, fields.calendarRequiresConfirmation",
            sampleText: "Kairo roadmap review"
        )
        verifyShortcutDemoContract(
            id: "home-action-preview",
            titleText: "Home Action Preview",
            stepText: "1 step: previewHomeAction",
            inputText: "Input: text, sourceName, variables",
            outputText: "Output: proposedActions, fields.homeActionCount, fields.homeActionRiskTier",
            sampleText: "desk lamp"
        )
        verifyShortcutDemoContract(
            id: "generic-node-runner",
            titleText: "Generic Node Runner",
            stepText: "2 steps: summarize -> extractTasks",
            inputText: "Input: nodeKind, inputJSON",
            outputText: "Output: outputJSON, displayText, fields.taskCount, fields.chainText, tasks",
            sampleText: "Shortcut dictionary"
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
        XCTAssertTrue(findStaticText(containing: "Needs confirmation", direction: .down).exists)
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
        XCTAssertTrue(findStaticText(containing: "Needs confirmation", direction: .down).exists)
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

}
