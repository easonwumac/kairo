import Foundation

public struct OAuthConnectorClientConfiguration: Equatable, Sendable {
    public var clientID: String
    public var redirectURI: String
    public var scopes: [String]?

    public init(clientID: String, redirectURI: String, scopes: [String]? = nil) {
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
    }
}

public struct OAuthConnectorClientConfigurationLoader: Sendable {
    public init() {}

    public func load(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        infoDictionary: [String: Any]? = Bundle.main.infoDictionary,
        registry: any OAuthConnectorRegistryProviding = IntegrationRegistry()
    ) -> [String: OAuthConnectorClientConfiguration] {
        var configurations = Self.loadFromInfoDictionary(infoDictionary)
        configurations.merge(Self.loadFromEnvironment(environment, registry: registry)) { _, environmentValue in
            environmentValue
        }
        return configurations
    }

    private static func loadFromEnvironment(
        _ environment: [String: String],
        registry: any OAuthConnectorRegistryProviding
    ) -> [String: OAuthConnectorClientConfiguration] {
        var configurations: [String: OAuthConnectorClientConfiguration] = [:]
        for metadata in registry.oauthConnectors.compactMap(\.oauth) {
            let key = metadata.providerKey
                .uppercased()
                .replacingOccurrences(of: "-", with: "_")
            guard let clientID = trimmed(environment["KAIRO_OAUTH_\(key)_CLIENT_ID"]),
                  let redirectURI = trimmed(environment["KAIRO_OAUTH_\(key)_REDIRECT_URI"]) else {
                continue
            }
            configurations[metadata.providerKey] = OAuthConnectorClientConfiguration(
                clientID: clientID,
                redirectURI: redirectURI,
                scopes: scopes(from: environment["KAIRO_OAUTH_\(key)_SCOPES"])
            )
        }
        return configurations
    }

    private static func loadFromInfoDictionary(_ infoDictionary: [String: Any]?) -> [String: OAuthConnectorClientConfiguration] {
        guard let rawConfigurations = infoDictionary?["KairoOAuthClientConfigurations"] as? [String: [String: Any]] else {
            return [:]
        }

        var configurations: [String: OAuthConnectorClientConfiguration] = [:]
        for (providerKey, rawConfiguration) in rawConfigurations {
            guard let clientID = trimmed(rawConfiguration["clientID"] as? String),
                  let redirectURI = trimmed(rawConfiguration["redirectURI"] as? String) else {
                continue
            }
            configurations[providerKey] = OAuthConnectorClientConfiguration(
                clientID: clientID,
                redirectURI: redirectURI,
                scopes: scopes(from: rawConfiguration["scopes"] as? String)
            )
        }
        return configurations
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private static func scopes(from value: String?) -> [String]? {
        let scopes = value?
            .split { $0 == " " || $0 == "," }
            .map(String.init)
            .filter { !$0.isEmpty }
        return scopes?.isEmpty == false ? scopes : nil
    }
}

public enum OAuthConnectorLoginReadiness: String, Codable, Equatable, Sendable {
    case connected
    case readyToAuthorize
    case needsClientConfiguration
    case needsReauthorization

    public var settingsStatusText: String {
        switch self {
        case .connected:
            return KairoL10n.string("settings.oauth.status.connected")
        case .readyToAuthorize:
            return KairoL10n.string("settings.oauth.status.readyToAuthorize")
        case .needsClientConfiguration:
            return KairoL10n.string("settings.oauth.status.needsClientConfiguration")
        case .needsReauthorization:
            return KairoL10n.string("settings.oauth.status.needsReauthorization")
        }
    }
}

public struct OAuthConnectorLoginOption: Identifiable, Equatable, Sendable {
    public var id: String { integrationKey }
    public var integrationKey: String
    public var displayName: String
    public var providerKey: String
    public var readiness: OAuthConnectorLoginReadiness
    public var defaultScopes: [String]
    public var grantedScopes: [String]
    public var requiresBackendTokenExchange: Bool
    public var accountDataBoundary: String

    public init(
        integrationKey: String,
        displayName: String,
        providerKey: String,
        readiness: OAuthConnectorLoginReadiness,
        defaultScopes: [String],
        grantedScopes: [String] = [],
        requiresBackendTokenExchange: Bool,
        accountDataBoundary: String
    ) {
        self.integrationKey = integrationKey
        self.displayName = displayName
        self.providerKey = providerKey
        self.readiness = readiness
        self.defaultScopes = defaultScopes
        self.grantedScopes = grantedScopes
        self.requiresBackendTokenExchange = requiresBackendTokenExchange
        self.accountDataBoundary = accountDataBoundary
    }

    public var canStartAuthorization: Bool {
        switch readiness {
        case .readyToAuthorize, .needsReauthorization:
            return true
        case .connected, .needsClientConfiguration:
            return false
        }
    }

    public var settingsDetailText: String {
        if !grantedScopes.isEmpty {
            return KairoL10n.string("settings.oauth.grantedScopes", grantedScopes.joined(separator: ", "))
        }
        if !defaultScopes.isEmpty {
            return KairoL10n.string("settings.oauth.defaultScopes", defaultScopes.joined(separator: ", "))
        }
        return accountDataBoundary
    }
}

public enum OAuthConnectorLoginCenterError: Error, Equatable {
    case missingIntegration(String)
    case missingOAuthMetadata(String)
    case missingClientConfiguration(String)
}

public typealias OAuthConnectorRegistryProviding = AppIntegrationRegistryProviding

public protocol OAuthConnectorLoginServicing: Sendable {
    func loginOptions() async throws -> [OAuthConnectorLoginOption]
    func makeAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession
    func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview
    func exchangeCallback(
        _ callbackURL: URL,
        expectedState: String,
        codeVerifier: String?
    ) async throws -> OAuthTokenSet
    func disconnect(providerKey: String) async throws
}

public extension OAuthConnectorLoginServicing {
    func makeAuthorizationSession(for integrationKey: String) async throws -> OAuthConnectorAuthorizationSession {
        try await makeAuthorizationSession(
            for: integrationKey,
            state: OAuthNonce.make(),
            codeVerifier: OAuthNonce.make(length: 64)
        )
    }
}

public actor OAuthConnectorLoginCenter: OAuthConnectorLoginServicing {
    private let registry: any OAuthConnectorRegistryProviding
    private let credentialStore: CredentialStore
    private let clientConfigurations: [String: OAuthConnectorClientConfiguration]
    private let callbackStore: FileBackedOAuthConnectorCallbackStore?
    private let tokenExchangeHTTPClient: any HTTPClient

    public init(
        registry: any OAuthConnectorRegistryProviding = IntegrationRegistry(),
        credentialStore: CredentialStore,
        clientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        callbackStore: FileBackedOAuthConnectorCallbackStore? = nil,
        tokenExchangeHTTPClient: any HTTPClient = URLSessionHTTPClient()
    ) {
        self.registry = registry
        self.credentialStore = credentialStore
        self.clientConfigurations = clientConfigurations
        self.callbackStore = callbackStore
        self.tokenExchangeHTTPClient = tokenExchangeHTTPClient
    }

    public func loginOptions() async throws -> [OAuthConnectorLoginOption] {
        var options: [OAuthConnectorLoginOption] = []
        options.reserveCapacity(registry.oauthConnectors.count)

        for integration in registry.oauthConnectors {
            let metadata = integration.oauth!
            let tokenState = try await loadTokenState(for: metadata.providerKey)
            let readiness: OAuthConnectorLoginReadiness
            let grantedScopes: [String]

            switch tokenState {
            case .valid(let tokens):
                readiness = .connected
                grantedScopes = tokens.scopes
            case .invalid:
                readiness = .needsReauthorization
                grantedScopes = []
            case .missing:
                readiness = clientConfigurations[metadata.providerKey] == nil ? .needsClientConfiguration : .readyToAuthorize
                grantedScopes = []
            }

            let option = OAuthConnectorLoginOption(
                integrationKey: integration.key,
                displayName: integration.displayName,
                providerKey: metadata.providerKey,
                readiness: readiness,
                defaultScopes: metadata.defaultScopes,
                grantedScopes: grantedScopes,
                requiresBackendTokenExchange: metadata.requiresBackendTokenExchange,
                accountDataBoundary: metadata.accountDataBoundary
            )
            options.append(option)
        }

        return options
    }

    public func makeAuthorizationSession(
        for integrationKey: String,
        state: String = OAuthNonce.make(),
        codeVerifier: String = OAuthNonce.make(length: 64)
    ) async throws -> OAuthConnectorAuthorizationSession {
        guard let integration = registry.integration(for: integrationKey) else {
            throw OAuthConnectorLoginCenterError.missingIntegration(integrationKey)
        }
        guard let metadata = integration.oauth else {
            throw OAuthConnectorLoginCenterError.missingOAuthMetadata(integrationKey)
        }
        guard let configuration = clientConfigurations[metadata.providerKey] else {
            throw OAuthConnectorLoginCenterError.missingClientConfiguration(metadata.providerKey)
        }

        let service = OAuthConnectorAuthorizationService(
            metadata: metadata,
            clientID: configuration.clientID,
            redirectURI: configuration.redirectURI,
            credentialStore: credentialStore,
            scopes: configuration.scopes,
            httpClient: tokenExchangeHTTPClient
        )
        return try await service.makeAuthorizationSession(state: state, codeVerifier: codeVerifier)
    }

    public func exchangeCallback(
        _ callbackURL: URL,
        expectedState: String,
        codeVerifier: String?
    ) async throws -> OAuthTokenSet {
        let callback = try Self.callbackComponents(from: callbackURL)
        guard let integration = registry.oauthConnectors.first(where: { $0.oauth?.providerKey == callback.providerKey }),
              let metadata = integration.oauth else {
            throw OAuthConnectorCallbackPreviewError.unknownProvider(callback.providerKey)
        }
        guard let configuration = clientConfigurations[metadata.providerKey] else {
            throw OAuthConnectorLoginCenterError.missingClientConfiguration(metadata.providerKey)
        }

        let service = OAuthConnectorAuthorizationService(
            metadata: metadata,
            clientID: configuration.clientID,
            redirectURI: configuration.redirectURI,
            credentialStore: credentialStore,
            scopes: configuration.scopes,
            httpClient: tokenExchangeHTTPClient
        )
        let code = try await service.validateCallback(callbackURL, expectedState: expectedState)
        return try await service.exchangeAuthorizationCode(code, codeVerifier: codeVerifier)
    }

    public func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        let callback = try Self.callbackComponents(from: callbackURL)
        guard let integration = registry.oauthConnectors.first(where: { $0.oauth?.providerKey == callback.providerKey }),
              let metadata = integration.oauth else {
            throw OAuthConnectorCallbackPreviewError.unknownProvider(callback.providerKey)
        }

        let items = callback.queryItems
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw OAuthConnectorCallbackPreviewError.authorizationFailed(error)
        }
        guard let code = items.first(where: { $0.name == "code" })?.value,
              !code.isEmpty else {
            throw OAuthConnectorCallbackPreviewError.missingCode
        }

        let preview = OAuthConnectorCallbackPreview(
            providerKey: metadata.providerKey,
            integrationKey: integration.key,
            state: items.first(where: { $0.name == "state" })?.value,
            authorizationCodeLength: code.count,
            requiresBackendTokenExchange: metadata.requiresBackendTokenExchange
        )
        try await callbackStore?.save(preview)
        return preview
    }

    public func disconnect(providerKey: String) async throws {
        try await credentialStore.deleteSecret(for: CredentialKey.oauthTokenSet(providerKey: providerKey))
    }

    private enum TokenState {
        case valid(OAuthTokenSet)
        case invalid
        case missing
    }

    private func loadTokenState(for providerKey: String) async throws -> TokenState {
        guard let encoded = try await credentialStore.readSecret(for: CredentialKey.oauthTokenSet(providerKey: providerKey)) else {
            return .missing
        }
        let decoded = try? OAuthTokenSet.decodeStoredSecret(encoded)
        guard let tokens = decoded ?? nil else {
            return .invalid
        }
        return .valid(tokens)
    }

    private static func callbackComponents(from callbackURL: URL) throws -> (providerKey: String, queryItems: [URLQueryItem]) {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              components.scheme == "kairo",
              components.host == "oauth" else {
            throw OAuthConnectorCallbackPreviewError.invalidCallbackURL
        }

        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
        guard pathComponents.count == 2,
              pathComponents[1] == "callback" else {
            throw OAuthConnectorCallbackPreviewError.unsupportedCallbackURL
        }

        return (providerKey: pathComponents[0], queryItems: components.queryItems ?? [])
    }
}

public actor OAuthConnectorInteractiveLoginService {
    private let loginCenter: any OAuthConnectorLoginServicing
    private let webAuthenticationRunner: any OAuthWebAuthenticationRunner

    public init(
        loginCenter: any OAuthConnectorLoginServicing,
        webAuthenticationRunner: any OAuthWebAuthenticationRunner
    ) {
        self.loginCenter = loginCenter
        self.webAuthenticationRunner = webAuthenticationRunner
    }

    public func signIn(for integrationKey: String) async throws -> OAuthTokenSet {
        let session = try await loginCenter.makeAuthorizationSession(for: integrationKey)
        let callbackScheme = try Self.callbackScheme(from: session.authorizationURL)
        let callbackURL = try await webAuthenticationRunner.authenticate(
            authorizationURL: session.authorizationURL,
            callbackScheme: callbackScheme
        )
        return try await loginCenter.exchangeCallback(
            callbackURL,
            expectedState: session.state,
            codeVerifier: session.codeVerifier
        )
    }

    private static func callbackScheme(from authorizationURL: URL) throws -> String {
        guard let components = URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false),
              let redirectURI = components.queryItems?.first(where: { $0.name == "redirect_uri" })?.value,
              let scheme = URLComponents(string: redirectURI)?.scheme,
              !scheme.isEmpty else {
            throw OAuthWebAuthenticationError.unavailable
        }
        return scheme
    }
}
