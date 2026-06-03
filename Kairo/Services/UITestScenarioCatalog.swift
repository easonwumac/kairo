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
            id: "launch-drawer",
            title: "Launch and Drawer Navigation",
            userGoal: "Confirm the app boots full-screen and exposes Chat, Skills, Shortcuts, Access, Models, and Settings through the side drawer.",
            requiredAccessibilityIdentifiers: [
                "root.safe-area-header",
                "root.drawer.toggle",
                "root.drawer",
                "root.drawer.chat",
                "root.drawer.skills",
                "root.drawer.shortcuts",
                "root.drawer.access",
                "root.drawer.models",
                "root.drawer.settings"
            ],
            assertions: [
                "The primary header is laid out below the device safe area so Dynamic Island and status bar regions do not cover controls.",
                "The drawer toggle is visible after launch.",
                "The drawer exposes Chat, Skills, Shortcuts, Access, Models, and Settings navigation without a bottom TabView."
            ]
        ),
        UITestScenario(
            id: "chat-send",
            title: "Chat Send Smoke Test",
            userGoal: "Send a message through the chat composer and verify a visible assistant response.",
            requiredAccessibilityIdentifiers: [
                "chat.history.thread",
                "chat.new",
                "chat.provider-route",
                "chat.provider-route.title",
                "chat.provider-route.detail",
                "chat.provider-route.badge",
                "chat.provider-route.preference",
                "chat.provider-route.preference.automatic",
                "chat.provider-route.preference.preferLocal",
                "chat.provider-route.preference.preferCloud",
                "chat.provider-route.preference.localOnly",
                "chat.composer.surface",
                "chat.composer.input-shell",
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.user",
                "chat.message.assistant"
            ],
            assertions: [
                "The chat surface shows the current model/provider route before the user sends a prompt.",
                "The user can switch route preference directly from Chat without opening Settings.",
                "The chat composer has a large, visible tap target.",
                "A chat thread or new chat entry point can open the composer.",
                "User-entered text appears in the transcript.",
                "A Kairo assistant response appears after sending."
            ]
        ),
        UITestScenario(
            id: "chat-message-copy-reply",
            title: "Chat Message Copy and Reply",
            userGoal: "Copy or reply to a visible chat message without pasting the whole quoted message into the composer.",
            requiredAccessibilityIdentifiers: [
                "chat.message.assistant",
                "chat.message.copy.",
                "chat.message.reply.",
                "chat.reply-preview",
                "chat.composer.surface",
                "chat.composer.text",
                "chat.composer.send"
            ],
            assertions: [
                "Message text supports selection and copying.",
                "Each message exposes visible Copy and Reply controls.",
                "Reply creates a compact preview above the composer.",
                "Sending a reply references the selected message without pasting the full source text into the composer."
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
                "chat.tool-candidate.shortcut-save-shared-text",
                "chat.tool-candidate.shortcut-save-shared-text.summary"
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
            id: "chat-contact-confirmation",
            title: "Chat Contact Confirmation",
            userGoal: "Ask Kairo to create a Contacts.framework contact, preview the action, and confirm it through a visible user-controlled flow.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.createContactDraft",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "A contact-create request creates an assistant response.",
                "The response exposes a createContactDraft action preview.",
                "The preview is shown before Contacts.framework execution.",
                "The contact is created only after visible confirmation.",
                "The flow does not read, search, or export the user's Contacts database."
            ]
        ),
        UITestScenario(
            id: "chat-email-draft-confirmation",
            title: "Chat Email Draft Handoff Confirmation",
            userGoal: "Ask Kairo to compose an email draft, preview it, and confirm a visible mailto handoff without sending mail automatically.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.composeEmailDraft",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "An email draft request creates an assistant response.",
                "The response exposes a composeEmailDraft action preview.",
                "The preview shows recipient, subject, and body before any handoff.",
                "Kairo opens only a user-visible mailto draft handoff after confirmation.",
                "The flow does not read Apple Mail or send email silently."
            ]
        ),
        UITestScenario(
            id: "chat-map-directions-confirmation",
            title: "Chat Apple Maps Directions Handoff Confirmation",
            userGoal: "Ask Kairo for directions, preview the destination and mode, and confirm a visible Apple Maps handoff.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.openMapDirections",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "A directions request creates an assistant response.",
                "The response exposes an openMapDirections action preview.",
                "The preview shows destination and transport mode before opening Maps.",
                "Kairo opens only a user-visible Apple Maps link after confirmation.",
                "The flow does not read current location or start navigation silently."
            ]
        ),
        UITestScenario(
            id: "chat-messages-handoff-confirmation",
            title: "Chat Messages Handoff Confirmation",
            userGoal: "Ask Kairo to draft a text, preview the recipient and body, and confirm a visible Messages recipient handoff.",
            requiredAccessibilityIdentifiers: [
                "chat.composer.text",
                "chat.composer.send",
                "chat.message.assistant",
                "chat.proposed-actions",
                "chat.proposed-action.openMessageHandoff",
                "chat.action-preview",
                "chat.action.confirm",
                "chat.action-result"
            ],
            assertions: [
                "A text-message request creates an assistant response.",
                "The response exposes an openMessageHandoff action preview.",
                "The preview shows recipient and body before opening Messages.",
                "Kairo opens only a user-visible sms: recipient handoff after confirmation.",
                "The flow does not read Messages, insert body text through the URL, or send silently."
            ]
        ),
        UITestScenario(
            id: "automations-recipe-center",
            title: "Shortcuts Recipe Center",
            userGoal: "Open Shortcuts, add Kairo-owned sample recipes, preview/run a recipe, and toggle it without creating Apple Shortcuts.",
            requiredAccessibilityIdentifiers: [
                "root.drawer.shortcuts",
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
                "The Shortcuts screen exposes Kairo internal recipes.",
                "Sample recipes are added by a visible user action.",
                "Preview and run actions stay within Kairo's recipe runner.",
                "Enable/disable state is user-visible.",
                "The UI states that Kairo does not create Apple Shortcuts silently."
            ]
        ),
        UITestScenario(
            id: "automations-shortcut-templates",
            title: "Shortcuts Template Guidance",
            userGoal: "Open Shortcuts and verify Kairo explains user-approved Apple Shortcuts template setup for running internal recipes.",
            requiredAccessibilityIdentifiers: [
                "root.drawer.shortcuts",
                "automations.shortcut-templates",
                "automations.shortcut-template.disclaimer",
                "automations.shortcut-template.run-kairo-recipe-shortcut",
                "automations.shortcut-template.run-kairo-recipe-shortcut.instructions"
            ],
            assertions: [
                "The Shortcuts screen exposes Shortcut template metadata.",
                "The UI states that Apple Shortcuts installation requires user approval.",
                "Run Kairo Recipe template instructions are visible.",
                "Kairo does not claim silent Apple Shortcut installation."
            ]
        ),
        UITestScenario(
            id: "automations-shortcut-demo-io",
            title: "Shortcuts Node Demo Contracts",
            userGoal: "Open Shortcuts and verify Kairo exposes runnable node demo input/output contracts for user-installed Shortcut examples.",
            requiredAccessibilityIdentifiers: shortcutDemoIdentifiers(prefix: "automations.shortcut-demo", sectionIdentifier: "automations.shortcut-demos"),
            assertions: [
                "The Shortcuts screen exposes Shortcut node demo recipes.",
                "Each demo shows the Kairo node path.",
                "Each demo shows Shortcut input contract fields.",
                "Each demo shows output contract fields.",
                "Each demo exposes sample input without executing Apple Shortcuts.",
                "The generic node runner shows node kind and JSON input/output contracts for downstream Shortcut steps."
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
                "settings.shortcuts.demos"
            ],
            assertions: [
                "API key status is visible.",
                "API key field is secure and save is disabled until text is entered.",
                "OAuth connector status list is visible.",
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
            id: "settings-local-model-expanded-catalog",
            title: "Settings Expanded Model Catalog",
            userGoal: "Open Models with a remote catalog seed and verify Kairo keeps the starter pair compact until the user explicitly reveals more downloadable models.",
            requiredAccessibilityIdentifiers: [
                "settings.models.local",
                "settings.models.qwen3-5-0-8b-q4-k-m.name",
                "settings.models.llama3-2-1b-instruct-q4-k-m.name",
                "settings.models.show-more",
                "settings.models.smollm2-1-7b-instruct-q4-k-m.name"
            ],
            assertions: [
                "The first Models screen remains a compact starter pair.",
                "Extra remote catalog entries are hidden behind a visible Show more control.",
                "Revealed models are still downloadable metadata only, not bundled weights.",
                "The expanded catalog path is deterministic in UI tests."
            ]
        ),
        UITestScenario(
            id: "settings-local-model-reply-check",
            title: "Settings Local Model Reply Check",
            userGoal: "Run a local model reply check against an installed model record and verify Kairo shows a non-empty local response.",
            requiredAccessibilityIdentifiers: [
                "settings.models.local",
                "settings.models.qwen3-5-0-8b-q4-k-m.row",
                "settings.models.qwen3-5-0-8b-q4-k-m.name",
                "settings.models.qwen3-5-0-8b-q4-k-m.status",
                "settings.models.qwen3-5-0-8b-q4-k-m.reply-check",
                "settings.models.benchmark-message"
            ],
            assertions: [
                "Reply check execution is a visible user action.",
                "The UI test path seeds only an install record and deterministic runtime, not model weights.",
                "The reply check reports non-empty response text and generation token speed.",
                "Production runtime remains explicit and fails closed until a real local inference runtime is wired."
            ]
        ),
        UITestScenario(
            id: "settings-shortcut-demo-io",
            title: "Shortcut Demo Input Output Contracts",
            userGoal: "Open Settings and verify every Shortcut demo exposes node steps, Shortcut input fields, output fields, and sample input.",
            requiredAccessibilityIdentifiers: settingsShortcutDemoIdentifiers(),
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
                "root.drawer.access",
                "access.skills.manager",
                "access.skills.local-create.name",
                "access.skills.local-create.summary",
                "access.skills.local-create.button",
                "access.skill.user-ui-created-skill",
                "access.skill.user-ui-created-skill.enable",
                "access.skills.marketplace-refresh",
                "access.skills.manifest-import",
                "access.skills.manifest-import.text",
                "access.skills.manifest-import.button",
                "access.skill.shortcut-save-shared-text",
                "access.skill.shortcut-screenshot-to-reminders",
                "access.skill.shortcut-reply-draft-from-shared-text",
                "access.skill.shortcut-email-triage",
                "access.skill.shortcut-meeting-prep-brief",
                "access.skill.shortcut-generic-node-runner",
                "access.skill.shortcut-save-shared-text.disable",
                "access.skill.shortcut-save-shared-text.enable",
                "access.skill.marketplace-weather-briefing.install",
                "access.skill.marketplace-qwen-oauth-workflow.install",
                "access.skills.message",
                "access.skills.manifest-preview",
                "access.skills.manifest-preview.compatibility",
                "access.skills.manifest-preview.confirm",
                "access.homekit.demos",
                "access.homekit.demo.evening-scene",
                "access.homekit.demo.evening-scene.confirm"
            ],
            assertions: [
                "Skill Manager section is visible.",
                "A user-created local skill draft can be created disabled before it is enabled.",
                "Marketplace refresh control is visible.",
                "Signed manifest import controls are visible.",
                "Shortcut demo skills are visible in the Skill Manager.",
                "A built-in Shortcut skill can be disabled and enabled.",
                "A marketplace skill can show a signed manifest preview and confirm install.",
                "A marketplace skill with missing OAuth/model prerequisites is compatibility-blocked.",
                "HomeKit demo section is visible.",
                "A scene control demo is visible.",
                "The demo exposes confirmation before execution."
            ]
        )
    ])

    private static func settingsShortcutDemoIdentifiers() -> [String] {
        var identifiers = ["settings.shortcuts.demos"]
        for recipe in ShortcutDemoCatalog.default.recipes {
            identifiers.append("settings.shortcuts.demo.\(recipe.id)")
            identifiers.append("settings.shortcuts.demo.\(recipe.id).input")
            identifiers.append("settings.shortcuts.demo.\(recipe.id).output")
            identifiers.append("settings.shortcuts.demo.\(recipe.id).sample")
        }
        return identifiers
    }

    private static func shortcutDemoIdentifiers(prefix: String, sectionIdentifier: String) -> [String] {
        var identifiers = ["root.drawer.shortcuts", sectionIdentifier]
        for recipe in ShortcutDemoCatalog.default.recipes {
            identifiers.append("\(prefix).\(recipe.id)")
            identifiers.append("\(prefix).\(recipe.id).steps")
            identifiers.append("\(prefix).\(recipe.id).input")
            identifiers.append("\(prefix).\(recipe.id).output")
            identifiers.append("\(prefix).\(recipe.id).sample")
            identifiers.append("\(prefix).\(recipe.id).preview-sample")
            identifiers.append("\(prefix).\(recipe.id).preview-result")
        }
        return identifiers
    }
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
