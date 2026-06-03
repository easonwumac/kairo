import Foundation

public struct LocalModelRoutingAIProvider: AIProvider {
    private let cloudProvider: any AIProvider
    private let localModelSettingsService: LocalModelSettingsService

    public init(
        cloudProvider: any AIProvider,
        localModelSettingsService: LocalModelSettingsService
    ) {
        self.cloudProvider = cloudProvider
        self.localModelSettingsService = localModelSettingsService
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let status = await localModelSettingsService.status()
        let context = await localModelSettingsService.routingContext(
            taskClass: Self.taskClass(for: request),
            privacyModeEnabled: request.privacyMode == .privateChat,
            requiresToolUse: Self.requiresToolUse(request),
            requiresCurrentInfo: Self.requiresCurrentInfo(request),
            contextTokenEstimate: Self.estimatedTokenCount(for: request)
        )
        let router = ProviderRouter(
            cloudProvider: cloudProvider,
            localProvider: LocalFallbackProvider(installedModelID: status.selectedModelID)
        )
        return try await router.complete(request, context: context)
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        try await cloudProvider.embed(request)
    }

    private static func taskClass(for request: AICompletionRequest) -> ProviderTaskClass {
        let text = normalizedText(for: request)
        if containsAny(text, ["summarize", "summary", "整理", "摘要"]) {
            return .summarization
        }
        if containsAny(text, ["draft", "reply", "rewrite", "polish", "email", "回覆", "改寫", "潤飾", "草稿"]) {
            return .drafts
        }
        if requiresToolUse(request) {
            return .toolUse
        }
        if requiresCurrentInfo(request) {
            return .webCurrentInfo
        }
        if estimatedTokenCount(for: request) > 4_096 {
            return .longContext
        }
        return .simpleQuestionAnswer
    }

    private static func requiresToolUse(_ request: AICompletionRequest) -> Bool {
        let text = normalizedText(for: request)
        return containsAny(text, [
            "shortcut", "homekit", "reminder", "calendar", "notification", "gmail", "slack", "notion", "github",
            "捷徑", "家庭", "燈", "門鎖", "提醒", "行事曆", "通知", "寄信", "建立"
        ])
    }

    private static func requiresCurrentInfo(_ request: AICompletionRequest) -> Bool {
        let text = normalizedText(for: request)
        return containsAny(text, [
            "latest", "today", "news", "weather", "stock", "price", "search", "lookup",
            "最新", "今天", "新聞", "天氣", "股價", "搜尋", "查詢"
        ])
    }

    private static func estimatedTokenCount(for request: AICompletionRequest) -> Int {
        let promptLength = request.systemPrompt.count + request.userPrompt.count
        let memoryLength = request.memoryContext.reduce(0) { total, memory in
            total + memory.content.count + memory.summary.count
        }
        let attachmentLength = request.attachmentContext.reduce(0) { total, attachment in
            total + attachment.displayName.count + (attachment.textPreview?.count ?? 0)
        }
        let textLength = promptLength + memoryLength + attachmentLength
        return max(1, textLength / 4)
    }

    private static func normalizedText(for request: AICompletionRequest) -> String {
        [
            request.userPrompt,
            request.attachmentContext.compactMap(\.textPreview).joined(separator: " ")
        ]
        .joined(separator: " ")
        .lowercased()
    }

    private static func containsAny(_ text: String, _ needles: [String]) -> Bool {
        needles.contains { text.contains($0.lowercased()) }
    }
}
