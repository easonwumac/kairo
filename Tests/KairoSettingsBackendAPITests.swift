import XCTest
@testable import KairoCore

final class KairoSettingsBackendAPITests: XCTestCase {
    func testSettingsBackendAPIManagesOpenAIKeyWithoutLeakingSecrets() async throws {
        let credentials = InMemoryCredentialStore()
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: credentials),
            oauthLoginCenter: OAuthConnectorLoginCenter(credentialStore: credentials)
        )

        var status = try await api.openAIStatus()
        XCTAssertFalse(status.hasAPIKey)

        let dryRun = try await api.dryRunOpenAIAPIKey(" openai-test-key-1234567890 ")
        XCTAssertFalse(dryRun.usesSavedKey)
        XCTAssertEqual(dryRun.redactedKey, "open...7890")
        XCTAssertEqual(dryRun.message, KairoL10n.string("settings.openai.dryRun.noNetwork"))
        let unsavedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertNil(unsavedOpenAIKey)

        try await api.saveOpenAIAPIKey(" openai-live-key-abcdef1234 ")
        status = try await api.openAIStatus()
        XCTAssertTrue(status.hasAPIKey)
        let savedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertEqual(savedOpenAIKey, "openai-live-key-abcdef1234")

        let savedDryRun = try await api.dryRunOpenAIAPIKey(nil)
        XCTAssertTrue(savedDryRun.usesSavedKey)
        XCTAssertEqual(savedDryRun.redactedKey, "open...1234")

        try await api.deleteOpenAIAPIKey()
        status = try await api.openAIStatus()
        XCTAssertFalse(status.hasAPIKey)
        let deletedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertNil(deletedOpenAIKey)
    }

    func testSettingsOpenAIKeyCoordinatorManagesCredentialLifecycle() async throws {
        let credentials = InMemoryCredentialStore()
        let coordinator = SettingsOpenAIKeyCoordinator(
            settingsService: OpenAISettingsService(credentialStore: credentials)
        )

        var status = try await coordinator.status()
        XCTAssertFalse(status.hasAPIKey)

        let dryRun = try await coordinator.dryRunAPIKey(" openai-test-key-1234567890 ")
        let unsavedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertFalse(dryRun.usesSavedKey)
        XCTAssertNil(unsavedOpenAIKey)

        try await coordinator.saveAPIKey(" openai-live-key-abcdef1234 ")
        status = try await coordinator.status()
        let savedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertTrue(status.hasAPIKey)
        XCTAssertEqual(savedOpenAIKey, "openai-live-key-abcdef1234")

        let savedDryRun = try await coordinator.dryRunAPIKey(nil)
        XCTAssertTrue(savedDryRun.usesSavedKey)

        try await coordinator.deleteAPIKey()
        status = try await coordinator.status()
        let deletedOpenAIKey = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertFalse(status.hasAPIKey)
        XCTAssertNil(deletedOpenAIKey)
    }

    func testSettingsBackendAPIDependsOnOAuthLoginServiceAbstraction() async throws {
        let oauthService = StubOAuthConnectorLoginService(
            options: [
                OAuthConnectorLoginOption(
                    integrationKey: "chatgpt",
                    displayName: "ChatGPT",
                    providerKey: "chatgpt",
                    readiness: .readyToAuthorize,
                    defaultScopes: ["openid"],
                    requiresBackendTokenExchange: false,
                    accountDataBoundary: "Account profile only"
                )
            ]
        )
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: InMemoryCredentialStore()),
            oauthLoginCenter: oauthService
        )

        let options = try await api.oauthLoginOptions()
        let didLoadOptions = await oauthService.didLoadOptions()

        XCTAssertEqual(options.map(\.providerKey), ["chatgpt"])
        XCTAssertTrue(didLoadOptions)
    }

    func testSettingsBackendAPIManagesOAuthLoginWithoutPersistingAuthorizationCode() async throws {
        let fileURL = temporaryFileURL(named: "oauth-callbacks.json")
        let callbackStore = try await FileBackedOAuthConnectorCallbackStore(fileURL: fileURL)
        let credentials = InMemoryCredentialStore()
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: credentials),
            oauthLoginCenter: OAuthConnectorLoginCenter(
                credentialStore: credentials,
                clientConfigurations: [
                    "google": OAuthConnectorClientConfiguration(
                        clientID: "google-client",
                        redirectURI: "kairo://oauth/google/callback",
                        scopes: ["openid", "email"]
                    )
                ],
                callbackStore: callbackStore
            )
        )

        let options = try await api.oauthLoginOptions()
        let googleOption = try XCTUnwrap(options.first { $0.providerKey == "google" })
        XCTAssertEqual(googleOption.readiness, .readyToAuthorize)
        XCTAssertTrue(googleOption.canStartAuthorization)

        let session = try await api.makeOAuthAuthorizationSession(
            for: "gmail-google-workspace",
            state: "state-123",
            codeVerifier: "verifier-123"
        )
        XCTAssertEqual(session.providerKey, "google")
        XCTAssertTrue(session.authorizationURL.absoluteString.contains("client_id=google-client"))
        XCTAssertFalse(session.authorizationURL.absoluteString.contains("sample-sensitive-code"))

        let preview = try await api.previewOAuthCallback(
            URL(string: "kairo://oauth/google/callback?code=sample-sensitive-code&state=state-123")!
        )
        XCTAssertEqual(preview.providerKey, "google")
        XCTAssertEqual(preview.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-sensitive-code".count)
        XCTAssertFalse(preview.settingsStatusText.contains("sample-sensitive-code"))

        let storedJSON = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(storedJSON.contains("sample-sensitive-code"))
        XCTAssertTrue(storedJSON.contains(#""authorizationCodeLength":21"#))

        try await credentials.saveSecret(
            try OAuthTokenSet(accessToken: "oauth-token", scopes: ["openid"]).encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "google")
        )
        var connectedOptions = try await api.oauthLoginOptions()
        XCTAssertEqual(connectedOptions.first { $0.providerKey == "google" }?.readiness, .connected)

        try await api.disconnectOAuthProvider(providerKey: "google")
        let disconnectedToken = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "google"))
        XCTAssertNil(disconnectedToken)
        connectedOptions = try await api.oauthLoginOptions()
        XCTAssertEqual(connectedOptions.first { $0.providerKey == "google" }?.readiness, .readyToAuthorize)
    }

    func testSettingsBackendAPIExchangesChatGPTOAuthCallbackWithoutPersistingAuthorizationCode() async throws {
        let credentials = InMemoryCredentialStore()
        let httpClient = ChatBackendCapturingHTTPClient(body: #"{"access_token":"access-token","scope":"openid profile email"}"#)
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: credentials),
            oauthLoginCenter: OAuthConnectorLoginCenter(
                credentialStore: credentials,
                clientConfigurations: [
                    "chatgpt": OAuthConnectorClientConfiguration(
                        clientID: "chatgpt-client",
                        redirectURI: "kairo://oauth/chatgpt/callback"
                    )
                ],
                tokenExchangeHTTPClient: httpClient
            )
        )

        let session = try await api.makeOAuthAuthorizationSession(
            for: "chatgpt",
            state: "state-123",
            codeVerifier: "verifier-123"
        )
        let tokens = try await api.exchangeOAuthCallback(
            URL(string: "kairo://oauth/chatgpt/callback?code=auth-code-abc&state=state-123")!,
            expectedState: session.state,
            codeVerifier: session.codeVerifier
        )

        XCTAssertEqual(tokens.accessToken, "access-token")
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "chatgpt"))
        XCTAssertNotNil(storedRaw)
        XCTAssertFalse(storedRaw?.contains("auth-code-abc") == true)
    }

    func testSettingsBackendAPITreatsMalformedOAuthTokenAsReauthorizationRequired() async throws {
        let credentials = InMemoryCredentialStore()
        let api = KairoSettingsBackendService(
            openAISettingsService: OpenAISettingsService(credentialStore: credentials),
            oauthLoginCenter: OAuthConnectorLoginCenter(
                credentialStore: credentials,
                clientConfigurations: [
                    "google": OAuthConnectorClientConfiguration(
                        clientID: "google-client",
                        redirectURI: "kairo://oauth/google/callback",
                        scopes: ["openid", "email"]
                    )
                ]
            )
        )

        try await credentials.saveSecret(
            "raw-broken-oauth-secret",
            for: CredentialKey.oauthTokenSet(providerKey: "google")
        )

        var options = try await api.oauthLoginOptions()
        var googleOption = try XCTUnwrap(options.first { $0.providerKey == "google" })
        XCTAssertEqual(googleOption.readiness, .needsReauthorization)
        XCTAssertTrue(googleOption.canStartAuthorization)
        XCTAssertTrue(googleOption.grantedScopes.isEmpty)
        XCTAssertFalse(googleOption.settingsDetailText.contains("raw-broken-oauth-secret"))

        let malformedJSON = Data(#"{"accessToken":42}"#.utf8).base64EncodedString()
        try await credentials.saveSecret(
            malformedJSON,
            for: CredentialKey.oauthTokenSet(providerKey: "google")
        )

        options = try await api.oauthLoginOptions()
        googleOption = try XCTUnwrap(options.first { $0.providerKey == "google" })
        XCTAssertEqual(googleOption.readiness, .needsReauthorization)
        XCTAssertTrue(googleOption.canStartAuthorization)
        XCTAssertTrue(googleOption.grantedScopes.isEmpty)
        XCTAssertFalse(googleOption.settingsDetailText.contains(malformedJSON))
    }

    func testSettingsOAuthConnectorCoordinatorCompletesManualCallbackFallback() async throws {
        let credentials = InMemoryCredentialStore()
        let httpClient = ChatBackendCapturingHTTPClient(body: #"{"access_token":"manual-token","scope":"openid"}"#)
        let center = OAuthConnectorLoginCenter(
            credentialStore: credentials,
            clientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ],
            tokenExchangeHTTPClient: httpClient
        )
        let coordinator = SettingsOAuthConnectorCoordinator(loginService: center)
        let options = try await coordinator.loginOptions()
        let option = try XCTUnwrap(options.first { $0.providerKey == "chatgpt" })

        let outcome = try await coordinator.authorize(option)
        guard case .fallback(let session) = outcome else {
            return XCTFail("Expected manual authorization fallback when no web runner is available.")
        }
        let hasPendingSession = await coordinator.hasPendingSession(for: "chatgpt")
        XCTAssertTrue(hasPendingSession)

        let completion = try await coordinator.completeCallbackLogin(
            URL(string: "kairo://oauth/chatgpt/callback?code=manual-code&state=\(session.state)")!
        )
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "chatgpt"))
        let hasClearedPendingSession = await coordinator.hasPendingSession(for: "chatgpt")

        XCTAssertEqual(completion.providerKey, "chatgpt")
        XCTAssertEqual(completion.tokens.accessToken, "manual-token")
        XCTAssertFalse(hasClearedPendingSession)
        XCTAssertFalse(storedRaw?.contains("manual-code") == true)
    }

    @MainActor
    func testSettingsOAuthConnectorCoordinatorCompletesInteractiveLogin() async throws {
        let credentials = InMemoryCredentialStore()
        let httpClient = ChatBackendCapturingHTTPClient(body: #"{"access_token":"interactive-token","scope":"openid profile"}"#)
        let center = OAuthConnectorLoginCenter(
            credentialStore: credentials,
            clientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ],
            tokenExchangeHTTPClient: httpClient
        )
        let runner = SettingsFakeOAuthWebAuthenticationRunner { authorizationURL, callbackScheme in
            let components = try XCTUnwrap(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
            let state = try XCTUnwrap(components.queryItems?.first { $0.name == "state" }?.value)
            return URL(string: "\(callbackScheme)://oauth/chatgpt/callback?code=interactive-code&state=\(state)")!
        }
        let coordinator = SettingsOAuthConnectorCoordinator(
            loginService: center,
            webAuthenticationRunner: runner
        )
        let options = try await coordinator.loginOptions()
        let option = try XCTUnwrap(options.first { $0.providerKey == "chatgpt" })

        let outcome = try await coordinator.authorize(option)
        guard case .completed = outcome else {
            return XCTFail("Expected interactive login to complete without manual callback fallback.")
        }
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "chatgpt"))
        let hasPendingSession = await coordinator.hasPendingSession(for: "chatgpt")

        XCTAssertEqual(runner.receivedCallbackScheme, "kairo")
        XCTAssertEqual(runner.receivedAuthorizationURL?.host, "auth.openai.com")
        XCTAssertFalse(hasPendingSession)
        XCTAssertFalse(storedRaw?.contains("interactive-code") == true)
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }
}

private actor StubOAuthConnectorLoginService: OAuthConnectorLoginServicing {
    private let options: [OAuthConnectorLoginOption]
    private var loadedOptions = false

    init(options: [OAuthConnectorLoginOption]) {
        self.options = options
    }

    func loginOptions() async throws -> [OAuthConnectorLoginOption] {
        loadedOptions = true
        return options
    }

    func makeAuthorizationSession(
        for integrationKey: String,
        state: String,
        codeVerifier: String
    ) async throws -> OAuthConnectorAuthorizationSession {
        OAuthConnectorAuthorizationSession(
            providerKey: integrationKey,
            authorizationURL: URL(string: "kairo://oauth/\(integrationKey)/authorize")!,
            state: state,
            codeVerifier: codeVerifier
        )
    }

    func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        OAuthConnectorCallbackPreview(
            providerKey: "chatgpt",
            integrationKey: "chatgpt",
            state: nil,
            authorizationCodeLength: 0,
            requiresBackendTokenExchange: false
        )
    }

    func exchangeCallback(
        _ callbackURL: URL,
        expectedState: String,
        codeVerifier: String?
    ) async throws -> OAuthTokenSet {
        OAuthTokenSet(accessToken: "stub-token")
    }

    func disconnect(providerKey: String) async throws {}

    func didLoadOptions() -> Bool {
        loadedOptions
    }
}

@MainActor
private final class SettingsFakeOAuthWebAuthenticationRunner: OAuthWebAuthenticationRunner {
    private let callback: (URL, String) throws -> URL
    private(set) var receivedAuthorizationURL: URL?
    private(set) var receivedCallbackScheme: String?

    init(callback: @escaping (URL, String) throws -> URL) {
        self.callback = callback
    }

    func authenticate(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        receivedAuthorizationURL = authorizationURL
        receivedCallbackScheme = callbackScheme
        return try callback(authorizationURL, callbackScheme)
    }
}
