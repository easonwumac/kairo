import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Security)
import Security
#endif

public struct OAuthTokenSet: Codable, Equatable, Sendable {
    public var accessToken: String
    public var refreshToken: String?
    public var expiresAt: Date?
    public var scopes: [String]

    public init(accessToken: String, refreshToken: String? = nil, expiresAt: Date? = nil, scopes: [String] = []) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.expiresAt = expiresAt
        self.scopes = scopes
    }

    public func encodedForStorage() throws -> String {
        let data = try JSONEncoder().encode(self)
        return data.base64EncodedString()
    }

    public static func decodeStoredSecret(_ encoded: String) throws -> OAuthTokenSet? {
        guard let data = Data(base64Encoded: encoded) else {
            return nil
        }
        return try JSONDecoder().decode(OAuthTokenSet.self, from: data)
    }
}

public struct ChatGPTOAuthConfiguration: Equatable, Sendable {
    public var authorizationEndpoint: URL
    public var tokenEndpoint: URL
    public var clientID: String
    public var redirectURI: String
    public var scopes: [String]
    public var audience: String?

    public init(
        authorizationEndpoint: URL,
        tokenEndpoint: URL,
        clientID: String,
        redirectURI: String,
        scopes: [String],
        audience: String? = nil
    ) {
        self.authorizationEndpoint = authorizationEndpoint
        self.tokenEndpoint = tokenEndpoint
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.scopes = scopes
        self.audience = audience
    }
}

public struct OAuthAuthorizationSession: Equatable, Sendable {
    public var authorizationURL: URL
    public var state: String
    public var codeVerifier: String

    public init(authorizationURL: URL, state: String, codeVerifier: String) {
        self.authorizationURL = authorizationURL
        self.state = state
        self.codeVerifier = codeVerifier
    }
}

public struct OAuthConnectorAuthorizationSession: Equatable, Sendable {
    public var providerKey: String
    public var authorizationURL: URL
    public var state: String
    public var codeVerifier: String?

    public init(providerKey: String, authorizationURL: URL, state: String, codeVerifier: String? = nil) {
        self.providerKey = providerKey
        self.authorizationURL = authorizationURL
        self.state = state
        self.codeVerifier = codeVerifier
    }
}

public actor ChatGPTOAuthService {
    private let configuration: ChatGPTOAuthConfiguration
    private let credentialStore: CredentialStore

    public init(configuration: ChatGPTOAuthConfiguration, credentialStore: CredentialStore) {
        self.configuration = configuration
        self.credentialStore = credentialStore
    }

    public func makeAuthorizationSession(state: String = OAuthNonce.make(), codeVerifier: String = OAuthNonce.make(length: 64)) throws -> OAuthAuthorizationSession {
        var components = URLComponents(url: configuration.authorizationEndpoint, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: configuration.clientID),
            URLQueryItem(name: "redirect_uri", value: configuration.redirectURI),
            URLQueryItem(name: "scope", value: configuration.scopes.joined(separator: " ")),
            URLQueryItem(name: "state", value: state),
            URLQueryItem(name: "code_challenge", value: PKCE.codeChallenge(for: codeVerifier)),
            URLQueryItem(name: "code_challenge_method", value: "S256")
        ])
        if let audience = configuration.audience {
            queryItems.append(URLQueryItem(name: "audience", value: audience))
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw ChatGPTOAuthError.invalidAuthorizationURL
        }
        return OAuthAuthorizationSession(authorizationURL: url, state: state, codeVerifier: codeVerifier)
    }

    public func validateCallback(_ callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw ChatGPTOAuthError.invalidCallback
        }
        let items = components.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw ChatGPTOAuthError.authorizationFailed(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            throw ChatGPTOAuthError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw ChatGPTOAuthError.missingCode
        }
        return code
    }

    public func storeTokens(_ tokens: OAuthTokenSet) async throws {
        try await credentialStore.saveSecret(tokens.encodedForStorage(), for: CredentialKey.chatGPTOAuthTokenSet)
    }

    public func loadTokens() async throws -> OAuthTokenSet? {
        guard let encoded = try await credentialStore.readSecret(for: CredentialKey.chatGPTOAuthTokenSet) else {
            return nil
        }
        return try OAuthTokenSet.decodeStoredSecret(encoded)
    }

    public func signOut() async throws {
        try await credentialStore.deleteSecret(for: CredentialKey.chatGPTOAuthTokenSet)
    }
}

public enum ChatGPTOAuthError: Error, Equatable {
    case invalidAuthorizationURL
    case invalidCallback
    case authorizationFailed(String)
    case stateMismatch
    case missingCode
}

public actor OAuthConnectorAuthorizationService {
    private let metadata: OAuthConnectorMetadata
    private let clientID: String
    private let redirectURI: String
    private let scopes: [String]
    private let credentialStore: CredentialStore

    public init(
        metadata: OAuthConnectorMetadata,
        clientID: String,
        redirectURI: String,
        credentialStore: CredentialStore,
        scopes: [String]? = nil
    ) {
        self.metadata = metadata
        self.clientID = clientID
        self.redirectURI = redirectURI
        self.credentialStore = credentialStore
        self.scopes = scopes ?? metadata.defaultScopes
    }

    public func makeAuthorizationSession(
        state: String = OAuthNonce.make(),
        codeVerifier: String = OAuthNonce.make(length: 64)
    ) throws -> OAuthConnectorAuthorizationSession {
        var components = URLComponents(url: metadata.authorizationEndpoint, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(contentsOf: [
            URLQueryItem(name: "response_type", value: "code"),
            URLQueryItem(name: "client_id", value: clientID),
            URLQueryItem(name: "redirect_uri", value: redirectURI),
            URLQueryItem(name: "state", value: state)
        ])
        if !scopes.isEmpty {
            queryItems.append(URLQueryItem(name: "scope", value: scopes.joined(separator: " ")))
        }
        if metadata.requiresPKCE {
            queryItems.append(contentsOf: [
                URLQueryItem(name: "code_challenge", value: PKCE.codeChallenge(for: codeVerifier)),
                URLQueryItem(name: "code_challenge_method", value: "S256")
            ])
        }
        components?.queryItems = queryItems

        guard let url = components?.url else {
            throw OAuthConnectorAuthorizationError.invalidAuthorizationURL
        }
        return OAuthConnectorAuthorizationSession(
            providerKey: metadata.providerKey,
            authorizationURL: url,
            state: state,
            codeVerifier: metadata.requiresPKCE ? codeVerifier : nil
        )
    }

    public func validateCallback(_ callbackURL: URL, expectedState: String) throws -> String {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false) else {
            throw OAuthConnectorAuthorizationError.invalidCallback
        }
        let items = components.queryItems ?? []
        if let error = items.first(where: { $0.name == "error" })?.value {
            throw OAuthConnectorAuthorizationError.authorizationFailed(error)
        }
        guard items.first(where: { $0.name == "state" })?.value == expectedState else {
            throw OAuthConnectorAuthorizationError.stateMismatch
        }
        guard let code = items.first(where: { $0.name == "code" })?.value, !code.isEmpty else {
            throw OAuthConnectorAuthorizationError.missingCode
        }
        return code
    }

    public func storeTokens(_ tokens: OAuthTokenSet) async throws {
        try await credentialStore.saveSecret(tokens.encodedForStorage(), for: tokenKey)
    }

    public func loadTokens() async throws -> OAuthTokenSet? {
        guard let encoded = try await credentialStore.readSecret(for: tokenKey) else {
            return nil
        }
        return try OAuthTokenSet.decodeStoredSecret(encoded)
    }

    public func signOut() async throws {
        try await credentialStore.deleteSecret(for: tokenKey)
    }

    private var tokenKey: String {
        CredentialKey.oauthTokenSet(providerKey: metadata.providerKey)
    }
}

public enum OAuthConnectorAuthorizationError: Error, Equatable {
    case invalidAuthorizationURL
    case invalidCallback
    case authorizationFailed(String)
    case stateMismatch
    case missingCode
}

public enum OAuthNonce {
    public static func make(length: Int = 32) -> String {
        let characters = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-._~")
        var bytes = [UInt8](repeating: 0, count: length)
        _ = SecRandomCopyBytesIfAvailable(&bytes)
        return String(bytes.map { characters[Int($0) % characters.count] })
    }

    private static func SecRandomCopyBytesIfAvailable(_ bytes: inout [UInt8]) -> Int32 {
        #if canImport(Security)
        importSecurityRandom(&bytes)
        #else
        for index in bytes.indices {
            bytes[index] = UInt8((index * 31 + 17) % 255)
        }
        #endif
        return 0
    }

    #if canImport(Security)
    private static func importSecurityRandom(_ bytes: inout [UInt8]) {
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
    }
    #endif
}

public enum PKCE {
    public static func codeChallenge(for verifier: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString()
        #else
        return verifier
        #endif
    }
}

private extension Data {
    func base64URLEncodedString() -> String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
