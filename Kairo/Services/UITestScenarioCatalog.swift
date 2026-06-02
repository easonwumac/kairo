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
            id: "chat-tool-preview",
            title: "Chat Tool Preview",
            userGoal: "Ask for a HomeKit skill action and verify Kairo shows a visible confirmation preview instead of silently executing it.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.controlHome"
            ],
            assertions: [
                "A HomeKit request creates an assistant response.",
                "The response exposes a proposed action strip.",
                "The HomeKit action preview is visible and remains confirmation-gated."
            ]
        ),
        UITestScenario(
            id: "chat-shortcut-tool-candidate",
            title: "Chat Shortcut Tool Candidate",
            userGoal: "Ask for task extraction and verify Kairo surfaces an installed Shortcut skill candidate without silently running Apple Shortcuts.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.tool-candidates",
                "chat.tool-candidate.shortcut-save-shared-text"
            ],
            assertions: [
                "A task-extraction request creates an assistant response.",
                "The response exposes a managed tool candidate strip.",
                "The Shortcut skill candidate is visible as a handoff/setup path, not an executed Shortcut."
            ]
        ),
        UITestScenario(
            id: "memory-manual-save",
            title: "Memory Manual Save",
            userGoal: "Open Memory, save a user-provided memory, and verify it appears in the list.",
            requiredAccessibilityIdentifiers: [
                "root.tab.memory",
                "memory.add.text",
                "memory.add.save",
                "memory.list",
                "memory.record"
            ],
            assertions: [
                "The Memory tab exposes a manual memory text field.",
                "The Save button is disabled until the user enters text.",
                "A saved memory appears visibly in the Memory list."
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
            id: "settings-shortcut-demo-io",
            title: "Shortcut Demo Input Output Contracts",
            userGoal: "Open Settings and verify every Shortcut demo exposes node steps, Shortcut input fields, output fields, and sample input.",
            requiredAccessibilityIdentifiers: [
                "settings.shortcuts.demos",
                "settings.shortcuts.demo.daily-briefing",
                "settings.shortcuts.demo.daily-briefing.input",
                "settings.shortcuts.demo.daily-briefing.output",
                "settings.shortcuts.demo.daily-briefing.sample",
                "settings.shortcuts.demo.save-shared-text",
                "settings.shortcuts.demo.save-shared-text.input",
                "settings.shortcuts.demo.save-shared-text.output",
                "settings.shortcuts.demo.save-shared-text.sample",
                "settings.shortcuts.demo.screenshot-to-reminders",
                "settings.shortcuts.demo.screenshot-to-reminders.input",
                "settings.shortcuts.demo.screenshot-to-reminders.output",
                "settings.shortcuts.demo.screenshot-to-reminders.sample"
            ],
            assertions: [
                "Each Shortcut demo row is visible in Settings.",
                "Each demo shows the Kairo node path.",
                "Each demo shows Shortcut input contract fields.",
                "Each demo shows output contract fields.",
                "Each demo exposes sample input without executing Apple Shortcuts."
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
