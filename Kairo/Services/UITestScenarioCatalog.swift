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
            userGoal: "Confirm the app boots and exposes the primary Chat, Memory, Automations, Access, and Settings surfaces.",
            requiredAccessibilityIdentifiers: [
                "root.tab.chat",
                "root.tab.memory",
                "root.tab.automations",
                "root.tab.access",
                "root.tab.settings"
            ],
            assertions: [
                "Chat tab is visible after launch.",
                "Memory, Automations, Access, and Settings tabs are reachable."
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
            id: "chat-notification-confirmation",
            title: "Chat Notification Confirmation",
            userGoal: "Ask Kairo to schedule a local notification, preview the action, and confirm it through a visible user-controlled flow.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.sendNotification",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "A notification request creates an assistant response.",
                "The response exposes a sendNotification action preview.",
                "The preview is shown before execution.",
                "The notification is scheduled only after visible confirmation."
            ]
        ),
        UITestScenario(
            id: "chat-reminder-confirmation",
            title: "Chat Reminder Confirmation",
            userGoal: "Ask Kairo to create an EventKit reminder, preview the action, and confirm it through a visible user-controlled flow.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.createReminderDraft",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "A reminder request creates an assistant response.",
                "The response exposes a createReminderDraft action preview.",
                "The preview is shown before EventKit execution.",
                "The reminder is created only after visible confirmation."
            ]
        ),
        UITestScenario(
            id: "chat-calendar-confirmation",
            title: "Chat Calendar Confirmation",
            userGoal: "Ask Kairo to create an EventKit calendar event, preview the action, and confirm it through a visible user-controlled flow.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.createCalendarDraft",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "A calendar request creates an assistant response.",
                "The response exposes a createCalendarDraft action preview.",
                "The preview is shown before EventKit execution.",
                "The calendar event is created only after visible confirmation."
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
            id: "automations-recipe-center",
            title: "Automations Recipe Center",
            userGoal: "Open Automations, add Kairo-owned sample recipes, preview/run a recipe, and toggle it without creating Apple Shortcuts.",
            requiredAccessibilityIdentifiers: [
                "root.tab.automations",
                "automations.recipe-center",
                "automations.seed-samples",
                "automations.list",
                "automations.recipe.daily-briefing",
                "automations.recipe.daily-briefing.preview",
                "automations.recipe.daily-briefing.run",
                "automations.recipe.daily-briefing.toggle",
                "automations.message"
            ],
            assertions: [
                "The Automations tab exposes Kairo internal recipes.",
                "Sample recipes are added by a visible user action.",
                "Preview and run actions stay within Kairo's recipe runner.",
                "Enable/disable state is user-visible.",
                "The UI states that Kairo does not create Apple Shortcuts silently."
            ]
        ),
        UITestScenario(
            id: "automations-shortcut-templates",
            title: "Automations Shortcut Templates",
            userGoal: "Open Automations and verify Kairo explains user-approved Apple Shortcuts template setup for running internal recipes.",
            requiredAccessibilityIdentifiers: [
                "root.tab.automations",
                "automations.shortcut-templates",
                "automations.shortcut-template.disclaimer",
                "automations.shortcut-template.run-kairo-recipe-shortcut",
                "automations.shortcut-template.run-kairo-recipe-shortcut.instructions"
            ],
            assertions: [
                "The Automations tab exposes Shortcut template metadata.",
                "The UI states that Apple Shortcuts installation requires user approval.",
                "Run Kairo Recipe template instructions are visible.",
                "Kairo does not claim silent Apple Shortcut installation."
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
                "settings.models.qwen2-5-coder-0-5b-instruct-q4-k-m.status",
                "settings.models.qwen2-5-coder-0-5b-instruct-q4-k-m.download",
                "settings.models.qwen2-5-coder-1-5b-instruct-q4-k-m.status",
                "settings.models.qwen2-5-coder-1-5b-instruct-q4-k-m.download",
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
                "settings.models.stablelm2-chat-1-6b-q4-k-m.status",
                "settings.models.stablelm2-chat-1-6b-q4-k-m.download",
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
            id: "settings-oauth-connectors",
            title: "Settings OAuth Connector Readiness",
            userGoal: "Open Settings and verify OAuth connector readiness, scope boundaries, and backend exchange requirements are visible.",
            requiredAccessibilityIdentifiers: [
                "settings.oauth.connectors",
                "settings.oauth.google.row",
                "settings.oauth.google.name",
                "settings.oauth.google.status",
                "settings.oauth.google.detail",
                "settings.oauth.google.backend-exchange",
                "settings.oauth.microsoft.row",
                "settings.oauth.microsoft.name",
                "settings.oauth.microsoft.status",
                "settings.oauth.microsoft.detail",
                "settings.oauth.microsoft.backend-exchange",
                "settings.oauth.notion.row",
                "settings.oauth.notion.name",
                "settings.oauth.notion.status",
                "settings.oauth.notion.detail",
                "settings.oauth.notion.backend-exchange",
                "settings.oauth.slack.row",
                "settings.oauth.slack.name",
                "settings.oauth.slack.status",
                "settings.oauth.slack.detail",
                "settings.oauth.slack.backend-exchange",
                "settings.oauth.chatgpt.row",
                "settings.oauth.chatgpt.name",
                "settings.oauth.chatgpt.status",
                "settings.oauth.chatgpt.detail",
                "settings.oauth.github.row",
                "settings.oauth.github.name",
                "settings.oauth.github.status",
                "settings.oauth.github.detail",
                "settings.oauth.github.backend-exchange"
            ],
            assertions: [
                "Every configured OAuth connector is visible in Settings.",
                "Readiness is visible without exposing stored tokens.",
                "Default scopes or account data boundaries are visible.",
                "Backend token exchange requirements are visible where needed.",
                "No connector attempts silent authorization during the smoke test."
            ]
        ),
        UITestScenario(
            id: "settings-local-model-benchmark",
            title: "Settings Local Model Benchmark Flow",
            userGoal: "Open Settings and verify Qwen3.5 0.8B exposes reference benchmark metadata plus a user-triggered benchmark action that requires a downloaded model.",
            requiredAccessibilityIdentifiers: [
                "settings.models.local",
                "settings.models.qwen3-5-0-8b-q4-k-m.row",
                "settings.models.qwen3-5-0-8b-q4-k-m.name",
                "settings.models.qwen3-5-0-8b-q4-k-m.status",
                "settings.models.qwen3-5-0-8b-q4-k-m.benchmark",
                "settings.models.qwen3-5-0-8b-q4-k-m.benchmark-run",
                "settings.models.qwen3-5-0-8b-q4-k-m.download",
                "settings.models.benchmark-message"
            ],
            assertions: [
                "Qwen3.5 0.8B is shown as a downloadable model, not a bundled asset.",
                "Reference MLX/GGUF benchmark metadata is visible and labelled as not iPhone verified.",
                "Benchmark execution is a visible user action.",
                "Benchmark execution fails closed until the model is downloaded."
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
                "settings.shortcuts.demo.screenshot-to-reminders.sample",
                "settings.shortcuts.demo.reply-draft-from-shared-text",
                "settings.shortcuts.demo.reply-draft-from-shared-text.input",
                "settings.shortcuts.demo.reply-draft-from-shared-text.output",
                "settings.shortcuts.demo.reply-draft-from-shared-text.sample",
                "settings.shortcuts.demo.meeting-prep-brief",
                "settings.shortcuts.demo.meeting-prep-brief.input",
                "settings.shortcuts.demo.meeting-prep-brief.output",
                "settings.shortcuts.demo.meeting-prep-brief.sample",
                "settings.shortcuts.demo.generic-node-runner",
                "settings.shortcuts.demo.generic-node-runner.input",
                "settings.shortcuts.demo.generic-node-runner.output",
                "settings.shortcuts.demo.generic-node-runner.sample"
            ],
            assertions: [
                "Each Shortcut demo row is visible in Settings.",
                "Each demo shows the Kairo node path.",
                "Each demo shows Shortcut input contract fields.",
                "Each demo shows output contract fields.",
                "Each demo exposes sample input without executing Apple Shortcuts.",
                "The generic node runner shows node kind and JSON input/output contracts for downstream Shortcut steps."
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
                "access.skill.shortcut-reply-draft-from-shared-text",
                "access.skill.shortcut-meeting-prep-brief",
                "access.skill.shortcut-generic-node-runner",
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
