import Foundation

public protocol AppIntegrationSkillCatalogProviding: Sendable {
    var skills: [AppIntegrationSkill] { get }
}

public protocol AppIntegrationSkillReferencing {
    var integrationSkillID: AppIntegrationSkillID? { get }
}

public enum AppIntegrationSkillResolution: Equatable, Sendable {
    case notReferenced
    case missing(AppIntegrationSkillID)
    case resolved(AppIntegrationSkill)

    public var skillID: AppIntegrationSkillID? {
        switch self {
        case .notReferenced:
            return nil
        case .missing(let skillID):
            return skillID
        case .resolved(let skill):
            return skill.id
        }
    }

    public var blockedExecutionFields: [String: String] {
        switch self {
        case .notReferenced:
            return [:]
        case .missing:
            return [
                "integrationAvailability": AppIntegrationSkillAvailabilityStatus.unsupported.rawValue,
                "integrationSetupRequirement": AppIntegrationSkillSetupRequirement.unsupported.rawValue,
                "integrationExecutionMode": AppIntegrationExecutionMode.previewOnly.rawValue
            ]
        case .resolved(let skill):
            return skill.blockedExecutionFields
        }
    }
}

public extension AppIntegrationSkillCatalogProviding {
    func skill(id: AppIntegrationSkillID) -> AppIntegrationSkill? {
        skills.first { $0.id == id }
    }

    func skill(for reference: any AppIntegrationSkillReferencing) -> AppIntegrationSkill? {
        guard let integrationSkillID = reference.integrationSkillID else { return nil }
        return skill(id: integrationSkillID)
    }

    func resolveSkill(id: AppIntegrationSkillID) -> AppIntegrationSkillResolution {
        guard let skill = skill(id: id) else {
            return .missing(id)
        }
        return .resolved(skill)
    }

    func resolveSkill(for reference: any AppIntegrationSkillReferencing) -> AppIntegrationSkillResolution {
        guard let integrationSkillID = reference.integrationSkillID else {
            return .notReferenced
        }
        return resolveSkill(id: integrationSkillID)
    }

    var executableSkills: [AppIntegrationSkill] {
        skills.filter(\.canBeSuggestedAsExecutable)
    }

    var oauthProviderKeys: [String] {
        Array(Set(skills.compactMap(\.oauth?.providerKey))).sorted()
    }
}

public enum AppIntegrationSkillID: String, Codable, CaseIterable, Sendable, Identifiable {
    case appleMailHandoff = "apple.mail.handoff"
    case appleMessagesHandoff = "apple.messages.handoff"
    case applePhoneHandoff = "apple.phone.handoff"
    case safariWebSearchHandoff = "safari.webSearch.handoff"
    case appleMapsDirectionsHandoff = "apple.maps.directions.handoff"
    case googleMapsDirectionsHandoff = "google.maps.directions.handoff"
    case gmailDraftAPI = "gmail.draft.api"
    case whatsappMessageHandoff = "whatsapp.message.handoff"
    case lineShareHandoff = "line.share.handoff"
    case slackOpenHandoff = "slack.open.handoff"
    case notionPageAPI = "notion.page.api"
    case todoistTaskAPI = "todoist.task.api"
    case draftsCreateHandoff = "drafts.create.handoff"

    public var id: String { rawValue }
}

public extension AppIntegrationSkillID {
    var shortcutNodeKind: ShortcutNodeKind? {
        switch self {
        case .appleMailHandoff:
            return .createEmailDraft
        case .appleMessagesHandoff:
            return .prepareMessageHandoff
        case .applePhoneHandoff:
            return .preparePhoneCallHandoff
        case .safariWebSearchHandoff:
            return .prepareWebSearchHandoff
        case .appleMapsDirectionsHandoff,
             .googleMapsDirectionsHandoff,
             .gmailDraftAPI,
             .whatsappMessageHandoff,
             .lineShareHandoff,
             .slackOpenHandoff,
             .notionPageAPI,
             .todoistTaskAPI,
             .draftsCreateHandoff:
            return nil
        }
    }
}

public enum AppIntegrationSkillCategory: String, Codable, CaseIterable, Sendable {
    case communication
    case productivity
    case browserSearchKnowledge
    case mapsLocation
    case filesMedia
}

public enum AppIntegrationSkillSurface: String, Codable, CaseIterable, Sendable {
    case appShortcut
    case userShortcut
    case urlScheme
    case universalLink
    case shareExtensionInput
    case oauthAPI
    case webAPI
}

public enum AppIntegrationSkillSetupRequirement: String, Codable, CaseIterable, Sendable {
    case none
    case installApp
    case createUserShortcut
    case connectOAuth
    case unsupported
}

public enum AppIntegrationInstalledAppRequirement: String, Codable, CaseIterable, Sendable {
    case none
    case optional
    case required
}

public enum AppIntegrationSkillAvailabilityStatus: String, Codable, CaseIterable, Sendable {
    case available
    case requiresInstalledApp
    case requiresUserShortcut
    case requiresOAuth
    case previewOnly
    case unsupported
    case disabled

    public var allowsExecutableSuggestion: Bool {
        switch self {
        case .available:
            return true
        case .requiresInstalledApp, .requiresUserShortcut, .requiresOAuth, .previewOnly, .unsupported, .disabled:
            return false
        }
    }
}

public enum AppIntegrationExecutionMode: String, Codable, CaseIterable, Sendable {
    case previewOnly
    case openURL
    case runUserShortcut
    case apiCall
    case draftOnly
}

public struct AppIntegrationSkillSchema: Codable, Equatable, Sendable {
    public var input: String
    public var output: String

    public init(input: String, output: String) {
        self.input = input
        self.output = output
    }
}

public struct AppIntegrationSkillEndpoint: Codable, Equatable, Sendable {
    public var scheme: String?
    public var universalLinkHost: String?
    public var apiBaseURL: URL?
    public var exampleURLTemplate: String?

    public init(
        scheme: String? = nil,
        universalLinkHost: String? = nil,
        apiBaseURL: URL? = nil,
        exampleURLTemplate: String? = nil
    ) {
        self.scheme = scheme
        self.universalLinkHost = universalLinkHost
        self.apiBaseURL = apiBaseURL
        self.exampleURLTemplate = exampleURLTemplate
    }
}

public struct AppIntegrationOAuthRequirement: Codable, Equatable, Sendable {
    public var providerKey: String
    public var authorizationEndpoint: URL
    public var tokenEndpoint: URL?
    public var requiredScopes: [String]
    public var tokenStoragePolicy: String
    public var disconnectPolicy: String

    public init(
        providerKey: String,
        authorizationEndpoint: URL,
        tokenEndpoint: URL? = nil,
        requiredScopes: [String],
        tokenStoragePolicy: String = "keychainOnly",
        disconnectPolicy: String = "deleteTokenAndDerivedAccountMetadata"
    ) {
        self.providerKey = providerKey
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.requiredScopes = requiredScopes
        self.tokenStoragePolicy = tokenStoragePolicy
        self.disconnectPolicy = disconnectPolicy
    }
}

public struct AppIntegrationAuditMetadata: Codable, Equatable, Sendable {
    public var capabilityKeys: [CapabilityKey]
    public var payloadPolicy: String
    public var externalSideEffectPolicy: String

    public init(
        capabilityKeys: [CapabilityKey],
        payloadPolicy: String = "redactedPayloadOnly",
        externalSideEffectPolicy: String = "visibleUserInitiatedOnly"
    ) {
        self.capabilityKeys = capabilityKeys
        self.payloadPolicy = payloadPolicy
        self.externalSideEffectPolicy = externalSideEffectPolicy
    }
}

public struct AppIntegrationFallback: Codable, Equatable, Sendable {
    public var reasonKey: String
    public var safeAlternativeKey: String

    public init(reasonKey: String, safeAlternativeKey: String) {
        self.reasonKey = reasonKey
        self.safeAlternativeKey = safeAlternativeKey
    }
}

public struct AppIntegrationSkill: Identifiable, Codable, Equatable, Sendable {
    public var id: AppIntegrationSkillID
    public var appName: String
    public var bundleID: String?
    public var integrationKey: String
    public var category: AppIntegrationSkillCategory
    public var supportedSurfaces: [AppIntegrationSkillSurface]
    public var schema: AppIntegrationSkillSchema
    public var setupRequirement: AppIntegrationSkillSetupRequirement
    public var installedAppRequirement: AppIntegrationInstalledAppRequirement
    public var permissionRequirement: PermissionRequirement
    public var availabilityStatus: AppIntegrationSkillAvailabilityStatus
    public var riskTier: ActionRiskTier
    public var confirmationPolicy: BuiltInPhoneToolConfirmationPolicy
    public var previewTextKey: String
    public var examplePromptKey: String
    public var executionMode: AppIntegrationExecutionMode
    public var endpoints: [AppIntegrationSkillEndpoint]
    public var oauth: AppIntegrationOAuthRequirement?
    public var fallback: AppIntegrationFallback
    public var audit: AppIntegrationAuditMetadata
    public var sourceReference: String

    public init(
        id: AppIntegrationSkillID,
        appName: String,
        bundleID: String? = nil,
        integrationKey: String,
        category: AppIntegrationSkillCategory,
        supportedSurfaces: [AppIntegrationSkillSurface],
        schema: AppIntegrationSkillSchema,
        setupRequirement: AppIntegrationSkillSetupRequirement,
        installedAppRequirement: AppIntegrationInstalledAppRequirement,
        permissionRequirement: PermissionRequirement,
        availabilityStatus: AppIntegrationSkillAvailabilityStatus,
        riskTier: ActionRiskTier,
        confirmationPolicy: BuiltInPhoneToolConfirmationPolicy,
        previewTextKey: String,
        examplePromptKey: String? = nil,
        executionMode: AppIntegrationExecutionMode,
        endpoints: [AppIntegrationSkillEndpoint],
        oauth: AppIntegrationOAuthRequirement? = nil,
        fallback: AppIntegrationFallback,
        audit: AppIntegrationAuditMetadata,
        sourceReference: String
    ) {
        self.id = id
        self.appName = appName
        self.bundleID = bundleID
        self.integrationKey = integrationKey
        self.category = category
        self.supportedSurfaces = supportedSurfaces
        self.schema = schema
        self.setupRequirement = setupRequirement
        self.installedAppRequirement = installedAppRequirement
        self.permissionRequirement = permissionRequirement
        self.availabilityStatus = availabilityStatus
        self.riskTier = riskTier
        self.confirmationPolicy = confirmationPolicy
        self.previewTextKey = previewTextKey
        self.examplePromptKey = examplePromptKey ?? "appIntegration.\(id.rawValue).examplePrompt"
        self.executionMode = executionMode
        self.endpoints = endpoints
        self.oauth = oauth
        self.fallback = fallback
        self.audit = audit
        self.sourceReference = sourceReference
    }

    public var requiresConfirmation: Bool {
        riskTier.requiresConfirmation || !confirmationPolicy.allowsExecutionWithoutConfirmation
    }

    public var canBeSuggestedAsExecutable: Bool {
        availabilityStatus.allowsExecutableSuggestion
            && confirmationPolicy != .manualSetupOnly
            && executionMode != .previewOnly
    }

    public var shortcutNodeKind: ShortcutNodeKind? {
        id.shortcutNodeKind
    }

    public var blockedExecutionFields: [String: String] {
        [
            "integrationAvailability": availabilityStatus.rawValue,
            "integrationSetupRequirement": setupRequirement.rawValue,
            "integrationExecutionMode": executionMode.rawValue,
            "integrationFallbackReasonKey": fallback.reasonKey,
            "integrationFallbackSafeAlternativeKey": fallback.safeAlternativeKey
        ]
    }
}

public struct AppIntegrationSkillCatalog: AppIntegrationSkillCatalogProviding {
    public var skills: [AppIntegrationSkill]

    public init(seedSource: any AppIntegrationSkillSeeding = DefaultAppIntegrationSkillSeedFactory()) {
        self.skills = seedSource.skills
    }

    public init(skills: [AppIntegrationSkill]) {
        self.skills = skills
    }

    public static let defaultSkills: [AppIntegrationSkill] = DefaultAppIntegrationSkillSeedFactory.defaultSkills
}
