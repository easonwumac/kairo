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
    static let kairoStarterModelIDs = [
        "qwen3-5-0-8b-q4-k-m",
        "llama3-2-1b-instruct-q4-k-m"
    ]

    static let kairoStarterModels: [LocalModelManifest] = [
        .qwen35Tiny,
        .llama32OneBInstruct
    ]

    static let kairoDefault = LocalModelCatalog(
        generatedAt: Date(timeIntervalSince1970: 1_767_225_600),
        signingKeyID: "kairo-default-local-settings",
        signature: "unsigned-settings-placeholder",
        sourceRepository: URL(string: "https://github.com/easonwumac/kairo-models"),
        minimumSafetyPolicyVersion: "2026.1",
        models: kairoStarterModels
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
