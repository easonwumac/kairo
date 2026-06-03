import Foundation
import CryptoKit

public enum LocalModelDownloadError: Error, Equatable {
    case checksumMismatch(expected: String, actual: String)
    case unsupportedManifest(String)
    case downloadUnavailable
}

public protocol LocalModelDownloader: Sendable {
    func download(_ manifest: LocalModelManifest, progress: (@Sendable (Double) -> Void)?) async throws -> URL
}

public actor VerifiedLocalModelDownloader: LocalModelDownloader {
    private let httpClient: any HTTPClient
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let modelsDirectory: URL

    public init(
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        installRegistry: FileBackedLocalModelInstallRegistry,
        modelsDirectory: URL
    ) {
        self.httpClient = httpClient
        self.installRegistry = installRegistry
        self.modelsDirectory = modelsDirectory
    }

    public func download(_ manifest: LocalModelManifest, progress: (@Sendable (Double) -> Void)? = nil) async throws -> URL {
        try validate(manifest)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let destinationURL = installedModelURL(for: manifest)
        let temporaryURL = destinationURL.appendingPathExtension("download")

        progress?(0)
        try await installRegistry.upsert(LocalModelInstallRecord(
            modelID: manifest.id,
            version: manifest.version,
            status: .downloading,
            fileURL: destinationURL,
            installedSizeBytes: 0,
            sha256: manifest.sha256
        ))

        do {
            let request = URLRequest(url: manifest.downloadURL)
            let (data, response) = try await httpClient.data(for: request)
            guard (200..<300).contains(response.statusCode) else {
                let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? ""
                throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
            }

            let actualChecksum = Self.sha256Hex(data)
            guard actualChecksum == manifest.sha256.lowercased() else {
                throw LocalModelDownloadError.checksumMismatch(expected: manifest.sha256, actual: actualChecksum)
            }

            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try FileManager.default.removeItem(at: temporaryURL)
            }
            try data.write(to: temporaryURL, options: [.atomic])
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)

            let record = LocalModelInstallRecord(
                modelID: manifest.id,
                version: manifest.version,
                status: .installed,
                fileURL: destinationURL,
                installedSizeBytes: Int64(data.count),
                sha256: actualChecksum,
                lastVerifiedAt: Date()
            )
            try await installRegistry.upsert(record)
            progress?(1)
            return destinationURL
        } catch {
            if FileManager.default.fileExists(atPath: temporaryURL.path) {
                try? FileManager.default.removeItem(at: temporaryURL)
            }
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try? FileManager.default.removeItem(at: destinationURL)
            }
            try await installRegistry.upsert(LocalModelInstallRecord(
                modelID: manifest.id,
                version: manifest.version,
                status: .failed,
                fileURL: destinationURL,
                installedSizeBytes: 0,
                sha256: failedChecksum(for: error, fallback: manifest.sha256),
                failureReason: failureReason(for: error)
            ))
            throw error
        }
    }

    private func validate(_ manifest: LocalModelManifest) throws {
        guard ["https", "file"].contains(manifest.downloadURL.scheme?.lowercased()) else {
            throw LocalModelDownloadError.unsupportedManifest("Local model downloads require HTTPS or file URLs.")
        }
        guard !manifest.sha256.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalModelDownloadError.unsupportedManifest("Local model manifest is missing sha256.")
        }
    }

    private func installedModelURL(for manifest: LocalModelManifest) -> URL {
        let fileExtension = manifest.downloadURL.pathExtension.isEmpty ? "model" : manifest.downloadURL.pathExtension
        let fileName = "\(Self.sanitizedFileComponent(manifest.id))-\(Self.sanitizedFileComponent(manifest.version)).\(fileExtension)"
        return modelsDirectory.appendingPathComponent(fileName)
    }

    private func failedChecksum(for error: Error, fallback: String) -> String {
        if case let LocalModelDownloadError.checksumMismatch(_, actual) = error {
            return actual
        }
        return fallback
    }

    private func failureReason(for error: Error) -> String {
        switch error {
        case let LocalModelDownloadError.checksumMismatch(expected, actual):
            return "Checksum mismatch. Expected \(expected), got \(actual)."
        case let HTTPClientError.unacceptableStatusCode(statusCode, _):
            return "HTTP status \(statusCode)."
        default:
            return String(describing: error)
        }
    }

    public static func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    public static func sanitizedFileComponent(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let sanitized = String(scalars).trimmingCharacters(in: CharacterSet(charactersIn: ".-"))
        return sanitized.isEmpty ? "model" : sanitized
    }
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

public enum LocalModelBenchmarkError: Error, Equatable, Sendable {
    case modelUnavailable(String)
    case modelNotInstalled(String)
    case runtimeUnavailable(String)
}

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

public struct LocalModelSettings: Codable, Equatable, Sendable {
    public var selectedModelID: String?
    public var preference: ProviderRoutePreference

    public init(selectedModelID: String? = nil, preference: ProviderRoutePreference = .automatic) {
        self.selectedModelID = selectedModelID
        self.preference = preference
    }
}

public struct LocalModelSettingsStatus: Equatable, Sendable {
    public var selectedModelID: String?
    public var selectedModel: LocalModelManifest?
    public var installedRecord: LocalModelInstallRecord?
    public var preference: ProviderRoutePreference
    public var availableModels: [LocalModelManifest]
    public var installedModels: [LocalModelInstallRecord]

    public init(
        selectedModelID: String?,
        selectedModel: LocalModelManifest?,
        installedRecord: LocalModelInstallRecord?,
        preference: ProviderRoutePreference,
        availableModels: [LocalModelManifest],
        installedModels: [LocalModelInstallRecord]
    ) {
        self.selectedModelID = selectedModelID
        self.selectedModel = selectedModel
        self.installedRecord = installedRecord
        self.preference = preference
        self.availableModels = availableModels
        self.installedModels = installedModels
    }

    public var localModelInstalled: Bool {
        selectedModel != nil && installedRecord?.status == .installed
    }

    public var settingsRows: [LocalModelSettingsRow] {
        let installedByID = Dictionary(uniqueKeysWithValues: installedModels.map { ($0.modelID, $0) })
        return availableModels
            .enumerated()
            .map { index, model in
                let record = installedByID[model.id]
                let isSelected = selectedModelID == model.id && record?.status == .installed
                return (index, LocalModelSettingsRow(model: model, installRecord: record, isSelected: isSelected))
            }
            .sorted { lhs, rhs in
                if lhs.1.primaryAction == rhs.1.primaryAction {
                    return lhs.0 < rhs.0
                }
                return lhs.1.primaryAction.sortPriority < rhs.1.primaryAction.sortPriority
            }
            .map(\.1)
    }
}

public enum LocalModelSettingsPrimaryAction: String, Codable, Equatable, Sendable {
    case download
    case retryDownload
    case select
    case selected
    case unavailable

    public var title: String {
        switch self {
        case .download:
            return "Download"
        case .retryDownload:
            return "Retry"
        case .select:
            return "Select"
        case .selected:
            return "Selected"
        case .unavailable:
            return "Unavailable"
        }
    }

    public var accessibilitySuffix: String {
        switch self {
        case .download, .retryDownload:
            return "download"
        case .select, .selected:
            return "select"
        case .unavailable:
            return "unavailable"
        }
    }

    fileprivate var sortPriority: Int {
        switch self {
        case .selected:
            return 0
        case .select:
            return 1
        case .download, .retryDownload:
            return 2
        case .unavailable:
            return 3
        }
    }
}

public struct LocalModelSettingsRow: Identifiable, Equatable, Sendable {
    public var id: String { modelID }
    public var modelID: String
    public var displayName: String
    public var detailText: String
    public var benchmarkSummaryText: String?
    public var statusText: String
    public var primaryAction: LocalModelSettingsPrimaryAction
    public var manifest: LocalModelManifest
    public var installRecord: LocalModelInstallRecord?
    public var canDelete: Bool { installRecord != nil }

    public init(model: LocalModelManifest, installRecord: LocalModelInstallRecord?, isSelected: Bool) {
        self.modelID = model.id
        self.displayName = model.displayName
        self.detailText = model.settingsDetailText
        self.benchmarkSummaryText = model.benchmarkSummaryText
        self.manifest = model
        self.installRecord = installRecord

        if isSelected {
            self.statusText = "已選用"
            self.primaryAction = .selected
        } else if let installRecord {
            switch installRecord.status {
            case .installed:
                self.statusText = "已安裝"
                self.primaryAction = .select
            case .downloading:
                self.statusText = "下載中"
                self.primaryAction = .unavailable
            case .failed:
                self.statusText = "下載失敗"
                self.primaryAction = .retryDownload
            }
        } else {
            self.statusText = "可下載"
            self.primaryAction = .download
        }
    }
}

public extension LocalModelManifest {
    var settingsDetailText: String {
        [
            parameterCount,
            quantization,
            "\(Self.formattedBytes(fileSizeBytes))",
            "\(contextWindow / 1000)K ctx"
        ].joined(separator: " · ")
    }

    var recommendedBenchmarkProfile: LocalModelBenchmarkProfile? {
        benchmarkProfiles.max { lhs, rhs in
            if lhs.generationTokensPerSecond == rhs.generationTokensPerSecond {
                return lhs.promptTokensPerSecond < rhs.promptTokensPerSecond
            }
            return lhs.generationTokensPerSecond < rhs.generationTokensPerSecond
        }
    }

    var benchmarkSummaryText: String? {
        guard let benchmark = recommendedBenchmarkProfile else {
            return nil
        }

        let runtimeLabel: String
        switch benchmark.runtime {
        case .mlx:
            runtimeLabel = "MLX"
        case .gguf:
            runtimeLabel = "GGUF"
        case .coreML:
            runtimeLabel = "Core ML"
        case .unknown:
            runtimeLabel = benchmark.runtimePackage
        }

        var parts = [
            "\(runtimeLabel) ref \(Self.formattedRate(benchmark.generationTokensPerSecond)) gen tok/s",
            "\(Self.formattedRate(benchmark.promptTokensPerSecond)) prompt tok/s",
            benchmark.testPlatform
        ]
        if let peakMemoryMB = benchmark.peakMemoryMB {
            parts.append("\(Self.formattedMemoryMB(peakMemoryMB)) peak")
        }
        if benchmark.isReferenceOnlyForIOS {
            parts.append("iPhone not verified")
        }
        return parts.joined(separator: " · ")
    }

    private static func formattedBytes(_ bytes: Int64) -> String {
        let units = ["B", "KB", "MB", "GB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024, unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(Int(value)) \(units[unitIndex])"
        }
        return String(format: "%.1f %@", value, units[unitIndex])
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

public enum LocalModelSelectionError: Error, Equatable {
    case modelUnavailable(String)
    case modelNotInstalled(String)
}

public actor FileBackedLocalModelSettingsStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var currentSettings: LocalModelSettings = LocalModelSettings()

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try await loadFromDisk()
    }

    public func settings() -> LocalModelSettings {
        currentSettings
    }

    public func save(_ settings: LocalModelSettings) throws {
        currentSettings = settings
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            currentSettings = LocalModelSettings()
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            currentSettings = LocalModelSettings()
            return
        }

        currentSettings = try decoder.decode(LocalModelSettings.self, from: data)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(currentSettings)
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public actor LocalModelSettingsService {
    private var catalog: LocalModelCatalog
    private let installRegistry: FileBackedLocalModelInstallRegistry
    private let settingsStore: FileBackedLocalModelSettingsStore

    public init(
        catalog: LocalModelCatalog,
        installRegistry: FileBackedLocalModelInstallRegistry,
        settingsStore: FileBackedLocalModelSettingsStore
    ) {
        self.catalog = catalog
        self.installRegistry = installRegistry
        self.settingsStore = settingsStore
    }

    public func replaceCatalog(_ catalog: LocalModelCatalog) {
        self.catalog = catalog
    }

    public func status(minimumSafetyPolicyVersion: String = "2026.1") async -> LocalModelSettingsStatus {
        let settings = await settingsStore.settings()
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        let availableIDs = Set(availableModels.map(\.id))
        let installedModels = await installRegistry.installedRecords()
            .filter { availableIDs.contains($0.modelID) }
        let selectedModel = settings.selectedModelID.flatMap { selectedID in
            availableModels.first { $0.id == selectedID }
        }
        let installedRecord = settings.selectedModelID.flatMap { selectedID in
            installedModels.first { $0.modelID == selectedID }
        }

        return LocalModelSettingsStatus(
            selectedModelID: settings.selectedModelID,
            selectedModel: selectedModel,
            installedRecord: installedRecord,
            preference: settings.preference,
            availableModels: availableModels,
            installedModels: installedModels
        )
    }

    public func selectModel(id: String, minimumSafetyPolicyVersion: String = "2026.1") async throws {
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        guard availableModels.contains(where: { $0.id == id }) else {
            throw LocalModelSelectionError.modelUnavailable(id)
        }
        guard await installRegistry.record(for: id)?.status == .installed else {
            throw LocalModelSelectionError.modelNotInstalled(id)
        }

        var settings = await settingsStore.settings()
        settings.selectedModelID = id
        try await settingsStore.save(settings)
    }

    public func clearSelectedModel() async throws {
        var settings = await settingsStore.settings()
        settings.selectedModelID = nil
        try await settingsStore.save(settings)
    }

    public func setPreference(_ preference: ProviderRoutePreference) async throws {
        var settings = await settingsStore.settings()
        settings.preference = preference
        try await settingsStore.save(settings)
    }

    public func deleteModel(id: String) async throws {
        let record = await installRegistry.record(for: id)
        if let record, FileManager.default.fileExists(atPath: record.fileURL.path) {
            try FileManager.default.removeItem(at: record.fileURL)
        }

        try await installRegistry.delete(modelID: id)

        var settings = await settingsStore.settings()
        if settings.selectedModelID == id {
            settings.selectedModelID = nil
            try await settingsStore.save(settings)
        }
    }

    public func routingContext(
        taskClass: ProviderTaskClass = .simpleQuestionAnswer,
        networkAvailable: Bool = true,
        privacyModeEnabled: Bool = false,
        offlineModeEnabled: Bool = false,
        requiresToolUse: Bool = false,
        requiresCurrentInfo: Bool = false,
        contextTokenEstimate: Int = 0,
        minimumSafetyPolicyVersion: String = "2026.1"
    ) async -> ProviderRoutingContext {
        let modelStatus = await status(minimumSafetyPolicyVersion: minimumSafetyPolicyVersion)
        return ProviderRoutingContext(
            preference: modelStatus.preference,
            networkAvailable: networkAvailable,
            privacyModeEnabled: privacyModeEnabled,
            offlineModeEnabled: offlineModeEnabled,
            taskClass: taskClass,
            requiresToolUse: requiresToolUse,
            requiresCurrentInfo: requiresCurrentInfo,
            contextTokenEstimate: contextTokenEstimate,
            localModelInstalled: modelStatus.localModelInstalled,
            localContextWindow: modelStatus.selectedModel?.contextWindow ?? 2048
        )
    }
}
