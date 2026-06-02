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

public struct ShortcutTemplate: Codable, Equatable, Sendable {
    public var identifier: String
    public var title: String
    public var inputSummary: String
    public var outputSummary: String
    public var requiresExplicitUserSetup: Bool

    public init(
        identifier: String,
        title: String,
        inputSummary: String,
        outputSummary: String,
        requiresExplicitUserSetup: Bool = true
    ) {
        self.identifier = identifier
        self.title = title
        self.inputSummary = inputSummary
        self.outputSummary = outputSummary
        self.requiresExplicitUserSetup = requiresExplicitUserSetup
    }
}
