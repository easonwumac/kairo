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
    public var firstTokenLatencyMS: Double?
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
        firstTokenLatencyMS: Double? = nil,
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
        self.firstTokenLatencyMS = firstTokenLatencyMS
        self.peakMemoryMB = peakMemoryMB
        self.measuredAt = measuredAt
        self.isReferenceOnlyForIOS = isReferenceOnlyForIOS
        self.notes = notes
    }

    public var summaryText: String {
        var parts = [
            "PP \(Self.formattedRate(promptTokensPerSecond)) tok/s",
            "TK \(Self.formattedRate(generationTokensPerSecond)) tok/s"
        ]
        if let firstTokenLatencyMS {
            parts.insert(
                KairoL10n.string("localModel.benchmark.metric.firstToken", Self.formattedLatencyMS(firstTokenLatencyMS)),
                at: 0
            )
        }
        if let peakMemoryMB {
            parts.append(KairoL10n.string("localModel.benchmark.metric.peakMemory", Self.formattedMemoryMB(peakMemoryMB)))
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

    private static func formattedLatencyMS(_ value: Double) -> String {
        if value >= 1000 {
            return String(format: "%.2fs", value / 1000.0)
        }
        return "\(Int(value.rounded()))ms"
    }

    private static func formattedMemoryMB(_ memoryMB: Int) -> String {
        if memoryMB >= 1024 {
            return String(format: "%.2f GB", Double(memoryMB) / 1024.0)
        }
        return "\(memoryMB) MB"
    }
}

public struct LocalModelPerformanceModelSummary: Equatable, Identifiable, Sendable {
    public var id: String { modelID }
    public var modelID: String
    public var modelDisplayName: String
    public var runCount: Int
    public var averagePromptTokensPerSecond: Double
    public var averageGenerationTokensPerSecond: Double
    public var averageFirstTokenLatencyMS: Double?
    public var peakMemoryMB: Int?
    public var kvCacheHitRate: Double
    public var prefillTokenCount: Int
    public var cachedTokenCount: Int

    public init(
        modelID: String,
        modelDisplayName: String,
        runCount: Int,
        averagePromptTokensPerSecond: Double,
        averageGenerationTokensPerSecond: Double,
        averageFirstTokenLatencyMS: Double? = nil,
        peakMemoryMB: Int? = nil,
        kvCacheHitRate: Double = 0,
        prefillTokenCount: Int = 0,
        cachedTokenCount: Int = 0
    ) {
        self.modelID = modelID
        self.modelDisplayName = modelDisplayName
        self.runCount = runCount
        self.averagePromptTokensPerSecond = averagePromptTokensPerSecond
        self.averageGenerationTokensPerSecond = averageGenerationTokensPerSecond
        self.averageFirstTokenLatencyMS = averageFirstTokenLatencyMS
        self.peakMemoryMB = peakMemoryMB
        self.kvCacheHitRate = kvCacheHitRate
        self.prefillTokenCount = prefillTokenCount
        self.cachedTokenCount = cachedTokenCount
    }
}

public struct LocalModelPerformanceSnapshot: Equatable, Sendable {
    public var totalRunCount: Int
    public var averagePromptTokensPerSecond: Double?
    public var averageGenerationTokensPerSecond: Double?
    public var averageFirstTokenLatencyMS: Double?
    public var peakMemoryMB: Int?
    public var kvCacheHitRate: Double
    public var prefillTokenCount: Int
    public var cachedTokenCount: Int
    public var cacheUsedBytes: Int64
    public var cacheCapacityBytes: Int64
    public var isCacheEnabled: Bool
    public var modelSummaries: [LocalModelPerformanceModelSummary]

    public init(
        totalRunCount: Int,
        averagePromptTokensPerSecond: Double? = nil,
        averageGenerationTokensPerSecond: Double? = nil,
        averageFirstTokenLatencyMS: Double? = nil,
        peakMemoryMB: Int? = nil,
        kvCacheHitRate: Double = 0,
        prefillTokenCount: Int = 0,
        cachedTokenCount: Int = 0,
        cacheUsedBytes: Int64 = 0,
        cacheCapacityBytes: Int64 = LocalModelCacheSettings.defaultCapacityBytes,
        isCacheEnabled: Bool = true,
        modelSummaries: [LocalModelPerformanceModelSummary] = []
    ) {
        self.totalRunCount = totalRunCount
        self.averagePromptTokensPerSecond = averagePromptTokensPerSecond
        self.averageGenerationTokensPerSecond = averageGenerationTokensPerSecond
        self.averageFirstTokenLatencyMS = averageFirstTokenLatencyMS
        self.peakMemoryMB = peakMemoryMB
        self.kvCacheHitRate = kvCacheHitRate
        self.prefillTokenCount = prefillTokenCount
        self.cachedTokenCount = cachedTokenCount
        self.cacheUsedBytes = cacheUsedBytes
        self.cacheCapacityBytes = cacheCapacityBytes
        self.isCacheEnabled = isCacheEnabled
        self.modelSummaries = modelSummaries
    }
}

public protocol LocalModelBenchmarkEngine: Sendable {
    func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int,
        contextSize: Int
    ) async throws -> LocalModelBenchmarkRunResult
}

public struct UnavailableLocalModelBenchmarkEngine: LocalModelBenchmarkEngine {
    private let reason: String

    public init(reason: String = KairoL10n.string("settings.models.runtimeUnavailable.iOSSimulatorQwen")) {
        self.reason = reason
    }

    public func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int,
        contextSize: Int
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
    private let firstTokenLatencyMS: Double?
    private let peakMemoryMB: Int?
    private let measuredAt: Date

    public init(
        runtime: LocalModelRuntime,
        runtimePackage: String = "deterministic-test-runtime",
        generationTokensPerSecond: Double,
        promptTokensPerSecond: Double,
        promptTokens: Int = 32,
        firstTokenLatencyMS: Double? = nil,
        peakMemoryMB: Int? = nil,
        measuredAt: Date = Date(timeIntervalSince1970: 1_780_358_400)
    ) {
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.generationTokensPerSecond = generationTokensPerSecond
        self.promptTokensPerSecond = promptTokensPerSecond
        self.promptTokens = promptTokens
        self.firstTokenLatencyMS = firstTokenLatencyMS
        self.peakMemoryMB = peakMemoryMB
        self.measuredAt = measuredAt
    }

    public func runBenchmark(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        generatedTokenTarget: Int,
        contextSize: Int
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
            firstTokenLatencyMS: firstTokenLatencyMS,
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

    public func allResults() -> [LocalModelBenchmarkRunResult] {
        resultsByModelID.values
            .flatMap { $0 }
            .sorted {
                if $0.measuredAt == $1.measuredAt {
                    return $0.modelID < $1.modelID
                }
                return $0.measuredAt > $1.measuredAt
            }
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

    public func deleteResults(for modelID: String) throws {
        guard resultsByModelID[modelID] != nil else { return }
        resultsByModelID[modelID] = nil
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

    public func deleteResults(for modelID: String) async throws {
        try await resultStore.deleteResults(for: modelID)
    }

    public func performanceSnapshot(
        cacheSettings: LocalModelCacheSettings = .defaultValue,
        cacheUsedBytes: Int64 = 0
    ) async -> LocalModelPerformanceSnapshot {
        let results = await resultStore.allResults()
        guard !results.isEmpty else {
            return LocalModelPerformanceSnapshot(
                totalRunCount: 0,
                cacheUsedBytes: cacheUsedBytes,
                cacheCapacityBytes: cacheSettings.capacityBytes,
                isCacheEnabled: cacheSettings.isEnabled
            )
        }
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)
        let modelNamesByID = Dictionary(uniqueKeysWithValues: availableModels.map { ($0.id, $0.displayName) })
        let grouped = Dictionary(grouping: results, by: \.modelID)
        let summaries: [LocalModelPerformanceModelSummary] = grouped.map { modelID, modelResults in
            let prefillTokenCount = modelResults.reduce(0) { $0 + $1.promptTokens }
            return LocalModelPerformanceModelSummary(
                modelID: modelID,
                modelDisplayName: modelNamesByID[modelID] ?? modelResults.first?.modelDisplayName ?? modelID,
                runCount: modelResults.count,
                averagePromptTokensPerSecond: Self.average(modelResults.map(\.promptTokensPerSecond)) ?? 0,
                averageGenerationTokensPerSecond: Self.average(modelResults.map(\.generationTokensPerSecond)) ?? 0,
                averageFirstTokenLatencyMS: Self.average(modelResults.compactMap(\.firstTokenLatencyMS)),
                peakMemoryMB: modelResults.compactMap(\.peakMemoryMB).max(),
                kvCacheHitRate: 0,
                prefillTokenCount: prefillTokenCount,
                cachedTokenCount: 0
            )
        }
        .sorted { lhs, rhs in
            if lhs.runCount == rhs.runCount {
                return lhs.modelDisplayName < rhs.modelDisplayName
            }
            return lhs.runCount > rhs.runCount
        }

        return LocalModelPerformanceSnapshot(
            totalRunCount: results.count,
            averagePromptTokensPerSecond: Self.average(results.map(\.promptTokensPerSecond)),
            averageGenerationTokensPerSecond: Self.average(results.map(\.generationTokensPerSecond)),
            averageFirstTokenLatencyMS: Self.average(results.compactMap(\.firstTokenLatencyMS)),
            peakMemoryMB: results.compactMap(\.peakMemoryMB).max(),
            kvCacheHitRate: 0,
            prefillTokenCount: results.reduce(0) { $0 + $1.promptTokens },
            cachedTokenCount: 0,
            cacheUsedBytes: cacheUsedBytes,
            cacheCapacityBytes: cacheSettings.capacityBytes,
            isCacheEnabled: cacheSettings.isEnabled,
            modelSummaries: summaries
        )
    }

    public func runBenchmark(
        modelID: String,
        prompt: String = "Benchmark Kairo local drafting.",
        generatedTokenTarget: Int = 512,
        contextSize: Int = 4096,
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
            generatedTokenTarget: generatedTokenTarget,
            contextSize: contextSize
        )
        try await resultStore.upsert(result)
        return result
    }

    private static func average(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }
}
