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
        ("qwen3-5-2b-q4-k-m", "Qwen3.5 2B Q4_K_M"),
        ("qwen3-0-6b-q4-k-m", "Qwen3 0.6B Q4_K_M"),
        ("qwen3-1-7b-q4-k-m", "Qwen3 1.7B Q4_K_M"),
        ("qwen2-5-0-5b-instruct-q4-k-m", "Qwen2.5 0.5B Instruct Q4_K_M"),
        ("qwen2-5-1-5b-instruct-q4-k-m", "Qwen2.5 1.5B Instruct Q4_K_M"),
        ("llama3-2-1b-instruct-q4-k-m", "Llama 3.2 1B Instruct Q4_K_M"),
        ("deepseek-r1-distill-qwen-1-5b-q4-k-m", "DeepSeek R1 Distill Qwen 1.5B Q4_K_M"),
        ("h2o-danube2-1-8b-chat-q4-k-m", "H2O Danube2 1.8B Chat Q4_K_M"),
        ("openelm-1-1b-instruct-q4-k-m", "OpenELM 1.1B Instruct Q4_K_M"),
        ("falcon-h1-1-5b-instruct-q4-k-m", "Falcon-H1 1.5B Instruct Q4_K_M"),
        ("smollm2-135m-instruct-q4-k-m", "SmolLM2 135M Instruct Q4_K_M"),
        ("smollm2-360m-instruct-q4-k-m", "SmolLM2 360M Instruct Q4_K_M"),
        ("smollm2-1-7b-instruct-q4-k-m", "SmolLM2 1.7B Instruct Q4_K_M"),
        ("tinyllama-1-1b-chat-q4-k-m", "TinyLlama 1.1B Chat Q4_K_M"),
        ("gemma3-1b-it-q4-k-m", "Gemma 3 1B IT Q4_K_M"),
        ("gemma2-2b-it-q4-k-m", "Gemma 2 2B IT Q4_K_M"),
        ("gemma4-e2b-it-q4-k-m", "Gemma 4 E2B IT Q4_K_M")
    ]
    private let localModelDownloadIdentifiers = [
        "settings.models.qwen3-5-0-8b-q4-k-m.download",
        "settings.models.qwen3-5-2b-q4-k-m.download",
        "settings.models.qwen3-0-6b-q4-k-m.download",
        "settings.models.qwen3-1-7b-q4-k-m.download",
        "settings.models.qwen2-5-0-5b-instruct-q4-k-m.download",
        "settings.models.qwen2-5-1-5b-instruct-q4-k-m.download",
        "settings.models.llama3-2-1b-instruct-q4-k-m.download",
        "settings.models.deepseek-r1-distill-qwen-1-5b-q4-k-m.download",
        "settings.models.h2o-danube2-1-8b-chat-q4-k-m.download",
        "settings.models.openelm-1-1b-instruct-q4-k-m.download",
        "settings.models.falcon-h1-1-5b-instruct-q4-k-m.download",
        "settings.models.smollm2-135m-instruct-q4-k-m.download",
        "settings.models.smollm2-360m-instruct-q4-k-m.download",
        "settings.models.smollm2-1-7b-instruct-q4-k-m.download",
        "settings.models.tinyllama-1-1b-chat-q4-k-m.download",
        "settings.models.gemma3-1b-it-q4-k-m.download",
        "settings.models.gemma2-2b-it-q4-k-m.download",
        "settings.models.gemma4-e2b-it-q4-k-m.download"
    ]

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launchArguments.append("--reset-ui-testing-data")
        app.launch()
    }

    func testLaunchTabsChatAndSettingsSmokeFlow() throws {
        assertPrimaryTabsExist()
        sendChatMessage()
        openAccessAndVerifyHomeKitDemos()
        verifySkillManagerInteractionFlow()
        openSettingsAndVerifyAPIKeyStatus(verifyAllLocalModels: false)
    }

    func testSettingsLocalModelCatalogListsDownloadableModels() throws {
        assertPrimaryTabsExist()
        openSettingsAndVerifyAPIKeyStatus(verifyAllLocalModels: true)
    }

    private func assertPrimaryTabsExist() {
        XCTAssertTrue(tabButton(identifier: "root.tab.chat", label: "Chat").waitForExistence(timeout: 5))
        XCTAssertTrue(tabButton(identifier: "root.tab.memory", label: "Memory").exists)
        XCTAssertTrue(tabButton(identifier: "root.tab.access", label: "Access").exists)
        XCTAssertTrue(tabButton(identifier: "root.tab.settings", label: "Settings").exists)
    }

    private func sendChatMessage() {
        tapTab(identifier: "root.tab.chat", label: "Chat")
        openCurrentThreadIfNeeded()
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
        tapTab(identifier: "root.tab.access", label: "Access")
        scrollTowardTop()
        XCTAssertTrue(findButton("access.skills.marketplace-refresh", direction: .down).exists)
        XCTAssertTrue(findElement("access.skills.manifest-import", direction: .down).exists)
        XCTAssertTrue(findElement("access.skills.manifest-import.text", direction: .down).exists)
        XCTAssertTrue(findButton("access.skills.manifest-import.button", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.homekit-evening-scene", direction: .down).exists)
        XCTAssertTrue(findButton("access.skill.homekit-evening-scene.manage", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-save-shared-text", direction: .down).exists)
        XCTAssertTrue(findElement("access.skill.shortcut-screenshot-to-reminders", direction: .down).exists)
        XCTAssertTrue(findElement("access.homekit.demos", direction: .down).exists)
        XCTAssertTrue(findElement("access.homekit.demo.evening-scene", direction: .down).exists)
        XCTAssertTrue(findButton("access.homekit.demo.evening-scene.confirm", direction: .down).exists)
    }

    private func verifySkillManagerInteractionFlow() {
        tapTab(identifier: "root.tab.access", label: "Access")

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
        tapTab(identifier: "root.tab.settings", label: "Settings")
        XCTAssertTrue(findElement("settings.openai.api-key-status").exists)
        XCTAssertTrue(anyElement("settings.openai.api-key-field").exists)
        XCTAssertTrue(findButton("settings.openai.save-api-key").exists)
        XCTAssertTrue(findElement("settings.oauth.connectors", direction: .down).exists)
        XCTAssertTrue(findElement("settings.models.local", direction: .down).exists)
        XCTAssertTrue(findStaticText(containing: "github.com/easonwumac/kairo-models", direction: .down).exists)
        let refreshCatalogButton = findButton(labeled: "Refresh Catalog", direction: .both)
        XCTAssertTrue(refreshCatalogButton.exists)
        refreshCatalogButton.tap()
        XCTAssertTrue(findStaticText(containing: "已刷新 model catalog", direction: .down).exists)
        scrollTowardTop(maxSwipes: 8)
        XCTAssertTrue(findElement("settings.models.local", direction: .down).exists)
        let localModelsToVerify = verifyAllLocalModels
            ? localModelExpectations.sorted { $0.0 < $1.0 }
            : Array(localModelExpectations.prefix(3).sorted { $0.0 < $1.0 })
        for localModel in localModelsToVerify {
            verifyDownloadableLocalModel(
                id: localModel.0,
                displayName: localModel.1,
                downloadIdentifier: "settings.models.\(localModel.0).download"
            )
        }
        XCTAssertTrue(findStaticText(containing: "可下載", direction: .both).exists)
        XCTAssertTrue(findButton(labeled: "Download", direction: .both).exists)
        XCTAssertTrue(findElement("settings.shortcuts.demos", direction: .down).exists)
    }

    private func verifyDownloadableLocalModel(id: String, displayName: String, downloadIdentifier: String) {
        XCTAssertFalse(displayName.isEmpty)
        XCTAssertTrue(findElement("settings.models.\(id).name", direction: .down, maxSwipes: 6).exists)
        XCTAssertTrue(findButton(downloadIdentifier, direction: .down, maxSwipes: 2).exists)
    }

    private func tapTab(identifier: String, label: String) {
        dismissKeyboardIfPresent()
        let button = tabButton(identifier: identifier, label: label)
        XCTAssertTrue(button.waitForExistence(timeout: 5))
        button.tap()
    }

    private func tabButton(identifier: String, label: String) -> XCUIElement {
        let tabBarButton = app.tabBars.buttons[label]
        if tabBarButton.exists {
            return tabBarButton
        }

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
