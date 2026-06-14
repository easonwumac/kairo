import Foundation

private let kairoRouterLogFileURL: URL = {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent("KairoUITesting", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("router.log")
}()

private func kairoRouterLog(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    print("[KAIRO_ROUTER] \(message)")
    fflush(stdout)
    if let data = line.data(using: .utf8) {
        if let fh = try? FileHandle(forUpdating: kairoRouterLogFileURL) {
            _ = try? fh.seekToEnd()
            try? fh.write(contentsOf: data)
            try? fh.close()
        } else {
            try? data.write(to: kairoRouterLogFileURL, options: .atomic)
        }
    }
}

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
            localRuntimeAvailable: Self.runtimeAvailable(
                for: status.selectedModel,
                fallbackRuntimeAvailable: localRuntimeAvailable
            )
        )
        let router = ProviderRouter(
            cloudProvider: cloudProvider,
            localProvider: localProvider
        )
        let decision = router.decision(for: routedRequest, context: context)
        kairoRouterLog("[ROUTER] decision=\(decision.route.rawValue) reason=\(decision.reason.rawValue) taskClass=\(String(describing: Self.taskClass(for: routedRequest))) localInstalled=\(context.localModelInstalled) runtimeAvail=\(context.localRuntimeAvailable) preference=\(context.preference.rawValue)")
        if decision.route == .unavailable {
            throw AIProviderError.localInferenceUnavailable(Self.unavailableMessage(status: status, decision: decision))
        }
        if decision.route == .local {
            let localResponse = try await router.complete(routedRequest, context: context)
            if let escalationReason = Self.localEscalationReason(localResponse, context: context) {
                kairoRouterLog("[ROUTER] local_response_escalation reason=companionEscalation")
                let cloudResponse = try await cloudProvider.complete(routedRequest)
                return Self.response(
                    cloudResponse,
                    annotatedWithLocalEscalationFrom: localResponse,
                    reason: escalationReason
                )
            }
            return localResponse
        }
        return try await router.complete(routedRequest, context: context)
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        try await cloudProvider.embed(request)
    }

    private static func runtimeAvailable(
        for model: LocalModelManifest?,
        fallbackRuntimeAvailable: Bool
    ) -> Bool {
        guard model?.runtime == .appleFoundationModels else {
            return fallbackRuntimeAvailable
        }
        return AppleFoundationModelAIProvider.isRuntimeSupported
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
        if containsAny(text, [
            "deep reasoning", "reason through", "think through", "analyze deeply", "tradeoff", "architecture",
            "深入分析", "深度分析", "推理", "架構", "取捨", "比較方案"
        ]) {
            return .complexReasoning
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

    private static func localEscalationReason(
        _ response: AICompletionResponse,
        context: ProviderRoutingContext
    ) -> String? {
        guard context.networkAvailable,
              !context.offlineModeEnabled,
              !context.privacyModeEnabled,
              context.preference != .localOnly,
              let raw = response.rawModelResponse,
              let stableResponse = AFMStableResponse.parse(raw)
        else { return nil }
        guard stableResponse.needsEscalation else { return nil }
        let reason = stableResponse.escalationReason.trimmingCharacters(in: .whitespacesAndNewlines)
        return reason.isEmpty ? "local model requested companion" : reason
    }

    private static func response(
        _ response: AICompletionResponse,
        annotatedWithLocalEscalationFrom localResponse: AICompletionResponse,
        reason: String
    ) -> AICompletionResponse {
        var annotated = response
        var stages = localResponse.promptPipelineTrace?.stages ?? [
            PromptPipelineStageTrace(
                name: .requestModel,
                status: .passed,
                outputCharacters: localResponse.rawModelResponse?.count ?? localResponse.message.count,
                detail: "local response"
            )
        ]
        stages.append(PromptPipelineStageTrace(
            name: .routeEscalation,
            status: .repaired,
            detail: "AFM requested companion: \(reason)"
        ))
        if let companionTrace = response.promptPipelineTrace {
            stages.append(contentsOf: companionTrace.stages)
        } else {
            stages.append(PromptPipelineStageTrace(
                name: .requestModel,
                status: .passed,
                outputCharacters: response.rawModelResponse?.count ?? response.message.count,
                detail: "companion response"
            ))
        }
        let issues = (localResponse.promptPipelineTrace?.validationIssues ?? [])
            + ["AFM requested companion: \(reason)"]
            + (response.promptPipelineTrace?.validationIssues ?? [])
        annotated.promptPipelineTrace = PromptPipelineTrace(
            providerID: "local-escalation-router",
            status: .needsRepair,
            stages: stages,
            validationIssues: issues
        )
        return annotated
    }

    private static func request(
        _ request: AICompletionRequest,
        applying responseLanguage: ChatResponseLanguagePreference
    ) -> AICompletionRequest {
        AICompletionRequest(
            systemPrompt: """
            \(request.systemPrompt)

            Primary language:
            \(responseLanguage.promptInstruction)
            If the user explicitly asks for another language, follow the user's explicit language request.
            """,
            userPrompt: request.userPrompt,
            conversationID: request.conversationID,
            conversationHistory: request.conversationHistory,
            memoryContext: request.memoryContext,
            wikiContext: request.wikiContext,
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
