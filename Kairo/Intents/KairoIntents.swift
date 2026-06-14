#if canImport(AppIntents)
import AppIntents
import Foundation

@available(iOS 16.0, macOS 13.0, *)
public struct AskKairoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Ask Kairo"
    public static var description = IntentDescription("Ask Kairo using the app's memory and supported capabilities.")

    @Parameter(title: "Question")
    public var question: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let agent = try await KairoAgentIntentSupport.agent()
        let response = try await agent.respond(to: question)
        let output = ShortcutNodeOutput(
            kind: .ask,
            displayText: response.message,
            fields: ["answer": response.message],
            proposedActions: response.proposedActions
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: response.message))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SaveToKairoMemoryIntent: AppIntent {
    public static var title: LocalizedStringResource = "Save to Kairo Memory"
    public static var description = IntentDescription("Save text into Kairo's user-controlled memory.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(
            .saveMemory,
            input: ShortcutNodeInput(text: text, sourceName: "Save to Kairo Memory")
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SearchKairoMemoryIntent: AppIntent {
    public static var title: LocalizedStringResource = "Search Kairo Memory"
    public static var description = IntentDescription("Search Kairo's user-controlled memory.")

    @Parameter(title: "Query")
    public var query: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(.searchMemory, input: ShortcutNodeInput(query: query))
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SummarizeWithKairoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Summarize with Kairo"
    public static var description = IntentDescription("Summarize text passed from Shortcuts without executing external actions.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(.summarize, input: ShortcutNodeInput(text: text, sourceName: "Summarize with Kairo"))
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ExtractKairoTasksIntent: AppIntent {
    public static var title: LocalizedStringResource = "Extract Kairo Tasks"
    public static var description = IntentDescription("Extract task drafts from Shortcut input and return structured output for downstream actions.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(.extractTasks, input: ShortcutNodeInput(text: text, sourceName: "Extract Kairo Tasks"))
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CreateDailyBriefingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Daily Briefing"
    public static var description = IntentDescription("Create a Kairo briefing from Shortcut input and return structured task suggestions.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(.dailyBriefing, input: ShortcutNodeInput(text: text, sourceName: "Create Daily Briefing"))
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CreateReminderDraftsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Reminder Drafts"
    public static var description = IntentDescription("Create reminder drafts from Shortcut input without writing Reminders until a later confirmed action.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(.createReminderDraft, input: ShortcutNodeInput(text: text, sourceName: "Create Reminder Drafts"))
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CreateCalendarDraftsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Calendar Drafts"
    public static var description = IntentDescription("Create calendar drafts from Shortcut input without writing Calendar until a later confirmed action.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(.createCalendarDraft, input: ShortcutNodeInput(text: text, sourceName: "Create Calendar Drafts"))
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CreateContactDraftsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Contact Drafts"
    public static var description = IntentDescription("Create contact drafts from Shortcut input without writing Contacts until a later user-confirmed action.")

    @Parameter(title: "Text")
    public var text: String

    @Parameter(title: "Name")
    public var name: String?

    @Parameter(title: "Phone")
    public var phone: String?

    @Parameter(title: "Email")
    public var email: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        var variables: [String: String] = [:]
        if let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            variables["name"] = name
        }
        if let phone = phone?.trimmingCharacters(in: .whitespacesAndNewlines), !phone.isEmpty {
            variables["phone"] = phone
        }
        if let email = email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            variables["email"] = email
        }

        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(
            .createContactDraft,
            input: ShortcutNodeInput(text: text, sourceName: "Create Contact Drafts", variables: variables)
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CreateEmailDraftsIntent: AppIntent {
    public static var title: LocalizedStringResource = "Create Email Drafts"
    public static var description = IntentDescription("Create email drafts from Shortcut input without sending mail until a later user-reviewed step.")

    @Parameter(title: "Text")
    public var text: String

    @Parameter(title: "Recipient")
    public var recipient: String?

    @Parameter(title: "Subject")
    public var subject: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        var variables: [String: String] = [:]
        if let recipient = recipient?.trimmingCharacters(in: .whitespacesAndNewlines), !recipient.isEmpty {
            variables["recipient"] = recipient
        }
        if let subject = subject?.trimmingCharacters(in: .whitespacesAndNewlines), !subject.isEmpty {
            variables["subject"] = subject
        }

        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(
            .createEmailDraft,
            input: ShortcutNodeInput(text: text, sourceName: "Create Email Drafts", variables: variables)
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct PrepareMessageHandoffIntent: AppIntent {
    public static var title: LocalizedStringResource = "Prepare Message Handoff"
    public static var description = IntentDescription("Prepare a visible Messages recipient handoff without sending a message or putting body text into the sms: URL.")

    @Parameter(title: "Message Body")
    public var messageBody: String

    @Parameter(title: "Recipient")
    public var recipient: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        var variables: [String: String] = ["body": messageBody]
        if let recipient = recipient?.trimmingCharacters(in: .whitespacesAndNewlines), !recipient.isEmpty {
            variables["recipient"] = recipient
        }

        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(
            .prepareMessageHandoff,
            input: ShortcutNodeInput(text: messageBody, sourceName: "Prepare Message Handoff", variables: variables)
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct PreparePhoneCallHandoffIntent: AppIntent {
    public static var title: LocalizedStringResource = "Prepare Phone Call Handoff"
    public static var description = IntentDescription("Prepare a visible Phone handoff from a phone number without placing a call silently.")

    @Parameter(title: "Phone Number")
    public var phoneNumber: String

    @Parameter(title: "Label")
    public var label: String?

    @Parameter(title: "Notes")
    public var notes: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        var variables: [String: String] = [:]
        let trimmedPhoneNumber = phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedPhoneNumber.isEmpty {
            variables["phoneNumber"] = trimmedPhoneNumber
        }
        if let label = label?.trimmingCharacters(in: .whitespacesAndNewlines), !label.isEmpty {
            variables["label"] = label
        }
        let trimmedNotes = notes?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let trimmedLabel = label?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let text = trimmedNotes.isEmpty
            ? "Call \(trimmedLabel.isEmpty ? trimmedPhoneNumber : trimmedLabel)"
            : trimmedNotes

        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(
            .preparePhoneCallHandoff,
            input: ShortcutNodeInput(text: text, sourceName: "Prepare Phone Call Handoff", variables: variables)
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct PrepareWebSearchHandoffIntent: AppIntent {
    public static var title: LocalizedStringResource = "Prepare Web Search Handoff"
    public static var description = IntentDescription("Prepare a visible Safari search handoff from a query without browsing silently.")

    @Parameter(title: "Query")
    public var query: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let runtime = try await KairoShortcutIntentSupport.runtime()
        let output = try await runtime.run(
            .prepareWebSearchHandoff,
            input: ShortcutNodeInput(
                text: trimmedQuery,
                sourceName: "Prepare Web Search Handoff",
                variables: ["query": trimmedQuery]
            )
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct TriageKairoCaptureIntent: AppIntent {
    public static var title: LocalizedStringResource = "Triage Kairo Capture"
    public static var description = IntentDescription("Classify captured text into Kairo Action Inbox suggestions without writing data or opening other apps.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let output = try await KairoCaptureIntentSupport.triage(text: text)
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public enum KairoOpenSectionAppEnum: String, AppEnum {
    case chat
    case library
    case infoPages
    case memory
    case models
    case permissions

    public static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Kairo Section")
    public static var caseDisplayRepresentations: [KairoOpenSectionAppEnum: DisplayRepresentation] = [
        .chat: "Chat",
        .library: "Library",
        .infoPages: "InfoPages",
        .memory: "Memory",
        .models: "Models",
        .permissions: "Permissions"
    ]

    public var routeSection: KairoURLSection {
        switch self {
        case .chat:
            return .chat
        case .library:
            return .assets
        case .infoPages:
            return .pages
        case .memory:
            return .memory
        case .models:
            return .models
        case .permissions:
            return .access
        }
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct OpenKairoSectionIntent: AppIntent {
    public static var title: LocalizedStringResource = "Open Kairo"
    public static var description = IntentDescription("Open Kairo to a focused workspace such as Chat, Library, InfoPages, Memory, Models, or Permissions.")
    public static var openAppWhenRun = true

    @Parameter(title: "Section")
    public var section: KairoOpenSectionAppEnum

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        KairoIntentRouteStore().save(.section(section.routeSection))
        return .result(dialog: IntentDialog(stringLiteral: "Opening Kairo \(section.rawValue)."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ReviewKairoCapturesIntent: AppIntent {
    public static var title: LocalizedStringResource = "Review Kairo Captures"
    public static var description = IntentDescription("Open Kairo to review pending captured items and confirm suggested actions.")
    public static var openAppWhenRun = true

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        KairoIntentRouteStore().save(.captureReview)
        return .result(dialog: IntentDialog(stringLiteral: "Opening Kairo capture review."))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CaptureTextInKairoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Capture Text in Kairo"
    public static var description = IntentDescription("Send text into Kairo's Capture Inbox and open review for user-confirmed actions.")
    public static var openAppWhenRun = true

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let output = KairoCaptureIntentSupport.captureText(text)
        return .result(
            value: try output.encodedJSONString(),
            dialog: IntentDialog(stringLiteral: output.displayText)
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct CaptureURLInKairoIntent: AppIntent {
    public static var title: LocalizedStringResource = "Capture URL in Kairo"
    public static var description = IntentDescription("Send a URL into Kairo's Capture Inbox and open review for user-confirmed actions.")
    public static var openAppWhenRun = true

    @Parameter(title: "URL")
    public var url: URL

    @Parameter(title: "Note")
    public var note: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let output = KairoCaptureIntentSupport.captureURL(url, note: note)
        return .result(
            value: try output.encodedJSONString(),
            dialog: IntentDialog(stringLiteral: output.displayText)
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct KairoAppShortcutsProvider: AppShortcutsProvider {
    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: TriageKairoCaptureIntent(),
            phrases: [
                "Triage capture with \(.applicationName)",
                "Review captured text in \(.applicationName)"
            ],
            shortTitle: "Triage Capture",
            systemImageName: "tray.and.arrow.down"
        )
        AppShortcut(
            intent: OpenKairoSectionIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Open \(.applicationName) workspace"
            ],
            shortTitle: "Open Kairo",
            systemImageName: "arrow.up.right.square"
        )
        AppShortcut(
            intent: ReviewKairoCapturesIntent(),
            phrases: [
                "Review captures in \(.applicationName)",
                "Open \(.applicationName) capture review"
            ],
            shortTitle: "Review Captures",
            systemImageName: "checklist.checked"
        )
        AppShortcut(
            intent: CaptureTextInKairoIntent(),
            phrases: [
                "Capture text in \(.applicationName)",
                "Send text to \(.applicationName)"
            ],
            shortTitle: "Capture Text",
            systemImageName: "text.badge.plus"
        )
        AppShortcut(
            intent: CaptureURLInKairoIntent(),
            phrases: [
                "Capture URL in \(.applicationName)",
                "Send URL to \(.applicationName)"
            ],
            shortTitle: "Capture URL",
            systemImageName: "link.badge.plus"
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct RunKairoShortcutNodeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Run Kairo Shortcut Node"
    public static var description = IntentDescription("Run a Kairo Shortcut node from a node kind and ShortcutNodeInput JSON, returning structured JSON output.")

    @Parameter(title: "Node Kind")
    public var nodeKind: String

    @Parameter(title: "Input JSON")
    public var inputJSON: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let service = try await KairoShortcutIntentSupport.invocationService()
        let outputJSON = try await service.run(nodeKindRawValue: nodeKind, inputJSON: inputJSON)
        let output = try JSONDecoder().decode(ShortcutNodeOutput.self, from: Data(outputJSON.utf8))
        return .result(value: outputJSON, dialog: IntentDialog(stringLiteral: output.displayText))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct RunKairoRecipeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Run Kairo Recipe"
    public static var description = IntentDescription("Run a user-approved Kairo internal automation recipe. This does not create Apple Shortcuts.")

    @Parameter(title: "Recipe ID")
    public var recipeID: String

    @Parameter(title: "Input")
    public var input: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let runner = try await KairoRecipeIntentSupport.runner()
        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: recipeID,
            surface: .shortcut,
            input: input,
            dryRun: false,
            userConfirmed: false
        ))
        let value = try KairoRecipeIntentSupport.encode(result)

        if result.requiresConfirmation {
            return .result(
                value: value,
                dialog: IntentDialog(stringLiteral: KairoL10n.string("intents.recipe.run.requiresConfirmation", result.summary))
            )
        }

        return .result(value: value, dialog: IntentDialog(stringLiteral: result.summary))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SuggestKairoRecipeIntent: AppIntent {
    public static var title: LocalizedStringResource = "Suggest Kairo Recipe"
    public static var description = IntentDescription("Create a disabled Kairo internal recipe draft for review. Kairo does not create Apple Shortcuts.")

    @Parameter(title: "Automation Request")
    public var automationRequest: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let recipes = KairoRecipeIntentSupport.suggestRecipes(for: automationRequest)
        guard let recipe = recipes.first else {
            return .result(
                value: "[]",
                dialog: IntentDialog(stringLiteral: KairoL10n.string("intents.recipe.suggest.none"))
            )
        }

        let store = try await KairoRecipeIntentSupport.store()
        try await store.save(recipe)
        let encoded = try KairoRecipeIntentSupport.encode(recipe)
        return .result(
            value: encoded,
            dialog: IntentDialog(stringLiteral: KairoL10n.string("intents.recipe.suggest.savedDraft", recipe.title))
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ListKairoRecipesIntent: AppIntent {
    public static var title: LocalizedStringResource = "List Kairo Recipes"
    public static var description = IntentDescription("List enabled Kairo internal recipes available for Shortcuts.")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let store = try await KairoRecipeIntentSupport.store()
        let recipes = try await store.listRecipes()
        let enabledRecipes = recipes.filter(\.isEnabled)
        let summary: String
        if enabledRecipes.isEmpty {
            summary = KairoL10n.string("intents.recipe.list.empty")
        } else {
            summary = enabledRecipes.map { "\($0.title) (\($0.id))" }.joined(separator: "\n")
        }

        return .result(value: summary, dialog: IntentDialog(stringLiteral: summary))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct RunKairoDailyBriefingIntent: AppIntent {
    public static var title: LocalizedStringResource = "Run Kairo Daily Briefing"
    public static var description = IntentDescription("Run or seed Kairo's Daily Briefing internal recipe through a user-approved Shortcut action.")

    @Parameter(title: "Input")
    public var input: String?

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let store = try await KairoRecipeIntentSupport.store()
        let dailyID = "daily-briefing"
        if try await store.recipe(id: dailyID) == nil {
            try await store.save(KairoRecipeTemplateFactory.dailyBriefing())
        }

        let runner = KairoRecipeIntentSupport.runner(store: store)
        let result = try await runner.run(KairoRecipeRunRequest(
            recipeID: dailyID,
            surface: .shortcut,
            input: input,
            dryRun: false,
            userConfirmed: false
        ))
        let value = try KairoRecipeIntentSupport.encode(result)

        if result.requiresConfirmation {
            return .result(
                value: value,
                dialog: IntentDialog(stringLiteral: KairoL10n.string("intents.recipe.daily.requiresConfirmation", result.summary))
            )
        }

        return .result(value: value, dialog: IntentDialog(stringLiteral: result.summary))
    }
}

public struct KairoCaptureTriageOutput: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var displayText: String
    public var triage: ActionInboxTriage
    public var recommendedRoute: KairoCaptureTriageRoute
    public var recommendedDeepLink: String?
    public var summaryTitle: String
    public var summaryBullets: [String]
    public var suggestionKinds: [ActionInboxSuggestionKind]
    public var actionKinds: [AgentActionKind]
    public var proposedActions: [AgentAction]

    public init(
        schemaVersion: Int = 1,
        displayText: String,
        triage: ActionInboxTriage,
        recommendedRoute: KairoCaptureTriageRoute,
        recommendedDeepLink: String? = nil,
        summaryTitle: String,
        summaryBullets: [String],
        suggestionKinds: [ActionInboxSuggestionKind],
        actionKinds: [AgentActionKind],
        proposedActions: [AgentAction]
    ) {
        self.schemaVersion = schemaVersion
        self.displayText = displayText
        self.triage = triage
        self.recommendedRoute = recommendedRoute
        self.recommendedDeepLink = recommendedDeepLink
        self.summaryTitle = summaryTitle
        self.summaryBullets = summaryBullets
        self.suggestionKinds = suggestionKinds
        self.actionKinds = actionKinds
        self.proposedActions = proposedActions
    }

    public func encodedJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public struct KairoCaptureIntentOutput: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var displayText: String
    public var queued: Bool
    public var captureID: UUID?
    public var captureKind: KairoIntentCaptureKind?
    public var recommendedRoute: KairoCaptureTriageRoute
    public var recommendedDeepLink: String?
    public var textPreview: String
    public var url: String?

    public init(
        schemaVersion: Int = 1,
        displayText: String,
        queued: Bool,
        captureID: UUID?,
        captureKind: KairoIntentCaptureKind?,
        recommendedRoute: KairoCaptureTriageRoute,
        recommendedDeepLink: String?,
        textPreview: String,
        url: String?
    ) {
        self.schemaVersion = schemaVersion
        self.displayText = displayText
        self.queued = queued
        self.captureID = captureID
        self.captureKind = captureKind
        self.recommendedRoute = recommendedRoute
        self.recommendedDeepLink = recommendedDeepLink
        self.textPreview = textPreview
        self.url = url
    }

    public func encodedJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(self)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

public enum KairoCaptureTriageRoute: String, Codable, CaseIterable, Sendable {
    case captureReview
    case chat

    public var route: KairoURLRoute {
        switch self {
        case .captureReview:
            return .captureReview
        case .chat:
            return .section(.chat)
        }
    }

    public var deepLinkString: String? {
        route.deepLink?.absoluteString
    }
}

enum KairoCaptureIntentSupport {
    static func captureText(
        _ text: String,
        store: KairoIntentCaptureStore = KairoIntentCaptureStore(),
        routeStore: KairoIntentRouteStore = KairoIntentRouteStore()
    ) -> KairoCaptureIntentOutput {
        let capture = store.saveText(text, sourceName: "Shortcut Capture")
        return captureOutput(from: capture, fallbackText: text, routeStore: routeStore)
    }

    static func captureURL(
        _ url: URL,
        note: String? = nil,
        store: KairoIntentCaptureStore = KairoIntentCaptureStore(),
        routeStore: KairoIntentRouteStore = KairoIntentRouteStore()
    ) -> KairoCaptureIntentOutput {
        let capture = store.saveURL(url, note: note, sourceName: "Shortcut URL")
        return captureOutput(from: capture, fallbackText: note ?? url.absoluteString, routeStore: routeStore)
    }

    static func triage(text: String, sourceName: String = "Triage Kairo Capture") async throws -> KairoCaptureTriageOutput {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [builder.text(trimmed, displayName: sourceName)],
            sourceApplication: "AppIntent",
            receivedAt: Date()
        )
        let inbox = KairoActionInboxBackendService(
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: [item])
        )
        let inboxItem = try await inbox.pendingItems(limit: 1).first
        let suggestions = inboxItem?.suggestions ?? []
        let actions = suggestions.compactMap(\.action)
        let summary = inboxItem?.summary ?? ActionInboxSummary(title: sourceName)
        let triage = inboxItem?.triage ?? .captureOnly
        let recommendedRoute = Self.recommendedRoute(for: triage)
        let actionKinds = actions.map(\.kind)
        let actionSummary = actionKinds.isEmpty
            ? triage.rawValue
            : actionKinds.map(\.rawValue).joined(separator: ", ")

        return KairoCaptureTriageOutput(
            displayText: "Capture triaged: \(actionSummary)",
            triage: triage,
            recommendedRoute: recommendedRoute,
            recommendedDeepLink: recommendedRoute.deepLinkString,
            summaryTitle: summary.title,
            summaryBullets: summary.bullets,
            suggestionKinds: suggestions.map(\.kind),
            actionKinds: actionKinds,
            proposedActions: actions
        )
    }

    private static func recommendedRoute(for triage: ActionInboxTriage) -> KairoCaptureTriageRoute {
        switch triage {
        case .captureOnly:
            return .chat
        case .createInfoPage, .createReminder, .saveMemory, .openHandoff:
            return .captureReview
        }
    }

    private static func captureOutput(
        from capture: KairoIntentCapture?,
        fallbackText: String,
        routeStore: KairoIntentRouteStore
    ) -> KairoCaptureIntentOutput {
        let recommendedRoute: KairoCaptureTriageRoute = .captureReview
        if capture != nil {
            routeStore.save(recommendedRoute.route)
        }
        let preview = (capture?.text ?? fallbackText)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let boundedPreview = String(preview.prefix(220))
        let displayText = capture == nil
            ? "Capture was not queued."
            : "Opening Kairo capture review."
        return KairoCaptureIntentOutput(
            displayText: displayText,
            queued: capture != nil,
            captureID: capture?.id,
            captureKind: capture?.kind,
            recommendedRoute: recommendedRoute,
            recommendedDeepLink: recommendedRoute.deepLinkString,
            textPreview: boundedPreview,
            url: capture?.url?.absoluteString
        )
    }
}

enum KairoRecipeIntentSupport {
    static func store(
        provider: any KairoRecipeRunnerProviding = LiveKairoRecipeRunnerProvider()
    ) async throws -> any KairoRecipeStore {
        try await provider.makeStore()
    }

    static func runner(
        provider: any KairoRecipeRunnerProviding = LiveKairoRecipeRunnerProvider()
    ) async throws -> KairoRecipeRunner {
        try await provider.makeRunner()
    }

    static func runner(
        store: any KairoRecipeStore,
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog()
    ) -> KairoRecipeRunner {
        KairoRecipeRunner(
            recipeStore: store,
            toolCatalog: toolCatalog,
            appIntegrationSkillCatalog: appIntegrationSkillCatalog
        )
    }

    static func suggestRecipes(
        for request: String,
        planner: any KairoRecipePlanning = KairoRecipePlanner(),
        now: Date = Date()
    ) -> [KairoRecipe] {
        planner.suggestRecipes(for: request, now: now)
    }

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}

private enum KairoAgentIntentSupport {
    static func agent(
        provider: any KairoAgentProviding = LiveKairoAgentProvider()
    ) async throws -> AgentCore {
        try await provider.makeAgent()
    }
}

enum KairoShortcutIntentSupport {
    static func runtime(
        provider: any ShortcutNodeRuntimeProviding = LiveShortcutNodeRuntimeProvider()
    ) async throws -> ShortcutNodeRuntime {
        try await provider.makeRuntime()
    }

    static func invocationService(
        provider: any ShortcutNodeRuntimeProviding = LiveShortcutNodeRuntimeProvider()
    ) async throws -> ShortcutNodeInvocationService {
        let runtime = try await runtime(provider: provider)
        return ShortcutNodeInvocationService(runtime: runtime)
    }
}
#endif
