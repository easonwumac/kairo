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
    public var generatedTokens: Int
    public var generationTokensPerSecond: Double
    public var measuredAt: Date
    public var notes: String

    public init(
        modelID: String,
        modelDisplayName: String,
        runtime: LocalModelRuntime,
        runtimePackage: String,
        prompt: String,
        responseText: String,
        generatedTokens: Int,
        generationTokensPerSecond: Double,
        measuredAt: Date,
        notes: String
    ) {
        self.modelID = modelID
        self.modelDisplayName = modelDisplayName
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.prompt = prompt
        self.responseText = responseText
        self.generatedTokens = generatedTokens
        self.generationTokensPerSecond = generationTokensPerSecond
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
        prompt: String
    ) async throws -> LocalModelReplyCheckResult
}

public struct UnavailableLocalModelReplyCheckRuntime: LocalModelReplyCheckRuntime {
    private let reason: String

    public init(reason: String = "No local inference runtime is wired for iOS yet.") {
        self.reason = reason
    }

    public func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String
    ) async throws -> LocalModelReplyCheckResult {
        throw LocalModelReplyCheckError.runtimeUnavailable(reason)
    }
}

public struct DeterministicLocalModelReplyCheckRuntime: LocalModelReplyCheckRuntime {
    private let runtime: LocalModelRuntime
    private let runtimePackage: String
    private let responseText: String
    private let generatedTokens: Int
    private let generationTokensPerSecond: Double
    private let measuredAt: Date

    public init(
        runtime: LocalModelRuntime = .gguf,
        runtimePackage: String = "deterministic-test-runtime",
        responseText: String,
        generatedTokens: Int = 24,
        generationTokensPerSecond: Double,
        measuredAt: Date = Date(timeIntervalSince1970: 1_780_358_400)
    ) {
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.responseText = responseText
        self.generatedTokens = generatedTokens
        self.generationTokensPerSecond = generationTokensPerSecond
        self.measuredAt = measuredAt
    }

    public func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String
    ) async throws -> LocalModelReplyCheckResult {
        LocalModelReplyCheckResult(
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: runtime,
            runtimePackage: runtimePackage,
            prompt: prompt,
            responseText: responseText,
            generatedTokens: generatedTokens,
            generationTokensPerSecond: generationTokensPerSecond,
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
            prompt: prompt
        )
        if result.responseText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw LocalModelReplyCheckError.runtimeUnavailable("Runtime returned an empty response.")
        }
        return result
    }
}
