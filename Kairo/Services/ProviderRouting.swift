import Foundation

public struct LocalFallbackProvider: AIProvider {
    public var installedModelID: String?

    public init(installedModelID: String? = nil) {
        self.installedModelID = installedModelID
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let trimmedPrompt = request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = installedModelID.map {
            KairoL10n.string("chat.provider.localFallback.named", $0)
        } ?? KairoL10n.string("chat.provider.localFallback.generic")
        let subject = trimmedPrompt.isEmpty
            ? KairoL10n.string("chat.provider.localFallback.emptyRequest")
            : KairoL10n.string("chat.provider.localFallback.quotedRequest", String(trimmedPrompt.prefix(80)))
        return AICompletionResponse(
            message: KairoL10n.string("chat.provider.localFallback.response", prefix, subject),
            proposedActions: []
        )
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        throw AIProviderError.unsupported
    }
}

public enum ProviderRoute: String, Codable, Equatable, Sendable {
    case local
    case cloud
    case unavailable
}

public enum ProviderRoutePreference: String, Codable, Equatable, Sendable {
    case automatic
    case preferLocal
    case preferCloud
    case localOnly

    public static let settingsChoices: [ProviderRoutePreference] = [
        .automatic,
        .preferLocal,
        .preferCloud,
        .localOnly
    ]

    public var settingsTitle: String {
        switch self {
        case .automatic:
            return KairoL10n.string("settings.route.automatic.title")
        case .preferLocal:
            return KairoL10n.string("settings.route.preferLocal.title")
        case .preferCloud:
            return KairoL10n.string("settings.route.preferCloud.title")
        case .localOnly:
            return KairoL10n.string("settings.route.localOnly.title")
        }
    }

    public var settingsDetailText: String {
        switch self {
        case .automatic:
            return KairoL10n.string("settings.route.automatic.detail")
        case .preferLocal:
            return KairoL10n.string("settings.route.preferLocal.detail")
        case .preferCloud:
            return KairoL10n.string("settings.route.preferCloud.detail")
        case .localOnly:
            return KairoL10n.string("settings.route.localOnly.detail")
        }
    }
}

public enum ProviderTaskClass: String, Codable, Equatable, Sendable {
    case drafts
    case summarization
    case simpleQuestionAnswer
    case offlineChat
    case privacySensitiveLowRisk
    case complexReasoning
    case toolUse
    case webCurrentInfo
    case longContext
    case regulatedAdvice
    case codeExecution
    case accountAction
}

public enum ProviderRouteReason: String, Codable, Equatable, Sendable {
    case offlineSelected
    case privacySelected
    case cloudUnavailable
    case userPreferredLocal
    case userPreferredCloud
    case localIncapable
    case localUnavailable
    case companionEscalation
    case safetyEscalation
    case contextTooLong
    case toolRequired
    case cloudDefault
}

public struct ProviderRoutingContext: Codable, Equatable, Sendable {
    public var preference: ProviderRoutePreference
    public var networkAvailable: Bool
    public var privacyModeEnabled: Bool
    public var offlineModeEnabled: Bool
    public var taskClass: ProviderTaskClass
    public var requiresToolUse: Bool
    public var requiresCurrentInfo: Bool
    public var contextTokenEstimate: Int
    public var localModelInstalled: Bool
    public var localRuntimeAvailable: Bool
    public var localContextWindow: Int

    public init(
        preference: ProviderRoutePreference = .automatic,
        networkAvailable: Bool = true,
        privacyModeEnabled: Bool = false,
        offlineModeEnabled: Bool = false,
        taskClass: ProviderTaskClass = .simpleQuestionAnswer,
        requiresToolUse: Bool = false,
        requiresCurrentInfo: Bool = false,
        contextTokenEstimate: Int = 0,
        localModelInstalled: Bool = false,
        localRuntimeAvailable: Bool = false,
        localContextWindow: Int = 2048
    ) {
        self.preference = preference
        self.networkAvailable = networkAvailable
        self.privacyModeEnabled = privacyModeEnabled
        self.offlineModeEnabled = offlineModeEnabled
        self.taskClass = taskClass
        self.requiresToolUse = requiresToolUse
        self.requiresCurrentInfo = requiresCurrentInfo
        self.contextTokenEstimate = contextTokenEstimate
        self.localModelInstalled = localModelInstalled
        self.localRuntimeAvailable = localRuntimeAvailable
        self.localContextWindow = localContextWindow
    }
}

public struct ProviderRouteDecision: Codable, Equatable, Sendable {
    public var route: ProviderRoute
    public var reason: ProviderRouteReason

    public init(route: ProviderRoute, reason: ProviderRouteReason) {
        self.route = route
        self.reason = reason
    }
}

public struct ProviderRouter: AIProvider {
    private let cloudProvider: AIProvider
    private let localProvider: AIProvider
    private let defaultContext: ProviderRoutingContext

    public init(
        cloudProvider: AIProvider,
        localProvider: AIProvider = LocalFallbackProvider(),
        defaultContext: ProviderRoutingContext = ProviderRoutingContext()
    ) {
        self.cloudProvider = cloudProvider
        self.localProvider = localProvider
        self.defaultContext = defaultContext
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        try await complete(request, context: defaultContext)
    }

    public func complete(_ request: AICompletionRequest, context: ProviderRoutingContext) async throws -> AICompletionResponse {
        switch decision(for: request, context: context).route {
        case .local:
            return try await localProvider.complete(request)
        case .cloud:
            return try await cloudProvider.complete(request)
        case .unavailable:
            throw AIProviderError.unsupported
        }
    }

    public func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        try await cloudProvider.embed(request)
    }

    public func decision(for request: AICompletionRequest, context: ProviderRoutingContext) -> ProviderRouteDecision {
        if context.preference == .preferCloud, context.networkAvailable {
            return ProviderRouteDecision(route: .cloud, reason: .userPreferredCloud)
        }

        if context.requiresToolUse || context.taskClass == .toolUse || context.taskClass == .accountAction || context.taskClass == .codeExecution {
            return cloudOrUnavailable(context: context, reason: .toolRequired)
        }

        if context.requiresCurrentInfo || context.taskClass == .webCurrentInfo {
            return cloudOrUnavailable(context: context, reason: .localIncapable)
        }

        if context.taskClass == .regulatedAdvice {
            return cloudOrUnavailable(context: context, reason: .safetyEscalation)
        }

        if context.taskClass == .complexReasoning {
            return cloudOrUnavailable(context: context, reason: .companionEscalation)
        }

        if context.taskClass == .longContext || context.contextTokenEstimate > context.localContextWindow {
            return cloudOrUnavailable(context: context, reason: .contextTooLong)
        }

        let localAllowed = isLocalAllowed(taskClass: context.taskClass)
        if (context.offlineModeEnabled || !context.networkAvailable) && localAllowed {
            return localOrUnavailable(context: context, reason: context.offlineModeEnabled ? .offlineSelected : .cloudUnavailable)
        }

        if context.privacyModeEnabled && localAllowed {
            return localOrUnavailable(context: context, reason: .privacySelected)
        }

        if (context.preference == .preferLocal || context.preference == .localOnly) && localAllowed {
            return localOrUnavailable(context: context, reason: .userPreferredLocal)
        }

        if context.preference == .localOnly {
            return ProviderRouteDecision(route: .unavailable, reason: .localIncapable)
        }

        return cloudOrUnavailable(context: context, reason: .cloudDefault)
    }

    private func isLocalAllowed(taskClass: ProviderTaskClass) -> Bool {
        switch taskClass {
        case .drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .privacySensitiveLowRisk:
            return true
        case .complexReasoning, .toolUse, .webCurrentInfo, .longContext, .regulatedAdvice, .codeExecution, .accountAction:
            return false
        }
    }

    private func localOrUnavailable(context: ProviderRoutingContext, reason: ProviderRouteReason) -> ProviderRouteDecision {
        guard context.localModelInstalled && context.localRuntimeAvailable else {
            if context.preference == .localOnly || context.offlineModeEnabled || context.privacyModeEnabled || !context.networkAvailable {
                return ProviderRouteDecision(route: .unavailable, reason: .localUnavailable)
            }
            return cloudOrUnavailable(context: context, reason: .localUnavailable)
        }
        return ProviderRouteDecision(route: .local, reason: reason)
    }

    private func cloudOrUnavailable(context: ProviderRoutingContext, reason: ProviderRouteReason) -> ProviderRouteDecision {
        guard context.networkAvailable, !context.offlineModeEnabled, !context.privacyModeEnabled, context.preference != .localOnly else {
            return ProviderRouteDecision(route: .unavailable, reason: reason)
        }
        return ProviderRouteDecision(route: .cloud, reason: reason)
    }
}
