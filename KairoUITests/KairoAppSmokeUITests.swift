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
        app.launchArguments.append(contentsOf: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
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

    func testSettingsCanSaveDryRunAndDeleteOpenAIAPIKey() throws {
        relaunchForUITesting(initialSection: "settings")
        XCTAssertTrue(anyElement("settings.form").waitForExistence(timeout: 5))
        let initialStatus = anyElement("settings.openai.api-key-status")
        XCTAssertTrue(initialStatus.waitForExistence(timeout: 5))
        XCTAssertTrue(initialStatus.label.contains("Not configured"), initialStatus.label)
        let field = anyElement("settings.openai.api-key-field")
        XCTAssertTrue(field.exists)
        field.tap()
        field.typeText("ui-test-api-key-1234567890")
        dismissKeyboardIfPresent()
        let save = findButton("settings.openai.save-api-key", direction: .both, maxSwipes: 1)
        XCTAssertTrue(save.exists)
        save.tap()
        XCTAssertTrue(findStaticText(containing: "Configured", direction: .both, maxSwipes: 1).waitForExistence(timeout: 5))
        let savedStatus = anyElement("settings.openai.api-key-status")
        XCTAssertTrue(savedStatus.label.contains("Configured"), savedStatus.label)
        let dryRun = findButton("settings.openai.dry-run-api-key", direction: .both, maxSwipes: 1)
        XCTAssertTrue(dryRun.exists)
        dryRun.tap()
        let dryRunMessage = findElement("settings.openai.status-message", direction: .both, maxSwipes: 1)
        XCTAssertTrue(dryRunMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(dryRunMessage.label.contains("OpenAI dry run completed: ui-t...7890"), dryRunMessage.label)
        XCTAssertTrue(dryRunMessage.label.contains("no network request was sent"), dryRunMessage.label)
        let delete = findButton("settings.openai.delete-api-key", direction: .both, maxSwipes: 1)
        XCTAssertTrue(delete.exists)
        delete.tap()
        XCTAssertTrue(findStaticText(containing: "Not configured", direction: .both, maxSwipes: 1).waitForExistence(timeout: 5))
        let deletedStatus = anyElement("settings.openai.api-key-status")
        XCTAssertTrue(deletedStatus.label.contains("Not configured"), deletedStatus.label)
    }

    func testSettingsCanClearMetadataOnlyAuditLog() throws {
        relaunchForUITesting(initialSection: "settings")
        XCTAssertTrue(anyElement("settings.form").waitForExistence(timeout: 5))

        let clearAuditLog = findElement("settings.privacy.clear-audit-log", direction: .both, maxSwipes: 4)
        XCTAssertTrue(clearAuditLog.exists)
        XCTAssertTrue(findElement("settings.privacy.audit-log-detail", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "does not delete chat history", direction: .both, maxSwipes: 1).exists)
        tapElement(clearAuditLog)

        let status = findElement("settings.privacy.status", direction: .both, maxSwipes: 1)
        XCTAssertTrue(status.waitForExistence(timeout: 5))
        XCTAssertTrue(status.label.contains("Metadata-only audit log cleared."), status.label)
    }

    func testMemoryCenterCanAddSearchAndDeleteMemory() throws {
        relaunchForUITesting(initialSection: "memory")

        let addField = anyElement("memory.add.text")
        XCTAssertTrue(addField.waitForExistence(timeout: 5))
        addField.tap()
        addField.typeText("Beta launch checklist: invite reviewers and prepare notes.")
        dismissKeyboardIfPresent()

        let save = findButton("memory.add.save", direction: .both, maxSwipes: 1)
        XCTAssertTrue(save.exists)
        save.tap()

        XCTAssertTrue(findStaticText(containing: "Beta launch checklist", direction: .both, maxSwipes: 1).waitForExistence(timeout: 5))

        let search = findElement("memory.search.text", direction: .both, maxSwipes: 1)
        XCTAssertTrue(search.exists)
        search.tap()
        search.typeText("reviewers")
        dismissKeyboardIfPresent()

        let summary = findElement("memory.search.summary", direction: .both, maxSwipes: 1)
        XCTAssertTrue(summary.waitForExistence(timeout: 5))
        XCTAssertTrue(summary.label.contains("reviewers"), summary.label)
        XCTAssertTrue(findStaticText(containing: "Beta launch checklist", direction: .both, maxSwipes: 1).exists)

        let clear = findButton("memory.search.clear", direction: .both, maxSwipes: 1)
        XCTAssertTrue(clear.exists)
        clear.tap()

        let delete = findButton("memory.record.delete", direction: .both, maxSwipes: 1)
        XCTAssertTrue(delete.waitForExistence(timeout: 5))
        delete.tap()

        XCTAssertTrue(anyElement("memory.export.share").exists)
        XCTAssertFalse(anyElement("memory.record").exists)
    }

    func testChatShowsWhenAssistantUsedMemoryContext() throws {
        relaunchForUITesting(initialSection: "memory")

        let addField = anyElement("memory.add.text")
        XCTAssertTrue(addField.waitForExistence(timeout: 5))
        addField.tap()
        addField.typeText("Reviewer memory: prepare concise beta launch notes.")
        dismissKeyboardIfPresent()

        let save = findButton("memory.add.save", direction: .both, maxSwipes: 1)
        XCTAssertTrue(save.exists)
        save.tap()
        XCTAssertTrue(findStaticText(containing: "Reviewer memory", direction: .both, maxSwipes: 1).waitForExistence(timeout: 5))

        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Reviewer memory")
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        let memoryBadge = findElement("chat.message.memory-context", direction: .both, maxSwipes: 2)
        XCTAssertTrue(memoryBadge.waitForExistence(timeout: 5))
        XCTAssertTrue(memoryBadge.label.contains("Used 1 memory item"), memoryBadge.label)
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
        XCTAssertTrue(findStaticText(containing: "Download Qwen3.5 0.8B Q4_K_M before running a benchmark.", direction: .both, maxSwipes: 2).exists)
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
            detailText: "Default scopes: openid, email, profile, https://www.googleapis.com/auth/gmail.readonly",
            expectsBackendExchange: true
        )
        verifyOAuthConnector(
            providerKey: "microsoft",
            displayName: "Microsoft 365 / Outlook",
            detailText: "Default scopes: openid, profile, offline_access, User.Read, Mail.Read, Calendars.ReadWrite",
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
            detailText: "Default scopes: channels:history, chat:write",
            expectsBackendExchange: true
        )
        verifyOAuthConnector(
            providerKey: "chatgpt",
            displayName: "ChatGPT",
            detailText: "Default scopes: openid, profile, email",
            expectsBackendExchange: false
        )
        verifyOAuthConnector(
            providerKey: "github",
            displayName: "GitHub",
            detailText: "Default scopes: read:user, repo",
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

    func testAccessSkillManagerPreviewsSignedMarketplaceSkillUpdate() throws {
        relaunchForUITesting(initialSection: "access", seedInstalledWeatherSkill: true)

        let searchField = findElement("access.skills.search", direction: .down, maxSwipes: 3)
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("weather")
        dismissKeyboardIfPresent()

        let updateWeather = findButton("access.skill.marketplace-weather-briefing.update", direction: .both, maxSwipes: 2)
        XCTAssertTrue(updateWeather.exists)
        updateWeather.tap()

        let preview = app.descendants(matching: .any)["access.skills.manifest-preview"]
        XCTAssertTrue(preview.waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["access.skills.manifest-preview.summary"].label.contains("Update Weather Briefing from 2.0.0 to 2.1.0."))
        XCTAssertTrue(app.staticTexts["access.skills.manifest-preview.version"].label.contains("Installed 2.0.0 -> Incoming 2.1.0"))
        XCTAssertTrue(app.staticTexts["access.skills.manifest-preview.changelog"].label.contains("Adds storm alerts."))

        let confirmInstall = app.buttons["access.skills.manifest-preview.confirm"]
        XCTAssertTrue(confirmInstall.exists)
        XCTAssertTrue(confirmInstall.isEnabled)
        confirmInstall.tap()

        XCTAssertTrue(findStaticText(containing: "Weather Briefing installed from signed manifest.", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertTrue(findButton("access.skill.marketplace-weather-briefing.disable", direction: .both, maxSwipes: 2).exists)
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

        let removeDraft = findButton("access.skill.user-ui-created-skill.remove", direction: .both, maxSwipes: 2)
        XCTAssertTrue(removeDraft.exists)
        removeDraft.tap()
        XCTAssertTrue(findStaticText(containing: "UI Created Skill removed from manager.", direction: .both, maxSwipes: 2).waitForExistence(timeout: 5))
        XCTAssertFalse(anyElement("access.skill.user-ui-created-skill").exists)
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

    func testFlowASharedTextToReminderPreviewConfirm() throws {
        relaunchForUITesting(initialSection: "chat", seedSharedTaskText: true)
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()

        XCTAssertTrue(anyElement("chat.share-import.banner").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Imported 1 shared item", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Launch Notes: TODO: Send prototype link", direction: .both, maxSwipes: 1).exists)
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        let composerValue = composer.value as? String ?? ""
        XCTAssertTrue(composerValue.contains("Create reminder: Send prototype link"), composerValue)

        let sendShare = findButton("chat.share-import.send", direction: .both, maxSwipes: 1)
        XCTAssertTrue(sendShare.exists)
        tapElement(sendShare)

        XCTAssertTrue(anyElement("chat.message.user").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        XCTAssertTrue(anyElement("chat.share-import.review-banner").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Reminder draft ready", direction: .both, maxSwipes: 1).exists)
        let action = findButton("chat.share-import.review-action", direction: .both, maxSwipes: 1)
        XCTAssertTrue(action.exists)
        tapElement(action)

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Create Reminder", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Send prototype link", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Creates reminder", direction: .both, maxSwipes: 1).exists)
        XCTAssertFalse(findStaticText(containing: "tier2LowRiskWrite", direction: .both, maxSwipes: 1).exists)
        let confirm = findButton("chat.action.confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        tapElement(confirm)

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: "Created reminder: Send prototype link", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Shared content was cleared from the import queue.", direction: .both, maxSwipes: 1).exists)
    }

    func testChatCanPreviewAndConfirmNotificationAction() throws {
        verifyChatActionPreview(
            prompt: "通知我喝水",
            actionIdentifier: "chat.proposed-action.sendNotification",
            previewContains: ["Schedule Local Notification"],
            resultText: "Scheduled local notification."
        )
    }

    func testChatCanPreviewAndConfirmReminderAction() throws {
        verifyChatActionPreview(
            prompt: "建立提醒事項：下班前整理 Kairo model list",
            actionIdentifier: "chat.proposed-action.createReminderDraft",
            previewContains: ["Create Reminder"],
            resultText: "Created reminder: 下班前整理 Kairo model list"
        )
    }

    func testChatCanPreviewAndConfirmCalendarAction() throws {
        verifyChatActionPreview(
            prompt: "幫我安排週五 10:00 Kairo roadmap review 會議",
            actionIdentifier: "chat.proposed-action.createCalendarDraft",
            reviewIdentifier: "chat.calendar.review-action",
            previewContains: ["Create Calendar Event", "Kairo roadmap review", "Creates calendar event"],
            resultText: "Created calendar event: Kairo roadmap review"
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
            reviewIdentifier: "chat.handoff.review-action",
            reviewBannerIdentifier: "chat.handoff.review-banner",
            previewContains: ["Compose Email Draft", "alex@example.com", "Kairo update"],
            resultText: "Opened visible Mail draft handoff. No email has been sent."
        )
    }

    func testChatCanPreviewAndConfirmMapDirectionsHandoff() throws {
        verifyChatActionPreview(
            prompt: "Drive to Apple Park",
            actionIdentifier: "chat.proposed-action.openMapDirections",
            reviewIdentifier: "chat.handoff.review-action",
            reviewBannerIdentifier: "chat.handoff.review-banner",
            previewContains: ["Open Apple Maps Directions", "Apple Park", "Apple Maps opens visibly"],
            resultText: "Opened visible Apple Maps handoff. Navigation still requires user action in Maps."
        )
    }

    func testChatCanPreviewAndConfirmMessagesHandoff() throws {
        verifyChatActionPreview(
            prompt: "Text 0912-345-678 body I am running late.",
            actionIdentifier: "chat.proposed-action.openMessageHandoff",
            reviewIdentifier: "chat.handoff.review-action",
            reviewBannerIdentifier: "chat.handoff.review-banner",
            previewContains: ["Open Messages Handoff", "0912-345-678", "I am running late.", "Body stays in Kairo preview"],
            resultText: "Opened visible Messages recipient handoff. No message has been sent"
        )
    }

    func testChatCanPreviewAndConfirmPhoneCallHandoff() throws {
        verifyChatActionPreview(
            prompt: "Call 0912-345-678",
            actionIdentifier: "chat.proposed-action.openPhoneCallHandoff",
            reviewIdentifier: "chat.handoff.review-action",
            reviewBannerIdentifier: "chat.handoff.review-banner",
            previewContains: ["Phone Handoff", "0912-345-678", "Phone opens visibly"],
            resultText: "Opened visible Phone handoff. No call has been placed"
        )
    }

    func testChatCanPreviewAndConfirmWebSearchHandoff() throws {
        verifyChatActionPreview(
            prompt: "Search web for SwiftUI App Intents examples",
            actionIdentifier: "chat.proposed-action.openWebSearchHandoff",
            reviewIdentifier: "chat.handoff.review-action",
            reviewBannerIdentifier: "chat.handoff.review-banner",
            previewContains: ["Web Search Handoff", "SwiftUI App Intents examples", "Safari opens visibly"],
            resultText: "Opened visible Safari web search handoff. No browsing has happened inside Kairo."
        )
    }

}
