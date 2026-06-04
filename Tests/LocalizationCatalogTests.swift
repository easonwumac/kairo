import XCTest

final class LocalizationCatalogTests: XCTestCase {
    func testChatFlowLocalizationKeysHaveEnglishAndTraditionalChineseValues() throws {
        let keys = [
            "root.accessibility.shell",
            "root.backToChat",
            "root.menu",
            "root.menu.open",
            "root.menu.close",
            "root.menu.title",
            "root.menu.subtitle",
            "root.menu.privacyNote",
            "root.menu.accessibility",
            "root.navigation.title",
            "root.section.chat.title",
            "root.section.chat.subtitle",
            "root.section.memory.title",
            "root.section.memory.subtitle",
            "root.section.shortcuts.title",
            "root.section.shortcuts.subtitle",
            "root.section.access.title",
            "root.section.access.subtitle",
            "root.section.models.title",
            "root.section.models.subtitle",
            "root.section.settings.title",
            "root.section.settings.subtitle",
            "automations.title",
            "automations.subtitle",
            "automations.recipeCenter.section",
            "automations.recipeCenter.detail",
            "automations.recipeCenter.addSamples",
            "automations.shortcutTemplates.section",
            "automations.shortcutTemplates.openTemplate",
            "automations.shortcutDemos.section",
            "automations.shortcutDemos.detail",
            "automations.shortcutDemos.previewSample",
            "automations.shortcutDemos.previewSampleAccessibility",
            "automations.recipes.section",
            "automations.recipes.empty",
            "automations.status.section",
            "automations.recipe.enabled",
            "automations.recipe.disabled",
            "automations.recipe.risk",
            "automations.recipe.preview",
            "automations.recipe.run",
            "automations.recipe.enable",
            "automations.recipe.disable",
            "automations.message.loadFailed",
            "automations.message.samplesAdded",
            "automations.message.samplesAddFailed",
            "automations.message.samplePreview",
            "automations.message.samplePreviewFailed",
            "automations.message.previewResult",
            "automations.message.previewFailed",
            "automations.message.requiresConfirmation",
            "automations.message.runResult",
            "automations.message.runFailed",
            "automations.message.toggleResult",
            "automations.message.toggleFailed",
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
            "chat.action.support.implemented",
            "chat.action.support.needsConfirmation",
            "chat.action.support.plannedIntegration",
            "chat.action.support.unavailableInSandbox",
            "chat.action.description.answer",
            "chat.action.description.saveMemory",
            "chat.action.description.createReminder",
            "chat.action.description.createCalendar",
            "chat.action.description.createContact",
            "chat.action.description.composeEmail",
            "chat.action.description.openMaps",
            "chat.action.description.openMessages",
            "chat.action.description.openPhone",
            "chat.action.description.openWeb",
            "chat.action.description.sendNotification",
            "chat.action.description.openURL",
            "chat.action.description.controlHome",
            "chat.action.description.externalAPI",
            "chat.action.description.unsupported",
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
