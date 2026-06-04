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
    case revokedSigningKey(String)
    case signingKeyPendingPublication(String)
    case signingKeyNotYetValid(String)
    case signingKeyExpired(String)
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

public enum AgentSkillMarketplaceCatalogError: Error, Equatable, Sendable, LocalizedError {
    case invalidSkillID(String)
    case invalidPermission(skillID: String, permission: String)
    case invalidManifestURL(skillID: String, manifestURL: String)
    case duplicateSkillID(String)
    case manifestSkillMismatch(expectedSkillID: String, actualSkillID: String)
    case confirmationRequiredDisabled(skillID: String)
    case nonProductionCatalogSignatureStatus(String)
    case invalidJSON

    public var errorDescription: String? {
        switch self {
        case .invalidSkillID(let skillID):
            return "Marketplace catalog contains an invalid skill id: \(skillID)."
        case .invalidPermission(let skillID, let permission):
            return "Marketplace skill \(skillID) uses an unknown permission: \(permission)."
        case .invalidManifestURL(let skillID, let manifestURL):
            return "Marketplace skill \(skillID) has an invalid manifest URL: \(manifestURL)."
        case .duplicateSkillID(let skillID):
            return "Marketplace catalog contains a duplicate skill id: \(skillID)."
        case .manifestSkillMismatch(let expectedSkillID, let actualSkillID):
            return "Marketplace manifest skill id mismatch: expected \(expectedSkillID), got \(actualSkillID)."
        case .confirmationRequiredDisabled(let skillID):
            return "Marketplace skill \(skillID) disables required confirmation."
        case .nonProductionCatalogSignatureStatus(let status):
            return "Marketplace catalog is marked \(status), not productionSigned."
        case .invalidJSON:
            return "Marketplace catalog JSON is invalid."
        }
    }
}

public enum AgentSkillMarketplaceCatalogSignatureStatus: String, Codable, Equatable, Sendable {
    case productionSigned
    case referenceUnsigned
}

public struct AgentSkillRemoteMarketplaceCatalog: Codable, Equatable, Sendable {
    public var marketplaceVersion: String
    public var sourceRepository: URL
    public var generatedAt: Date?
    public var catalogSignatureStatus: AgentSkillMarketplaceCatalogSignatureStatus
    public var catalog: AgentSkillCatalog

    public init(
        marketplaceVersion: String,
        sourceRepository: URL,
        generatedAt: Date?,
        catalogSignatureStatus: AgentSkillMarketplaceCatalogSignatureStatus,
        catalog: AgentSkillCatalog
    ) {
        self.marketplaceVersion = marketplaceVersion
        self.sourceRepository = sourceRepository
        self.generatedAt = generatedAt
        self.catalogSignatureStatus = catalogSignatureStatus
        self.catalog = catalog
    }
}

private struct AgentSkillMarketplaceIndex: Decodable, Sendable {
    public var marketplaceVersion: String
    public var sourceRepository: URL
    public var generatedAt: Date?
    public var catalogSignatureStatus: AgentSkillMarketplaceCatalogSignatureStatus
    public var skills: [AgentSkillMarketplaceIndexEntry]

    private enum CodingKeys: String, CodingKey {
        case marketplaceVersion
        case sourceRepository
        case generatedAt
        case catalogSignatureStatus
        case skills
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.marketplaceVersion = try container.decode(String.self, forKey: .marketplaceVersion)
        self.sourceRepository = try container.decode(URL.self, forKey: .sourceRepository)
        self.generatedAt = try container.decodeIfPresent(Date.self, forKey: .generatedAt)
        self.catalogSignatureStatus = try container.decodeIfPresent(
            AgentSkillMarketplaceCatalogSignatureStatus.self,
            forKey: .catalogSignatureStatus
        ) ?? .productionSigned
        self.skills = try container.decode([AgentSkillMarketplaceIndexEntry].self, forKey: .skills)
    }
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
        guard index.catalogSignatureStatus == .productionSigned else {
            throw AgentSkillMarketplaceCatalogError.nonProductionCatalogSignatureStatus(
                index.catalogSignatureStatus.rawValue
            )
        }

        let skills = try index.skills.map(skill(from:))
        try validateUniqueSkillIDs(skills)

        return AgentSkillRemoteMarketplaceCatalog(
            marketplaceVersion: index.marketplaceVersion,
            sourceRepository: index.sourceRepository,
            generatedAt: index.generatedAt,
            catalogSignatureStatus: index.catalogSignatureStatus,
            catalog: AgentSkillCatalog(skills: skills)
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
            let manifest = try JSONDecoder().decode(AgentSkillManifest.self, from: data)
            guard manifest.skill.id == skill.id else {
                throw AgentSkillMarketplaceCatalogError.manifestSkillMismatch(
                    expectedSkillID: skill.id,
                    actualSkillID: manifest.skill.id
                )
            }
            return manifest
        } catch let error as AgentSkillMarketplaceCatalogError {
            throw error
        } catch {
            throw AgentSkillManifestImportError.invalidJSON
        }
    }

    private func skill(from entry: AgentSkillMarketplaceIndexEntry) throws -> AgentSkill {
        guard !entry.id.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AgentSkillMarketplaceCatalogError.invalidSkillID(entry.id)
        }
        guard entry.requiresConfirmation else {
            throw AgentSkillMarketplaceCatalogError.confirmationRequiredDisabled(skillID: entry.id)
        }

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
        guard manifestURL.scheme?.lowercased() == "https" else {
            throw AgentSkillMarketplaceCatalogError.invalidManifestURL(
                skillID: entry.id,
                manifestURL: manifestURL.absoluteString
            )
        }
        guard isTrustedManifestURL(manifestURL) else {
            throw AgentSkillMarketplaceCatalogError.invalidManifestURL(
                skillID: entry.id,
                manifestURL: manifestURL.absoluteString
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

    private func validateUniqueSkillIDs(_ skills: [AgentSkill]) throws {
        var seenSkillIDs = Set<String>()
        for skill in skills {
            guard seenSkillIDs.insert(skill.id).inserted else {
                throw AgentSkillMarketplaceCatalogError.duplicateSkillID(skill.id)
            }
        }
    }

    private func isTrustedManifestURL(_ manifestURL: URL) -> Bool {
        guard
            manifestURL.scheme?.lowercased() == indexURL.scheme?.lowercased(),
            manifestURL.host?.lowercased() == indexURL.host?.lowercased()
        else {
            return false
        }

        let indexDirectoryPath = indexURL.deletingLastPathComponent().standardized.path
        return manifestURL.standardized.path.hasPrefix(indexDirectoryPath + "/")
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

public enum AgentSkillTrustedPublicKeyStatus: String, Codable, Equatable, Sendable {
    case active
    case revoked
}

public enum AgentSkillTrustedPublicKeyPublicationStatus: String, Codable, Equatable, Sendable {
    case pendingPublication
    case published
}

public struct AgentSkillTrustedPublicKey: Codable, Equatable, Identifiable, Sendable {
    public var id: String { keyID }
    public var keyID: String
    public var algorithm: AgentSkillManifestSignatureAlgorithm
    public var publicKeyBase64: String
    public var status: AgentSkillTrustedPublicKeyStatus
    public var publicationStatus: AgentSkillTrustedPublicKeyPublicationStatus
    public var validFrom: Date?
    public var expiresAt: Date?
    public var revokedAt: Date?
    public var revokedReason: String?

    public init(
        keyID: String,
        algorithm: AgentSkillManifestSignatureAlgorithm,
        publicKeyBase64: String,
        status: AgentSkillTrustedPublicKeyStatus = .active,
        publicationStatus: AgentSkillTrustedPublicKeyPublicationStatus = .published,
        validFrom: Date? = nil,
        expiresAt: Date? = nil,
        revokedAt: Date? = nil,
        revokedReason: String? = nil
    ) {
        self.keyID = keyID
        self.algorithm = algorithm
        self.publicKeyBase64 = publicKeyBase64
        self.status = status
        self.publicationStatus = publicationStatus
        self.validFrom = validFrom
        self.expiresAt = expiresAt
        self.revokedAt = revokedAt
        self.revokedReason = revokedReason
    }

    private enum CodingKeys: String, CodingKey {
        case keyID
        case algorithm
        case publicKeyBase64
        case status
        case publicationStatus
        case validFrom
        case expiresAt
        case revokedAt
        case revokedReason
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.keyID = try container.decode(String.self, forKey: .keyID)
        self.algorithm = try container.decode(AgentSkillManifestSignatureAlgorithm.self, forKey: .algorithm)
        self.publicKeyBase64 = try container.decode(String.self, forKey: .publicKeyBase64)
        self.status = try container.decodeIfPresent(AgentSkillTrustedPublicKeyStatus.self, forKey: .status) ?? .active
        self.publicationStatus = try container.decodeIfPresent(
            AgentSkillTrustedPublicKeyPublicationStatus.self,
            forKey: .publicationStatus
        ) ?? .published
        self.validFrom = try Self.decodeDateIfPresent(from: container, forKey: .validFrom)
        self.expiresAt = try Self.decodeDateIfPresent(from: container, forKey: .expiresAt)
        self.revokedAt = try Self.decodeDateIfPresent(from: container, forKey: .revokedAt)
        self.revokedReason = try container.decodeIfPresent(String.self, forKey: .revokedReason)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(keyID, forKey: .keyID)
        try container.encode(algorithm, forKey: .algorithm)
        try container.encode(publicKeyBase64, forKey: .publicKeyBase64)
        try container.encode(status, forKey: .status)
        try container.encode(publicationStatus, forKey: .publicationStatus)
        try Self.encodeDateIfPresent(validFrom, to: &container, forKey: .validFrom)
        try Self.encodeDateIfPresent(expiresAt, to: &container, forKey: .expiresAt)
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

public struct AgentSkillManifestTrustStore: Codable, Equatable, Sendable {
    public var trustedKeys: [AgentSkillTrustedPublicKey]

    public static let defaultRelease = AgentSkillManifestTrustStore(trustedKeys: [
        AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2025",
            algorithm: .p256SHA256,
            publicKeyBase64: "",
            status: .revoked,
            publicationStatus: .pendingPublication,
            revokedReason: "Superseded by the 2026 marketplace signing key."
        ),
        AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: "",
            status: .active,
            publicationStatus: .pendingPublication
        )
    ])

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

    public func validateForInstall(
        trustStore: AgentSkillManifestTrustStore,
        currentDate: Date = Date()
    ) throws {
        try validateForInstall()

        guard let signature else {
            throw AgentSkillManifestValidationError.missingSignature
        }
        guard let trustedKey = trustStore.trustedKey(id: signature.keyID) else {
            throw AgentSkillManifestValidationError.unknownSigningKey(signature.keyID)
        }
        guard trustedKey.status == .active else {
            throw AgentSkillManifestValidationError.revokedSigningKey(signature.keyID)
        }
        guard trustedKey.publicationStatus == .published else {
            throw AgentSkillManifestValidationError.signingKeyPendingPublication(signature.keyID)
        }
        if let validFrom = trustedKey.validFrom, currentDate < validFrom {
            throw AgentSkillManifestValidationError.signingKeyNotYetValid(signature.keyID)
        }
        if let expiresAt = trustedKey.expiresAt, currentDate >= expiresAt {
            throw AgentSkillManifestValidationError.signingKeyExpired(signature.keyID)
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
