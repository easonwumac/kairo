import Foundation

public struct PromptCacheOptimization: Sendable {
    public let isEnabled: Bool
    public let fixedPrefixTokens: Int
    public let expectedVariableTokens: Int

    public init(
        isEnabled: Bool = true,
        fixedPrefixTokens: Int = 512,
        expectedVariableTokens: Int = 170
    ) {
        self.isEnabled = isEnabled
        self.fixedPrefixTokens = fixedPrefixTokens
        self.expectedVariableTokens = expectedVariableTokens
    }

    public var estimatedCacheHitRate: Double {
        guard isEnabled, fixedPrefixTokens > 0 else { return 0 }
        let total = Double(fixedPrefixTokens + expectedVariableTokens)
        return Double(fixedPrefixTokens) / total
    }
}

public struct PromptCacheMetrics: Equatable, Sendable {
    public var totalRequests: Int
    public var cacheHits: Int
    public var totalCachedTokens: Int
    public var totalPromptTokens: Int
    public var estimatedTimeSavedSeconds: Double

    public var cacheHitRate: Double {
        totalRequests > 0 ? Double(cacheHits) / Double(totalRequests) : 0
    }

    public var avgCachedTokensPerHit: Int {
        cacheHits > 0 ? totalCachedTokens / cacheHits : 0
    }

    public static let zero = PromptCacheMetrics(
        totalRequests: 0, cacheHits: 0, totalCachedTokens: 0,
        totalPromptTokens: 0, estimatedTimeSavedSeconds: 0
    )
}

private actor CacheMetricsStore {
    var metrics = PromptCacheMetrics.zero
    var isWarm = false

    func record(cachedTokens: Int, promptTokens: Int) {
        metrics.totalRequests += 1
        metrics.totalPromptTokens += promptTokens
        if cachedTokens > 0 {
            metrics.cacheHits += 1
            metrics.totalCachedTokens += cachedTokens
            metrics.estimatedTimeSavedSeconds += Double(cachedTokens) * 0.001
        }
    }

    func markWarm() { isWarm = true }
    func snapshot() -> PromptCacheMetrics { metrics }
}

public final class PromptCacheManager: @unchecked Sendable {
    private let store = CacheMetricsStore()
    public let optimization: PromptCacheOptimization

    public init(optimization: PromptCacheOptimization = PromptCacheOptimization()) {
        self.optimization = optimization
    }

    public var isWarm: Bool {
        get async { await store.isWarm }
    }

    public func markWarm() async {
        await store.markWarm()
    }

    public func metrics() async -> PromptCacheMetrics {
        await store.snapshot()
    }

    public func recordResponse(promptTokens: Int, cachedTokens: Int) async {
        await store.record(cachedTokens: cachedTokens, promptTokens: promptTokens)
    }

    public static func extractCachedTokens(from responseJSON: [String: Any]) -> Int {
        guard let usage = responseJSON["usage"] as? [String: Any],
              let details = usage["prompt_tokens_details"] as? [String: Any],
              let cached = details["cached_tokens"] as? Int
        else { return 0 }
        return cached
    }
}

extension LocalModelRuntimeAIProvider {
    public func completionWithCache(
        _ request: AICompletionRequest,
        cacheManager: PromptCacheManager? = nil
    ) async throws -> AICompletionResponse {
        let response = try await complete(request)

        if let cacheManager {
            let promptTokens = response.inferenceMetrics?.promptTokens ?? 0
            await cacheManager.recordResponse(
                promptTokens: promptTokens,
                cachedTokens: 0
            )
        }

        return response
    }
}
