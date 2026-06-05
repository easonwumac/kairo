import Foundation

public protocol AppIntegrationSkillSeeding: Sendable {
    var skills: [AppIntegrationSkill] { get }
}

public struct DefaultAppIntegrationSkillSeedFactory: AppIntegrationSkillSeeding {
    public init() {}

    public var skills: [AppIntegrationSkill] {
        Self.defaultSkills
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
