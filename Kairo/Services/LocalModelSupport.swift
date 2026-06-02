import Foundation

public enum LocalModelCapability: String, Codable, Equatable, Sendable, CaseIterable {
    case drafts
    case summarization
    case simpleQuestionAnswer
    case offlineChat
    case rewriting
    case extraction
    case toolUse
    case webCurrentInfo
    case codeExecution
    case accountActions
    case regulatedAdvice
}

public struct LocalModelManifest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var family: String
    public var version: String
    public var parameterCount: String
    public var quantization: String
    public var fileSizeBytes: Int64
    public var installedSizeBytes: Int64
    public var contextWindow: Int
    public var tokenizerID: String
    public var licenseName: String
    public var licenseURL: URL
    public var minOSVersion: String
    public var minDeviceClass: String
    public var minRAMGB: Double
    public var supportedLocales: [String]
    public var capabilities: [LocalModelCapability]
    public var disallowedCapabilities: [LocalModelCapability]
    public var downloadURL: URL
    public var sha256: String
    public var signature: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var safetyPolicyVersion: String
    public var deprecated: Bool
    public var replacementModelID: String?

    public init(
        id: String,
        displayName: String,
        family: String,
        version: String,
        parameterCount: String,
        quantization: String,
        fileSizeBytes: Int64,
        installedSizeBytes: Int64,
        contextWindow: Int,
        tokenizerID: String,
        licenseName: String,
        licenseURL: URL,
        minOSVersion: String,
        minDeviceClass: String,
        minRAMGB: Double,
        supportedLocales: [String],
        capabilities: [LocalModelCapability],
        disallowedCapabilities: [LocalModelCapability] = [],
        downloadURL: URL,
        sha256: String,
        signature: String? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        safetyPolicyVersion: String,
        deprecated: Bool = false,
        replacementModelID: String? = nil
    ) {
        self.id = id
        self.displayName = displayName
        self.family = family
        self.version = version
        self.parameterCount = parameterCount
        self.quantization = quantization
        self.fileSizeBytes = fileSizeBytes
        self.installedSizeBytes = installedSizeBytes
        self.contextWindow = contextWindow
        self.tokenizerID = tokenizerID
        self.licenseName = licenseName
        self.licenseURL = licenseURL
        self.minOSVersion = minOSVersion
        self.minDeviceClass = minDeviceClass
        self.minRAMGB = minRAMGB
        self.supportedLocales = supportedLocales
        self.capabilities = capabilities
        self.disallowedCapabilities = disallowedCapabilities
        self.downloadURL = downloadURL
        self.sha256 = sha256
        self.signature = signature
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.safetyPolicyVersion = safetyPolicyVersion
        self.deprecated = deprecated
        self.replacementModelID = replacementModelID
    }
}

public struct LocalModelCatalog: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var signingKeyID: String
    public var signature: String
    public var minimumSafetyPolicyVersion: String
    public var models: [LocalModelManifest]

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date = Date(),
        signingKeyID: String,
        signature: String,
        minimumSafetyPolicyVersion: String,
        models: [LocalModelManifest]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.signingKeyID = signingKeyID
        self.signature = signature
        self.minimumSafetyPolicyVersion = minimumSafetyPolicyVersion
        self.models = models
    }

    public func availableModels(minimumSafetyPolicyVersion: String) -> [LocalModelManifest] {
        models.filter { model in
            !model.deprecated
            && model.safetyPolicyVersion.compare(minimumSafetyPolicyVersion, options: .numeric) != .orderedAscending
        }
    }

    public static func decode(_ data: Data) throws -> LocalModelCatalog {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(LocalModelCatalog.self, from: data)
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }
}

public enum LocalModelDownloadError: Error, Equatable {
    case checksumMismatch(expected: String, actual: String)
    case unsupportedManifest(String)
    case downloadUnavailable
}

public protocol LocalModelDownloader: Sendable {
    func download(_ manifest: LocalModelManifest, progress: (@Sendable (Double) -> Void)?) async throws -> URL
}

public enum LocalModelInstallStatus: String, Codable, Equatable, Sendable {
    case downloading
    case installed
    case failed
}

public struct LocalModelInstallRecord: Codable, Equatable, Sendable {
    public var modelID: String
    public var version: String
    public var status: LocalModelInstallStatus
    public var fileURL: URL
    public var installedSizeBytes: Int64
    public var sha256: String
    public var installedAt: Date
    public var lastVerifiedAt: Date?
    public var failureReason: String?

    public init(
        modelID: String,
        version: String,
        status: LocalModelInstallStatus,
        fileURL: URL,
        installedSizeBytes: Int64,
        sha256: String,
        installedAt: Date = Date(),
        lastVerifiedAt: Date? = nil,
        failureReason: String? = nil
    ) {
        self.modelID = modelID
        self.version = version
        self.status = status
        self.fileURL = fileURL
        self.installedSizeBytes = installedSizeBytes
        self.sha256 = sha256
        self.installedAt = installedAt
        self.lastVerifiedAt = lastVerifiedAt
        self.failureReason = failureReason
    }
}

public actor FileBackedLocalModelInstallRegistry {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var records: [String: LocalModelInstallRecord] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func record(for modelID: String) -> LocalModelInstallRecord? {
        records[modelID]
    }

    public func installedRecords() -> [LocalModelInstallRecord] {
        records.values
            .filter { $0.status == .installed }
            .sorted { $0.modelID < $1.modelID }
    }

    public func upsert(_ record: LocalModelInstallRecord) throws {
        records[record.modelID] = record
        try persist()
    }

    public func delete(modelID: String) throws {
        records[modelID] = nil
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            records = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            records = [:]
            return
        }

        let decoded = try decoder.decode([LocalModelInstallRecord].self, from: data)
        records = Dictionary(uniqueKeysWithValues: decoded.map { ($0.modelID, $0) })
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(records.values.sorted { $0.modelID < $1.modelID })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public struct LocalFallbackProvider: AIProvider {
    public var installedModelID: String?

    public init(installedModelID: String? = nil) {
        self.installedModelID = installedModelID
    }

    public func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        let trimmedPrompt = request.userPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = installedModelID.map { "Local fallback (\($0))" } ?? "Local fallback"
        let subject = trimmedPrompt.isEmpty ? "this request" : "\"\(String(trimmedPrompt.prefix(80)))\""
        return AICompletionResponse(
            message: "\(prefix) is a placeholder for short private/offline drafts. I can help with \(subject), but local mode cannot browse the web, use tools, or perform account actions.",
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

        if context.taskClass == .regulatedAdvice || context.taskClass == .complexReasoning {
            return cloudOrUnavailable(context: context, reason: .safetyEscalation)
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
        guard context.localModelInstalled else {
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
