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
#endif
