import Foundation

public enum LocalModelReplyCheckError: Error, Equatable, Sendable {
    case modelUnavailable(String)
    case modelNotInstalled(String)
    case runtimeUnavailable(String)
}

public struct LocalModelReplyCheckResult: Codable, Equatable, Sendable {
    public var modelID: String
    public var modelDisplayName: String
    public var runtime: LocalModelRuntime
    public var runtimePackage: String
    public var prompt: String
    public var responseText: String
    public var promptTokens: Int?
    public var generatedTokens: Int
    public var promptTokensPerSecond: Double?
    public var generationTokensPerSecond: Double
    public var firstTokenLatencyMS: Double?
    public var peakMemoryMB: Int?
    public var measuredAt: Date
    public var notes: String

    public init(
        modelID: String,
        modelDisplayName: String,
        runtime: LocalModelRuntime,
        runtimePackage: String,
        prompt: String,
        responseText: String,
        promptTokens: Int? = nil,
        generatedTokens: Int,
        promptTokensPerSecond: Double? = nil,
        generationTokensPerSecond: Double,
        firstTokenLatencyMS: Double? = nil,
        peakMemoryMB: Int? = nil,
        measuredAt: Date,
        notes: String
    ) {
        self.modelID = modelID
        self.modelDisplayName = modelDisplayName
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.prompt = prompt
        self.responseText = responseText
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.promptTokensPerSecond = promptTokensPerSecond
        self.generationTokensPerSecond = generationTokensPerSecond
        self.firstTokenLatencyMS = firstTokenLatencyMS
        self.peakMemoryMB = peakMemoryMB
        self.measuredAt = measuredAt
        self.notes = notes
    }

    public var summaryText: String {
        "\(Self.formattedRate(generationTokensPerSecond)) gen tok/s · \(runtimePackage) · \(responseText)"
    }

    private static func formattedRate(_ rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))"
        }
        return String(format: "%.1f", rate)
    }
}

public protocol LocalModelReplyCheckRuntime: Sendable {
    func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult
}

public struct LocalModelConversationRuntimeKey: Hashable, Sendable {
    public var conversationID: String
    public var modelID: String
    public var modelFilePath: String
    public var contextSize: Int
    public var maxOutputTokens: Int
    public var temperature: Double

    public init(
        conversationID: String,
        modelID: String,
        modelFilePath: String,
        contextSize: Int,
        maxOutputTokens: Int,
        temperature: Double
    ) {
        self.conversationID = conversationID
        self.modelID = modelID
        self.modelFilePath = modelFilePath
        self.contextSize = contextSize
        self.maxOutputTokens = maxOutputTokens
        self.temperature = temperature
    }
}

public protocol LocalModelConversationalReplyRuntime: LocalModelReplyCheckRuntime {
    func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        initialPrompt: String,
        turnPrompt: String,
        conversationKey: LocalModelConversationRuntimeKey,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult
}

public struct UnavailableLocalModelReplyCheckRuntime: LocalModelReplyCheckRuntime {
    private let reason: String

    public init(reason: String = KairoL10n.string("settings.models.runtimeUnavailable.iOSSimulatorQwen")) {
        self.reason = reason
    }

    public func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult {
        _ = parameters
        throw LocalModelReplyCheckError.runtimeUnavailable(reason)
    }
}

public struct DeterministicLocalModelReplyCheckRuntime: LocalModelReplyCheckRuntime {
    private let runtime: LocalModelRuntime
    private let runtimePackage: String
    private let responseText: String
    private let promptTokens: Int?
    private let generatedTokens: Int
    private let promptTokensPerSecond: Double?
    private let generationTokensPerSecond: Double
    private let firstTokenLatencyMS: Double?
    private let peakMemoryMB: Int?
    private let measuredAt: Date

    public init(
        runtime: LocalModelRuntime = .gguf,
        runtimePackage: String = "deterministic-test-runtime",
        responseText: String,
        promptTokens: Int? = nil,
        generatedTokens: Int = 24,
        promptTokensPerSecond: Double? = nil,
        generationTokensPerSecond: Double,
        firstTokenLatencyMS: Double? = nil,
        peakMemoryMB: Int? = nil,
        measuredAt: Date = Date(timeIntervalSince1970: 1_780_358_400)
    ) {
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.responseText = responseText
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.promptTokensPerSecond = promptTokensPerSecond
        self.generationTokensPerSecond = generationTokensPerSecond
        self.firstTokenLatencyMS = firstTokenLatencyMS
        self.peakMemoryMB = peakMemoryMB
        self.measuredAt = measuredAt
    }

    public func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult {
        _ = parameters
        return LocalModelReplyCheckResult(
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: runtime,
            runtimePackage: runtimePackage,
            prompt: prompt,
            responseText: responseText,
            promptTokens: promptTokens,
            generatedTokens: generatedTokens,
            promptTokensPerSecond: promptTokensPerSecond,
            generationTokensPerSecond: generationTokensPerSecond,
            firstTokenLatencyMS: firstTokenLatencyMS,
            peakMemoryMB: peakMemoryMB,
            measuredAt: measuredAt,
            notes: "Deterministic reply check runtime for tests and UI smoke validation."
        )
    }
}
public actor LocalModelReplyCheckService {
    private var catalog: LocalModelCatalog
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let runtime: any LocalModelReplyCheckRuntime

    public init(
        catalog: LocalModelCatalog,
        installRegistry: FileBackedLocalModelInstallRegistry,
        runtime: any LocalModelReplyCheckRuntime = UnavailableLocalModelReplyCheckRuntime()
    ) {
        self.catalog = catalog
        self.installRegistry = installRegistry
        self.runtime = runtime
    }

    public func replaceCatalog(_ catalog: LocalModelCatalog) {
        self.catalog = catalog
    }

    public func runReplyCheck(
        modelID: String,
        prompt: String = "Reply with one short sentence confirming Kairo local model response.",
        parameters: LocalModelRuntimeParameters = .defaultValue,
        minimumSafetyPolicyVersion: String = "2026.1"
    ) async throws -> LocalModelReplyCheckResult {
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        guard let model = availableModels.first(where: { $0.id == modelID }) else {
            throw LocalModelReplyCheckError.modelUnavailable(modelID)
        }
        guard let installRecord = await installRegistry.record(for: modelID),
              installRecord.status == .installed
        else {
            throw LocalModelReplyCheckError.modelNotInstalled(modelID)
        }

        let result = try await runtime.generateReply(
            model: model,
            installRecord: installRecord,
            prompt: prompt,
            parameters: parameters.clamped(to: model)
        )
        if result.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LocalModelReplyCheckError.runtimeUnavailable("Runtime returned an empty response.")
        }
        return result
    }
}
