import Foundation

public struct AppIntegration: Identifiable, Codable, Equatable, Sendable {
    public var id: String { key }
    public var key: String
    public var displayName: String
    public var category: IntegrationCategory
    public var surfaces: [IntegrationSurface]
    public var requiredCapabilities: [CapabilityKey]
    public var oauth: OAuthConnectorMetadata?
    public var urlSchemes: [URLSchemeIntegration]
    public var appIntentIdentifiers: [String]
    public var shortcutTemplates: [ShortcutTemplate]
    public var sandboxNotes: String
    public var status: IntegrationStatus

    public init(
        key: String,
        displayName: String,
        category: IntegrationCategory,
        surfaces: [IntegrationSurface],
        requiredCapabilities: [CapabilityKey] = [],
        oauth: OAuthConnectorMetadata? = nil,
        urlSchemes: [URLSchemeIntegration] = [],
        appIntentIdentifiers: [String] = [],
        shortcutTemplates: [ShortcutTemplate] = [],
        sandboxNotes: String,
        status: IntegrationStatus
    ) {
        self.key = key
        self.displayName = displayName
        self.category = category
        self.surfaces = surfaces
        self.requiredCapabilities = requiredCapabilities
        self.oauth = oauth
        self.urlSchemes = urlSchemes
        self.appIntentIdentifiers = appIntentIdentifiers
        self.shortcutTemplates = shortcutTemplates
        self.sandboxNotes = sandboxNotes
        self.status = status
    }
}

public enum IntegrationCategory: String, Codable, CaseIterable, Sendable {
    case appleSystem
    case productivity
    case communication
    case knowledge
    case storage
    case developer
    case ai
}

public enum IntegrationSurface: String, Codable, CaseIterable, Sendable {
    case appIntents
    case shortcuts
    case urlScheme
    case universalLink
    case shareExtension
    case documentPicker
    case oauthAPI
    case eventKit
    case homeKit
    case userNotifications
}

public enum IntegrationStatus: String, Codable, Sendable {
    case available
    case scaffolded
    case requiresUserSetup
    case requiresBackend
    case unsupportedBySandbox
}

public struct OAuthConnectorMetadata: Codable, Equatable, Sendable {
    public var providerKey: String
    public var authorizationEndpoint: URL
    public var tokenEndpoint: URL?
    public var defaultScopes: [String]
    public var callbackScheme: String
    public var requiresPKCE: Bool
    public var requiresBackendTokenExchange: Bool
    public var accountDataBoundary: String

    public init(
        providerKey: String,
        authorizationEndpoint: URL,
        tokenEndpoint: URL? = nil,
        defaultScopes: [String],
        callbackScheme: String = "kairo",
        requiresPKCE: Bool = true,
        requiresBackendTokenExchange: Bool = false,
        accountDataBoundary: String
    ) {
        self.providerKey = providerKey
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.defaultScopes = defaultScopes
        self.callbackScheme = callbackScheme
        self.requiresPKCE = requiresPKCE
        self.requiresBackendTokenExchange = requiresBackendTokenExchange
        self.accountDataBoundary = accountDataBoundary
    }
}

public struct URLSchemeIntegration: Codable, Equatable, Sendable {
    public var scheme: String
    public var exampleURL: String
    public var requiresCanOpenURLDeclaration: Bool
    public var userVisibleOnly: Bool
    public var notes: String

    public init(
        scheme: String,
        exampleURL: String,
        requiresCanOpenURLDeclaration: Bool = true,
        userVisibleOnly: Bool = true,
        notes: String
    ) {
        self.scheme = scheme
        self.exampleURL = exampleURL
        self.requiresCanOpenURLDeclaration = requiresCanOpenURLDeclaration
        self.userVisibleOnly = userVisibleOnly
        self.notes = notes
    }
}

public enum ShortcutTemplateCategory: String, Codable, CaseIterable, Sendable {
    case dailyBriefing
    case meetingPrep
    case shareSheet
    case keyboard
    case actionButton
    case screenshotToTasks
    case carMode
    case genericRecipe
}

public struct ShortcutTemplate: Codable, Equatable, Identifiable, Sendable {
    public var id: String { identifier }
    public var identifier: String
    public var title: String
    public var description: String
    public var category: ShortcutTemplateCategory
    public var inputSummary: String
    public var outputSummary: String
    public var requiredIntentIdentifiers: [String]
    public var recommendedRecipeTemplateID: String?
    public var installURL: URL?
    public var setupInstructions: [String]
    public var requiresExplicitUserSetup: Bool

    public init(
        identifier: String,
        title: String,
        description: String = "",
        category: ShortcutTemplateCategory = .genericRecipe,
        inputSummary: String,
        outputSummary: String,
        requiredIntentIdentifiers: [String] = [],
        recommendedRecipeTemplateID: String? = nil,
        installURL: URL? = nil,
        setupInstructions: [String] = [],
        requiresExplicitUserSetup: Bool = true
    ) {
        self.identifier = identifier
        self.title = title
        self.description = description
        self.category = category
        self.inputSummary = inputSummary
        self.outputSummary = outputSummary
        self.requiredIntentIdentifiers = requiredIntentIdentifiers
        self.recommendedRecipeTemplateID = recommendedRecipeTemplateID
        self.installURL = installURL
        self.setupInstructions = setupInstructions
        self.requiresExplicitUserSetup = requiresExplicitUserSetup
    }

    private enum CodingKeys: String, CodingKey {
        case identifier
        case title
        case description
        case category
        case inputSummary
        case outputSummary
        case requiredIntentIdentifiers
        case recommendedRecipeTemplateID
        case installURL
        case setupInstructions
        case requiresExplicitUserSetup
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.identifier = try container.decode(String.self, forKey: .identifier)
        self.title = try container.decode(String.self, forKey: .title)
        self.description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        self.category = try container.decodeIfPresent(ShortcutTemplateCategory.self, forKey: .category) ?? .genericRecipe
        self.inputSummary = try container.decode(String.self, forKey: .inputSummary)
        self.outputSummary = try container.decode(String.self, forKey: .outputSummary)
        self.requiredIntentIdentifiers = try container.decodeIfPresent([String].self, forKey: .requiredIntentIdentifiers) ?? []
        self.recommendedRecipeTemplateID = try container.decodeIfPresent(String.self, forKey: .recommendedRecipeTemplateID)
        self.installURL = try container.decodeIfPresent(URL.self, forKey: .installURL)
        self.setupInstructions = try container.decodeIfPresent([String].self, forKey: .setupInstructions) ?? []
        self.requiresExplicitUserSetup = try container.decodeIfPresent(Bool.self, forKey: .requiresExplicitUserSetup) ?? true
    }
}
