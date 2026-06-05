import Foundation

public struct LocalModelRoutingAIProvider: AIProvider {
    private let cloudProvider: any AIProvider
    private let localModelSettingsService: LocalModelSettingsService
    private let localProvider: any AIProvider
    private let localRuntimeAvailable: Bool

    public init(
        cloudProvider: any AIProvider,
        localModelSettingsService: LocalModelSettingsService,
        localProvider: (any AIProvider)? = nil,
        localRuntimeAvailable: Bool = false
    ) {
        self.cloudProvider = cloudProvider
        self.localModelSettingsService = localModelSettingsService
        self.localProvider = localProvider ?? LocalFallbackProvider()
        self.localRuntimeAvailable = localRuntimeAvailable
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let status = await localModelSettingsService.status()
        let routedRequest = Self.request(
            request,
            applying: status.responseLanguage
        )
        let context = await localModelSettingsService.routingContext(
            taskClass: Self.taskClass(for: routedRequest),
            privacyModeEnabled: routedRequest.privacyMode == .privateChat,
            requiresToolUse: Self.requiresToolUse(routedRequest),
            requiresCurrentInfo: Self.requiresCurrentInfo(routedRequest),
            contextTokenEstimate: Self.estimatedTokenCount(for: routedRequest),
            localRuntimeAvailable: localRuntimeAvailable
        )
        let router = ProviderRouter(
            cloudProvider: cloudProvider,
            localProvider: localProvider
        )
        let decision = router.decision(for: routedRequest, context: context)
        if decision.route == .unavailable {
            throw AIProviderError.localInferenceUnavailable(Self.unavailableMessage(status: status, decision: decision))
        }
        return try await router.complete(routedRequest, context: context)
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

    private static func request(
        _ request: AICompletionRequest,
        applying responseLanguage: ChatResponseLanguagePreference
    ) -> AICompletionRequest {
        AICompletionRequest(
            systemPrompt: """
            \(request.systemPrompt)

            Response language:
            \(responseLanguage.promptInstruction)
            If the user explicitly asks for another language, follow the user's explicit language request.
            """,
            userPrompt: request.userPrompt,
            memoryContext: request.memoryContext,
            allowedCapabilities: request.allowedCapabilities,
            attachmentContext: request.attachmentContext,
            toolContext: request.toolContext,
            privacyMode: request.privacyMode
        )
    }

    private static func unavailableMessage(
        status: LocalModelSettingsStatus,
        decision: ProviderRouteDecision
    ) -> String {
        if status.preference == .localOnly && !status.localModelInstalled {
            return KairoL10n.string("chat.error.localInference.reason.localOnlyNoModel")
        }
        if status.preference == .localOnly && status.localModelInstalled {
            return KairoL10n.string("chat.error.localInference.reason.localOnlyRuntimeUnavailable")
        }
        if decision.reason == .localUnavailable {
            return KairoL10n.string("chat.error.localInference.reason.privateNoModel")
        }
        return KairoL10n.string("chat.error.localInference.reason.routeUnavailable")
    }
}
