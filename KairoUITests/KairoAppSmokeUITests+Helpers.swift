import XCTest

extension KairoAppSmokeUITests {
    func assertPrimaryDrawerItemsExist() {
        XCTAssertTrue(anyElement("root.safe-area-header").waitForExistence(timeout: 5))
        let menuButton = findButton("root.drawer.toggle", direction: .both, maxSwipes: 1)
        XCTAssertTrue(menuButton.exists)
        XCTAssertGreaterThan(menuButton.frame.minY, 20)

        openDrawer()
        XCTAssertTrue(findButton("root.drawer.chat", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.memory", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.shortcuts", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.access", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.models", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findButton("root.drawer.settings", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Phone tools", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "Workflows", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: "AI setup", direction: .both, maxSwipes: 1).exists)
        let closeButton = findButton("root.drawer.close", direction: .both, maxSwipes: 1)
        XCTAssertTrue(closeButton.exists)
        XCTAssertGreaterThan(closeButton.frame.minY, 20)
        closeDrawerIfOpen()
    }

    func sendChatMessage() {
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

    func openAccessAndVerifyHomeKitDemos() {
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")
        scrollTowardTop()
        expandAdvancedSkillSetup()
        XCTAssertTrue(findButton("access.skills.marketplace-refresh", direction: .down, maxSwipes: 4).exists)
        XCTAssertTrue(findElement("access.skills.manifest-import", direction: .down).exists)
        XCTAssertTrue(findElement("access.skills.manifest-import.text", direction: .down).exists)
        XCTAssertTrue(findButton("access.skills.manifest-import.button", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.homekit-evening-scene", direction: .down).exists)
        XCTAssertTrue(findButton("access.skill.homekit-evening-scene.manage", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-save-shared-text", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-screenshot-to-reminders", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-reply-draft-from-shared-text", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-email-triage", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-meeting-prep-brief", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-generic-node-runner", direction: .down).exists)
        XCTAssertTrue(findElement("access.homekit.demos", direction: .down).exists)
        XCTAssertTrue(findElement("access.homekit.demo.evening-scene", direction: .down).exists)
        XCTAssertTrue(findButton("access.homekit.demo.evening-scene.confirm", direction: .down).exists)
    }

    func verifySkillManagerInteractionFlow() {
        selectDrawerSection(identifier: "root.drawer.access", label: "Access")
        expandAdvancedSkillSetup()

        let refreshMarketplace = findButton("access.skills.marketplace-refresh", direction: .down, maxSwipes: 4)
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

    func expandAdvancedSkillSetup() {
        if anyElement("access.skills.manifest-import").exists {
            return
        }
        let toggle = findElement("access.skills.advanced.toggle", direction: .down, maxSwipes: 8)
        XCTAssertTrue(toggle.exists)
        tapElement(toggle)
        XCTAssertTrue(findElement("access.skills.manifest-import", direction: .down, maxSwipes: 4).waitForExistence(timeout: 5))
    }

    func openSettingsAndVerifyAPIKeyStatus(verifyAllLocalModels: Bool) {
        selectDrawerSection(identifier: "root.drawer.settings", label: "Settings")
        openConnectionSetupIfNeeded()
        XCTAssertTrue(findElement("settings.openai.api-key-status").exists)
        XCTAssertTrue(anyElement("settings.openai.api-key-field").exists)
        XCTAssertTrue(findButton("settings.openai.save-api-key").exists)
        XCTAssertTrue(findElement("settings.oauth.connectors", direction: .down).exists)
        if verifyAllLocalModels {
            openModelsAndVerifyLocalModelCatalog(verifyAllLocalModels: true)
        }
    }

    func openConnectionSetupIfNeeded() {
        if anyElement("settings.openai.api-key-status").exists {
            return
        }
        let setup = findButton(labeled: "Show connection setup", direction: .both, maxSwipes: 3)
        XCTAssertTrue(setup.exists)
        tapElement(setup)
        guard !anyElement("settings.openai.api-key-status").waitForExistence(timeout: 2) else {
            return
        }

        let identifiedSetup = findElement("settings.connection.toggle", direction: .both, maxSwipes: 1)
        XCTAssertTrue(identifiedSetup.exists)
        tapElement(identifiedSetup)
        XCTAssertTrue(anyElement("settings.openai.api-key-status").waitForExistence(timeout: 2))
    }

    func openModelsAndVerifyLocalModelCatalog(verifyAllLocalModels: Bool, selectFromDrawer: Bool = true) {
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
        XCTAssertTrue(app.staticTexts["settings.models.\(localModelsToVerify[0].0).status"].label.contains("Downloadable"))
        XCTAssertTrue(app.buttons["settings.models.\(localModelsToVerify[0].0).download"].exists)
        for localModel in localModelsToVerify {
            verifyDownloadableLocalModel(
                id: localModel.0,
                displayName: localModel.1,
                downloadIdentifier: "settings.models.\(localModel.0).download"
            )
        }
    }

    func verifyDownloadableLocalModel(id: String, displayName: String, downloadIdentifier: String) {
        XCTAssertFalse(displayName.isEmpty)
        XCTAssertTrue(anyElement("settings.models.\(id).name").exists, id)
        if id == "qwen3-5-0-8b-q4-k-m" {
            let runtimeFit = anyElement("settings.models.\(id).runtime-fit")
            XCTAssertTrue(runtimeFit.exists)
            XCTAssertTrue(runtimeFit.label.contains("Download: GGUF"))
            XCTAssertTrue(runtimeFit.label.contains("MLX ref only"))
            XCTAssertTrue(anyElement("settings.models.\(id).runtime-pill.0").exists)
            XCTAssertTrue(anyElement("settings.models.\(id).runtime-pill.1").exists)
            XCTAssertTrue(anyElement("settings.models.\(id).runtime-pill.2").exists)

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

    func verifyShortcutDemoContract(
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

    func assertShortcutDemoField(namespace: String = "settings.shortcuts.demo", id: String, suffix: String, contains expectedText: String) {
        let element = findElement("\(namespace).\(id).\(suffix)", direction: .both, maxSwipes: 4)
        XCTAssertTrue(element.exists, "\(namespace).\(id).\(suffix) should exist")
        XCTAssertTrue(
            element.label.contains(expectedText),
            "\(namespace).\(id).\(suffix) label '\(element.label)' should contain '\(expectedText)'"
        )
    }

    func verifyOAuthConnector(
        providerKey: String,
        displayName: String,
        detailText: String,
        expectsBackendExchange: Bool
    ) {
        XCTAssertFalse(providerKey.isEmpty)
        XCTAssertTrue(findStaticText(containing: displayName, direction: .both, maxSwipes: 6).exists)
        XCTAssertTrue(findStaticText(containing: "Client configuration required", direction: .both, maxSwipes: 1).exists)
        XCTAssertTrue(findStaticText(containing: detailText, direction: .both, maxSwipes: 2).exists)

        if expectsBackendExchange {
            XCTAssertTrue(findStaticText(containing: "Requires backend token exchange.", direction: .both, maxSwipes: 1).exists)
        }
    }

    func verifyChatActionPreview(
        prompt: String,
        actionIdentifier: String,
        reviewIdentifier: String? = nil,
        reviewBannerIdentifier: String? = nil,
        previewContains: [String],
        resultText: String
    ) {
        assertPrimaryDrawerItemsExist()
        selectDrawerSection(identifier: "root.drawer.chat", label: "Chat")
        openCurrentThreadIfNeeded()
        let composer = anyElement("chat.composer.text")
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText(prompt)
        anyElement("chat.composer.send").tap()

        XCTAssertTrue(anyElement("chat.message.assistant").waitForExistence(timeout: 5))
        if reviewIdentifier != nil {
            let bannerIdentifier = reviewBannerIdentifier ?? "chat.calendar.review-banner"
            XCTAssertTrue(findElement(bannerIdentifier, direction: .both, maxSwipes: 1).waitForExistence(timeout: 5))
        }
        let action = findButton(reviewIdentifier ?? actionIdentifier, direction: .down)
        XCTAssertTrue(action.exists)
        tapElement(action)

        XCTAssertTrue(anyElement("chat.action-preview").waitForExistence(timeout: 5))
        for text in previewContains {
            XCTAssertTrue(findStaticText(containing: text, direction: .both, maxSwipes: 1).exists, text)
        }
        let confirm = findButton("chat.action.confirm", direction: .both, maxSwipes: 1)
        XCTAssertTrue(confirm.exists)
        tapElement(confirm)

        XCTAssertTrue(anyElement("chat.action-result").waitForExistence(timeout: 5))
        XCTAssertTrue(findStaticText(containing: resultText, direction: .both, maxSwipes: 1).exists)
    }

    func selectDrawerSection(identifier: String, label: String) {
        dismissKeyboardIfPresent()
        openDrawer()
        let button = drawerButton(identifier: identifier, label: label)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    func openDrawer() {
        if anyElement("root.drawer").waitForExistence(timeout: 0.5) {
            return
        }

        let toggle = anyElement("root.drawer.toggle")
        XCTAssertTrue(toggle.waitForExistence(timeout: 5))
        toggle.tap()
        XCTAssertTrue(anyElement("root.drawer").waitForExistence(timeout: 5))
    }

    func closeDrawerIfOpen() {
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

    func drawerButton(identifier: String, label: String) -> XCUIElement {
        let identifiedButton = app.buttons[identifier]
        if identifiedButton.exists {
            return identifiedButton
        }

        return app.buttons[label]
    }

    func openCurrentThreadIfNeeded() {
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

    func findButton(
        _ identifier: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let query = app.buttons.matching(identifier: identifier)
        return findHittableButton(in: query, direction: direction, maxSwipes: maxSwipes)
    }

    func findElement(
        _ identifier: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let element = anyElement(identifier)
        return find(element, direction: direction, maxSwipes: maxSwipes)
    }

    func findTextField(
        _ identifier: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let identifiedElement = app.textFields.matching(identifier: identifier).firstMatch
        let element = identifiedElement.exists ? identifiedElement : app.textFields.firstMatch
        return find(element, direction: direction, maxSwipes: maxSwipes)
    }

    func findButton(
        labeled label: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "label == %@", label))
        return findHittableButton(in: query, direction: direction, maxSwipes: maxSwipes)
    }

    func findStaticText(
        containing text: String,
        direction: SearchDirection = .both,
        maxSwipes: Int = 8
    ) -> XCUIElement {
        let predicate = NSPredicate(format: "label CONTAINS %@", text)
        let staticText = app.staticTexts.containing(predicate).firstMatch
        return find(staticText, direction: direction, maxSwipes: maxSwipes)
    }

    func firstHittableButtonIdentifier(beginningWith prefix: String) -> XCUIElement {
        let query = app.buttons.matching(NSPredicate(format: "identifier BEGINSWITH %@", prefix))
        let hittable = query.allElementsBoundByIndex.first { $0.exists && $0.isHittable }
        return hittable ?? query.firstMatch
    }

    func tapElement(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.exists, file: file, line: line)
        if element.isHittable {
            element.tap()
            return
        }
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    func relaunchWithInstalledLocalModelForTesting(initialSection: String? = nil) {
        relaunchForUITesting(initialSection: initialSection, seedInstalledLocalModel: true)
    }

    func relaunchWithLiveLocalModelRuntimeForTesting(
        initialSection: String? = nil,
        modelFilePath: String,
        selectLocalModel: Bool = false,
        localRoutePreference: String? = nil
    ) {
        relaunchForUITesting(
            initialSection: initialSection,
            seedInstalledLocalModel: true,
            liveLocalModelRuntime: true,
            localModelFilePath: modelFilePath,
            selectLocalModel: selectLocalModel,
            localRoutePreference: localRoutePreference
        )
    }

    func relaunchForUITesting(
        initialSection: String? = nil,
        seedInstalledLocalModel: Bool = false,
        seedInstalledWeatherSkill: Bool = false,
        seedExpandedLocalModelCatalog: Bool = false,
        seedSharedTaskText: Bool = false,
        settingsShortcutDemosOnly: Bool = false,
        liveLocalModelRuntime: Bool = false,
        localModelFilePath: String? = nil,
        selectLocalModel: Bool = false,
        localRoutePreference: String? = nil
    ) {
        app.terminate()
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--reset-ui-testing-data")
        app.launchArguments.append(contentsOf: ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"])
        if seedInstalledLocalModel {
            app.launchArguments.append("--ui-testing-installed-local-model")
        }
        if seedInstalledWeatherSkill {
            app.launchArguments.append("--ui-testing-installed-weather-skill")
        }
        if seedExpandedLocalModelCatalog {
            app.launchArguments.append("--ui-testing-expanded-local-model-catalog")
        }
        if seedSharedTaskText {
            app.launchArguments.append("--ui-testing-seed-shared-task")
        }
        if settingsShortcutDemosOnly {
            app.launchArguments.append("--ui-testing-settings-shortcut-demos-only")
        }
        if liveLocalModelRuntime {
            app.launchArguments.append("--ui-testing-live-local-model-runtime")
        }
        if let localModelFilePath {
            app.launchArguments.append("--ui-testing-local-model-file=\(localModelFilePath)")
        }
        if selectLocalModel {
            app.launchArguments.append("--ui-testing-select-local-model")
        }
        if let localRoutePreference {
            app.launchArguments.append("--ui-testing-local-route-preference=\(localRoutePreference)")
        }
        if let initialSection {
            app.launchArguments.append("--ui-testing-root-section=\(initialSection)")
        }
        app.launch()
    }

    func find(
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

    func findHittableButton(
        in query: XCUIElementQuery,
        direction: SearchDirection,
        maxSwipes: Int
    ) -> XCUIElement {
        if let button = firstExistingButton(in: query), button.isHittable {
            return button
        }

        if direction == .down || direction == .both {
            for _ in 0..<maxSwipes {
                scrollDown()
                if let button = firstExistingButton(in: query), button.isHittable {
                    return button
                }
            }
        }

        if direction == .up || direction == .both {
            for _ in 0..<maxSwipes {
                scrollUp()
                if let button = firstExistingButton(in: query), button.isHittable {
                    return button
                }
            }
        }

        return query.firstMatch
    }

    private func firstExistingButton(in query: XCUIElementQuery) -> XCUIElement? {
        let buttons = query.allElementsBoundByIndex
        if let hittable = buttons.first(where: { $0.exists && $0.isHittable }) {
            return hittable
        }
        return buttons.first { $0.exists }
    }

    func anyElement(_ identifier: String) -> XCUIElement {
        app.descendants(matching: .any)[identifier]
    }

    func scrollTowardTop(maxSwipes: Int = 4) {
        for _ in 0..<maxSwipes {
            scrollUp()
        }
    }

    func dismissKeyboardIfPresent() {
        let keyboard = app.keyboards.firstMatch
        guard keyboard.exists else {
            return
        }

        let doneButton = keyboard.buttons["Done"]
        let returnButton = keyboard.buttons["Return"]
        let keyboardDismissButton = doneButton.exists ? doneButton : returnButton
        if keyboardDismissButton.exists {
            keyboardDismissButton.tap()
            if keyboard.waitForNonExistence(timeout: 2) {
                return
            }
        }

        app.swipeDown()
        _ = keyboard.waitForNonExistence(timeout: 3)
    }

    func scrollDown() {
        scrollingSurface().swipeUp()
    }

    func scrollUp() {
        scrollingSurface().swipeDown()
    }

    func scrollingSurface() -> XCUIElement {
        let collectionView = app.collectionViews.firstMatch
        if collectionView.exists {
            return collectionView
        }

        let scrollView = app.scrollViews.allElementsBoundByIndex.first { element in
            element.exists && element.identifier != "root.primary-tabs"
        }
        if let scrollView {
            return scrollView
        }

        return app
    }
}
