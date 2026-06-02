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
