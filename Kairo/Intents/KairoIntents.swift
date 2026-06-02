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
#endif
