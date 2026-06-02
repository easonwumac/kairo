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

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let agent = AgentCore()
        let response = try await agent.respond(to: question)
        return .result(dialog: IntentDialog(stringLiteral: response.message))
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SaveToKairoMemoryIntent: AppIntent {
    public static var title: LocalizedStringResource = "Save to Kairo Memory"
    public static var description = IntentDescription("Save text into Kairo's user-controlled memory.")

    @Parameter(title: "Text")
    public var text: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // TODO: 正式 App target 應改用 App Group shared JSONFileMemoryStore，讓 Shortcut / Share Extension / 主 App 共用 memory queue。
        let store = InMemoryMemoryStore()
        let memory = MemoryRecord(
            title: String(text.prefix(40)),
            summary: String(text.prefix(160)),
            content: text,
            source: .appIntent
        )
        try await store.save(memory)
        return .result(dialog: "Saved to Kairo memory: \(memory.title)")
    }
}

@available(iOS 16.0, macOS 13.0, *)
public struct SearchKairoMemoryIntent: AppIntent {
    public static var title: LocalizedStringResource = "Search Kairo Memory"
    public static var description = IntentDescription("Search Kairo's user-controlled memory.")

    @Parameter(title: "Query")
    public var query: String

    public init() {}

    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // TODO: 正式 App target 應查詢 shared memory store。
        return .result(dialog: "Search requested: \(query)")
    }
}
#endif
