import Foundation
import CryptoKit

public enum AgentSkillKind: String, Codable, Equatable, Sendable {
    case homeKitControl
    case shortcutWorkflow
    case oauthConnector
    case localModel
    case custom
}

public enum AgentSkillSource: String, Codable, Equatable, Sendable {
    case builtIn
    case marketplace
    case userCreated
}

public enum AgentSkillInstallationStatus: String, Codable, Equatable, Sendable {
    case installed
    case available
    case disabled
}

public struct AgentSkill: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var displayName: String
    public var summary: String
    public var kind: AgentSkillKind
    public var source: AgentSkillSource
    public var installationStatus: AgentSkillInstallationStatus
    public var requiredCapabilities: [CapabilityKey]
    public var action: AgentAction?
    public var shortcutRecipeID: String?
    public var downloadURL: URL?
    public var version: String
    public var author: String

    public init(
        id: String,
        displayName: String,
        summary: String,
        kind: AgentSkillKind,
        source: AgentSkillSource,
        installationStatus: AgentSkillInstallationStatus,
        requiredCapabilities: [CapabilityKey],
        action: AgentAction? = nil,
        shortcutRecipeID: String? = nil,
        downloadURL: URL? = nil,
        version: String = "1.0",
        author: String = "Kairo"
    ) {
        self.id = id
        self.displayName = displayName
        self.summary = summary
        self.kind = kind
        self.source = source
        self.installationStatus = installationStatus
        self.requiredCapabilities = requiredCapabilities
        self.action = action
        self.shortcutRecipeID = shortcutRecipeID
        self.downloadURL = downloadURL
        self.version = version
        self.author = author
    }

    public var canDownload: Bool {
        source == .marketplace && installationStatus == .available && downloadURL != nil
    }

    public var managementSummary: String {
        let capabilityList = requiredCapabilities.map(\.rawValue).joined(separator: ", ")
        let confirmation = action?.requiresConfirmation == true ? "Requires confirmation" : "No external write"
        return "\(installationStatus.settingsTitle) · \(kind.settingsTitle) · \(confirmation) · capabilities: \(capabilityList)"
    }

    public static func marketplaceTemplate(
        id: String,
        displayName: String,
        summary: String,
        requiredCapabilities: [CapabilityKey],
        downloadURL: URL,
        kind: AgentSkillKind = .custom
    ) -> AgentSkill {
        AgentSkill(
            id: id,
            displayName: displayName,
            summary: summary,
            kind: kind,
            source: .marketplace,
            installationStatus: .available,
            requiredCapabilities: requiredCapabilities,
            downloadURL: downloadURL
        )
    }
}

public struct AgentSkillCatalog: Codable, Equatable, Sendable {
    public var skills: [AgentSkill]

    public init(skills: [AgentSkill]) {
        self.skills = skills
    }

    public func skill(id: String) -> AgentSkill? {
        skills.first { $0.id == id }
    }

    public var installedSkills: [AgentSkill] {
        skills.filter { $0.installationStatus == .installed }
    }

    public var availableSkills: [AgentSkill] {
        skills.filter { $0.installationStatus == .available }
    }

    public var disabledSkills: [AgentSkill] {
        skills.filter { $0.installationStatus == .disabled }
    }

    public func replacing(_ skill: AgentSkill) -> AgentSkillCatalog {
        var updatedSkills = skills.filter { $0.id != skill.id }
        updatedSkills.append(skill)
        return AgentSkillCatalog(skills: updatedSkills)
    }

    public func updatingStatus(id: String, to status: AgentSkillInstallationStatus) -> AgentSkillCatalog {
        AgentSkillCatalog(skills: skills.map { skill in
            guard skill.id == id else { return skill }
            var updated = skill
            updated.installationStatus = status
            return updated
        })
    }

    public func removingSkill(id: String) -> AgentSkillCatalog {
        AgentSkillCatalog(skills: skills.filter { $0.id != id })
    }

    public static let demoMarketplaceSkills: [AgentSkill] = [
        AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Downloadable skill package that summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
    ]

    public static let defaultWithMarketplaceSamples = AgentSkillCatalog(
        skills: AgentSkillCatalog.default.skills + AgentSkillCatalog.demoMarketplaceSkills
    )

    public static let `default` = AgentSkillCatalog(skills: [
        AgentSkill(
            id: "homekit-evening-scene",
            displayName: "Evening HomeKit Scene",
            summary: "Run the Evening Wind Down HomeKit scene after visible confirmation.",
            kind: .homeKitControl,
            source: .builtIn,
            installationStatus: .installed,
            requiredCapabilities: [.homeKit],
            action: HomeKitControlDemoCatalog.default.recipe(id: "evening-scene")?.action
        ),
        AgentSkill(
            id: "homekit-desk-lamp",
            displayName: "Desk Lamp HomeKit Control",
            summary: "Turn on the office desk lamp after visible confirmation.",
            kind: .homeKitControl,
            source: .builtIn,
            installationStatus: .installed,
            requiredCapabilities: [.homeKit],
            action: HomeKitControlDemoCatalog.default.recipe(id: "desk-lamp")?.action
        ),
        AgentSkill(
            id: "shortcut-daily-briefing",
            displayName: "Shortcut Daily Briefing",
            summary: "Use the Daily Briefing Shortcut recipe as an installed skill.",
            kind: .shortcutWorkflow,
            source: .builtIn,
            installationStatus: .installed,
            requiredCapabilities: [.appIntents],
            shortcutRecipeID: "daily-briefing"
        )
    ])
}

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
}

public struct AgentSkillManifest: Codable, Equatable, Sendable {
    public var skill: AgentSkill
    public var packageVersion: String
    public var checksumAlgorithm: AgentSkillManifestChecksumAlgorithm
    public var checksum: String
    public var signature: AgentSkillManifestSignature?

    public init(
        skill: AgentSkill,
        packageVersion: String,
        checksumAlgorithm: AgentSkillManifestChecksumAlgorithm = .sha256,
        checksum: String,
        signature: AgentSkillManifestSignature?
    ) {
        self.skill = skill
        self.packageVersion = packageVersion
        self.checksumAlgorithm = checksumAlgorithm
        self.checksum = checksum
        self.signature = signature
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
            checksum: checksum
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
        signingKey: P256.Signing.PrivateKey
    ) throws -> AgentSkillManifest {
        var manifest = AgentSkillManifest(
            skill: skill,
            packageVersion: packageVersion,
            checksum: try sha256Hex(for: skill),
            signature: nil
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

public actor FileBackedAgentSkillStore {
    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private var skills: [AgentSkill] = []

    public init(fileURL: URL) async throws {
        self.fileURL = fileURL
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try await loadFromDisk()
    }

    public func listSkills() -> [AgentSkill] {
        skills
    }

    public func upsert(_ skill: AgentSkill) throws {
        skills.removeAll { $0.id == skill.id }
        skills.append(skill)
        try persist()
    }

    public func removeSkill(id: String) throws {
        skills.removeAll { $0.id == id }
        try persist()
    }

    private func loadFromDisk() async throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            skills = []
            return
        }

        let data = try Data(contentsOf: fileURL)
        guard !data.isEmpty else {
            skills = []
            return
        }

        skills = try decoder.decode([AgentSkill].self, from: data)
    }

    private func persist() throws {
        let directory = fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let data = try encoder.encode(skills.sorted { $0.id < $1.id })
        let temporaryURL = fileURL.appendingPathExtension("tmp")
        try data.write(to: temporaryURL, options: [.atomic])

        if FileManager.default.fileExists(atPath: fileURL.path) {
            _ = try FileManager.default.replaceItemAt(fileURL, withItemAt: temporaryURL)
        } else {
            try FileManager.default.moveItem(at: temporaryURL, to: fileURL)
        }
    }
}

public struct AgentSkillManagerService: Sendable {
    private let store: FileBackedAgentSkillStore
    private let builtInCatalog: AgentSkillCatalog
    private let trustStore: AgentSkillManifestTrustStore?

    public init(
        store: FileBackedAgentSkillStore,
        builtInCatalog: AgentSkillCatalog = .default,
        trustStore: AgentSkillManifestTrustStore? = nil
    ) {
        self.store = store
        self.builtInCatalog = builtInCatalog
        self.trustStore = trustStore
    }

    public func catalog() async throws -> AgentSkillCatalog {
        let persistedSkills = await store.listSkills()
        let combinedSkills = merge(base: builtInCatalog.skills, overrides: persistedSkills)
        return AgentSkillCatalog(skills: combinedSkills)
    }

    @discardableResult
    public func install(manifest: AgentSkillManifest) async throws -> AgentSkill {
        if let trustStore {
            try manifest.validateForInstall(trustStore: trustStore)
        } else {
            try manifest.validateForInstall()
        }
        let skill = manifest.installableSkill
        try await store.upsert(skill)
        return skill
    }

    @discardableResult
    public func installManifest(jsonString: String) async throws -> AgentSkill {
        let manifest = try AgentSkillManifest.decodeJSONString(jsonString)
        return try await install(manifest: manifest)
    }

    @discardableResult
    public func disableSkill(id: String) async throws -> AgentSkill? {
        try await updateStatus(id: id, to: .disabled)
    }

    @discardableResult
    public func enableSkill(id: String) async throws -> AgentSkill? {
        try await updateStatus(id: id, to: .installed)
    }

    public func removeSkill(id: String) async throws {
        try await store.removeSkill(id: id)
    }

    private func updateStatus(id: String, to status: AgentSkillInstallationStatus) async throws -> AgentSkill? {
        guard var skill = try await catalog().skill(id: id) else {
            return nil
        }
        skill.installationStatus = status
        try await store.upsert(skill)
        return skill
    }

    private func merge(base: [AgentSkill], overrides: [AgentSkill]) -> [AgentSkill] {
        var mergedByID = Dictionary(uniqueKeysWithValues: base.map { ($0.id, $0) })
        for skill in overrides {
            mergedByID[skill.id] = skill
        }

        let baseIDs = base.map(\.id)
        let baseSkills = baseIDs.compactMap { mergedByID.removeValue(forKey: $0) }
        let extraSkills = mergedByID.values.sorted { $0.id < $1.id }
        return baseSkills + extraSkills
    }
}

public extension AgentSkillKind {
    var settingsTitle: String {
        switch self {
        case .homeKitControl:
            return "HomeKit Control"
        case .shortcutWorkflow:
            return "Shortcut Workflow"
        case .oauthConnector:
            return "OAuth Connector"
        case .localModel:
            return "Local Model"
        case .custom:
            return "Custom Skill"
        }
    }
}

public extension AgentSkillInstallationStatus {
    var settingsTitle: String {
        switch self {
        case .installed:
            return "Installed"
        case .available:
            return "Available"
        case .disabled:
            return "Disabled"
        }
    }
}
