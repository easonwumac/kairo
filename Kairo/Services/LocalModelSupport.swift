import Foundation
import CryptoKit

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

public enum LocalModelRuntime: String, Codable, Equatable, Sendable, CaseIterable {
    case gguf
    case mlx
    case coreML
    case unknown
}

public struct LocalModelBenchmarkProfile: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var runtime: LocalModelRuntime
    public var runtimePackage: String
    public var artifactReference: String
    public var promptTokens: Int
    public var generatedTokens: Int
    public var trials: Int
    public var promptTokensPerSecond: Double
    public var generationTokensPerSecond: Double
    public var peakMemoryMB: Int?
    public var testPlatform: String
    public var measuredAt: Date
    public var sourceURL: URL?
    public var supportsInAppDownload: Bool
    public var isReferenceOnlyForIOS: Bool
    public var notes: String

    public init(
        id: String,
        runtime: LocalModelRuntime,
        runtimePackage: String,
        artifactReference: String,
        promptTokens: Int,
        generatedTokens: Int,
        trials: Int,
        promptTokensPerSecond: Double,
        generationTokensPerSecond: Double,
        peakMemoryMB: Int? = nil,
        testPlatform: String,
        measuredAt: Date,
        sourceURL: URL? = nil,
        supportsInAppDownload: Bool,
        isReferenceOnlyForIOS: Bool,
        notes: String
    ) {
        self.id = id
        self.runtime = runtime
        self.runtimePackage = runtimePackage
        self.artifactReference = artifactReference
        self.promptTokens = promptTokens
        self.generatedTokens = generatedTokens
        self.trials = trials
        self.promptTokensPerSecond = promptTokensPerSecond
        self.generationTokensPerSecond = generationTokensPerSecond
        self.peakMemoryMB = peakMemoryMB
        self.testPlatform = testPlatform
        self.measuredAt = measuredAt
        self.sourceURL = sourceURL
        self.supportsInAppDownload = supportsInAppDownload
        self.isReferenceOnlyForIOS = isReferenceOnlyForIOS
        self.notes = notes
    }
}

public struct LocalModelManifest: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var family: String
    public var version: String
    public var parameterCount: String
    public var quantization: String
    public var runtime: LocalModelRuntime
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
    public var benchmarkProfiles: [LocalModelBenchmarkProfile]
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
        runtime: LocalModelRuntime = .gguf,
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
        benchmarkProfiles: [LocalModelBenchmarkProfile] = [],
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
        self.runtime = runtime
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
        self.benchmarkProfiles = benchmarkProfiles
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.safetyPolicyVersion = safetyPolicyVersion
        self.deprecated = deprecated
        self.replacementModelID = replacementModelID
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case family
        case version
        case parameterCount
        case quantization
        case runtime
        case fileSizeBytes
        case installedSizeBytes
        case contextWindow
        case tokenizerID
        case licenseName
        case licenseURL
        case minOSVersion
        case minDeviceClass
        case minRAMGB
        case supportedLocales
        case capabilities
        case disallowedCapabilities
        case downloadURL
        case sha256
        case signature
        case benchmarkProfiles
        case createdAt
        case updatedAt
        case safetyPolicyVersion
        case deprecated
        case replacementModelID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.family = try container.decode(String.self, forKey: .family)
        self.version = try container.decode(String.self, forKey: .version)
        self.parameterCount = try container.decode(String.self, forKey: .parameterCount)
        self.quantization = try container.decode(String.self, forKey: .quantization)
        self.runtime = try container.decodeIfPresent(LocalModelRuntime.self, forKey: .runtime) ?? .unknown
        self.fileSizeBytes = try container.decode(Int64.self, forKey: .fileSizeBytes)
        self.installedSizeBytes = try container.decode(Int64.self, forKey: .installedSizeBytes)
        self.contextWindow = try container.decode(Int.self, forKey: .contextWindow)
        self.tokenizerID = try container.decode(String.self, forKey: .tokenizerID)
        self.licenseName = try container.decode(String.self, forKey: .licenseName)
        self.licenseURL = try container.decode(URL.self, forKey: .licenseURL)
        self.minOSVersion = try container.decode(String.self, forKey: .minOSVersion)
        self.minDeviceClass = try container.decode(String.self, forKey: .minDeviceClass)
        self.minRAMGB = try container.decode(Double.self, forKey: .minRAMGB)
        self.supportedLocales = try container.decode([String].self, forKey: .supportedLocales)
        self.capabilities = try container.decode([LocalModelCapability].self, forKey: .capabilities)
        self.disallowedCapabilities = try container.decodeIfPresent([LocalModelCapability].self, forKey: .disallowedCapabilities) ?? []
        self.downloadURL = try container.decode(URL.self, forKey: .downloadURL)
        self.sha256 = try container.decode(String.self, forKey: .sha256)
        self.signature = try container.decodeIfPresent(String.self, forKey: .signature)
        self.benchmarkProfiles = try container.decodeIfPresent([LocalModelBenchmarkProfile].self, forKey: .benchmarkProfiles) ?? []
        self.createdAt = try container.decode(Date.self, forKey: .createdAt)
        self.updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        self.safetyPolicyVersion = try container.decode(String.self, forKey: .safetyPolicyVersion)
        self.deprecated = try container.decodeIfPresent(Bool.self, forKey: .deprecated) ?? false
        self.replacementModelID = try container.decodeIfPresent(String.self, forKey: .replacementModelID)
    }
}

public struct LocalModelCatalog: Codable, Equatable, Sendable {
    public var schemaVersion: Int
    public var generatedAt: Date
    public var signingKeyID: String
    public var signature: String
    public var sourceRepository: URL?
    public var minimumSafetyPolicyVersion: String
    public var models: [LocalModelManifest]

    public init(
        schemaVersion: Int = 1,
        generatedAt: Date = Date(),
        signingKeyID: String,
        signature: String,
        sourceRepository: URL? = nil,
        minimumSafetyPolicyVersion: String,
        models: [LocalModelManifest]
    ) {
        self.schemaVersion = schemaVersion
        self.generatedAt = generatedAt
        self.signingKeyID = signingKeyID
        self.signature = signature
        self.sourceRepository = sourceRepository
        self.minimumSafetyPolicyVersion = minimumSafetyPolicyVersion
        self.models = models
    }

    public func availableModels(minimumSafetyPolicyVersion: String) -> [LocalModelManifest] {
        models.filter { model in
            !model.deprecated
            && model.safetyPolicyVersion.compare(minimumSafetyPolicyVersion, options: .numeric) != .orderedAscending
        }
    }

    public func mergingRemoteCatalog(_ remoteCatalog: LocalModelCatalog) -> LocalModelCatalog {
        var modelsByID = Dictionary(uniqueKeysWithValues: models.map { ($0.id, $0) })
        var orderedIDs = models.map(\.id)

        for remoteModel in remoteCatalog.models {
            if modelsByID[remoteModel.id] == nil {
                orderedIDs.append(remoteModel.id)
            }
            modelsByID[remoteModel.id] = remoteModel
        }

        return LocalModelCatalog(
            schemaVersion: max(schemaVersion, remoteCatalog.schemaVersion),
            generatedAt: remoteCatalog.generatedAt,
            signingKeyID: remoteCatalog.signingKeyID,
            signature: remoteCatalog.signature,
            sourceRepository: remoteCatalog.sourceRepository ?? sourceRepository,
            minimumSafetyPolicyVersion: Self.stricterSafetyPolicy(
                minimumSafetyPolicyVersion,
                remoteCatalog.minimumSafetyPolicyVersion
            ),
            models: orderedIDs.compactMap { modelsByID[$0] }
        )
    }

    private static func stricterSafetyPolicy(_ lhs: String, _ rhs: String) -> String {
        lhs.compare(rhs, options: .numeric) == .orderedAscending ? rhs : lhs
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

public extension LocalModelCatalog {
    static let kairoDefault = LocalModelCatalog(
        generatedAt: Date(timeIntervalSince1970: 1_767_225_600),
        signingKeyID: "kairo-default-local-settings",
        signature: "unsigned-settings-placeholder",
        sourceRepository: URL(string: "https://github.com/easonwumac/kairo-models"),
        minimumSafetyPolicyVersion: "2026.1",
        models: [
            .qwen35Tiny,
            .llama32OneBInstruct,
            .deepSeekR1DistillQwenTiny,
            .smolLM2TinyInstruct
        ]
    )
}

public enum LocalModelCatalogServiceError: Error, Equatable {
    case invalidJSON
    case unsafeDownloadURL(modelID: String, url: String)
    case invalidChecksum(modelID: String, sha256: String)
}

public struct LocalModelCatalogService: Sendable {
    public static let defaultIndexURL = URL(string: "https://easonwumac.github.io/kairo-models/models.json")!
    public static let defaultStandaloneRepository = LocalModelCatalogService(indexURL: defaultIndexURL)

    private let indexURL: URL
    private let httpClient: any HTTPClient

    public init(
        indexURL: URL = Self.defaultIndexURL,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.indexURL = indexURL
        self.httpClient = httpClient
    }

    public func fetchCatalog() async throws -> LocalModelCatalog {
        let request = URLRequest(url: indexURL)
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
        }

        let catalog: LocalModelCatalog
        do {
            catalog = try LocalModelCatalog.decode(data)
        } catch {
            throw LocalModelCatalogServiceError.invalidJSON
        }

        try validate(catalog)
        return catalog
    }

    public func fetchMergedCatalog(with builtInCatalog: LocalModelCatalog = .kairoDefault) async throws -> LocalModelCatalog {
        let remoteCatalog = try await fetchCatalog()
        return builtInCatalog.mergingRemoteCatalog(remoteCatalog)
    }

    private func validate(_ catalog: LocalModelCatalog) throws {
        for model in catalog.models {
            guard model.downloadURL.scheme?.lowercased() == "https" else {
                throw LocalModelCatalogServiceError.unsafeDownloadURL(
                    modelID: model.id,
                    url: model.downloadURL.absoluteString
                )
            }
            guard model.sha256.count == 64 else {
                throw LocalModelCatalogServiceError.invalidChecksum(
                    modelID: model.id,
                    sha256: model.sha256
                )
            }
        }
    }
}

public extension LocalModelManifest {
    static let qwen35Tiny = ggufManifest(
        id: "qwen3-5-0-8b-q4-k-m",
        displayName: "Qwen3.5 0.8B Q4_K_M",
        family: "Qwen3.5",
        parameterCount: "0.8B",
        fileSizeBytes: 527_503_328,
        installedSizeBytes: 900 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen3.5-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/AaryanK/Qwen3.5-0.8B-GGUF/resolve/main/Qwen3.5-0.8B.q4_k_m.gguf",
        sha256: "e8e388246c2a6ddbbb9fffc0df7ef0bd0ad71622f3c851b68df6cc58b78a51af",
        benchmarkProfiles: [
            LocalModelBenchmarkProfile(
                id: "qwen3-5-0-8b-gguf-metal-2026-06-02",
                runtime: .gguf,
                runtimePackage: "llama.cpp Metal",
                artifactReference: "AaryanK/Qwen3.5-0.8B-GGUF:Q4_K_M",
                promptTokens: 512,
                generatedTokens: 128,
                trials: 5,
                promptTokensPerSecond: 8_810,
                generationTokensPerSecond: 214,
                testPlatform: "Apple Silicon Mac",
                measuredAt: Date(timeIntervalSince1970: 1_780_358_400),
                sourceURL: URL(string: "https://huggingface.co/AaryanK/Qwen3.5-0.8B-GGUF"),
                supportsInAppDownload: true,
                isReferenceOnlyForIOS: true,
                notes: "Developer reference benchmark with 512 prompt tokens and 128 generated tokens. Real iPhone latency, memory, thermal behavior, and runtime choice still require device testing."
            ),
            LocalModelBenchmarkProfile(
                id: "qwen3-5-0-8b-mlx-optiq-2026-06-02",
                runtime: .mlx,
                runtimePackage: "mlx-lm",
                artifactReference: "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
                promptTokens: 512,
                generatedTokens: 128,
                trials: 5,
                promptTokensPerSecond: 10_639,
                generationTokensPerSecond: 286,
                peakMemoryMB: 1_360,
                testPlatform: "Apple Silicon Mac",
                measuredAt: Date(timeIntervalSince1970: 1_780_358_400),
                sourceURL: URL(string: "https://huggingface.co/mlx-community/Qwen3.5-0.8B-OptiQ-4bit"),
                supportsInAppDownload: false,
                isReferenceOnlyForIOS: true,
                notes: "MLX is the stronger Apple Silicon validation path, but this artifact is not an in-app iPhone download target in this pass."
            )
        ]
    )

    static let qwen35Small = ggufManifest(
        id: "qwen3-5-2b-q4-k-m",
        displayName: "Qwen3.5 2B Q4_K_M",
        family: "Qwen3.5",
        parameterCount: "2B",
        fileSizeBytes: 1_270_808_512,
        installedSizeBytes: 2_000 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen3.5-tokenizer",
        minRAMGB: 6,
        downloadURL: "https://huggingface.co/AaryanK/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B.q4_k_m.gguf",
        sha256: "a511452ec932613d6b26b4fa24488fd431eb61eac69321460447d475edc221e2"
    )

    static let qwen25TinyInstruct = ggufManifest(
        id: "qwen2-5-1-5b-instruct-q4-k-m",
        displayName: "Qwen2.5 1.5B Instruct Q4_K_M",
        family: "Qwen2.5",
        parameterCount: "1.5B",
        fileSizeBytes: 1_117_320_736,
        installedSizeBytes: 1_700 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        sha256: "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
    )

    static let qwen25MathTinyInstruct = ggufManifest(
        id: "qwen2-5-math-1-5b-instruct-q4-k-m",
        displayName: "Qwen2.5 Math 1.5B Instruct Q4_K_M",
        family: "Qwen2.5 Math",
        parameterCount: "1.5B",
        fileSizeBytes: 986_048_832,
        installedSizeBytes: 1_500 * 1024 * 1024,
        contextWindow: 4_096,
        tokenizerID: "qwen2.5-math-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/bartowski/Qwen2.5-Math-1.5B-Instruct-GGUF/resolve/main/Qwen2.5-Math-1.5B-Instruct-Q4_K_M.gguf",
        sha256: "9614a50f03c897028920ca0dc4365da570bf587f9ee7768261216fe370b37e8e"
    )

    static let qwen25MicroInstruct = ggufManifest(
        id: "qwen2-5-0-5b-instruct-q4-k-m",
        displayName: "Qwen2.5 0.5B Instruct Q4_K_M",
        family: "Qwen2.5",
        parameterCount: "0.5B",
        fileSizeBytes: 491_400_032,
        installedSizeBytes: 800 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct-GGUF/resolve/main/qwen2.5-0.5b-instruct-q4_k_m.gguf",
        sha256: "74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db"
    )

    static let qwen25CoderMicroInstruct = ggufManifest(
        id: "qwen2-5-coder-0-5b-instruct-q4-k-m",
        displayName: "Qwen2.5-Coder 0.5B Instruct Q4_K_M",
        family: "Qwen2.5-Coder",
        parameterCount: "0.5B",
        fileSizeBytes: 491_400_512,
        installedSizeBytes: 800 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-coder-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/QuantFactory/Qwen2.5-Coder-0.5B-Instruct-GGUF/resolve/main/Qwen2.5-Coder-0.5B-Instruct.Q4_K_M.gguf",
        sha256: "5d933e04310b9184f9bc97e511820e71b5dc7704eda6f7c937126a241828e93e"
    )

    static let qwen25CoderTinyInstruct = ggufManifest(
        id: "qwen2-5-coder-1-5b-instruct-q4-k-m",
        displayName: "Qwen2.5-Coder 1.5B Instruct Q4_K_M",
        family: "Qwen2.5-Coder",
        parameterCount: "1.5B",
        fileSizeBytes: 1_117_320_768,
        installedSizeBytes: 1_700 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-coder-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/Qwen/Qwen2.5-Coder-1.5B-Instruct-GGUF/resolve/main/qwen2.5-coder-1.5b-instruct-q4_k_m.gguf",
        sha256: "cc324af070c2ecbfd324a30884d2f951a7ff756aba85cb811a6ec436933bb046"
    )

    static let qwen3Micro = ggufManifest(
        id: "qwen3-0-6b-q4-k-m",
        displayName: "Qwen3 0.6B Q4_K_M",
        family: "Qwen3",
        parameterCount: "0.6B",
        fileSizeBytes: 396_705_472,
        installedSizeBytes: 750 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen3-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/unsloth/Qwen3-0.6B-GGUF/resolve/main/Qwen3-0.6B-Q4_K_M.gguf",
        sha256: "ac2d97712095a558e31573f62f466a3f9d93990898b0ec79d7c974c1780d524a"
    )

    static let qwen3Tiny = ggufManifest(
        id: "qwen3-1-7b-q4-k-m",
        displayName: "Qwen3 1.7B Q4_K_M",
        family: "Qwen3",
        parameterCount: "1.7B",
        fileSizeBytes: 1_107_409_472,
        installedSizeBytes: 1_700 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen3-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/unsloth/Qwen3-1.7B-GGUF/resolve/main/Qwen3-1.7B-Q4_K_M.gguf",
        sha256: "b139949c5bd74937ad8ed8c8cf3d9ffb1e99c866c823204dc42c0d91fa181897"
    )

    static let llama32OneBInstruct = ggufManifest(
        id: "llama3-2-1b-instruct-q4-k-m",
        displayName: "Llama 3.2 1B Instruct Q4_K_M",
        family: "Llama 3.2",
        parameterCount: "1B",
        fileSizeBytes: 807_694_464,
        installedSizeBytes: 1_200 * 1024 * 1024,
        contextWindow: 131_072,
        tokenizerID: "llama3.2-tokenizer",
        licenseName: "Llama 3.2 Community License",
        licenseURL: "https://www.llama.com/llama3_2/license/",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/bartowski/Llama-3.2-1B-Instruct-GGUF/resolve/main/Llama-3.2-1B-Instruct-Q4_K_M.gguf",
        sha256: "6f85a640a97cf2bf5b8e764087b1e83da0fdb51d7c9fab7d0fece9385611df83"
    )

    static let granite32TwoBInstruct = ggufManifest(
        id: "granite3-2-2b-instruct-q4-k-m",
        displayName: "Granite 3.2 2B Instruct Q4_K_M",
        family: "Granite 3.2",
        parameterCount: "2B",
        fileSizeBytes: 1_530_551_136,
        installedSizeBytes: 2_200 * 1024 * 1024,
        contextWindow: 131_072,
        tokenizerID: "granite3.2-tokenizer",
        minRAMGB: 5,
        downloadURL: "https://huggingface.co/Mungert/granite-3.2-2b-instruct-GGUF/resolve/main/granite-3.2-2b-instruct-q4_k_m.gguf",
        sha256: "2db5bc4ba770f23bafe3376e49acbfac82fa04b75299bff41471399712fda0aa"
    )

    static let deepSeekR1DistillQwenTiny = ggufManifest(
        id: "deepseek-r1-distill-qwen-1-5b-q4-k-m",
        displayName: "DeepSeek R1 Distill Qwen 1.5B Q4_K_M",
        family: "DeepSeek R1 Distill Qwen",
        parameterCount: "1.5B",
        fileSizeBytes: 1_117_320_480,
        installedSizeBytes: 1_700 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-tokenizer",
        licenseName: "MIT",
        licenseURL: "https://opensource.org/license/mit",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/QuantFactory/DeepSeek-R1-Distill-Qwen-1.5B-GGUF/resolve/main/DeepSeek-R1-Distill-Qwen-1.5B.Q4_K_M.gguf",
        sha256: "41aa31689f2cbdcc5172e370db2ab7a10e17a9427520602437bd16d8d127d105"
    )

    static let lfm25TinyInstruct = ggufManifest(
        id: "lfm2-5-1-2b-instruct-q4-k-m",
        displayName: "LFM2.5 1.2B Instruct Q4_K_M",
        family: "LFM2.5",
        parameterCount: "1.2B",
        fileSizeBytes: 730_895_168,
        installedSizeBytes: 1_100 * 1024 * 1024,
        contextWindow: 128_000,
        tokenizerID: "lfm2.5-tokenizer",
        licenseName: "LFM 1.0 License",
        licenseURL: "https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF/blob/main/LICENSE",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/LiquidAI/LFM2.5-1.2B-Instruct-GGUF/resolve/main/LFM2.5-1.2B-Instruct-Q4_K_M.gguf",
        sha256: "b1b3de114215d9507409a662a501a631095a479a419584e8a2ded6304b19b4f5"
    )

    static let h2oDanube2Chat = ggufManifest(
        id: "h2o-danube2-1-8b-chat-q4-k-m",
        displayName: "H2O Danube2 1.8B Chat Q4_K_M",
        family: "H2O Danube2",
        parameterCount: "1.8B",
        fileSizeBytes: 1_112_145_056,
        installedSizeBytes: 1_700 * 1024 * 1024,
        contextWindow: 8_192,
        tokenizerID: "h2o-danube2-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/h2oai/h2o-danube2-1.8b-chat-GGUF/resolve/main/h2o-danube2-1.8b-chat-Q4_K_M.gguf",
        sha256: "6a303ee6b94a961aa43e48eb11629e933c4438fae5e6db336318a5d33fe57d79"
    )

    static let olmo2OneBInstruct = ggufManifest(
        id: "olmo2-0425-1b-instruct-q4-k-m",
        displayName: "OLMo 2 1B Instruct Q4_K_M",
        family: "OLMo 2",
        parameterCount: "1B",
        fileSizeBytes: 935_515_360,
        installedSizeBytes: 1_400 * 1024 * 1024,
        contextWindow: 4_096,
        tokenizerID: "olmo2-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/unsloth/OLMo-2-0425-1B-Instruct-GGUF/resolve/main/OLMo-2-0425-1B-Instruct-Q4_K_M.gguf",
        sha256: "54b26d5388274d038608b42fdf1afb7544d2e51a0fac4d1abf4a8c54a813fbbc"
    )

    static let openELM11BInstruct = ggufManifest(
        id: "openelm-1-1b-instruct-q4-k-m",
        displayName: "OpenELM 1.1B Instruct Q4_K_M",
        family: "OpenELM",
        parameterCount: "1.1B",
        fileSizeBytes: 678_056_320,
        installedSizeBytes: 1_100 * 1024 * 1024,
        contextWindow: 2_048,
        tokenizerID: "openelm-tokenizer",
        licenseName: "Apple Sample Code License",
        licenseURL: "https://huggingface.co/straino/OpenELM-1_1B-Instruct-Q4_K_M-GGUF/blob/main/LICENSE",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/straino/OpenELM-1_1B-Instruct-Q4_K_M-GGUF/resolve/main/openelm-1_1b-instruct-q4_k_m.gguf",
        sha256: "c687a192d7e914d42cd35f4832327068f2a4a5ec53e01dff853d814bfb5e3328"
    )

    static let falconH1TinyInstruct = ggufManifest(
        id: "falcon-h1-1-5b-instruct-q4-k-m",
        displayName: "Falcon-H1 1.5B Instruct Q4_K_M",
        family: "Falcon-H1",
        parameterCount: "1.5B",
        fileSizeBytes: 944_786_656,
        installedSizeBytes: 1_500 * 1024 * 1024,
        contextWindow: 131_072,
        tokenizerID: "falcon-h1-tokenizer",
        licenseName: "Falcon LLM License",
        licenseURL: "https://falconllm.tii.ae/falcon-terms-and-conditions.html",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/tiiuae/Falcon-H1-1.5B-Instruct-GGUF/resolve/main/Falcon-H1-1.5B-Instruct-Q4_K_M.gguf",
        sha256: "8b51aa2aa34a0373fd0cd64c02eb91d1bc1da681c09e955ad769d4a9b2d8385f"
    )

    static let smolLM2NanoInstruct = ggufManifest(
        id: "smollm2-135m-instruct-q4-k-m",
        displayName: "SmolLM2 135M Instruct Q4_K_M",
        family: "SmolLM2",
        parameterCount: "135M",
        fileSizeBytes: 105_454_144,
        installedSizeBytes: 250 * 1024 * 1024,
        contextWindow: 8_192,
        tokenizerID: "smollm2-tokenizer",
        minRAMGB: 2.5,
        downloadURL: "https://huggingface.co/unsloth/SmolLM2-135M-Instruct-GGUF/resolve/main/SmolLM2-135M-Instruct-Q4_K_M.gguf",
        sha256: "ed5fa30c487b282ec156c29062f1222e5c20875a944ac98289dbd242e947f747"
    )

    static let smolLM2MicroInstruct = ggufManifest(
        id: "smollm2-360m-instruct-q4-k-m",
        displayName: "SmolLM2 360M Instruct Q4_K_M",
        family: "SmolLM2",
        parameterCount: "360M",
        fileSizeBytes: 270_590_880,
        installedSizeBytes: 500 * 1024 * 1024,
        contextWindow: 8_192,
        tokenizerID: "smollm2-tokenizer",
        minRAMGB: 3,
        downloadURL: "https://huggingface.co/bartowski/SmolLM2-360M-Instruct-GGUF/resolve/main/SmolLM2-360M-Instruct-Q4_K_M.gguf",
        sha256: "2fa3f013dcdd7b99f9b237717fa0b12d75bbb89984cc1274be1471a465bac9c2"
    )

    static let smolLM2TinyInstruct = ggufManifest(
        id: "smollm2-1-7b-instruct-q4-k-m",
        displayName: "SmolLM2 1.7B Instruct Q4_K_M",
        family: "SmolLM2",
        parameterCount: "1.7B",
        fileSizeBytes: 1_055_609_824,
        installedSizeBytes: 1_600 * 1024 * 1024,
        contextWindow: 8_192,
        tokenizerID: "smollm2-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/bartowski/SmolLM2-1.7B-Instruct-GGUF/resolve/main/SmolLM2-1.7B-Instruct-Q4_K_M.gguf",
        sha256: "77665ea4815999596525c636fbeb56ba8b080b46ae85efef4f0d986a139834d7"
    )

    static let tinyLlamaChat = ggufManifest(
        id: "tinyllama-1-1b-chat-q4-k-m",
        displayName: "TinyLlama 1.1B Chat Q4_K_M",
        family: "TinyLlama",
        parameterCount: "1.1B",
        fileSizeBytes: 668_788_096,
        installedSizeBytes: 1_100 * 1024 * 1024,
        contextWindow: 4_096,
        tokenizerID: "llama2-tokenizer",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/TheBloke/TinyLlama-1.1B-Chat-v1.0-GGUF/resolve/main/tinyllama-1.1b-chat-v1.0.Q4_K_M.gguf",
        sha256: "9fecc3b3cd76bba89d504f29b616eedf7da85b96540e490ca5824d3f7d2776a0"
    )

    static let gemma3NanoIt = ggufManifest(
        id: "gemma3-270m-it-q4-k-m",
        displayName: "Gemma 3 270M IT Q4_K_M",
        family: "Gemma 3",
        parameterCount: "270M",
        fileSizeBytes: 253_115_424,
        installedSizeBytes: 450 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "gemma3-tokenizer",
        licenseName: "Gemma Terms of Use",
        licenseURL: "https://ai.google.dev/gemma/terms",
        minRAMGB: 3,
        downloadURL: "https://huggingface.co/unsloth/gemma-3-270m-it-GGUF/resolve/main/gemma-3-270m-it-Q4_K_M.gguf",
        sha256: "b1baabd6b729e4041822220d3e648e00d99cac5df86b10dffb77bcccf0688e39"
    )

    static let gemma3OneBIt = ggufManifest(
        id: "gemma3-1b-it-q4-k-m",
        displayName: "Gemma 3 1B IT Q4_K_M",
        family: "Gemma 3",
        parameterCount: "1B",
        fileSizeBytes: 806_058_240,
        installedSizeBytes: 1_200 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "gemma3-tokenizer",
        licenseName: "Gemma Terms of Use",
        licenseURL: "https://ai.google.dev/gemma/terms",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/ggml-org/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-Q4_K_M.gguf",
        sha256: "8ccc5cd1f1b3602548715ae25a66ed73fd5dc68a210412eea643eb20eb75a135"
    )

    static let gemma2TwoBIt = ggufManifest(
        id: "gemma2-2b-it-q4-k-m",
        displayName: "Gemma 2 2B IT Q4_K_M",
        family: "Gemma 2",
        parameterCount: "2B",
        fileSizeBytes: 1_495_095_008,
        installedSizeBytes: 2_200 * 1024 * 1024,
        contextWindow: 8_192,
        tokenizerID: "gemma2-tokenizer",
        licenseName: "Gemma Terms of Use",
        licenseURL: "https://ai.google.dev/gemma/terms",
        minRAMGB: 5,
        downloadURL: "https://huggingface.co/second-state/Gemma-2b-it-GGUF/resolve/main/gemma-2b-it-Q4_K_M.gguf",
        sha256: "4d736aa91fa06bb4d72a9e9017ad4e5c6a8fc16fb01b748c9b8332293c855402"
    )

    static let gemma4E2BIt = ggufManifest(
        id: "gemma4-e2b-it-q4-k-m",
        displayName: "Gemma 4 E2B IT Q4_K_M",
        family: "Gemma 4",
        parameterCount: "2B",
        fileSizeBytes: 3_106_736_256,
        installedSizeBytes: 3_700 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "gemma4-tokenizer",
        minRAMGB: 6,
        downloadURL: "https://huggingface.co/unsloth/gemma-4-E2B-it-GGUF/resolve/main/gemma-4-E2B-it-Q4_K_M.gguf",
        sha256: "9378bc471710229ef165709b62e34bfb62231420ddaf6d729e727305b5b8672d"
    )

    static let stableLM2ChatTiny = ggufManifest(
        id: "stablelm2-chat-1-6b-q4-k-m",
        displayName: "StableLM 2 Chat 1.6B Q4_K_M",
        family: "StableLM 2 Chat",
        parameterCount: "1.6B",
        fileSizeBytes: 1_031_443_456,
        installedSizeBytes: 1_600 * 1024 * 1024,
        contextWindow: 4_096,
        tokenizerID: "stablelm2-tokenizer",
        licenseName: "Stability AI Non-Commercial Research Community License",
        licenseURL: "https://huggingface.co/stabilityai/stablelm-2-1_6b-chat/blob/main/LICENSE",
        minRAMGB: 4,
        downloadURL: "https://huggingface.co/RichardErkhov/stabilityai_-_stablelm-2-1_6b-chat-gguf/resolve/main/stablelm-2-1_6b-chat.Q4_K_M.gguf",
        sha256: "cc3d155b10272a93cfd53304c95289b97ae677d8aaf455a23305c552fb83f091"
    )

    static let kairoDraftTiny = qwen35Tiny

    private static func ggufManifest(
        id: String,
        displayName: String,
        family: String,
        parameterCount: String,
        fileSizeBytes: Int64,
        installedSizeBytes: Int64,
        contextWindow: Int,
        tokenizerID: String,
        licenseName: String = "Apache-2.0",
        licenseURL: String = "https://www.apache.org/licenses/LICENSE-2.0",
        minRAMGB: Double,
        downloadURL: String,
        sha256: String,
        benchmarkProfiles: [LocalModelBenchmarkProfile] = []
    ) -> LocalModelManifest {
        LocalModelManifest(
            id: id,
            displayName: displayName,
            family: family,
            version: "1.0",
            parameterCount: parameterCount,
            quantization: "Q4_K_M",
            fileSizeBytes: fileSizeBytes,
            installedSizeBytes: installedSizeBytes,
            contextWindow: contextWindow,
            tokenizerID: tokenizerID,
            licenseName: licenseName,
            licenseURL: URL(string: licenseURL)!,
            minOSVersion: "17.0",
            minDeviceClass: "A15",
            minRAMGB: minRAMGB,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: URL(string: downloadURL)!,
            sha256: sha256,
            benchmarkProfiles: benchmarkProfiles,
            createdAt: Date(timeIntervalSince1970: 1_767_225_600),
            updatedAt: Date(timeIntervalSince1970: 1_767_225_600),
            safetyPolicyVersion: "2026.1"
        )
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
            .map { model in
                let record = installedByID[model.id]
                let isSelected = selectedModelID == model.id && record?.status == .installed
                return LocalModelSettingsRow(model: model, installRecord: record, isSelected: isSelected)
            }
            .sorted { lhs, rhs in
                if lhs.primaryAction == rhs.primaryAction {
                    return lhs.modelID < rhs.modelID
                }
                return lhs.primaryAction.sortPriority < rhs.primaryAction.sortPriority
            }
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
        case .download, .retryDownload:
            return 0
        case .select:
            return 1
        case .selected:
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
            "\(Self.formattedBytes(fileSizeBytes)) download",
            "\(contextWindow / 1000)K context",
            licenseName
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

    public static let settingsChoices: [ProviderRoutePreference] = [
        .automatic,
        .preferLocal,
        .preferCloud,
        .localOnly
    ]

    public var settingsTitle: String {
        switch self {
        case .automatic:
            return "Automatic"
        case .preferLocal:
            return "Prefer Local"
        case .preferCloud:
            return "Prefer Cloud"
        case .localOnly:
            return "Local Only"
        }
    }

    public var settingsDetailText: String {
        switch self {
        case .automatic:
            return "Routes eligible private/offline work locally when policy requires it."
        case .preferLocal:
            return "Uses the selected local model for eligible low-risk work when installed."
        case .preferCloud:
            return "Uses the cloud provider when network access is available."
        case .localOnly:
            return "Never routes prompts to cloud providers; unsupported local tasks fail closed."
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
