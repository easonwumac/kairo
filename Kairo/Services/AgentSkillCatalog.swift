import Foundation

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

public struct AgentSkillCompatibilityRequirements: Codable, Equatable, Sendable {
    public var minimumIOSVersion: String?
    public var requiredEntitlements: [String]
    public var requiredOAuthProviderKeys: [String]
    public var requiredLocalModelIDs: [String]

    private enum CodingKeys: String, CodingKey {
        case minimumIOSVersion
        case requiredEntitlements
        case requiredOAuthProviderKeys
        case requiredLocalModelIDs
    }

    public init(
        minimumIOSVersion: String? = nil,
        requiredEntitlements: [String] = [],
        requiredOAuthProviderKeys: [String] = [],
        requiredLocalModelIDs: [String] = []
    ) {
        self.minimumIOSVersion = minimumIOSVersion
        self.requiredEntitlements = requiredEntitlements
        self.requiredOAuthProviderKeys = requiredOAuthProviderKeys
        self.requiredLocalModelIDs = requiredLocalModelIDs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.minimumIOSVersion = try container.decodeIfPresent(String.self, forKey: .minimumIOSVersion)
        self.requiredEntitlements = try container.decodeIfPresent([String].self, forKey: .requiredEntitlements) ?? []
        self.requiredOAuthProviderKeys = try container.decodeIfPresent([String].self, forKey: .requiredOAuthProviderKeys) ?? []
        self.requiredLocalModelIDs = try container.decodeIfPresent([String].self, forKey: .requiredLocalModelIDs) ?? []
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(minimumIOSVersion, forKey: .minimumIOSVersion)
        if !requiredEntitlements.isEmpty {
            try container.encode(requiredEntitlements, forKey: .requiredEntitlements)
        }
        if !requiredOAuthProviderKeys.isEmpty {
            try container.encode(requiredOAuthProviderKeys, forKey: .requiredOAuthProviderKeys)
        }
        if !requiredLocalModelIDs.isEmpty {
            try container.encode(requiredLocalModelIDs, forKey: .requiredLocalModelIDs)
        }
    }

    public static let empty = AgentSkillCompatibilityRequirements()

    public var isEmpty: Bool {
        minimumIOSVersion == nil
        && requiredEntitlements.isEmpty
        && requiredOAuthProviderKeys.isEmpty
        && requiredLocalModelIDs.isEmpty
    }
}

public struct AgentSkillRuntimeContext: Codable, Equatable, Sendable {
    public var iosVersion: String
    public var grantedEntitlements: [String]
    public var connectedOAuthProviderKeys: [String]
    public var installedLocalModelIDs: [String]

    public init(
        iosVersion: String,
        grantedEntitlements: [String] = [],
        connectedOAuthProviderKeys: [String] = [],
        installedLocalModelIDs: [String] = []
    ) {
        self.iosVersion = iosVersion
        self.grantedEntitlements = grantedEntitlements
        self.connectedOAuthProviderKeys = connectedOAuthProviderKeys
        self.installedLocalModelIDs = installedLocalModelIDs
    }

    public static let permissive = AgentSkillRuntimeContext(
        iosVersion: "999.0",
        grantedEntitlements: ["*"],
        connectedOAuthProviderKeys: ["*"],
        installedLocalModelIDs: ["*"]
    )

    public static func current(
        grantedEntitlements: [String] = [],
        connectedOAuthProviderKeys: [String] = [],
        installedLocalModelIDs: [String] = []
    ) -> AgentSkillRuntimeContext {
        let version = ProcessInfo.processInfo.operatingSystemVersion
        return AgentSkillRuntimeContext(
            iosVersion: "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)",
            grantedEntitlements: grantedEntitlements,
            connectedOAuthProviderKeys: connectedOAuthProviderKeys,
            installedLocalModelIDs: installedLocalModelIDs
        )
    }
}

public enum AgentSkillCompatibilityIssueKind: String, Codable, Equatable, Sendable {
    case minimumIOSVersion
    case missingEntitlement
    case missingOAuthProvider
    case missingLocalModel
}

public enum AgentSkillCompatibilitySeverity: String, Codable, Equatable, Sendable {
    case blocking
    case warning
}

public struct AgentSkillCompatibilityIssue: Codable, Equatable, Identifiable, Sendable {
    public var id: String { "\(kind.rawValue):\(requirement)" }
    public var kind: AgentSkillCompatibilityIssueKind
    public var requirement: String
    public var severity: AgentSkillCompatibilitySeverity
    public var message: String

    public init(
        kind: AgentSkillCompatibilityIssueKind,
        requirement: String,
        severity: AgentSkillCompatibilitySeverity = .blocking,
        message: String
    ) {
        self.kind = kind
        self.requirement = requirement
        self.severity = severity
        self.message = message
    }
}

public struct AgentSkillCompatibilityReport: Codable, Equatable, Sendable {
    public var skillID: String
    public var issues: [AgentSkillCompatibilityIssue]

    public init(skillID: String, issues: [AgentSkillCompatibilityIssue]) {
        self.skillID = skillID
        self.issues = issues
    }

    public var blockingIssues: [AgentSkillCompatibilityIssue] {
        issues.filter { $0.severity == .blocking }
    }

    public var warningIssues: [AgentSkillCompatibilityIssue] {
        issues.filter { $0.severity == .warning }
    }

    public var isInstallable: Bool {
        blockingIssues.isEmpty
    }

    public var summary: String {
        if issues.isEmpty {
            return "Compatible with current Kairo runtime."
        }

        return issues.map(\.message).joined(separator: "; ")
    }
}

public struct AgentSkillCompatibilityEvaluator: Sendable {
    public var context: AgentSkillRuntimeContext

    public init(context: AgentSkillRuntimeContext = .permissive) {
        self.context = context
    }

    public func evaluate(_ skill: AgentSkill) -> AgentSkillCompatibilityReport {
        let requirements = skill.compatibilityRequirements
        var issues: [AgentSkillCompatibilityIssue] = []

        if let minimumIOSVersion = requirements.minimumIOSVersion,
           AgentSkillVersionComparator.compare(context.iosVersion, minimumIOSVersion) == .orderedAscending {
            issues.append(AgentSkillCompatibilityIssue(
                kind: .minimumIOSVersion,
                requirement: minimumIOSVersion,
                message: "Requires iOS \(minimumIOSVersion) or later"
            ))
        }

        for entitlement in requirements.requiredEntitlements where !contains(entitlement, in: context.grantedEntitlements) {
            issues.append(AgentSkillCompatibilityIssue(
                kind: .missingEntitlement,
                requirement: entitlement,
                message: "Missing entitlement \(entitlement)"
            ))
        }

        for providerKey in requirements.requiredOAuthProviderKeys where !contains(providerKey, in: context.connectedOAuthProviderKeys) {
            issues.append(AgentSkillCompatibilityIssue(
                kind: .missingOAuthProvider,
                requirement: providerKey,
                message: "Connect OAuth provider \(providerKey)"
            ))
        }

        for modelID in requirements.requiredLocalModelIDs where !contains(modelID, in: context.installedLocalModelIDs) {
            issues.append(AgentSkillCompatibilityIssue(
                kind: .missingLocalModel,
                requirement: modelID,
                message: "Download local model \(modelID)"
            ))
        }

        return AgentSkillCompatibilityReport(skillID: skill.id, issues: issues)
    }

    private func contains(_ requirement: String, in grantedValues: [String]) -> Bool {
        grantedValues.contains("*") || grantedValues.contains(requirement)
    }
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
    public var compatibilityRequirements: AgentSkillCompatibilityRequirements

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
        author: String = "Kairo",
        compatibilityRequirements: AgentSkillCompatibilityRequirements = .empty
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
        self.compatibilityRequirements = compatibilityRequirements
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case displayName
        case summary
        case kind
        case source
        case installationStatus
        case requiredCapabilities
        case action
        case shortcutRecipeID
        case downloadURL
        case version
        case author
        case compatibilityRequirements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try container.decode(String.self, forKey: .id)
        self.displayName = try container.decode(String.self, forKey: .displayName)
        self.summary = try container.decode(String.self, forKey: .summary)
        self.kind = try container.decode(AgentSkillKind.self, forKey: .kind)
        self.source = try container.decode(AgentSkillSource.self, forKey: .source)
        self.installationStatus = try container.decode(AgentSkillInstallationStatus.self, forKey: .installationStatus)
        self.requiredCapabilities = try container.decode([CapabilityKey].self, forKey: .requiredCapabilities)
        self.action = try container.decodeIfPresent(AgentAction.self, forKey: .action)
        self.shortcutRecipeID = try container.decodeIfPresent(String.self, forKey: .shortcutRecipeID)
        self.downloadURL = try container.decodeIfPresent(URL.self, forKey: .downloadURL)
        self.version = try container.decode(String.self, forKey: .version)
        self.author = try container.decode(String.self, forKey: .author)
        self.compatibilityRequirements = try container.decodeIfPresent(
            AgentSkillCompatibilityRequirements.self,
            forKey: .compatibilityRequirements
        ) ?? .empty
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(displayName, forKey: .displayName)
        try container.encode(summary, forKey: .summary)
        try container.encode(kind, forKey: .kind)
        try container.encode(source, forKey: .source)
        try container.encode(installationStatus, forKey: .installationStatus)
        try container.encode(requiredCapabilities, forKey: .requiredCapabilities)
        try container.encodeIfPresent(action, forKey: .action)
        try container.encodeIfPresent(shortcutRecipeID, forKey: .shortcutRecipeID)
        try container.encodeIfPresent(downloadURL, forKey: .downloadURL)
        try container.encode(version, forKey: .version)
        try container.encode(author, forKey: .author)
        if !compatibilityRequirements.isEmpty {
            try container.encode(compatibilityRequirements, forKey: .compatibilityRequirements)
        }
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

    public static func shortcutDemoSkill(for recipe: ShortcutDemoRecipe) -> AgentSkill {
        AgentSkill(
            id: "shortcut-\(recipe.id)",
            displayName: "Shortcut \(recipe.title)",
            summary: "Use the \(recipe.title) Shortcut recipe as an installed skill.",
            kind: .shortcutWorkflow,
            source: .builtIn,
            installationStatus: .installed,
            requiredCapabilities: [.appIntents],
            shortcutRecipeID: recipe.id
        )
    }
}

public struct AgentSkillDraftRequest: Codable, Equatable, Sendable {
    public var displayName: String
    public var summary: String
    public var kind: AgentSkillKind
    public var requiredCapabilities: [CapabilityKey]
    public var shortcutRecipeID: String?
    public var compatibilityRequirements: AgentSkillCompatibilityRequirements

    public init(
        displayName: String,
        summary: String,
        kind: AgentSkillKind = .custom,
        requiredCapabilities: [CapabilityKey] = [.appIntents],
        shortcutRecipeID: String? = nil,
        compatibilityRequirements: AgentSkillCompatibilityRequirements = .empty
    ) {
        self.displayName = displayName
        self.summary = summary
        self.kind = kind
        self.requiredCapabilities = requiredCapabilities
        self.shortcutRecipeID = shortcutRecipeID
        self.compatibilityRequirements = compatibilityRequirements
    }
}

public enum AgentSkillDraftError: Error, Equatable, Sendable {
    case emptyDisplayName
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

    public func mergingMarketplaceCatalog(_ marketplaceCatalog: AgentSkillCatalog) -> AgentSkillCatalog {
        var mergedByID = Dictionary(uniqueKeysWithValues: skills.map { ($0.id, $0) })
        var orderedIDs = skills.map(\.id)

        for remoteSkill in marketplaceCatalog.skills where remoteSkill.source == .marketplace {
            if let existingSkill = mergedByID[remoteSkill.id],
               existingSkill.installationStatus != .available {
                continue
            }

            if mergedByID[remoteSkill.id] == nil {
                orderedIDs.append(remoteSkill.id)
            }
            mergedByID[remoteSkill.id] = remoteSkill
        }

        let orderedSkills = orderedIDs.compactMap { mergedByID.removeValue(forKey: $0) }
        let remainingSkills = mergedByID.values.sorted { $0.id < $1.id }
        return AgentSkillCatalog(skills: orderedSkills + remainingSkills)
    }

    public static let demoMarketplaceSkills: [AgentSkill] = [
        AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Downloadable skill package that summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json")!
        )
    ]

    public static let defaultWithMarketplaceSamples = AgentSkillCatalog(
        skills: AgentSkillCatalog.default.skills + AgentSkillCatalog.demoMarketplaceSkills
    )

    public static let builtInHomeKitSkills: [AgentSkill] = [
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
            id: "homekit-front-door-lock",
            displayName: "Front Door Lock Guard",
            summary: "Preview a HomeKit security-device write; locks always require in-app confirmation.",
            kind: .homeKitControl,
            source: .builtIn,
            installationStatus: .installed,
            requiredCapabilities: [.homeKit],
            action: HomeKitControlDemoCatalog.default.recipe(id: "front-door-lock")?.action
        )
    ]

    public static let builtInShortcutSkills: [AgentSkill] = ShortcutDemoCatalog.default.recipes.map {
        AgentSkill.shortcutDemoSkill(for: $0)
    }

    public static let `default` = AgentSkillCatalog(
        skills: builtInHomeKitSkills + builtInShortcutSkills
    )
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
    private let compatibilityEvaluator: AgentSkillCompatibilityEvaluator

    public init(
        store: FileBackedAgentSkillStore,
        builtInCatalog: AgentSkillCatalog = .default,
        trustStore: AgentSkillManifestTrustStore? = nil,
        runtimeContext: AgentSkillRuntimeContext = .permissive
    ) {
        self.store = store
        self.builtInCatalog = builtInCatalog
        self.trustStore = trustStore
        self.compatibilityEvaluator = AgentSkillCompatibilityEvaluator(context: runtimeContext)
    }

    public func catalog() async throws -> AgentSkillCatalog {
        let persistedSkills = await store.listSkills()
        let combinedSkills = merge(base: builtInCatalog.skills, overrides: persistedSkills)
        return AgentSkillCatalog(skills: combinedSkills)
    }

    public func effectiveCatalog() async throws -> AgentSkillCatalog {
        let currentCatalog = try await catalog()
        return AgentSkillCatalog(skills: currentCatalog.skills.filter { skill in
            guard skill.installationStatus == .installed else { return true }
            return compatibilityEvaluator.evaluate(skill).isInstallable
        })
    }

    @discardableResult
    public func install(manifest: AgentSkillManifest) async throws -> AgentSkill {
        try validateManifestForInstall(manifest)
        let skill = manifest.installableSkill
        try validateCompatibility(for: skill)
        try await validateVersionTransition(for: skill)
        try await store.upsert(skill)
        return skill
    }

    public func previewInstall(manifest: AgentSkillManifest) async throws -> AgentSkillInstallPreview {
        try validateManifestForInstall(manifest)
        let existingSkill = try await catalog().skill(id: manifest.skill.id)
        let installedSkill = existingSkill?.installationStatus == .available ? nil : existingSkill
        return AgentSkillInstallPreview(
            manifest: manifest,
            installedSkill: installedSkill,
            compatibilityReport: compatibilityEvaluator.evaluate(manifest.skill)
        )
    }

    public func previewInstall(jsonString: String) async throws -> AgentSkillInstallPreview {
        let manifest = try AgentSkillManifest.decodeJSONString(jsonString)
        return try await previewInstall(manifest: manifest)
    }

    @discardableResult
    public func createUserSkillDraft(_ request: AgentSkillDraftRequest) async throws -> AgentSkill {
        let trimmedName = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw AgentSkillDraftError.emptyDisplayName
        }

        let trimmedSummary = request.summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let currentCatalog = try await catalog()
        let skillID = uniqueUserSkillID(base: trimmedName, existingIDs: Set(currentCatalog.skills.map(\.id)))
        let skill = AgentSkill(
            id: skillID,
            displayName: trimmedName,
            summary: trimmedSummary.isEmpty ? "User-created local Kairo skill draft." : trimmedSummary,
            kind: request.kind,
            source: .userCreated,
            installationStatus: .disabled,
            requiredCapabilities: request.requiredCapabilities,
            shortcutRecipeID: request.shortcutRecipeID,
            version: "local-draft",
            author: "User",
            compatibilityRequirements: request.compatibilityRequirements
        )
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

    private func validateManifestForInstall(_ manifest: AgentSkillManifest) throws {
        if let trustStore {
            try manifest.validateForInstall(trustStore: trustStore)
        } else {
            try manifest.validateForInstall()
        }
    }

    private func updateStatus(id: String, to status: AgentSkillInstallationStatus) async throws -> AgentSkill? {
        guard var skill = try await catalog().skill(id: id) else {
            return nil
        }
        skill.installationStatus = status
        try await store.upsert(skill)
        return skill
    }

    private func validateCompatibility(for incomingSkill: AgentSkill) throws {
        let report = compatibilityEvaluator.evaluate(incomingSkill)
        guard report.isInstallable else {
            throw AgentSkillInstallError.compatibilityBlocked(
                skillID: incomingSkill.id,
                issues: report.blockingIssues
            )
        }
    }

    private func uniqueUserSkillID(base: String, existingIDs: Set<String>) -> String {
        let slug = Self.slug(base)
        let baseID = "user-\(slug.isEmpty ? "skill" : slug)"
        guard existingIDs.contains(baseID) else {
            return baseID
        }

        var suffix = 2
        while existingIDs.contains("\(baseID)-\(suffix)") {
            suffix += 1
        }
        return "\(baseID)-\(suffix)"
    }

    private static func slug(_ value: String) -> String {
        let folded = value
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: Locale(identifier: "en_US_POSIX"))
            .lowercased()
        let scalars = folded.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar) {
                return Character(scalar)
            }
            return "-"
        }
        let collapsed = String(scalars)
            .split(separator: "-", omittingEmptySubsequences: true)
            .joined(separator: "-")
        return String(collapsed.prefix(64)).trimmingCharacters(in: CharacterSet(charactersIn: "-"))
    }

    private func validateVersionTransition(for incomingSkill: AgentSkill) async throws {
        guard let existingSkill = try await catalog().skill(id: incomingSkill.id) else {
            return
        }

        if AgentSkillVersionComparator.compare(incomingSkill.version, existingSkill.version) == .orderedAscending {
            throw AgentSkillInstallError.versionDowngrade(
                skillID: incomingSkill.id,
                installedVersion: existingSkill.version,
                incomingVersion: incomingSkill.version
            )
        }
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
