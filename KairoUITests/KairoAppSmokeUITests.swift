import XCTest

final class KairoAppSmokeUITests: XCTestCase {
    private enum SearchDirection: Equatable {
        case down
        case up
        case both
    }

    private var app: XCUIApplication!

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
        openSettingsAndVerifyAPIKeyStatus()
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

    private func openSettingsAndVerifyAPIKeyStatus() {
        tapTab(identifier: "root.tab.settings", label: "Settings")
        XCTAssertTrue(findElement("settings.openai.api-key-status").exists)
        XCTAssertTrue(anyElement("settings.openai.api-key-field").exists)
        XCTAssertTrue(findButton("settings.openai.save-api-key").exists)
        XCTAssertTrue(findElement("settings.oauth.connectors", direction: .down).exists)
        XCTAssertTrue(findElement("settings.models.local", direction: .down).exists)
        XCTAssertTrue(findStaticText(containing: "Qwen3.5 0.8B Q4_K_M", direction: .down, maxSwipes: 3).exists)
        XCTAssertTrue(findStaticText(containing: "可下載", direction: .down, maxSwipes: 2).exists)
        XCTAssertTrue(findButton(labeled: "Download", direction: .down, maxSwipes: 2).exists)
        XCTAssertTrue(findElement("settings.shortcuts.demos", direction: .down).exists)
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
        if element.waitForExistence(timeout: 1) {
            return element
        }

        if direction == .down || direction == .both {
            for _ in 0..<maxSwipes {
                scrollDown()
                if element.waitForExistence(timeout: 1) {
                    return element
                }
            }
        }

        if direction == .up || direction == .both {
            for _ in 0..<maxSwipes {
                scrollUp()
                if element.waitForExistence(timeout: 1) {
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
