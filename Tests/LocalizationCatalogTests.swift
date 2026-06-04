import XCTest

final class LocalizationCatalogTests: XCTestCase {
    func testChatFlowLocalizationKeysHaveEnglishAndTraditionalChineseValues() throws {
        let keys = [
            "chat.share.action.extractReminders",
            "chat.share.action.summarize",
            "chat.share.action.sendToChat",
            "chat.share.prompt.extractReminder",
            "chat.share.review.reminderReady",
            "chat.welcome.default",
            "chat.action.reviewReminder",
            "chat.action.reviewCalendar",
            "chat.action.reviewHandoff",
            "chat.action.preview.title",
            "chat.action.preview.confirm",
            "chat.action.result.reminder.success",
            "chat.action.result.calendar.success",
            "chat.action.result.email.success",
            "chat.action.result.message.success",
            "chat.action.result.phone.success",
            "chat.action.result.web.success",
            "chat.error.openAIKeyMissing",
            "chat.error.localInferenceUnavailable",
            "chat.provider.warning.openAIKeyMissing"
        ]
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let english = try localizedStrings(at: root.appendingPathComponent("Kairo/Resources/en.lproj/Localizable.strings"))
        let traditionalChinese = try localizedStrings(at: root.appendingPathComponent("Kairo/Resources/zh-Hant.lproj/Localizable.strings"))

        for key in keys {
            XCTAssertFalse(english[key, default: ""].isEmpty, "Missing English value for \(key)")
            XCTAssertFalse(traditionalChinese[key, default: ""].isEmpty, "Missing zh-Hant value for \(key)")
            XCTAssertNotEqual(english[key], key)
            XCTAssertNotEqual(traditionalChinese[key], key)
        }
    }

    private func localizedStrings(at url: URL) throws -> [String: String] {
        let dictionary = try XCTUnwrap(NSDictionary(contentsOf: url) as? [String: String])
        return dictionary
    }
}
