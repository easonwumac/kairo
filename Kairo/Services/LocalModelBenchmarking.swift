import Foundation

public enum LocalModelBenchmarkError: Error, Equatable, Sendable {
    case modelUnavailable(String)
    case modelNotInstalled(String)
    case runtimeUnavailable(String)
}
public struct LocalModelBenchmarkRunResult: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var modelID: String
    public var modelDisplayName: String
    public var runtime: LocalModelRuntime
    public var runtimePackage: String
    public var promptTokens: Int
    public var generatedTokens: Int
    public var promptTokensPerSecond: Double
    public var generationTokensPerSecond: Double
    public var peakMemoryMB: Int?
    public var measuredAt: Date
    public var isReferenceOnlyForIOS: Bool
    public var notes: String

    public init(
        id: String,
        modelID: String,
        modelDisplayName: String,
        runtime: LocalModelRuntime,
        runtimePackage: String,
        promptTokens: Int,
        generatedTokens: Int,
        promptTokensPerSecond: Double,
        generationTokensPerSecond: Double,
        peakMemoryMB: Int? = nil,
        measuredAt: Date,
        isReferenceOnlyForIOS: Bool = false,
        notes: String
    ) {
        self.id = id
        self.modelID = modelID
        self.modelDisplayName = modelDisplayName
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.promptTokensPerSecond = promptTokensPerSecond
        self.generationTokensPerSecond = generationTokensPerSecond
        self.peakMemoryMB = peakMemoryMB
        self.measuredAt = measuredAt
        self.isReferenceOnlyForIOS = isReferenceOnlyForIOS
        self.notes = notes
    }

    public var summaryText: String {
        var parts = [
            "\(Self.formattedRate(generationTokensPerSecond)) gen tok/s",
            "\(Self.formattedRate(promptTokensPerSecond)) prompt tok/s",
            runtimePackage
        ]
        if let peakMemoryMB {
            parts.append("\(Self.formattedMemoryMB(peakMemoryMB)) peak")
        }
        if isReferenceOnlyForIOS {
            parts.append("reference only")
        }
        return parts.joined(separator: " · ")
    }

    private static func formattedRate(_ rate: Double) -> String {
        if rate.rounded() == rate {
            return "\(Int(rate))"
        }
        return String(format: "%.1f", rate)
    }

    private static func formattedMemoryMB(_ memoryMB: Int) -> String {
        if memoryMB >= 1024 {
            return String(format: "%.2f GB", Double(memoryMB) / 1024.0)
        }
        return "\(memoryMB) MB"
    }
}

public protocol LocalModelBenchmarkEngine: Sendable {
    func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int
    ) async throws -> LocalModelBenchmarkRunResult
}

public struct UnavailableLocalModelBenchmarkEngine: LocalModelBenchmarkEngine {
    private let reason: String

    public init(reason: String = "No local inference runtime is wired for iOS yet.") {
        self.reason = reason
    }

    public func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int
    ) async throws -> LocalModelBenchmarkRunResult {
        throw LocalModelBenchmarkError.runtimeUnavailable(reason)
    }
}

public struct DeterministicLocalModelBenchmarkEngine: LocalModelBenchmarkEngine {
    private let runtime: LocalModelRuntime
    private let runtimePackage: String
    private let generationTokensPerSecond: Double
    private let promptTokensPerSecond: Double
    private let promptTokens: Int
    private let peakMemoryMB: Int?
    private let measuredAt: Date

    public init(
        runtime: LocalModelRuntime,
        runtimePackage: String = "deterministic-test-runtime",
        generationTokensPerSecond: Double,
        promptTokensPerSecond: Double,
        promptTokens: Int = 32,
        peakMemoryMB: Int? = nil,
        measuredAt: Date = Date(timeIntervalSince1970: 1_780_358_400)
    ) {
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.generationTokensPerSecond = generationTokensPerSecond
        self.promptTokensPerSecond = promptTokensPerSecond
        self.promptTokens = promptTokens
        self.peakMemoryMB = peakMemoryMB
        self.measuredAt = measuredAt
    }

    public func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int
    ) async throws -> LocalModelBenchmarkRunResult {
        LocalModelBenchmarkRunResult(
            id: "\(model.id)-benchmark-\(Int(measuredAt.timeIntervalSince1970))",
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: runtime,
            runtimePackage: runtimePackage,
            promptTokens: promptTokens,
            generatedTokens: generatedTokenTarget,
            promptTokensPerSecond: promptTokensPerSecond,
            generationTokensPerSecond: generationTokensPerSecond,
            peakMemoryMB: peakMemoryMB,
            measuredAt: measuredAt,
            isReferenceOnlyForIOS: false,
            notes: "Deterministic benchmark engine for tests and UI previews."
        )
    }
}

public actor FileBackedLocalModelBenchmarkStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var resultsByModelID: [String: [LocalModelBenchmarkRunResult]] = [:]

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        try await loadFromDisk()
    }

    public func latestResult(for modelID: String) -> LocalModelBenchmarkRunResult? {
        resultsByModelID[modelID]?.sorted { $0.measuredAt > $1.measuredAt }.first
    }

    public func allResults(for modelID: String) -> [LocalModelBenchmarkRunResult] {
        (resultsByModelID[modelID] ?? []).sorted { $0.measuredAt > $1.measuredAt }
    }

    public func upsert(_ result: LocalModelBenchmarkRunResult) throws {
        var results = resultsByModelID[result.modelID] ?? []
        if let existingIndex = results.firstIndex(where: { $0.id == result.id }) {
            results[existingIndex] = result
        } else {
            results.append(result)
        }
        resultsByModelID[result.modelID] = results
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            resultsByModelID = [:]
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            resultsByModelID = [:]
            return
        }

        let decoded = try decoder.decode([LocalModelBenchmarkRunResult].self, from: data)
        resultsByModelID = Dictionary(grouping: decoded, by: \.modelID)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let results = resultsByModelID.values
            .flatMap { $0 }
            .sorted {
                if $0.modelID == $1.modelID {
                    return $0.measuredAt > $1.measuredAt
                }
                return $0.modelID < $1.modelID
            }
        let data = try encoder.encode(results)
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public actor LocalModelBenchmarkService {
    private var catalog: LocalModelCatalog
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let resultStore: FileBackedLocalModelBenchmarkStore
    private let engine: any LocalModelBenchmarkEngine

    public init(
        catalog: LocalModelCatalog,
        installRegistry: FileBackedLocalModelInstallRegistry,
        resultStore: FileBackedLocalModelBenchmarkStore,
        engine: any LocalModelBenchmarkEngine = UnavailableLocalModelBenchmarkEngine()
    ) {
        self.catalog = catalog
        self.installRegistry = installRegistry
        self.resultStore = resultStore
        self.engine = engine
    }

    public func replaceCatalog(_ catalog: LocalModelCatalog) {
        self.catalog = catalog
    }

    public func latestResult(for modelID: String) async -> LocalModelBenchmarkRunResult? {
        await resultStore.latestResult(for: modelID)
    }

    public func runBenchmark(
        modelID: String,
        prompt: String = "Benchmark Kairo local drafting.",
        generatedTokenTarget: Int = 128,
        minimumSafetyPolicyVersion: String = "2026.1"
    ) async throws -> LocalModelBenchmarkRunResult {
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        guard let model = availableModels.first(where: { $0.id == modelID }) else {
            throw LocalModelBenchmarkError.modelUnavailable(modelID)
        }
        guard let installRecord = await installRegistry.record(for: modelID),
              installRecord.status == .installed
        else {
            throw LocalModelBenchmarkError.modelNotInstalled(modelID)
        }

        let result = try await engine.runBenchmark(
            model: model,
            installRecord: installRecord,
            prompt: prompt,
            generatedTokenTarget: generatedTokenTarget
        )
        try await resultStore.upsert(result)
        return result
    }
}
