import Foundation

public protocol AppIntegrationSkillCatalogProviding: Sendable {
    var skills: [AppIntegrationSkill] { get }
}

public extension AppIntegrationSkillCatalogProviding {
    func skill(id: AppIntegrationSkillID) -> AppIntegrationSkill? {
        skills.first { $0.id == id }
    }

    var executableSkills: [AppIntegrationSkill] {
        skills.filter(\.canBeSuggestedAsExecutable)
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
}

public struct AppIntegrationSkillCatalog: AppIntegrationSkillCatalogProviding {
    public var skills: [AppIntegrationSkill]

    public init(skills: [AppIntegrationSkill] = AppIntegrationSkillCatalog.defaultSkills) {
        self.skills = skills
    }

    public static let defaultSkills: [AppIntegrationSkill] = [
        .visibleHandoff(
            id: .appleMailHandoff,
            appName: "Mail",
            bundleID: "com.apple.mobilemail",
            integrationKey: "apple-mail",
            category: .communication,
            surfaces: [.urlScheme],
            schema: AppIntegrationSkillSchema(input: "EmailDraft", output: "VisibleMailtoHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(scheme: "mailto", exampleURLTemplate: "mailto:{recipient}?subject={subject}&body={body}")],
            capabilityKeys: [.mail],
            sourceReference: "public-url-scheme:mailto"
        ),
        .visibleHandoff(
            id: .appleMessagesHandoff,
            appName: "Messages",
            bundleID: "com.apple.MobileSMS",
            integrationKey: "apple-messages",
            category: .communication,
            surfaces: [.urlScheme],
            schema: AppIntegrationSkillSchema(input: "MessageDraft", output: "VisibleSMSHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(scheme: "sms", exampleURLTemplate: "sms:{recipient}&body={body}")],
            capabilityKeys: [.messages],
            sourceReference: "public-url-scheme:sms"
        ),
        .visibleHandoff(
            id: .applePhoneHandoff,
            appName: "Phone",
            bundleID: "com.apple.mobilephone",
            integrationKey: "apple-phone",
            category: .communication,
            surfaces: [.urlScheme],
            schema: AppIntegrationSkillSchema(input: "PhoneCallDraft", output: "VisibleTelHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(scheme: "tel", exampleURLTemplate: "tel:{phoneNumber}")],
            capabilityKeys: [.phone],
            sourceReference: "public-url-scheme:tel"
        ),
        .visibleHandoff(
            id: .safariWebSearchHandoff,
            appName: "Safari",
            bundleID: "com.apple.mobilesafari",
            integrationKey: "safari-web-search",
            category: .browserSearchKnowledge,
            surfaces: [.universalLink],
            schema: AppIntegrationSkillSchema(input: "WebSearchDraft", output: "VisibleHTTPSHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(universalLinkHost: "www.google.com", exampleURLTemplate: "https://www.google.com/search?q={query}")],
            capabilityKeys: [.web],
            sourceReference: "public-https-search-url"
        ),
        .visibleHandoff(
            id: .appleMapsDirectionsHandoff,
            appName: "Apple Maps",
            bundleID: "com.apple.Maps",
            integrationKey: "apple-maps",
            category: .mapsLocation,
            surfaces: [.universalLink],
            schema: AppIntegrationSkillSchema(input: "MapDirectionsDraft", output: "VisibleMapsHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(universalLinkHost: "maps.apple.com", exampleURLTemplate: "https://maps.apple.com/?daddr={destination}")],
            capabilityKeys: [.location],
            sourceReference: "public-apple-maps-url"
        ),
        .visibleHandoff(
            id: .googleMapsDirectionsHandoff,
            appName: "Google Maps",
            bundleID: "com.google.Maps",
            integrationKey: "google-maps",
            category: .mapsLocation,
            surfaces: [.universalLink, .urlScheme],
            schema: AppIntegrationSkillSchema(input: "MapDirectionsDraft", output: "VisibleGoogleMapsHandoff"),
            endpoints: [
                AppIntegrationSkillEndpoint(universalLinkHost: "www.google.com", exampleURLTemplate: "https://www.google.com/maps/dir/?api=1&destination={destination}"),
                AppIntegrationSkillEndpoint(scheme: "comgooglemaps", exampleURLTemplate: "comgooglemaps://?daddr={destination}&directionsmode=driving")
            ],
            capabilityKeys: [.location],
            sourceReference: "https://developers.google.com/maps/documentation/urls/ios-urlscheme"
        ),
        .oauthAPI(
            id: .gmailDraftAPI,
            appName: "Gmail",
            bundleID: "com.google.Gmail",
            integrationKey: "gmail-google-workspace",
            category: .communication,
            schema: AppIntegrationSkillSchema(input: "EmailDraft", output: "GmailDraftMetadata"),
            oauth: AppIntegrationOAuthRequirement(
                providerKey: "google",
                authorizationEndpoint: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!,
                tokenEndpoint: URL(string: "https://oauth2.googleapis.com/token"),
                requiredScopes: ["https://www.googleapis.com/auth/gmail.compose"]
            ),
            endpoints: [AppIntegrationSkillEndpoint(apiBaseURL: URL(string: "https://gmail.googleapis.com")!, exampleURLTemplate: "POST /gmail/v1/users/me/drafts")],
            capabilityKeys: [.mail, .externalConnectors],
            sourceReference: "https://developers.google.com/workspace/gmail/api/auth/scopes"
        ),
        .visibleHandoff(
            id: .whatsappMessageHandoff,
            appName: "WhatsApp",
            bundleID: "net.whatsapp.WhatsApp",
            integrationKey: "whatsapp",
            category: .communication,
            surfaces: [.universalLink],
            schema: AppIntegrationSkillSchema(input: "MessageDraft", output: "VisibleWhatsAppHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(universalLinkHost: "wa.me", exampleURLTemplate: "https://wa.me/{phoneNumber}?text={body}")],
            capabilityKeys: [.messages],
            sourceReference: "public-https-link:wa.me"
        ),
        .visibleHandoff(
            id: .lineShareHandoff,
            appName: "LINE",
            bundleID: "jp.naver.line",
            integrationKey: "line",
            category: .communication,
            surfaces: [.universalLink],
            schema: AppIntegrationSkillSchema(input: "MessageDraft", output: "VisibleLineShareHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(universalLinkHost: "line.me", exampleURLTemplate: "https://line.me/R/share?text={body}")],
            capabilityKeys: [.messages],
            sourceReference: "https://developers.line.biz/en/docs/messaging-api/using-line-url-scheme/"
        ),
        .visibleHandoff(
            id: .slackOpenHandoff,
            appName: "Slack",
            bundleID: "com.tinyspeck.chatlyio",
            integrationKey: "slack",
            category: .communication,
            surfaces: [.universalLink, .urlScheme],
            schema: AppIntegrationSkillSchema(input: "SlackDestinationDraft", output: "VisibleSlackHandoff"),
            endpoints: [
                AppIntegrationSkillEndpoint(universalLinkHost: "slack.com", exampleURLTemplate: "https://slack.com/app_redirect?channel={channelID}"),
                AppIntegrationSkillEndpoint(scheme: "slack", exampleURLTemplate: "slack://channel?team={teamID}&id={channelID}")
            ],
            capabilityKeys: [.externalConnectors],
            sourceReference: "https://api.slack.com/docs/deep-linking"
        ),
        .oauthAPI(
            id: .notionPageAPI,
            appName: "Notion",
            bundleID: "notion.id",
            integrationKey: "notion",
            category: .productivity,
            schema: AppIntegrationSkillSchema(input: "NotionPageDraft", output: "NotionPageMetadata"),
            oauth: AppIntegrationOAuthRequirement(
                providerKey: "notion",
                authorizationEndpoint: URL(string: "https://api.notion.com/v1/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://api.notion.com/v1/oauth/token"),
                requiredScopes: ["insert_content"]
            ),
            endpoints: [AppIntegrationSkillEndpoint(apiBaseURL: URL(string: "https://api.notion.com")!, exampleURLTemplate: "POST /v1/pages")],
            capabilityKeys: [.externalConnectors],
            sourceReference: "https://developers.notion.com/docs/authorization"
        ),
        .oauthAPI(
            id: .todoistTaskAPI,
            appName: "Todoist",
            bundleID: "com.todoist.ios",
            integrationKey: "todoist",
            category: .productivity,
            schema: AppIntegrationSkillSchema(input: "TodoistTaskDraft", output: "TodoistTaskMetadata"),
            oauth: AppIntegrationOAuthRequirement(
                providerKey: "todoist",
                authorizationEndpoint: URL(string: "https://app.todoist.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://api.todoist.com/oauth/access_token"),
                requiredScopes: ["data:read_write"]
            ),
            endpoints: [AppIntegrationSkillEndpoint(apiBaseURL: URL(string: "https://api.todoist.com")!, exampleURLTemplate: "POST /api/v1/tasks")],
            capabilityKeys: [.externalConnectors],
            sourceReference: "https://developer.todoist.com/api/v1/"
        ),
        .visibleHandoff(
            id: .draftsCreateHandoff,
            appName: "Drafts",
            bundleID: nil,
            integrationKey: "drafts",
            category: .productivity,
            surfaces: [.urlScheme],
            schema: AppIntegrationSkillSchema(input: "TextDraft", output: "VisibleDraftsCreateHandoff"),
            endpoints: [AppIntegrationSkillEndpoint(scheme: "drafts", exampleURLTemplate: "drafts://create?text={text}")],
            setupRequirement: .installApp,
            installedAppRequirement: .required,
            availabilityStatus: .requiresInstalledApp,
            capabilityKeys: [.documents],
            sourceReference: "https://docs.getdrafts.com/docs/automation/urlschemes.html"
        )
    ]
}

private extension AppIntegrationSkill {
    static func visibleHandoff(
        id: AppIntegrationSkillID,
        appName: String,
        bundleID: String?,
        integrationKey: String,
        category: AppIntegrationSkillCategory,
        surfaces: [AppIntegrationSkillSurface],
        schema: AppIntegrationSkillSchema,
        endpoints: [AppIntegrationSkillEndpoint],
        setupRequirement: AppIntegrationSkillSetupRequirement = .none,
        installedAppRequirement: AppIntegrationInstalledAppRequirement? = nil,
        availabilityStatus: AppIntegrationSkillAvailabilityStatus = .available,
        capabilityKeys: [CapabilityKey],
        sourceReference: String
    ) -> AppIntegrationSkill {
        AppIntegrationSkill(
            id: id,
            appName: appName,
            bundleID: bundleID,
            integrationKey: integrationKey,
            category: category,
            supportedSurfaces: surfaces,
            schema: schema,
            setupRequirement: setupRequirement,
            installedAppRequirement: installedAppRequirement ?? (surfaces.contains(.urlScheme) ? .optional : .none),
            permissionRequirement: .userInitiated,
            availabilityStatus: availabilityStatus,
            riskTier: .tier1Draft,
            confirmationPolicy: .previewAndExplicitConfirmation,
            previewTextKey: "appIntegration.\(id.rawValue).preview",
            executionMode: .openURL,
            endpoints: endpoints,
            fallback: AppIntegrationFallback(
                reasonKey: "appIntegration.\(id.rawValue).fallback.reason",
                safeAlternativeKey: "appIntegration.\(id.rawValue).fallback.safeAlternative"
            ),
            audit: AppIntegrationAuditMetadata(capabilityKeys: capabilityKeys),
            sourceReference: sourceReference
        )
    }

    static func oauthAPI(
        id: AppIntegrationSkillID,
        appName: String,
        bundleID: String?,
        integrationKey: String,
        category: AppIntegrationSkillCategory,
        schema: AppIntegrationSkillSchema,
        oauth: AppIntegrationOAuthRequirement,
        endpoints: [AppIntegrationSkillEndpoint],
        capabilityKeys: [CapabilityKey],
        sourceReference: String
    ) -> AppIntegrationSkill {
        AppIntegrationSkill(
            id: id,
            appName: appName,
            bundleID: bundleID,
            integrationKey: integrationKey,
            category: category,
            supportedSurfaces: [.oauthAPI, .webAPI],
            schema: schema,
            setupRequirement: .connectOAuth,
            installedAppRequirement: .none,
            permissionRequirement: .oauth,
            availabilityStatus: .requiresOAuth,
            riskTier: .tier3HighRiskExternal,
            confirmationPolicy: .manualSetupOnly,
            previewTextKey: "appIntegration.\(id.rawValue).preview",
            executionMode: .apiCall,
            endpoints: endpoints,
            oauth: oauth,
            fallback: AppIntegrationFallback(
                reasonKey: "appIntegration.\(id.rawValue).fallback.reason",
                safeAlternativeKey: "appIntegration.\(id.rawValue).fallback.safeAlternative"
            ),
            audit: AppIntegrationAuditMetadata(capabilityKeys: capabilityKeys),
            sourceReference: sourceReference
        )
    }
}
