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
                "chat.history.thread",
                "chat.new",
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.user",
                "chat.message.assistant"
            ],
            assertions: [
                "A chat thread or new chat entry point can open the composer.",
                "User-entered text appears in the transcript.",
                "A Kairo assistant response appears after sending."
            ]
        ),
        UITestScenario(
            id: "settings-api-key-status",
            title: "Settings Credential Status",
            userGoal: "Open Settings and verify API key plus OAuth connector status is visible without exposing secret values.",
            requiredAccessibilityIdentifiers: [
                "settings.openai.api-key-status",
                "settings.openai.api-key-field",
                "settings.openai.save-api-key",
                "settings.oauth.connectors",
                "settings.models.local",
                "settings.models.refresh-catalog",
                "settings.models.catalog-source",
                "settings.models.qwen3-5-0-8b-q4-k-m.status",
                "settings.models.qwen3-5-0-8b-q4-k-m.download",
                "settings.models.qwen3-5-2b-q4-k-m.status",
                "settings.models.qwen3-5-2b-q4-k-m.download",
                "settings.models.qwen3-0-6b-q4-k-m.status",
                "settings.models.qwen3-0-6b-q4-k-m.download",
                "settings.models.qwen3-1-7b-q4-k-m.status",
                "settings.models.qwen3-1-7b-q4-k-m.download",
                "settings.models.qwen2-5-0-5b-instruct-q4-k-m.status",
                "settings.models.qwen2-5-0-5b-instruct-q4-k-m.download",
                "settings.models.qwen2-5-1-5b-instruct-q4-k-m.status",
                "settings.models.qwen2-5-1-5b-instruct-q4-k-m.download",
                "settings.models.llama3-2-1b-instruct-q4-k-m.status",
                "settings.models.llama3-2-1b-instruct-q4-k-m.download",
                "settings.models.deepseek-r1-distill-qwen-1-5b-q4-k-m.status",
                "settings.models.deepseek-r1-distill-qwen-1-5b-q4-k-m.download",
                "settings.models.h2o-danube2-1-8b-chat-q4-k-m.status",
                "settings.models.h2o-danube2-1-8b-chat-q4-k-m.download",
                "settings.models.openelm-1-1b-instruct-q4-k-m.status",
                "settings.models.openelm-1-1b-instruct-q4-k-m.download",
                "settings.models.falcon-h1-1-5b-instruct-q4-k-m.status",
                "settings.models.falcon-h1-1-5b-instruct-q4-k-m.download",
                "settings.models.smollm2-135m-instruct-q4-k-m.status",
                "settings.models.smollm2-135m-instruct-q4-k-m.download",
                "settings.models.smollm2-360m-instruct-q4-k-m.status",
                "settings.models.smollm2-360m-instruct-q4-k-m.download",
                "settings.models.smollm2-1-7b-instruct-q4-k-m.status",
                "settings.models.smollm2-1-7b-instruct-q4-k-m.download",
                "settings.models.tinyllama-1-1b-chat-q4-k-m.status",
                "settings.models.tinyllama-1-1b-chat-q4-k-m.download",
                "settings.models.gemma3-1b-it-q4-k-m.status",
                "settings.models.gemma3-1b-it-q4-k-m.download",
                "settings.models.gemma2-2b-it-q4-k-m.status",
                "settings.models.gemma2-2b-it-q4-k-m.download",
                "settings.models.gemma4-e2b-it-q4-k-m.status",
                "settings.models.gemma4-e2b-it-q4-k-m.download",
                "settings.shortcuts.demos"
            ],
            assertions: [
                "API key status is visible.",
                "API key field is secure and save is disabled until text is entered.",
                "OAuth connector status list is visible.",
                "Local model catalog and status rows are visible.",
                "Local model route preference is visible.",
                "Shortcut demo recipes are visible."
            ]
        ),
        UITestScenario(
            id: "access-homekit-demos",
            title: "Access HomeKit Control Demos",
            userGoal: "Open Access and verify HomeKit control examples are visible as confirmed, sandbox-safe demos.",
            requiredAccessibilityIdentifiers: [
                "root.tab.access",
                "access.skills.manager",
                "access.skills.marketplace-refresh",
                "access.skills.manifest-import",
                "access.skills.manifest-import.text",
                "access.skills.manifest-import.button",
                "access.skill.shortcut-save-shared-text",
                "access.skill.shortcut-screenshot-to-reminders",
                "access.skill.shortcut-save-shared-text.disable",
                "access.skill.shortcut-save-shared-text.enable",
                "access.skill.marketplace-weather-briefing.install",
                "access.skills.message",
                "access.skills.manifest-preview.confirm",
                "access.homekit.demos",
                "access.homekit.demo.evening-scene",
                "access.homekit.demo.evening-scene.confirm"
            ],
            assertions: [
                "Skill Manager section is visible.",
                "Marketplace refresh control is visible.",
                "Signed manifest import controls are visible.",
                "Shortcut demo skills are visible in the Skill Manager.",
                "A built-in Shortcut skill can be disabled and enabled.",
                "A marketplace skill can show a signed manifest preview and confirm install.",
                "HomeKit demo section is visible.",
                "A scene control demo is visible.",
                "The demo exposes confirmation before execution."
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
