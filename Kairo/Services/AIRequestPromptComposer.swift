import Foundation

public enum AIRequestPromptComposer {
    public static func sessionContext(from request: AICompletionRequest) -> String {
        let capabilities = request.allowedCapabilities.map(\.rawValue).joined(separator: ", ")
        return """
        Allowed capabilities:
        \(capabilities.isEmpty ? "None" : capabilities)

        Tool context:
        \(request.toolContext ?? "No tool context supplied.")
        """
    }

    public static func perTurnContext(from request: AICompletionRequest) -> String {
        let memoryContext = MemoryPromptContextBuilder().build(from: request.memoryContext)
        let wikiContext = WikiPromptContextBuilder().build(from: request.wikiContext)
        var sections: [String] = []
        if memoryContext != "None" {
            sections.append("Relevant memory:\n\(memoryContext)")
        }
        if wikiContext != "None" {
            sections.append("Relevant wiki:\n\(wikiContext)")
        }
        let attachmentContext = CapabilityPromptContextBuilder.attachmentContext(request.attachmentContext)
        if !request.attachmentContext.isEmpty {
            sections.append(attachmentContext)
            sections.append(LibraryAssetClassificationPromptBuilder.context(for: request.attachmentContext))
        }
        return sections.joined(separator: "\n\n")
    }

    public static func currentUserText(from request: AICompletionRequest) -> String {
        let perTurn = perTurnContext(from: request)
        if perTurn.isEmpty {
            return request.userPrompt
        }
        if request.userPrompt.isEmpty {
            return perTurn
        }
        return "\(perTurn)\n\nUser:\n\(request.userPrompt)"
    }
}

public struct WikiPromptContextBuilder: Sendable {
    public init() {}

    public func build(from results: [KairoWikiSearchResult]) -> String {
        guard !results.isEmpty else { return "None" }
        return results.prefix(6).map { result in
            let snippet = result.snippet.isEmpty ? "No snippet" : result.snippet
            return "- [\(result.kind.rawValue)] \(result.title): \(snippet)"
        }.joined(separator: "\n")
    }
}
