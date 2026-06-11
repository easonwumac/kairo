import Foundation
import CryptoKit

public enum LocalModelCapability: String, Codable, Equatable, Sendable, CaseIterable {
    case drafts
    case summarization
    case simpleQuestionAnswer
    case offlineChat
    case rewriting
    case extraction
    case imageUnderstanding
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
    case appleFoundationModels
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

public struct LocalModelCompanionArtifact: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var role: String
    public var displayName: String
    public var fileSizeBytes: Int64
    public var downloadURL: URL
    public var sha256: String

    public init(
        id: String,
        role: String,
        displayName: String,
        fileSizeBytes: Int64,
        downloadURL: URL,
        sha256: String
    ) {
        self.id = id
        self.role = role
        self.displayName = displayName
        self.fileSizeBytes = fileSizeBytes
        self.downloadURL = downloadURL
        self.sha256 = sha256
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
    public var companionArtifacts: [LocalModelCompanionArtifact]
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
        companionArtifacts: [LocalModelCompanionArtifact] = [],
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
        self.companionArtifacts = companionArtifacts
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
        case companionArtifacts
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
        self.companionArtifacts = try container.decodeIfPresent([LocalModelCompanionArtifact].self, forKey: .companionArtifacts) ?? []
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
    public var catalogSignatureStatus: LocalModelCatalogSignatureStatus
    public var schemaVersion: Int
    public var generatedAt: Date
    public var signingKeyID: String
    public var signature: String
    public var sourceRepository: URL?
    public var minimumSafetyPolicyVersion: String
    public var models: [LocalModelManifest]

    public init(
        catalogSignatureStatus: LocalModelCatalogSignatureStatus = .productionSigned,
        schemaVersion: Int = 1,
        generatedAt: Date = Date(),
        signingKeyID: String,
        signature: String,
        sourceRepository: URL? = nil,
        minimumSafetyPolicyVersion: String,
        models: [LocalModelManifest]
    ) {
        self.catalogSignatureStatus = catalogSignatureStatus
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
            catalogSignatureStatus: remoteCatalog.catalogSignatureStatus,
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

    public func upserting(_ model: LocalModelManifest) -> LocalModelCatalog {
        var updated = self
        if let index = updated.models.firstIndex(where: { $0.id == model.id }) {
            updated.models[index] = model
        } else {
            updated.models.append(model)
        }
        return updated
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

    public func signingPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(LocalModelCatalogSigningPayload(
            catalogSignatureStatus: catalogSignatureStatus,
            schemaVersion: schemaVersion,
            generatedAt: generatedAt,
            signingKeyID: signingKeyID,
            sourceRepository: sourceRepository,
            minimumSafetyPolicyVersion: minimumSafetyPolicyVersion,
            models: models
        ))
    }

    private enum CodingKeys: String, CodingKey {
        case catalogSignatureStatus
        case schemaVersion
        case generatedAt
        case signingKeyID
        case signature
        case sourceRepository
        case minimumSafetyPolicyVersion
        case models
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.catalogSignatureStatus = try container.decodeIfPresent(
            LocalModelCatalogSignatureStatus.self,
            forKey: .catalogSignatureStatus
        ) ?? .productionSigned
        self.schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        self.generatedAt = try container.decode(Date.self, forKey: .generatedAt)
        self.signingKeyID = try container.decode(String.self, forKey: .signingKeyID)
        self.signature = try container.decode(String.self, forKey: .signature)
        self.sourceRepository = try container.decodeIfPresent(URL.self, forKey: .sourceRepository)
        self.minimumSafetyPolicyVersion = try container.decode(String.self, forKey: .minimumSafetyPolicyVersion)
        self.models = try container.decode([LocalModelManifest].self, forKey: .models)
    }

    public static func signedForTesting(
        catalog: LocalModelCatalog,
        keyID: String,
        signingKey: P256.Signing.PrivateKey
    ) throws -> LocalModelCatalog {
        var signedCatalog = catalog
        signedCatalog.signingKeyID = keyID
        signedCatalog.signature = ""
        let signature = try signingKey.signature(for: signedCatalog.signingPayloadData())
        signedCatalog.signature = signature.derRepresentation.base64EncodedString()
        return signedCatalog
    }
}

private struct LocalModelCatalogSigningPayload: Codable, Equatable, Sendable {
    public var catalogSignatureStatus: LocalModelCatalogSignatureStatus
    public var schemaVersion: Int
    public var generatedAt: Date
    public var signingKeyID: String
    public var sourceRepository: URL?
    public var minimumSafetyPolicyVersion: String
    public var models: [LocalModelManifest]
}

public enum LocalModelCatalogSignatureStatus: String, Codable, Equatable, Sendable {
    case productionSigned
    case referenceUnsigned
}

public extension LocalModelCatalog {
    static let kairoStarterModelIDs = [
        "apple-foundation-models-system",
        "gemma-4-e2b-it-qat-q4-0-gguf",
        "qwen2-5-0-5b-instruct-q4-k-m",
        "qwen2-5-1-5b-instruct-q4-k-m",
        "qwen2-5-vl-3b-instruct-q4-k-m",
        "gemma-4-e4b-it-qat-q4-0-gguf"
    ]

    static let kairoStarterModels: [LocalModelManifest] = [
        .appleFoundationModelsSystem,
        .gemma4E2BQATQ4_0,
        .qwen25HalfBInstruct,
        .qwen25OneAndHalfBInstruct,
        .qwen25VLThreeBInstruct,
        .gemma4E4BQATQ4_0
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

public enum LocalModelCatalogSigningKeyStatus: String, Codable, Equatable, Sendable {
    case active
    case revoked
}

public enum LocalModelCatalogSigningKeyPublicationStatus: String, Codable, Equatable, Sendable {
    case pendingPublication
    case published
}

public struct LocalModelTrustedSigningKey: Codable, Equatable, Identifiable, Sendable {
    public var id: String { keyID }
    public var keyID: String
    public var algorithm: String
    public var status: LocalModelCatalogSigningKeyStatus
    public var publicationStatus: LocalModelCatalogSigningKeyPublicationStatus
    public var publicKeyBase64: String
    public var validFrom: Date?
    public var validUntil: Date?
    public var revokedAt: Date?
    public var revokedReason: String?

    public init(
        keyID: String,
        algorithm: String,
        status: LocalModelCatalogSigningKeyStatus,
        publicationStatus: LocalModelCatalogSigningKeyPublicationStatus = .published,
        publicKeyBase64: String = "",
        validFrom: Date? = nil,
        validUntil: Date? = nil,
        revokedAt: Date? = nil,
        revokedReason: String? = nil
    ) {
        self.keyID = keyID
        self.algorithm = algorithm
        self.status = status
        self.publicationStatus = publicationStatus
        self.publicKeyBase64 = publicKeyBase64
        self.validFrom = validFrom
        self.validUntil = validUntil
        self.revokedAt = revokedAt
        self.revokedReason = revokedReason
    }

    private enum CodingKeys: String, CodingKey {
        case keyID
        case algorithm
        case status
        case publicationStatus
        case publicKeyBase64
        case validFrom
        case validUntil
        case revokedAt
        case revokedReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keyID = try container.decode(String.self, forKey: .keyID)
        self.algorithm = try container.decode(String.self, forKey: .algorithm)
        self.status = try container.decodeIfPresent(LocalModelCatalogSigningKeyStatus.self, forKey: .status) ?? .active
        self.publicationStatus = try container.decodeIfPresent(
            LocalModelCatalogSigningKeyPublicationStatus.self,
            forKey: .publicationStatus
        ) ?? .published
        self.publicKeyBase64 = try container.decodeIfPresent(String.self, forKey: .publicKeyBase64) ?? ""
        self.validFrom = try Self.decodeDateIfPresent(from: container, forKey: .validFrom)
        self.validUntil = try Self.decodeDateIfPresent(from: container, forKey: .validUntil)
        self.revokedAt = try Self.decodeDateIfPresent(from: container, forKey: .revokedAt)
        self.revokedReason = try container.decodeIfPresent(String.self, forKey: .revokedReason)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyID, forKey: .keyID)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(status, forKey: .status)
        try container.encode(publicationStatus, forKey: .publicationStatus)
        try container.encode(publicKeyBase64, forKey: .publicKeyBase64)
        try Self.encodeDateIfPresent(validFrom, to: &container, forKey: .validFrom)
        try Self.encodeDateIfPresent(validUntil, to: &container, forKey: .validUntil)
        try Self.encodeDateIfPresent(revokedAt, to: &container, forKey: .revokedAt)
        try container.encodeIfPresent(revokedReason, forKey: .revokedReason)
    }

    private static func decodeDateIfPresent(
        from container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws -> Date? {
        if let dateString = try? container.decodeIfPresent(String.self, forKey: key) {
            guard let date = ISO8601DateFormatter().date(from: dateString) else {
                throw DecodingError.dataCorruptedError(
                    forKey: key,
                    in: container,
                    debugDescription: "Expected ISO-8601 date string."
                )
            }
            return date
        }
        return try container.decodeIfPresent(Date.self, forKey: key)
    }

    private static func encodeDateIfPresent(
        _ date: Date?,
        to container: inout KeyedEncodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) throws {
        guard let date else { return }
        try container.encode(ISO8601DateFormatter().string(from: date), forKey: key)
    }
}

public struct LocalModelCatalogTrustStore: Codable, Equatable, Sendable {
    public var trustedKeys: [LocalModelTrustedSigningKey]

    public init(trustedKeys: [LocalModelTrustedSigningKey]) {
        self.trustedKeys = trustedKeys
    }

    public func trustedKey(id: String) -> LocalModelTrustedSigningKey? {
        trustedKeys.first { $0.keyID == id }
    }
}

public enum LocalModelCatalogServiceError: Error, Equatable, LocalizedError {
    case invalidJSON
    case missingSignature
    case unknownSigningKey(String)
    case revokedSigningKey(String)
    case signingKeyPendingPublication(String)
    case signingKeyNotYetValid(String)
    case signingKeyExpired(String)
    case unsupportedSignatureAlgorithm(String)
    case invalidSignature
    case nonProductionCatalogSignatureStatus(String)
    case invalidModelID(String)
    case missingCapabilities(modelID: String)
    case invalidSizeMetadata(modelID: String, fileSizeBytes: Int64, installedSizeBytes: Int64)
    case unsupportedRuntime(modelID: String, runtime: LocalModelRuntime)
    case duplicateModelID(String)
    case unsafeDownloadURL(modelID: String, url: String)
    case invalidChecksum(modelID: String, sha256: String)
    case unsupportedHuggingFaceInput(String)
    case unsupportedHuggingFaceLicense(String)
    case noDownloadableGGUF(repoID: String)

    public var errorDescription: String? {
        switch self {
        case .invalidJSON:
            return "Model catalog JSON is invalid."
        case .missingSignature:
            return "Model catalog is missing a production signature."
        case .unknownSigningKey(let keyID):
            return "Model catalog signing key is unknown: \(keyID)."
        case .revokedSigningKey(let keyID):
            return "Model catalog signing key has been revoked: \(keyID)."
        case .signingKeyPendingPublication(let keyID):
            return "Model catalog signing key is pending publication: \(keyID)."
        case .signingKeyNotYetValid(let keyID):
            return "Model catalog signing key is not active yet: \(keyID)."
        case .signingKeyExpired(let keyID):
            return "Model catalog signing key has expired: \(keyID)."
        case .unsupportedSignatureAlgorithm(let algorithm):
            return "Model catalog signature algorithm is unsupported: \(algorithm)."
        case .invalidSignature:
            return "Model catalog signature is invalid."
        case .nonProductionCatalogSignatureStatus(let status):
            return "Model catalog is marked \(status), not productionSigned."
        case .invalidModelID(let modelID):
            return "Model catalog contains an invalid model id: \(modelID)."
        case .missingCapabilities(let modelID):
            return "Model catalog must declare at least one capability for \(modelID)."
        case .invalidSizeMetadata(let modelID, let fileSizeBytes, let installedSizeBytes):
            return "Model catalog has invalid size metadata for \(modelID): file=\(fileSizeBytes), installed=\(installedSizeBytes)."
        case .unsupportedRuntime(let modelID, let runtime):
            return "Model catalog uses unsupported runtime for \(modelID): \(runtime.rawValue)."
        case .duplicateModelID(let modelID):
            return "Model catalog contains a duplicate model id: \(modelID)."
        case .unsafeDownloadURL(let modelID, let url):
            return "Model catalog has an unsafe download URL for \(modelID): \(url)."
        case .invalidChecksum(let modelID, let sha256):
            return "Model catalog has an invalid checksum for \(modelID): \(sha256)."
        case .unsupportedHuggingFaceInput(let input):
            return "Unsupported Hugging Face model input: \(input)."
        case .unsupportedHuggingFaceLicense(let license):
            return "Only Apache-2.0 Hugging Face models can be downloaded by Kairo. Found: \(license)."
        case .noDownloadableGGUF(let repoID):
            return "No downloadable GGUF file was found for \(repoID)."
        }
    }
}

public struct LocalModelCatalogService: Sendable {
    public static let defaultIndexURL = URL(string: "https://easonwumac.github.io/kairo-models/models.json")!
    public static let defaultStandaloneRepository = LocalModelCatalogService(indexURL: defaultIndexURL)
    public static let defaultTrustStore = LocalModelCatalogTrustStore(
        trustedKeys: [
            LocalModelTrustedSigningKey(
                keyID: "kairo-models-2025",
                algorithm: "p256-sha256",
                status: .revoked,
                publicationStatus: .pendingPublication,
                publicKeyBase64: "",
                revokedReason: "Superseded by the 2026 release signing key."
            ),
            LocalModelTrustedSigningKey(
                keyID: "kairo-models-2026",
                algorithm: "p256-sha256",
                status: .active,
                publicationStatus: .pendingPublication,
                publicKeyBase64: ""
            )
        ]
    )

    private let indexURL: URL
    private let httpClient: any HTTPClient
    private let trustStore: LocalModelCatalogTrustStore
    private let currentDate: @Sendable () -> Date

    public init(
        indexURL: URL = Self.defaultIndexURL,
        httpClient: any HTTPClient = URLSessionHTTPClient(),
        trustStore: LocalModelCatalogTrustStore = Self.defaultTrustStore,
        currentDate: @escaping @Sendable () -> Date = { Date() }
    ) {
        self.indexURL = indexURL
        self.httpClient = httpClient
        self.trustStore = trustStore
        self.currentDate = currentDate
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

    public func refreshCatalog(with builtInCatalog: LocalModelCatalog = .kairoDefault) async -> LocalModelCatalogRefreshResult {
        do {
            let mergedCatalog = try await fetchMergedCatalog(with: builtInCatalog)
            return LocalModelCatalogRefreshResult(catalog: mergedCatalog, source: .remote, error: nil)
        } catch {
            return LocalModelCatalogRefreshResult(catalog: builtInCatalog, source: .builtInFallback, error: error)
        }
    }

    public func resolveHuggingFaceModel(from input: String) async throws -> LocalModelManifest {
        let repoID = try Self.normalizedHuggingFaceRepoID(from: input)
        let modelInfoURL = URL(string: "https://huggingface.co/api/models/\(repoID)")!
        let treeURL = URL(string: "https://huggingface.co/api/models/\(repoID)/tree/main?recursive=1&expand=true")!

        let (infoData, infoResponse) = try await httpClient.data(for: URLRequest(url: modelInfoURL))
        guard (200..<300).contains(infoResponse.statusCode) else {
            let bodyPreview = String(data: infoData.prefix(300), encoding: .utf8) ?? ""
            throw HTTPClientError.unacceptableStatusCode(infoResponse.statusCode, bodyPreview)
        }
        let modelInfo = try JSONDecoder().decode(HuggingFaceModelInfo.self, from: infoData)
        guard modelInfo.license.lowercased() == "apache-2.0" else {
            throw LocalModelCatalogServiceError.unsupportedHuggingFaceLicense(modelInfo.license)
        }

        let (treeData, treeResponse) = try await httpClient.data(for: URLRequest(url: treeURL))
        guard (200..<300).contains(treeResponse.statusCode) else {
            let bodyPreview = String(data: treeData.prefix(300), encoding: .utf8) ?? ""
            throw HTTPClientError.unacceptableStatusCode(treeResponse.statusCode, bodyPreview)
        }
        let tree = try JSONDecoder().decode([HuggingFaceTreeItem].self, from: treeData)
        guard let primary = Self.preferredGGUFFile(in: tree) else {
            throw LocalModelCatalogServiceError.noDownloadableGGUF(repoID: repoID)
        }

        let companions = Self.companionArtifacts(in: tree, repoID: repoID, selectedPath: primary.path)
        let family = repoID.split(separator: "/").last.map(String.init) ?? repoID
        let isVisionModel = repoID.lowercased().contains("vl") || !companions.isEmpty
        let manifest = LocalModelManifest(
            id: Self.customModelID(repoID: repoID, filePath: primary.path),
            displayName: Self.displayName(repoID: repoID, filePath: primary.path),
            family: family,
            version: "custom",
            parameterCount: Self.parameterCount(from: repoID),
            quantization: Self.quantization(from: primary.path),
            runtime: .gguf,
            fileSizeBytes: primary.fileSizeBytes,
            installedSizeBytes: primary.fileSizeBytes + companions.reduce(Int64(0)) { $0 + $1.fileSizeBytes },
            contextWindow: 32_768,
            tokenizerID: Self.sanitizedCatalogID("\(repoID)-tokenizer"),
            licenseName: "Apache-2.0",
            licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
            minOSVersion: "17.0",
            minDeviceClass: isVisionModel ? "A17" : "A15",
            minRAMGB: isVisionModel ? 8 : 6,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: isVisionModel
                ? [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction, .imageUnderstanding]
                : [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: Self.resolveURL(repoID: repoID, path: primary.path),
            sha256: primary.sha256,
            companionArtifacts: companions,
            createdAt: currentDate(),
            updatedAt: currentDate(),
            safetyPolicyVersion: "2026.1"
        )
        try validateModelArtifacts(manifest)
        return manifest
    }

    public static func normalizedHuggingFaceRepoID(from input: String) throws -> String {
        var value = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.hasPrefix("https://huggingface.co/") {
            value.removeFirst("https://huggingface.co/".count)
        }
        value = value.split(separator: "?").first.map(String.init) ?? value
        let pieces = value.split(separator: "/").prefix(2).map(String.init)
        guard pieces.count == 2,
              pieces.allSatisfy({ !$0.isEmpty && $0.range(of: #"^[A-Za-z0-9][A-Za-z0-9._-]*$"#, options: .regularExpression) != nil }) else {
            throw LocalModelCatalogServiceError.unsupportedHuggingFaceInput(input)
        }
        return pieces.joined(separator: "/")
    }

    private func validate(_ catalog: LocalModelCatalog) throws {
        guard !catalog.signature.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LocalModelCatalogServiceError.missingSignature
        }
        guard catalog.catalogSignatureStatus == .productionSigned else {
            throw LocalModelCatalogServiceError.nonProductionCatalogSignatureStatus(
                catalog.catalogSignatureStatus.rawValue
            )
        }
        guard let trustedKey = trustStore.trustedKey(id: catalog.signingKeyID) else {
            throw LocalModelCatalogServiceError.unknownSigningKey(catalog.signingKeyID)
        }
        guard trustedKey.status == .active else {
            throw LocalModelCatalogServiceError.revokedSigningKey(catalog.signingKeyID)
        }
        guard trustedKey.publicationStatus == .published else {
            throw LocalModelCatalogServiceError.signingKeyPendingPublication(catalog.signingKeyID)
        }
        try validateTrustWindow(for: trustedKey)
        try validateSignature(for: catalog, trustedKey: trustedKey)
        try validateUniqueModelIDs(catalog.models)

        try catalog.models.forEach(validateModelArtifacts)
    }

    private static func isValidSHA256Hex(_ value: String) -> Bool {
        value.count == 64 && value.allSatisfy { character in
            character.isHexDigit
        }
    }

    private func validateUniqueModelIDs(_ models: [LocalModelManifest]) throws {
        var seenModelIDs = Set<String>()
        for model in models {
            guard !model.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw LocalModelCatalogServiceError.invalidModelID(model.id)
            }
            guard seenModelIDs.insert(model.id).inserted else {
                throw LocalModelCatalogServiceError.duplicateModelID(model.id)
            }
        }
    }

    private func validateModelArtifacts(_ model: LocalModelManifest) throws {
        guard !model.isSystemProvided else {
            return
        }
        guard model.downloadURL.scheme?.lowercased() == "https" else {
            throw LocalModelCatalogServiceError.unsafeDownloadURL(
                modelID: model.id,
                url: model.downloadURL.absoluteString
            )
        }
        guard !model.capabilities.isEmpty else {
            throw LocalModelCatalogServiceError.missingCapabilities(modelID: model.id)
        }
        guard model.fileSizeBytes > 0, model.installedSizeBytes >= model.fileSizeBytes else {
            throw LocalModelCatalogServiceError.invalidSizeMetadata(
                modelID: model.id,
                fileSizeBytes: model.fileSizeBytes,
                installedSizeBytes: model.installedSizeBytes
            )
        }
        guard model.runtime == .gguf else {
            throw LocalModelCatalogServiceError.unsupportedRuntime(
                modelID: model.id,
                runtime: model.runtime
            )
        }
        guard Self.isValidSHA256Hex(model.sha256) else {
            throw LocalModelCatalogServiceError.invalidChecksum(
                modelID: model.id,
                sha256: model.sha256
            )
        }
        for artifact in model.companionArtifacts {
            guard artifact.downloadURL.scheme?.lowercased() == "https" else {
                throw LocalModelCatalogServiceError.unsafeDownloadURL(
                    modelID: model.id,
                    url: artifact.downloadURL.absoluteString
                )
            }
            guard artifact.fileSizeBytes > 0 else {
                throw LocalModelCatalogServiceError.invalidSizeMetadata(
                    modelID: "\(model.id):\(artifact.id)",
                    fileSizeBytes: artifact.fileSizeBytes,
                    installedSizeBytes: artifact.fileSizeBytes
                )
            }
            guard Self.isValidSHA256Hex(artifact.sha256) else {
                throw LocalModelCatalogServiceError.invalidChecksum(
                    modelID: "\(model.id):\(artifact.id)",
                    sha256: artifact.sha256
                )
            }
        }
    }

    private static func preferredGGUFFile(in tree: [HuggingFaceTreeItem]) -> HuggingFaceTreeItem? {
        let ggufFiles = tree
            .filter { $0.path.lowercased().hasSuffix(".gguf") && !$0.path.lowercased().contains("mmproj") }
            .filter { $0.lfs != nil }
        return ggufFiles.sorted { lhs, rhs in
            scoreGGUFPath(lhs.path) > scoreGGUFPath(rhs.path)
        }.first
    }

    private static func companionArtifacts(
        in tree: [HuggingFaceTreeItem],
        repoID: String,
        selectedPath: String
    ) -> [LocalModelCompanionArtifact] {
        let selectedBase = selectedPath.lowercased()
            .replacingOccurrences(of: ".gguf", with: "")
            .replacingOccurrences(of: "-q4_k_m", with: "")
            .replacingOccurrences(of: "-q8_0", with: "")
        return tree
            .filter { $0.path.lowercased().hasSuffix(".gguf") && $0.path.lowercased().contains("mmproj") }
            .filter { item in
                guard item.lfs != nil else { return false }
                let lowerPath = item.path.lowercased()
                return lowerPath.contains("q8_0") || lowerPath.contains(selectedBase)
            }
            .prefix(1)
            .map { item in
                LocalModelCompanionArtifact(
                    id: sanitizedCatalogID(item.path.replacingOccurrences(of: ".gguf", with: "")),
                    role: "multimodalProjector",
                    displayName: item.path.split(separator: "/").last.map(String.init) ?? item.path,
                    fileSizeBytes: item.fileSizeBytes,
                    downloadURL: resolveURL(repoID: repoID, path: item.path),
                    sha256: item.sha256
                )
            }
    }

    private static func scoreGGUFPath(_ path: String) -> Int {
        let lower = path.lowercased()
        if lower.contains("q4_k_m") { return 100 }
        if lower.contains("q4_k_s") { return 90 }
        if lower.contains("q5_k_m") { return 80 }
        if lower.contains("q8_0") { return 70 }
        if lower.contains("f16") { return 10 }
        return 50
    }

    private static func customModelID(repoID: String, filePath: String) -> String {
        sanitizedCatalogID("\(repoID)-\(filePath.replacingOccurrences(of: ".gguf", with: ""))")
    }

    private static func displayName(repoID: String, filePath: String) -> String {
        let repoName = repoID.split(separator: "/").last.map(String.init) ?? repoID
        let fileName = filePath.split(separator: "/").last.map(String.init) ?? filePath
        return "\(repoName) · \(fileName.replacingOccurrences(of: ".gguf", with: ""))"
    }

    private static func parameterCount(from repoID: String) -> String {
        guard let range = repoID.range(of: #"(?i)(\d+(?:\.\d+)?\s*[BEM])"#, options: .regularExpression) else {
            return "Custom"
        }
        return repoID[range].replacingOccurrences(of: " ", with: "")
    }

    private static func quantization(from path: String) -> String {
        let upper = path.uppercased()
        for token in ["Q2_K", "Q3_K_L", "Q4_K_M", "Q4_K_S", "Q5_K_M", "Q5_K_S", "Q6_K", "Q8_0", "F16"] where upper.contains(token) {
            return token
        }
        return "GGUF"
    }

    private static func resolveURL(repoID: String, path: String) -> URL {
        URL(string: "https://huggingface.co/\(repoID)/resolve/main/\(path)")!
    }

    private static func sanitizedCatalogID(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_."))
        let scalars = value.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar).lowercased() : "-"
        }
        return String(scalars.joined()).trimmingCharacters(in: CharacterSet(charactersIn: "-."))
    }

    private func validateTrustWindow(for trustedKey: LocalModelTrustedSigningKey) throws {
        let now = currentDate()
        if let validFrom = trustedKey.validFrom, now < validFrom {
            throw LocalModelCatalogServiceError.signingKeyNotYetValid(trustedKey.keyID)
        }
        if let validUntil = trustedKey.validUntil, now > validUntil {
            throw LocalModelCatalogServiceError.signingKeyExpired(trustedKey.keyID)
        }
    }

    private func validateSignature(
        for catalog: LocalModelCatalog,
        trustedKey: LocalModelTrustedSigningKey
    ) throws {
        guard trustedKey.algorithm == "p256-sha256" else {
            throw LocalModelCatalogServiceError.unsupportedSignatureAlgorithm(trustedKey.algorithm)
        }
        guard
            let publicKeyData = Data(base64Encoded: trustedKey.publicKeyBase64),
            let signatureData = Data(base64Encoded: catalog.signature)
        else {
            throw LocalModelCatalogServiceError.invalidSignature
        }

        do {
            let publicKey = try P256.Signing.PublicKey(derRepresentation: publicKeyData)
            let signature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
            guard publicKey.isValidSignature(signature, for: try catalog.signingPayloadData()) else {
                throw LocalModelCatalogServiceError.invalidSignature
            }
        } catch let error as LocalModelCatalogServiceError {
            throw error
        } catch {
            throw LocalModelCatalogServiceError.invalidSignature
        }
    }
}

private struct HuggingFaceModelInfo: Decodable {
    struct CardData: Decodable {
        var license: String?
    }

    var cardData: CardData?

    var license: String {
        cardData?.license ?? "unknown"
    }
}

private struct HuggingFaceTreeItem: Decodable {
    struct LFS: Decodable {
        var oid: String
        var size: Int64
    }

    var path: String
    var size: Int64?
    var lfs: LFS?

    var fileSizeBytes: Int64 {
        lfs?.size ?? size ?? 0
    }

    var sha256: String {
        lfs?.oid ?? ""
    }
}

public struct LocalModelCatalogRefreshResult: Sendable {
    public enum Source: Equatable, Sendable {
        case remote
        case builtInFallback
    }

    public var catalog: LocalModelCatalog
    public var source: Source
    public var error: (any Error)?

    public init(catalog: LocalModelCatalog, source: Source, error: (any Error)?) {
        self.catalog = catalog
        self.source = source
        self.error = error
    }
}

public extension LocalModelManifest {
    static let appleFoundationModelsSystem = LocalModelManifest(
        id: "apple-foundation-models-system",
        displayName: "Apple Foundation Models",
        family: "Apple Foundation Models",
        version: "system",
        parameterCount: "System",
        quantization: "On-device",
        runtime: .appleFoundationModels,
        fileSizeBytes: 0,
        installedSizeBytes: 0,
        contextWindow: 8_192,
        tokenizerID: "foundation-models-system",
        licenseName: "Apple system framework",
        licenseURL: URL(string: "https://developer.apple.com/documentation/FoundationModels")!,
        minOSVersion: "26.0",
        minDeviceClass: "Apple Intelligence",
        minRAMGB: 8,
        supportedLocales: ["en", "zh-Hant"],
        capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction],
        disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
        downloadURL: URL(string: "https://developer.apple.com/documentation/FoundationModels")!,
        sha256: "system",
        benchmarkProfiles: [
            LocalModelBenchmarkProfile(
                id: "apple-foundation-models-system-ios26-reference",
                runtime: .appleFoundationModels,
                runtimePackage: "FoundationModels",
                artifactReference: "SystemLanguageModel.default",
                promptTokens: 0,
                generatedTokens: 0,
                trials: 0,
                promptTokensPerSecond: 0,
                generationTokensPerSecond: 0,
                testPlatform: "Apple Intelligence device",
                measuredAt: Date(timeIntervalSince1970: 1_780_358_400),
                sourceURL: URL(string: "https://developer.apple.com/documentation/FoundationModels"),
                supportsInAppDownload: false,
                isReferenceOnlyForIOS: false,
                notes: "System-provided Apple Foundation Models runtime. Availability depends on OS version, device support, region, and Apple Intelligence settings."
            )
        ],
        createdAt: Date(timeIntervalSince1970: 1_780_358_400),
        updatedAt: Date(timeIntervalSince1970: 1_780_358_400),
        safetyPolicyVersion: "2026.1"
    )

    static let gemma4E2BQATQ4_0 = LocalModelManifest(
        id: "gemma-4-e2b-it-qat-q4-0-gguf",
        displayName: "Gemma 4 E2B IT QAT Q4_0",
        family: "Gemma 4",
        version: "1.0",
        parameterCount: "E2B",
        quantization: "QAT Q4_0 + mmproj",
        runtime: .gguf,
        fileSizeBytes: 3_349_514_112,
        installedSizeBytes: 4_800 * 1024 * 1024,
        contextWindow: 131_072,
        tokenizerID: "gemma4-tokenizer",
        licenseName: "Apache-2.0",
        licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
        minOSVersion: "17.0",
        minDeviceClass: "A17",
        minRAMGB: 8,
        supportedLocales: ["en", "zh-Hant"],
        capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction, .imageUnderstanding],
        disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
        downloadURL: URL(string: "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/gemma-4-E2B_q4_0-it.gguf")!,
        sha256: "3646b4c147cd235a44d91df1546d3b7d8e29b547dbe4e1f80856419aa455e6fd",
        companionArtifacts: [
            LocalModelCompanionArtifact(
                id: "gemma4-e2b-mmproj",
                role: "multimodalProjector",
                displayName: "Gemma 4 E2B mmproj",
                fileSizeBytes: 986_833_312,
                downloadURL: URL(string: "https://huggingface.co/google/gemma-4-E2B-it-qat-q4_0-gguf/resolve/main/gemma-4-E2B-it-mmproj.gguf")!,
                sha256: "58c187648007cab392bd5678b87e862c3e8794017deb945feea2cf256195e96a"
            )
        ],
        createdAt: Date(timeIntervalSince1970: 1_780_358_400),
        updatedAt: Date(timeIntervalSince1970: 1_780_358_400),
        safetyPolicyVersion: "2026.1"
    )

    static let gemma4E4BQATQ4_0 = LocalModelManifest(
        id: "gemma-4-e4b-it-qat-q4-0-gguf",
        displayName: "Gemma 4 E4B IT QAT Q4_0",
        family: "Gemma 4",
        version: "1.0",
        parameterCount: "E4B",
        quantization: "QAT Q4_0 + mmproj",
        runtime: .gguf,
        fileSizeBytes: 5_154_939_136,
        installedSizeBytes: 6_900 * 1024 * 1024,
        contextWindow: 131_072,
        tokenizerID: "gemma4-tokenizer",
        licenseName: "Apache-2.0",
        licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
        minOSVersion: "17.0",
        minDeviceClass: "A17 Pro",
        minRAMGB: 10,
        supportedLocales: ["en", "zh-Hant"],
        capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction, .imageUnderstanding],
        disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
        downloadURL: URL(string: "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B_q4_0-it.gguf")!,
        sha256: "e8b6a059ba86947a44ace84d6e5679795bc41862c25c30513142588f0e9dba1d",
        companionArtifacts: [
            LocalModelCompanionArtifact(
                id: "gemma4-e4b-mmproj",
                role: "multimodalProjector",
                displayName: "Gemma 4 E4B mmproj",
                fileSizeBytes: 991_551_904,
                downloadURL: URL(string: "https://huggingface.co/google/gemma-4-E4B-it-qat-q4_0-gguf/resolve/main/gemma-4-E4B-it-mmproj.gguf")!,
                sha256: "c6398448d84a4836fdedf58f9775979e69ae0cc4dfdf4d697b5597693a555b12"
            )
        ],
        createdAt: Date(timeIntervalSince1970: 1_780_358_400),
        updatedAt: Date(timeIntervalSince1970: 1_780_358_400),
        safetyPolicyVersion: "2026.1"
    )

    static let qwen25HalfBInstruct = ggufManifest(
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

    static let qwen25OneAndHalfBInstruct = ggufManifest(
        id: "qwen2-5-1-5b-instruct-q4-k-m",
        displayName: "Qwen2.5 1.5B Instruct Q4_K_M",
        family: "Qwen2.5",
        parameterCount: "1.5B",
        fileSizeBytes: 1_117_320_736,
        installedSizeBytes: 1_700 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-tokenizer",
        minRAMGB: 6,
        downloadURL: "https://huggingface.co/Qwen/Qwen2.5-1.5B-Instruct-GGUF/resolve/main/qwen2.5-1.5b-instruct-q4_k_m.gguf",
        sha256: "6a1a2eb6d15622bf3c96857206351ba97e1af16c30d7a74ee38970e434e9407e"
    )

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

    static let qwen35TwoB = ggufManifest(
        id: "qwen3-5-2b-q4-k-m",
        displayName: "Qwen3.5 2B Q4_K_M",
        family: "Qwen3.5",
        parameterCount: "2B",
        fileSizeBytes: 1_270_808_512,
        installedSizeBytes: 1_900 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen3.5-tokenizer",
        minRAMGB: 6,
        downloadURL: "https://huggingface.co/AaryanK/Qwen3.5-2B-GGUF/resolve/main/Qwen3.5-2B.q4_k_m.gguf",
        sha256: "a511452ec932613d6b26b4fa24488fd431eb61eac69321460447d475edc221e2"
    )

    static let qwen25VLThreeBInstruct = LocalModelManifest(
        id: "qwen2-5-vl-3b-instruct-q4-k-m",
        displayName: "Qwen2.5-VL 3B Instruct Q4_K_M",
        family: "Qwen2.5-VL",
        version: "1.0",
        parameterCount: "3B",
        quantization: "Q4_K_M + mmproj Q8_0",
        runtime: .gguf,
        fileSizeBytes: 1_929_901_056,
        installedSizeBytes: 3_200 * 1024 * 1024,
        contextWindow: 32_768,
        tokenizerID: "qwen2.5-vl-tokenizer",
        licenseName: "Apache-2.0",
        licenseURL: URL(string: "https://www.apache.org/licenses/LICENSE-2.0")!,
        minOSVersion: "17.0",
        minDeviceClass: "A17",
        minRAMGB: 8,
        supportedLocales: ["en", "zh-Hant"],
        capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat, .rewriting, .extraction, .imageUnderstanding],
        disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
        downloadURL: URL(string: "https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/Qwen2.5-VL-3B-Instruct-Q4_K_M.gguf")!,
        sha256: "d02fe9b69ad8cadbbd228e387667af66612c44bed29ffc8eb1e7caf9ac486c12",
        companionArtifacts: [
            LocalModelCompanionArtifact(
                id: "mmproj-q8-0",
                role: "multimodalProjector",
                displayName: "Qwen2.5-VL 3B mmproj Q8_0",
                fileSizeBytes: 844_757_728,
                downloadURL: URL(string: "https://huggingface.co/ggml-org/Qwen2.5-VL-3B-Instruct-GGUF/resolve/main/mmproj-Qwen2.5-VL-3B-Instruct-Q8_0.gguf")!,
                sha256: "980c9b2f78c04e6cff93d277ada09e768394f112d75db3b4e9dea8a69f9fb904"
            )
        ],
        createdAt: Date(timeIntervalSince1970: 1_767_225_600),
        updatedAt: Date(timeIntervalSince1970: 1_767_225_600),
        safetyPolicyVersion: "2026.1"
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
