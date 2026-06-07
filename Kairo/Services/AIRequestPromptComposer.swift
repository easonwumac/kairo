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
        var sections: [String] = []
        if memoryContext != "None" {
            sections.append("Relevant memory:\n\(memoryContext)")
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
