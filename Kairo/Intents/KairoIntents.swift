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
        let agent = AgentCore()
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
        let runtime = try await ShortcutNodeRuntime.live()
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
        let runtime = try await ShortcutNodeRuntime.live()
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
        let runtime = try await ShortcutNodeRuntime.live()
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
        let runtime = try await ShortcutNodeRuntime.live()
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
        let runtime = try await ShortcutNodeRuntime.live()
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
        let runtime = try await ShortcutNodeRuntime.live()
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
        let runtime = try await ShortcutNodeRuntime.live()
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

        let runtime = try await ShortcutNodeRuntime.live()
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

        let runtime = try await ShortcutNodeRuntime.live()
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

        let runtime = try await ShortcutNodeRuntime.live()
        let output = try await runtime.run(
            .prepareMessageHandoff,
            input: ShortcutNodeInput(text: messageBody, sourceName: "Prepare Message Handoff", variables: variables)
        )
        let encodedOutput = try output.encodedJSONString()
        return .result(value: encodedOutput, dialog: IntentDialog(stringLiteral: output.displayText))
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
        let runtime = try await ShortcutNodeRuntime.live()
        let service = ShortcutNodeInvocationService(runtime: runtime)
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
        let store = try await KairoRecipeIntentSupport.recipeStore()
        let runner = KairoRecipeRunner(recipeStore: store)
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
                dialog: IntentDialog(stringLiteral: "Kairo prepared a recipe preview that requires confirmation in the Kairo app: \(result.summary)")
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
        let planner = KairoRecipePlanner()
        let recipes = planner.suggestRecipes(for: automationRequest)
        guard let recipe = recipes.first else {
            return .result(
                value: "[]",
                dialog: IntentDialog(stringLiteral: "Kairo could not suggest a recipe from that request.")
            )
        }

        let store = try await KairoRecipeIntentSupport.recipeStore()
        try await store.save(recipe)
        let encoded = try KairoRecipeIntentSupport.encode(recipe)
        return .result(
            value: encoded,
            dialog: IntentDialog(stringLiteral: "Kairo saved a disabled recipe draft named \(recipe.title). Review and enable it in Kairo Automations; this does not create Apple Shortcuts.")
        )
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct ListKairoRecipesIntent: AppIntent {
    public static var title: LocalizedStringResource = "List Kairo Recipes"
    public static var description = IntentDescription("List enabled Kairo internal recipes available for Shortcuts.")

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog & ReturnsValue<String> {
        let store = try await KairoRecipeIntentSupport.recipeStore()
        let recipes = try await store.listRecipes()
        let enabledRecipes = recipes.filter(\.isEnabled)
        let summary: String
        if enabledRecipes.isEmpty {
            summary = "No enabled Kairo recipes. Open Kairo Automations to add or enable recipes."
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
        let store = try await KairoRecipeIntentSupport.recipeStore()
        let dailyID = "daily-briefing"
        if try await store.recipe(id: dailyID) == nil {
            try await store.save(KairoRecipeTemplateFactory.dailyBriefing())
        }

        let runner = KairoRecipeRunner(recipeStore: store)
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
                dialog: IntentDialog(stringLiteral: "Kairo prepared a Daily Briefing preview that requires confirmation in the Kairo app: \(result.summary)")
            )
        }

        return .result(value: value, dialog: IntentDialog(stringLiteral: result.summary))
    }
}

private enum KairoRecipeIntentSupport {
    static func recipeStore() async throws -> FileBackedKairoRecipeStore {
        let paths = KairoSharedAppStorage.paths()
        return try await FileBackedKairoRecipeStore(fileURL: paths.kairoRecipeStoreURL)
    }

    static func encode<T: Encodable>(_ value: T) throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(value)
        return String(data: data, encoding: .utf8) ?? "{}"
    }
}
#endif
