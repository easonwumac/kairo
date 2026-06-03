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

public enum OAuthConnectorLoginReadiness: String, Codable, Equatable, Sendable {
    case connected
    case readyToAuthorize
    case needsClientConfiguration
    case needsReauthorization

    public var settingsStatusText: String {
        switch self {
        case .connected:
            return "已連線"
        case .readyToAuthorize:
            return "可授權"
        case .needsClientConfiguration:
            return "需要 Client 設定"
        case .needsReauthorization:
            return "需要重新授權"
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
            return "已授權 scopes: \(grantedScopes.joined(separator: ", "))"
        }
        if !defaultScopes.isEmpty {
            return "預設 scopes: \(defaultScopes.joined(separator: ", "))"
        }
        return accountDataBoundary
    }
}

public enum OAuthConnectorLoginCenterError: Error, Equatable {
    case missingIntegration(String)
    case missingOAuthMetadata(String)
    case missingClientConfiguration(String)
}

public actor OAuthConnectorLoginCenter {
    private let registry: IntegrationRegistry
    private let credentialStore: CredentialStore
    private let clientConfigurations: [String: OAuthConnectorClientConfiguration]
    private let callbackStore: FileBackedOAuthConnectorCallbackStore?

    public init(
        registry: IntegrationRegistry = IntegrationRegistry(),
        credentialStore: CredentialStore,
        clientConfigurations: [String: OAuthConnectorClientConfiguration] = [:],
        callbackStore: FileBackedOAuthConnectorCallbackStore? = nil
    ) {
        self.registry = registry
        self.credentialStore = credentialStore
        self.clientConfigurations = clientConfigurations
        self.callbackStore = callbackStore
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
            scopes: configuration.scopes
        )
        return try await service.makeAuthorizationSession(state: state, codeVerifier: codeVerifier)
    }

    public func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
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

        let providerKey = pathComponents[0]
        guard let integration = registry.oauthConnectors.first(where: { $0.oauth?.providerKey == providerKey }),
              let metadata = integration.oauth else {
            throw OAuthConnectorCallbackPreviewError.unknownProvider(providerKey)
        }

        let items = components.queryItems ?? []
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
}
