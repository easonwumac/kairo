import Foundation

public struct UITestScenarioCatalog: Codable, Equatable, Sendable {
    public var scenarios: [UITestScenario]

    public init(scenarios: [UITestScenario]) {
        self.scenarios = scenarios
    }

    public func scenario(id: String) -> UITestScenario? {
        scenarios.first { $0.id == id }
    }

    public static let `default` = UITestScenarioCatalog(scenarios: [
        UITestScenario(
            id: "launch-tabs",
            title: "Launch and Tab Navigation",
            userGoal: "Confirm the app boots and exposes the primary Chat, Memory, Access, and Settings surfaces.",
            requiredAccessibilityIdentifiers: [
                "root.tab.chat",
                "root.tab.memory",
                "root.tab.access",
                "root.tab.settings"
            ],
            assertions: [
                "Chat tab is visible after launch.",
                "Memory, Access, and Settings tabs are reachable."
            ]
        ),
        UITestScenario(
            id: "chat-send",
            title: "Chat Send Smoke Test",
            userGoal: "Send a message through the chat composer and verify a visible assistant response.",
            requiredAccessibilityIdentifiers: [
                "chat.surface",
                "chat.composer.text",
                "chat.composer.send"
            ],
            assertions: [
                "User-entered text appears in the transcript.",
                "A Kairo assistant response appears after sending."
            ]
        ),
        UITestScenario(
            id: "settings-api-key-status",
            title: "Settings Credential Status",
            userGoal: "Open Settings and verify API key plus OAuth connector status is visible without exposing secret values.",
            requiredAccessibilityIdentifiers: [
                "settings.form",
                "settings.openai.api-key-status",
                "settings.openai.api-key-field",
                "settings.openai.save-api-key",
                "settings.oauth.connectors",
                "settings.shortcuts.demos"
            ],
            assertions: [
                "API key status is visible.",
                "API key field is secure and save is disabled until text is entered.",
                "OAuth connector status list is visible.",
                "Shortcut demo recipes are visible."
            ]
        )
    ])
}

public struct UITestScenario: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var userGoal: String
    public var requiredAccessibilityIdentifiers: [String]
    public var assertions: [String]

    public init(
        id: String,
        title: String,
        userGoal: String,
        requiredAccessibilityIdentifiers: [String],
        assertions: [String]
    ) {
        self.id = id
        self.title = title
        self.userGoal = userGoal
        self.requiredAccessibilityIdentifiers = requiredAccessibilityIdentifiers
        self.assertions = assertions
    }
}
