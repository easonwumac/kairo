import Foundation

public struct IntegrationRegistry: Sendable {
    public var integrations: [AppIntegration]

    public init(integrations: [AppIntegration] = IntegrationRegistry.defaultIntegrations) {
        self.integrations = integrations
    }

    public func integration(for key: String) -> AppIntegration? {
        integrations.first { $0.key == key }
    }

    public func integrations(for surface: IntegrationSurface) -> [AppIntegration] {
        integrations.filter { $0.surfaces.contains(surface) }
    }

    public func integrations(for category: IntegrationCategory) -> [AppIntegration] {
        integrations.filter { $0.category == category }
    }

    public var oauthConnectors: [AppIntegration] {
        integrations.filter { $0.oauth != nil }
    }

    public var userVisibleHandoffs: [AppIntegration] {
        integrations.filter { integration in
            integration.surfaces.contains(.urlScheme) || integration.surfaces.contains(.universalLink) || integration.surfaces.contains(.shortcuts)
        }
    }

    public static let defaultIntegrations: [AppIntegration] = [
        AppIntegration(
            key: "apple-shortcuts",
            displayName: "Apple Shortcuts",
            category: .appleSystem,
            surfaces: [.appIntents, .shortcuts, .urlScheme],
            requiredCapabilities: [.appIntents],
            urlSchemes: [
                URLSchemeIntegration(
                    scheme: "shortcuts",
                    exampleURL: "shortcuts://run-shortcut?name=Kairo%20Daily%20Briefing&input=text",
                    notes: "Launch a user-visible Shortcut handoff with encoded Kairo input; the user must create, install, or approve the Shortcut."
                )
            ],
            appIntentIdentifiers: [
                "AskKairoIntent",
                "SaveToKairoMemoryIntent",
                "SearchKairoMemoryIntent",
                "SummarizeWithKairoIntent",
                "ExtractKairoTasksIntent",
                "CreateDailyBriefingIntent",
                "CreateReminderDraftsIntent",
                "RunKairoShortcutNodeIntent",
                "RunKairoRecipeIntent",
                "SuggestKairoRecipeIntent",
                "ListKairoRecipesIntent",
                "RunKairoDailyBriefingIntent"
            ],
            shortcutTemplates: [
                ShortcutTemplate(identifier: "daily-briefing", title: "Daily Briefing", inputSummary: "Date, calendar context, shared text, or shortcut variables", outputSummary: "Briefing text and suggested next actions"),
                ShortcutTemplate(identifier: "save-shared-text", title: "Save Shared Text", inputSummary: "Shortcut input text or URL", outputSummary: "Memory identifier and extracted tasks"),
                ShortcutTemplate(identifier: "screenshot-to-reminders", title: "Screenshot to Reminders", inputSummary: "OCR text from a user-selected screenshot", outputSummary: "Task titles and reminder drafts for downstream Shortcuts actions"),
                ShortcutTemplate(identifier: "reply-draft-from-shared-text", title: "Reply Draft from Shared Text", inputSummary: "Email or chat text explicitly shared by the user", outputSummary: "Reply draft text for manual review before sending"),
                ShortcutTemplate(identifier: "email-triage", title: "Email Triage", inputSummary: "Email thread text explicitly shared by the user", outputSummary: "Summary, follow-up tasks, and reply draft for manual review"),
                ShortcutTemplate(identifier: "meeting-prep-brief", title: "Meeting Prep Brief", inputSummary: "Meeting title, customer name, memory query, or meeting notes", outputSummary: "Meeting prep brief and task drafts"),
                ShortcutTemplate(identifier: "generic-node-runner", title: "Generic Node Runner", inputSummary: "Node kind plus ShortcutNodeInput JSON", outputSummary: "ShortcutNodeOutput JSON for downstream Shortcut steps")
            ] + ShortcutTemplateRegistry.default.templates,
            sandboxNotes: "Shortcuts must be configured or launched by the user. Kairo provides App Intents with structured JSON outputs for downstream Shortcut nodes, but it must not silently drive other apps.",
            status: .available
        ),
        AppIntegration(
            key: "apple-calendar-reminders",
            displayName: "Apple Calendar & Reminders",
            category: .appleSystem,
            surfaces: [.eventKit, .shortcuts],
            requiredCapabilities: [.calendar, .reminders],
            shortcutTemplates: [
                ShortcutTemplate(identifier: "meeting-prep", title: "Meeting Prep", inputSummary: "Upcoming calendar events supplied by EventKit or Shortcuts", outputSummary: "Preparation brief and optional reminder drafts")
            ],
            sandboxNotes: "EventKit requires runtime permission. Writes are limited to calendars/reminder lists the user grants and should be previewed before execution.",
            status: .scaffolded
        ),
        AppIntegration(
            key: "apple-home",
            displayName: "Apple Home",
            category: .appleSystem,
            surfaces: [.homeKit, .shortcuts],
            requiredCapabilities: [.homeKit],
            shortcutTemplates: [
                ShortcutTemplate(identifier: "home-scene-confirm", title: "Confirm Home Scene", inputSummary: "Scene or accessory target supplied by the user or Shortcut", outputSummary: "HomeKit control preview and confirmation result")
            ],
            sandboxNotes: "HomeKit requires the HomeKit entitlement, user Home authorization, and visible confirmation before Kairo runs a scene or writes an accessory characteristic. Kairo cannot control homes outside granted HomeKit access.",
            status: .scaffolded
        ),
        AppIntegration(
            key: "apple-mail",
            displayName: "Apple Mail",
            category: .communication,
            surfaces: [.shareExtension, .shortcuts],
            requiredCapabilities: [.shareExtension, .appIntents],
            shortcutTemplates: [
                ShortcutTemplate(identifier: "mail-to-memory", title: "Save Mail to Kairo", inputSummary: "Mail content explicitly shared or passed through Shortcuts", outputSummary: "Summary, memory record, and follow-up drafts")
            ],
            sandboxNotes: "Kairo cannot read the Mail database directly. The user must share content, use Shortcuts actions, or connect an official email API account separately.",
            status: .requiresUserSetup
        ),
        AppIntegration(
            key: "gmail-google-workspace",
            displayName: "Gmail / Google Workspace",
            category: .communication,
            surfaces: [.oauthAPI, .shareExtension, .universalLink],
            requiredCapabilities: [.externalConnectors],
            oauth: OAuthConnectorMetadata(
                providerKey: "google",
                authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token")!,
                defaultScopes: ["openid", "email", "profile", "https://www.googleapis.com/auth/gmail.readonly"],
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Only mailbox data covered by granted Google API scopes may be accessed; private app containers and browser sessions remain unavailable."
            ),
            sandboxNotes: "Use Google OAuth and official APIs. Sensitive scopes require consent, verification, and strong token handling; background sync should be server-assisted or BGTask-limited.",
            status: .requiresBackend
        ),
        AppIntegration(
            key: "microsoft-365",
            displayName: "Microsoft 365 / Outlook",
            category: .productivity,
            surfaces: [.oauthAPI, .universalLink],
            requiredCapabilities: [.externalConnectors],
            oauth: OAuthConnectorMetadata(
                providerKey: "microsoft",
                authorizationEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/authorize")!,
                tokenEndpoint: URL(string: "https://login.microsoftonline.com/common/oauth2/v2.0/token")!,
                defaultScopes: ["openid", "profile", "offline_access", "User.Read", "Mail.Read", "Calendars.ReadWrite"],
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Only Microsoft Graph resources covered by granted scopes are available."
            ),
            sandboxNotes: "Use Microsoft Graph OAuth scopes and preview account-changing actions before calling Graph write endpoints.",
            status: .requiresBackend
        ),
        AppIntegration(
            key: "notion",
            displayName: "Notion",
            category: .knowledge,
            surfaces: [.oauthAPI, .urlScheme, .shareExtension],
            requiredCapabilities: [.externalConnectors, .shareExtension],
            oauth: OAuthConnectorMetadata(
                providerKey: "notion",
                authorizationEndpoint: URL(string: "https://api.notion.com/v1/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://api.notion.com/v1/oauth/token")!,
                defaultScopes: [],
                requiresPKCE: false,
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Only pages/databases selected during Notion authorization may be read or written."
            ),
            urlSchemes: [
                URLSchemeIntegration(scheme: "notion", exampleURL: "notion://www.notion.so/", notes: "Open Notion visibly when installed; fall back to universal links.")
            ],
            sandboxNotes: "Notion API access is workspace-scoped and user-approved. Kairo should treat page writes as high-risk external actions.",
            status: .requiresBackend
        ),
        AppIntegration(
            key: "slack",
            displayName: "Slack",
            category: .communication,
            surfaces: [.oauthAPI, .urlScheme, .shareExtension],
            requiredCapabilities: [.externalConnectors, .shareExtension],
            oauth: OAuthConnectorMetadata(
                providerKey: "slack",
                authorizationEndpoint: URL(string: "https://slack.com/oauth/v2/authorize")!,
                tokenEndpoint: URL(string: "https://slack.com/api/oauth.v2.access")!,
                defaultScopes: ["channels:history", "chat:write"],
                requiresPKCE: false,
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Only channels and workspace resources covered by Slack OAuth scopes may be accessed."
            ),
            urlSchemes: [
                URLSchemeIntegration(scheme: "slack", exampleURL: "slack://open", notes: "User-visible handoff only; cannot scrape Slack UI or local app data.")
            ],
            sandboxNotes: "Slack reads/writes require OAuth scopes and workspace approval. Message sends require explicit preview and confirmation.",
            status: .requiresBackend
        ),
        AppIntegration(
            key: "chatgpt",
            displayName: "ChatGPT",
            category: .ai,
            surfaces: [.oauthAPI, .urlScheme, .universalLink, .shareExtension],
            requiredCapabilities: [.externalConnectors],
            oauth: OAuthConnectorMetadata(
                providerKey: "chatgpt",
                authorizationEndpoint: URL(string: "https://auth.openai.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.openai.com/oauth/token")!,
                defaultScopes: ["openid", "profile", "email"],
                accountDataBoundary: "OAuth identity and approved API resources only; Kairo cannot read ChatGPT web cookies or conversation history without an official API."
            ),
            urlSchemes: [
                URLSchemeIntegration(scheme: "chatgpt", exampleURL: "chatgpt://", notes: "Open ChatGPT visibly when installed. Do not claim programmatic control of ChatGPT UI.")
            ],
            sandboxNotes: "Kairo may hand off prompts or use official APIs. It must not access ChatGPT browser sessions, cookies, or local app storage.",
            status: .scaffolded
        ),
        AppIntegration(
            key: "files-and-icloud-drive",
            displayName: "Files / iCloud Drive",
            category: .storage,
            surfaces: [.documentPicker, .shareExtension, .shortcuts],
            requiredCapabilities: [.documents, .shareExtension],
            shortcutTemplates: [
                ShortcutTemplate(identifier: "summarize-file", title: "Summarize File with Kairo", inputSummary: "File selected by the user or passed by Shortcuts", outputSummary: "Summary and extracted tasks")
            ],
            sandboxNotes: "Access is limited to user-selected documents, security-scoped URLs, or files shared into Kairo.",
            status: .available
        ),
        AppIntegration(
            key: "github",
            displayName: "GitHub",
            category: .developer,
            surfaces: [.oauthAPI, .universalLink],
            requiredCapabilities: [.externalConnectors],
            oauth: OAuthConnectorMetadata(
                providerKey: "github",
                authorizationEndpoint: URL(string: "https://github.com/login/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://github.com/login/oauth/access_token")!,
                defaultScopes: ["read:user", "repo"],
                requiresPKCE: false,
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Repository access follows granted GitHub OAuth scopes and organization policies."
            ),
            sandboxNotes: "GitHub writes, issue comments, and repository changes are external account actions requiring preview and confirmation.",
            status: .requiresBackend
        )
    ]
}
