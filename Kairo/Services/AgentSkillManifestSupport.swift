import Foundation
import CryptoKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum AgentSkillManifestSignatureAlgorithm: String, Codable, Equatable, Sendable {
    case ed25519
    case p256SHA256
}

public enum AgentSkillManifestChecksumAlgorithm: String, Codable, Equatable, Sendable {
    case sha256
}

public struct AgentSkillManifestSignature: Codable, Equatable, Sendable {
    public var keyID: String
    public var algorithm: AgentSkillManifestSignatureAlgorithm
    public var value: String

    public init(
        keyID: String,
        algorithm: AgentSkillManifestSignatureAlgorithm,
        value: String
    ) {
        self.keyID = keyID
        self.algorithm = algorithm
        self.value = value
    }

    public var isPresent: Bool {
        !keyID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

public enum AgentSkillManifestValidationError: Error, Equatable, Sendable {
    case missingSignature
    case checksumMismatch
    case unavailableSkill
    case unknownSigningKey(String)
    case unsupportedSignatureAlgorithm(AgentSkillManifestSignatureAlgorithm)
    case invalidSignature
}

public enum AgentSkillManifestImportError: Error, Equatable, Sendable {
    case invalidJSON
}

public enum AgentSkillInstallError: Error, Equatable, Sendable {
    case versionDowngrade(skillID: String, installedVersion: String, incomingVersion: String)
    case compatibilityBlocked(skillID: String, issues: [AgentSkillCompatibilityIssue])
}

public enum AgentSkillMarketplaceCatalogError: Error, Equatable, Sendable {
    case invalidPermission(skillID: String, permission: String)
    case invalidManifestURL(skillID: String, manifestURL: String)
    case invalidJSON
}

public struct AgentSkillRemoteMarketplaceCatalog: Codable, Equatable, Sendable {
    public var marketplaceVersion: String
    public var sourceRepository: URL
    public var generatedAt: Date?
    public var catalog: AgentSkillCatalog

    public init(
        marketplaceVersion: String,
        sourceRepository: URL,
        generatedAt: Date?,
        catalog: AgentSkillCatalog
    ) {
        self.marketplaceVersion = marketplaceVersion
        self.sourceRepository = sourceRepository
        self.generatedAt = generatedAt
        self.catalog = catalog
    }
}

private struct AgentSkillMarketplaceIndex: Decodable, Sendable {
    public var marketplaceVersion: String
    public var sourceRepository: URL
    public var generatedAt: Date?
    public var skills: [AgentSkillMarketplaceIndexEntry]
}

private struct AgentSkillMarketplaceIndexEntry: Decodable, Sendable {
    public var id: String
    public var displayName: String
    public var summary: String
    public var version: String
    public var author: String
    public var category: String?
    public var kind: AgentSkillKind
    public var permissions: [String]
    public var riskTier: String
    public var requiresConfirmation: Bool
    public var installSurface: String
    public var manifestURL: String
    public var screenshots: [String]
    public var changelog: [String]
    public var compatibilityRequirements: AgentSkillCompatibilityRequirements?
}

public struct AgentSkillMarketplaceCatalogService: Sendable {
    public static let defaultIndexURL = URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!
    public static let defaultStandaloneRepository = AgentSkillMarketplaceCatalogService(indexURL: defaultIndexURL)

    private let indexURL: URL
    private let httpClient: any HTTPClient

    public init(
        indexURL: URL = Self.defaultIndexURL,
        httpClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.indexURL = indexURL
        self.httpClient = httpClient
    }

    public func fetchCatalog() async throws -> AgentSkillRemoteMarketplaceCatalog {
        let request = URLRequest(url: indexURL)
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let index: AgentSkillMarketplaceIndex
        do {
            index = try decoder.decode(AgentSkillMarketplaceIndex.self, from: data)
        } catch {
            throw AgentSkillMarketplaceCatalogError.invalidJSON
        }

        return AgentSkillRemoteMarketplaceCatalog(
            marketplaceVersion: index.marketplaceVersion,
            sourceRepository: index.sourceRepository,
            generatedAt: index.generatedAt,
            catalog: AgentSkillCatalog(skills: try index.skills.map(skill(from:)))
        )
    }

    public func fetchManifest(for skill: AgentSkill) async throws -> AgentSkillManifest {
        guard let downloadURL = skill.downloadURL else {
            throw AgentSkillMarketplaceCatalogError.invalidManifestURL(
                skillID: skill.id,
                manifestURL: ""
            )
        }

        let request = URLRequest(url: downloadURL)
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            let bodyPreview = String(data: data.prefix(300), encoding: .utf8) ?? ""
            throw HTTPClientError.unacceptableStatusCode(response.statusCode, bodyPreview)
        }

        do {
            return try JSONDecoder().decode(AgentSkillManifest.self, from: data)
        } catch {
            throw AgentSkillManifestImportError.invalidJSON
        }
    }

    private func skill(from entry: AgentSkillMarketplaceIndexEntry) throws -> AgentSkill {
        let requiredCapabilities = try entry.permissions.map { permission in
            guard let capability = CapabilityKey(rawValue: permission) else {
                throw AgentSkillMarketplaceCatalogError.invalidPermission(
                    skillID: entry.id,
                    permission: permission
                )
            }
            return capability
        }

        guard let manifestURL = URL(string: entry.manifestURL, relativeTo: indexURL)?.absoluteURL else {
            throw AgentSkillMarketplaceCatalogError.invalidManifestURL(
                skillID: entry.id,
                manifestURL: entry.manifestURL
            )
        }

        return AgentSkill(
            id: entry.id,
            displayName: entry.displayName,
            summary: entry.summary,
            kind: entry.kind,
            source: .marketplace,
            installationStatus: .available,
            requiredCapabilities: requiredCapabilities,
            downloadURL: manifestURL,
            version: entry.version,
            author: entry.author,
            compatibilityRequirements: entry.compatibilityRequirements ?? .empty
        )
    }
}

public enum AgentSkillInstallationChange: String, Codable, Equatable, Sendable {
    case install
    case reinstall
    case update
    case downgradeBlocked
}

public struct AgentSkillInstallPreview: Codable, Equatable, Sendable {
    public var manifest: AgentSkillManifest
    public var skillID: String
    public var displayName: String
    public var installedVersion: String?
    public var incomingVersion: String
    public var packageVersion: String
    public var changelog: [String]
    public var installationChange: AgentSkillInstallationChange
    public var compatibilityReport: AgentSkillCompatibilityReport

    public init(
        manifest: AgentSkillManifest,
        installedSkill: AgentSkill?,
        compatibilityReport: AgentSkillCompatibilityReport? = nil
    ) {
        self.manifest = manifest
        self.skillID = manifest.skill.id
        self.displayName = manifest.skill.displayName
        self.installedVersion = installedSkill?.version
        self.incomingVersion = manifest.skill.version
        self.packageVersion = manifest.packageVersion
        self.changelog = manifest.changelog
        self.compatibilityReport = compatibilityReport ?? AgentSkillCompatibilityEvaluator().evaluate(manifest.skill)

        if let installedSkill {
            switch AgentSkillVersionComparator.compare(manifest.skill.version, installedSkill.version) {
            case .orderedAscending:
                self.installationChange = .downgradeBlocked
            case .orderedSame:
                self.installationChange = .reinstall
            case .orderedDescending:
                self.installationChange = .update
            }
        } else {
            self.installationChange = .install
        }
    }

    public var summary: String {
        if !compatibilityReport.isInstallable {
            return "Blocked \(displayName): \(compatibilityReport.summary)"
        }

        switch installationChange {
        case .install:
            return "Install \(displayName) \(incomingVersion)."
        case .reinstall:
            return "Reinstall \(displayName) \(incomingVersion)."
        case .update:
            return "Update \(displayName) from \(installedVersion ?? "unknown") to \(incomingVersion)."
        case .downgradeBlocked:
            return "Blocked downgrade for \(displayName) from \(installedVersion ?? "unknown") to \(incomingVersion)."
        }
    }
}

public struct AgentSkillTrustedPublicKey: Codable, Equatable, Identifiable, Sendable {
    public var id: String { keyID }
    public var keyID: String
    public var algorithm: AgentSkillManifestSignatureAlgorithm
    public var publicKeyBase64: String

    public init(
        keyID: String,
        algorithm: AgentSkillManifestSignatureAlgorithm,
        publicKeyBase64: String
    ) {
        self.keyID = keyID
        self.algorithm = algorithm
        self.publicKeyBase64 = publicKeyBase64
    }
}

public struct AgentSkillManifestTrustStore: Codable, Equatable, Sendable {
    public var trustedKeys: [AgentSkillTrustedPublicKey]

    public init(trustedKeys: [AgentSkillTrustedPublicKey]) {
        self.trustedKeys = trustedKeys
    }

    public func trustedKey(id: String) -> AgentSkillTrustedPublicKey? {
        trustedKeys.first { $0.keyID == id }
    }
}

private struct AgentSkillManifestSigningPayload: Codable, Equatable, Sendable {
    public var skill: AgentSkill
    public var packageVersion: String
    public var checksumAlgorithm: AgentSkillManifestChecksumAlgorithm
    public var checksum: String
    public var changelog: [String]
}

public struct AgentSkillManifest: Codable, Equatable, Sendable {
    public var skill: AgentSkill
    public var packageVersion: String
    public var checksumAlgorithm: AgentSkillManifestChecksumAlgorithm
    public var checksum: String
    public var signature: AgentSkillManifestSignature?
    public var changelog: [String]

    private enum CodingKeys: String, CodingKey {
        case skill
        case packageVersion
        case checksumAlgorithm
        case checksum
        case signature
        case changelog
    }

    public init(
        skill: AgentSkill,
        packageVersion: String,
        checksumAlgorithm: AgentSkillManifestChecksumAlgorithm = .sha256,
        checksum: String,
        signature: AgentSkillManifestSignature?,
        changelog: [String] = []
    ) {
        self.skill = skill
        self.packageVersion = packageVersion
        self.checksumAlgorithm = checksumAlgorithm
        self.checksum = checksum
        self.signature = signature
        self.changelog = changelog
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.skill = try container.decode(AgentSkill.self, forKey: .skill)
        self.packageVersion = try container.decode(String.self, forKey: .packageVersion)
        self.checksumAlgorithm = try container.decode(AgentSkillManifestChecksumAlgorithm.self, forKey: .checksumAlgorithm)
        self.checksum = try container.decode(String.self, forKey: .checksum)
        self.signature = try container.decodeIfPresent(AgentSkillManifestSignature.self, forKey: .signature)
        self.changelog = try container.decodeIfPresent([String].self, forKey: .changelog) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(skill, forKey: .skill)
        try container.encode(packageVersion, forKey: .packageVersion)
        try container.encode(checksumAlgorithm, forKey: .checksumAlgorithm)
        try container.encode(checksum, forKey: .checksum)
        try container.encodeIfPresent(signature, forKey: .signature)
        try container.encode(changelog, forKey: .changelog)
    }

    public var installableSkill: AgentSkill {
        var updated = skill
        updated.source = .marketplace
        updated.installationStatus = .installed
        return updated
    }

    public func validateForInstall() throws {
        guard signature?.isPresent == true else {
            throw AgentSkillManifestValidationError.missingSignature
        }
        guard skill.canDownload else {
            throw AgentSkillManifestValidationError.unavailableSkill
        }
        let expectedChecksum = try Self.sha256Hex(for: skill)
        guard checksumAlgorithm == .sha256, checksum == expectedChecksum else {
            throw AgentSkillManifestValidationError.checksumMismatch
        }
    }

    public func validateForInstall(trustStore: AgentSkillManifestTrustStore) throws {
        try validateForInstall()

        guard let signature else {
            throw AgentSkillManifestValidationError.missingSignature
        }
        guard let trustedKey = trustStore.trustedKey(id: signature.keyID) else {
            throw AgentSkillManifestValidationError.unknownSigningKey(signature.keyID)
        }
        guard trustedKey.algorithm == signature.algorithm else {
            throw AgentSkillManifestValidationError.unsupportedSignatureAlgorithm(signature.algorithm)
        }

        switch signature.algorithm {
        case .p256SHA256:
            try validateP256Signature(signature, trustedKey: trustedKey)
        case .ed25519:
            throw AgentSkillManifestValidationError.unsupportedSignatureAlgorithm(signature.algorithm)
        }
    }

    public func signingPayloadData() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(AgentSkillManifestSigningPayload(
            skill: skill,
            packageVersion: packageVersion,
            checksumAlgorithm: checksumAlgorithm,
            checksum: checksum,
            changelog: changelog
        ))
    }

    public static func sha256Hex(for skill: AgentSkill) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(skill)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    public static func encodeJSONString(_ manifest: AgentSkillManifest) throws -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(manifest)
        return String(decoding: data, as: UTF8.self)
    }

    public static func decodeJSONString(_ jsonString: String) throws -> AgentSkillManifest {
        guard let data = jsonString.data(using: .utf8) else {
            throw AgentSkillManifestImportError.invalidJSON
        }

        do {
            return try JSONDecoder().decode(AgentSkillManifest.self, from: data)
        } catch {
            throw AgentSkillManifestImportError.invalidJSON
        }
    }

    public static func signedForTesting(skill: AgentSkill, packageVersion: String) throws -> AgentSkillManifest {
        AgentSkillManifest(
            skill: skill,
            packageVersion: packageVersion,
            checksum: try sha256Hex(for: skill),
            signature: AgentSkillManifestSignature(
                keyID: "kairo-test-key",
                algorithm: .ed25519,
                value: "test-signature"
            )
        )
    }

    public static func signedForTesting(
        skill: AgentSkill,
        packageVersion: String,
        keyID: String,
        signingKey: P256.Signing.PrivateKey,
        changelog: [String] = []
    ) throws -> AgentSkillManifest {
        var manifest = AgentSkillManifest(
            skill: skill,
            packageVersion: packageVersion,
            checksum: try sha256Hex(for: skill),
            signature: nil,
            changelog: changelog
        )
        let signature = try signingKey.signature(for: manifest.signingPayloadData())
        manifest.signature = AgentSkillManifestSignature(
            keyID: keyID,
            algorithm: .p256SHA256,
            value: signature.derRepresentation.base64EncodedString()
        )
        return manifest
    }

    private func validateP256Signature(
        _ signature: AgentSkillManifestSignature,
        trustedKey: AgentSkillTrustedPublicKey
    ) throws {
        guard
            let publicKeyData = Data(base64Encoded: trustedKey.publicKeyBase64),
            let signatureData = Data(base64Encoded: signature.value)
        else {
            throw AgentSkillManifestValidationError.invalidSignature
        }

        do {
            let publicKey = try P256.Signing.PublicKey(derRepresentation: publicKeyData)
            let ecdsaSignature = try P256.Signing.ECDSASignature(derRepresentation: signatureData)
            guard publicKey.isValidSignature(ecdsaSignature, for: try signingPayloadData()) else {
                throw AgentSkillManifestValidationError.invalidSignature
            }
        } catch let error as AgentSkillManifestValidationError {
            throw error
        } catch {
            throw AgentSkillManifestValidationError.invalidSignature
        }
    }
}
enum AgentSkillVersionComparator {
    static func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let leftComponents = components(lhs)
        let rightComponents = components(rhs)
        let count = max(leftComponents.count, rightComponents.count)

        for index in 0..<count {
            let leftValue = index < leftComponents.count ? leftComponents[index] : 0
            let rightValue = index < rightComponents.count ? rightComponents[index] : 0

            if leftValue < rightValue {
                return .orderedAscending
            }
            if leftValue > rightValue {
                return .orderedDescending
            }
        }

        return .orderedSame
    }

    private static func components(_ version: String) -> [Int] {
        let parts = version.split { character in
            character == "." || character == "-" || character == "_"
        }
        let values = parts.map { part -> Int in
            let numericPrefix = part.prefix { character in
                character.isNumber
            }
            return Int(numericPrefix) ?? 0
        }
        return values.isEmpty ? [0] : values
    }
}
