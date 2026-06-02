import XCTest

final class KairoAppSmokeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments.append("--ui-testing")
        app.launch()
    }

    func testLaunchTabsChatAndSettingsSmokeFlow() throws {
        assertPrimaryTabsExist()
        sendChatMessage()
        openSettingsAndVerifyAPIKeyStatus()
    }

    private func assertPrimaryTabsExist() {
        XCTAssertTrue(app.buttons["root.tab.chat"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["root.tab.memory"].exists)
        XCTAssertTrue(app.buttons["root.tab.access"].exists)
        XCTAssertTrue(app.buttons["root.tab.settings"].exists)
    }

    private func sendChatMessage() {
        app.buttons["root.tab.chat"].tap()
        let composer = app.textFields["chat.composer.text"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText("Run the Kairo UI smoke test")
        app.buttons["chat.composer.send"].tap()

        XCTAssertTrue(app.staticTexts["Run the Kairo UI smoke test"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts.containing(NSPredicate(format: "label CONTAINS %@", "mock 回應")).firstMatch.waitForExistence(timeout: 5))
    }

    private func openSettingsAndVerifyAPIKeyStatus() {
        app.buttons["root.tab.settings"].tap()
        XCTAssertTrue(app.otherElements["settings.form"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["settings.openai.api-key-status"].exists)
        XCTAssertTrue(app.secureTextFields["settings.openai.api-key-field"].exists)
        XCTAssertTrue(app.buttons["settings.openai.save-api-key"].exists)
        XCTAssertTrue(app.otherElements["settings.oauth.connectors"].exists)
        XCTAssertTrue(app.otherElements["settings.models.local"].exists)
        XCTAssertTrue(app.otherElements["settings.models.preference"].exists)
        XCTAssertTrue(app.otherElements["settings.shortcuts.demos"].exists)
    }
}
