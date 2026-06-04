import XCTest

final class KairoAppPersistenceUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testChatHistoryPersistsAfterAppRelaunch() throws {
        let persistedPrompt = "Persist chat history across relaunch"

        launchForUITesting(resetPersistentState: true)
        sendChatMessage(persistedPrompt)

        app.terminate()

        launchForUITesting(resetPersistentState: false)
        XCTAssertTrue(app.textFields["chat.composer.text"].waitForExistence(timeout: 5))
        let persistedUserMessage = app.otherElements["chat.message.user"]
        XCTAssertTrue(persistedUserMessage.waitForExistence(timeout: 5))
        XCTAssertTrue(persistedUserMessage.label.contains(persistedPrompt), persistedUserMessage.label)
        XCTAssertTrue(app.otherElements["chat.message.assistant"].waitForExistence(timeout: 5))
    }

    private func launchForUITesting(resetPersistentState: Bool) {
        app = XCUIApplication()
        app.launchArguments = ["--ui-testing", "--ui-testing-root-section=chat"]
        if resetPersistentState {
            app.launchArguments.append("--reset-ui-testing-data")
        }
        app.launch()
    }

    private func sendChatMessage(_ text: String) {
        let composer = app.textFields["chat.composer.text"]
        XCTAssertTrue(composer.waitForExistence(timeout: 5))
        composer.tap()
        composer.typeText(text)
        app.buttons["chat.composer.send"].tap()

        XCTAssertTrue(app.otherElements["chat.message.user"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.otherElements["chat.message.assistant"].waitForExistence(timeout: 5))
    }
}
