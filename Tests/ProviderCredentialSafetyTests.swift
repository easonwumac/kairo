import XCTest
@testable import KairoCore

final class ProviderCredentialSafetyTests: XCTestCase {
    func testOpenAISettingsServiceSavesAndDeletesAPIKey() async throws {
        let credentials = InMemoryCredentialStore()
        let service = OpenAISettingsService(credentialStore: credentials)

        let initialStatus = try await service.status()
        XCTAssertFalse(initialStatus.hasAPIKey)

        try await service.saveAPIKey("  test-key  ")
        let savedStatus = try await service.status()
        let savedSecret = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertTrue(savedStatus.hasAPIKey)
        XCTAssertEqual(savedSecret, "test-key")

        try await service.deleteAPIKey()
        let deletedStatus = try await service.status()
        XCTAssertFalse(deletedStatus.hasAPIKey)
    }

    func testOpenAISettingsServiceDryRunRedactsProvidedKeyWithoutSaving() async throws {
        let credentials = InMemoryCredentialStore()
        let service = OpenAISettingsService(credentialStore: credentials)

        let result = try await service.dryRunAPIKey(" sk-test-1234567890 ")

        XCTAssertFalse(result.usesSavedKey)
        XCTAssertEqual(result.redactedKey, "sk-t...7890")
        XCTAssertEqual(result.message, KairoL10n.string("settings.openai.dryRun.noNetwork"))
        let savedSecret = try await credentials.readSecret(for: CredentialKey.openAIAPIKey)
        XCTAssertNil(savedSecret)
    }

    func testOpenAISettingsServiceDryRunUsesSavedKeyWhenInputIsEmpty() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("sk-live-abcdef1234", for: CredentialKey.openAIAPIKey)
        let service = OpenAISettingsService(credentialStore: credentials)

        let result = try await service.dryRunAPIKey(nil as String?)

        XCTAssertTrue(result.usesSavedKey)
        XCTAssertEqual(result.redactedKey, "sk-l...1234")
    }

    func testOpenAISettingsServiceEmptyKeyErrorIsUserReadable() async throws {
        let service = OpenAISettingsService(credentialStore: InMemoryCredentialStore())

        do {
            try await service.saveAPIKey("   ")
            XCTFail("Expected empty API key save to fail.")
        } catch {
            XCTAssertEqual(error.localizedDescription, KairoL10n.string("settings.openai.error.emptyAPIKey"))
        }

        do {
            _ = try await service.dryRunAPIKey(nil as String?)
            XCTFail("Expected empty API key dry run to fail.")
        } catch {
            XCTAssertEqual(error.localizedDescription, KairoL10n.string("settings.openai.error.emptyAPIKey"))
        }
    }

    func testOAuthConnectorReadinessProvidesSettingsCopyAndActionState() {
        XCTAssertEqual(OAuthConnectorLoginReadiness.connected.settingsStatusText, KairoL10n.string("settings.oauth.status.connected"))
        XCTAssertEqual(OAuthConnectorLoginReadiness.readyToAuthorize.settingsStatusText, KairoL10n.string("settings.oauth.status.readyToAuthorize"))
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsClientConfiguration.settingsStatusText, KairoL10n.string("settings.oauth.status.needsClientConfiguration"))
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsReauthorization.settingsStatusText, KairoL10n.string("settings.oauth.status.needsReauthorization"))

        let readyOption = OAuthConnectorLoginOption(
            integrationKey: "gmail-google-workspace",
            displayName: "Gmail / Google Workspace",
            providerKey: "google",
            readiness: .readyToAuthorize,
            defaultScopes: ["openid"],
            requiresBackendTokenExchange: true,
            accountDataBoundary: "Google scopes only."
        )
        let connectedOption = OAuthConnectorLoginOption(
            integrationKey: "github",
            displayName: "GitHub",
            providerKey: "github",
            readiness: .connected,
            defaultScopes: ["repo"],
            grantedScopes: ["repo"],
            requiresBackendTokenExchange: true,
            accountDataBoundary: "GitHub scopes only."
        )

        XCTAssertTrue(readyOption.canStartAuthorization)
        XCTAssertFalse(connectedOption.canStartAuthorization)
        XCTAssertEqual(connectedOption.settingsDetailText, KairoL10n.string("settings.oauth.grantedScopes", "repo"))
    }

    func testOAuthConnectorClientConfigurationLoaderReadsChatGPTRuntimeConfigurationWithoutSecrets() {
        let loader = OAuthConnectorClientConfigurationLoader()

        let configurations = loader.load(
            environment: [
                "KAIRO_OAUTH_CHATGPT_CLIENT_ID": "chatgpt-client",
                "KAIRO_OAUTH_CHATGPT_REDIRECT_URI": "kairo://oauth/chatgpt/callback",
                "KAIRO_OAUTH_CHATGPT_SCOPES": "openid profile"
            ],
            infoDictionary: [
                "KairoOAuthClientConfigurations": [
                    "chatgpt": [
                        "clientID": "plist-client",
                        "redirectURI": "kairo://oauth/chatgpt/plist-callback"
                    ]
                ]
            ]
        )

        XCTAssertEqual(configurations["chatgpt"]?.clientID, "chatgpt-client")
        XCTAssertEqual(configurations["chatgpt"]?.redirectURI, "kairo://oauth/chatgpt/callback")
        XCTAssertEqual(configurations["chatgpt"]?.scopes, ["openid", "profile"])
    }

    func testOAuthConnectorClientConfigurationLoaderUsesInjectedRegistryProviders() {
        let loader = OAuthConnectorClientConfigurationLoader()
        let registry = IntegrationRegistry(integrations: [
            oauthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
        ])

        let configurations = loader.load(
            environment: [
                "KAIRO_OAUTH_CUSTOM_MAIL_CLIENT_ID": "custom-client",
                "KAIRO_OAUTH_CUSTOM_MAIL_REDIRECT_URI": "kairo://oauth/custom-mail/callback",
                "KAIRO_OAUTH_GOOGLE_CLIENT_ID": "google-client",
                "KAIRO_OAUTH_GOOGLE_REDIRECT_URI": "kairo://oauth/google/callback"
            ],
            infoDictionary: nil,
            registry: registry
        )

        XCTAssertEqual(configurations.map(\.key), ["custom-mail"])
        XCTAssertEqual(configurations["custom-mail"]?.clientID, "custom-client")
        XCTAssertNil(configurations["google"])
    }

    func testOAuthConnectorLoginCenterUsesInjectedRegistryOnly() async throws {
        let registry = IntegrationRegistry(integrations: [
            oauthIntegration(key: "custom-mail", displayName: "Custom Mail", providerKey: "custom-mail")
        ])
        let center = OAuthConnectorLoginCenter(
            registry: registry,
            credentialStore: InMemoryCredentialStore(),
            clientConfigurations: [
                "custom-mail": OAuthConnectorClientConfiguration(
                    clientID: "custom-client",
                    redirectURI: "kairo://oauth/custom-mail/callback"
                ),
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        )

        let options = try await center.loginOptions()

        XCTAssertEqual(options.map(\.integrationKey), ["custom-mail"])
        XCTAssertEqual(options.first?.providerKey, "custom-mail")
        XCTAssertEqual(options.first?.readiness, .readyToAuthorize)
    }

    func testChatGPTOAuthServiceBuildsPKCEAuthorizationURL() async throws {
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid", "profile"],
                audience: "chatgpt"
            ),
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/callback")
        XCTAssertEqual(query["scope"], "openid profile")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
        XCTAssertEqual(query["audience"], "chatgpt")
    }

    func testOAuthConnectorAuthorizationServiceBuildsPKCEAuthorizationURLFromRegistryMetadata() async throws {
        let google = try XCTUnwrap(IntegrationRegistry().integration(for: "gmail-google-workspace")?.oauth)
        let service = OAuthConnectorAuthorizationService(
            metadata: google,
            clientID: "ios-client-id",
            redirectURI: "kairo://oauth/google/callback",
            credentialStore: InMemoryCredentialStore()
        )

        let session = try await service.makeAuthorizationSession(state: "state-123", codeVerifier: "verifier-123")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(session.providerKey, "google")
        XCTAssertEqual(query["response_type"], "code")
        XCTAssertEqual(query["client_id"], "ios-client-id")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/google/callback")
        XCTAssertEqual(query["scope"], "openid email profile https://www.googleapis.com/auth/gmail.readonly")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
        XCTAssertNotEqual(query["code_challenge"], "verifier-123")
    }

    func testOAuthConnectorLoginCenterReportsStatusesForRegistryConnectors() async throws {
        let registry = IntegrationRegistry()
        let github = try XCTUnwrap(registry.integration(for: "github")?.oauth)
        let credentials = InMemoryCredentialStore()
        let githubAuth = OAuthConnectorAuthorizationService(
            metadata: github,
            clientID: "github-client",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials
        )
        try await githubAuth.storeTokens(OAuthTokenSet(accessToken: "dummy", scopes: ["repo"]))

        let center = OAuthConnectorLoginCenter(
            registry: registry,
            credentialStore: credentials,
            clientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback"
                )
            ]
        )

        let options = try await center.loginOptions()
        let google = try XCTUnwrap(options.first { $0.providerKey == "google" })
        let microsoft = try XCTUnwrap(options.first { $0.providerKey == "microsoft" })
        let connectedGitHub = try XCTUnwrap(options.first { $0.providerKey == "github" })

        XCTAssertEqual(options.map(\.providerKey), ["google", "microsoft", "notion", "slack", "chatgpt", "github"])
        XCTAssertEqual(google.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(google.readiness, .readyToAuthorize)
        XCTAssertEqual(microsoft.readiness, .needsClientConfiguration)
        XCTAssertEqual(connectedGitHub.readiness, .connected)
        XCTAssertEqual(connectedGitHub.grantedScopes, ["repo"])
        XCTAssertTrue(connectedGitHub.requiresBackendTokenExchange)
    }

    func testOAuthConnectorLoginCenterDisconnectDeletesStoredTokensAndResetsReadiness() async throws {
        let registry = IntegrationRegistry()
        let credentials = InMemoryCredentialStore()
        let githubAuth = OAuthConnectorAuthorizationService(
            metadata: try XCTUnwrap(registry.integration(for: "github")?.oauth),
            clientID: "github-client",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials,
            scopes: ["repo"]
        )
        try await githubAuth.storeTokens(OAuthTokenSet(accessToken: "dummy", scopes: ["repo"]))

        let center = OAuthConnectorLoginCenter(
            registry: registry,
            credentialStore: credentials,
            clientConfigurations: [
                "github": OAuthConnectorClientConfiguration(
                    clientID: "github-client",
                    redirectURI: "kairo://oauth/github/callback",
                    scopes: ["repo"]
                )
            ]
        )

        let connectedOptions = try await center.loginOptions()
        let connectedOption = try XCTUnwrap(connectedOptions.first { $0.providerKey == "github" })
        XCTAssertEqual(connectedOption.readiness, .connected)

        try await center.disconnect(providerKey: "github")

        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "github"))
        let disconnectedOptions = try await center.loginOptions()
        let disconnectedOption = try XCTUnwrap(disconnectedOptions.first { $0.providerKey == "github" })
        XCTAssertNil(storedRaw)
        XCTAssertEqual(disconnectedOption.readiness, .readyToAuthorize)
        XCTAssertTrue(disconnectedOption.canStartAuthorization)
    }

    func testOAuthConnectorLoginCenterTreatsMalformedStoredTokenAsNeedsReauthorization() async throws {
        let credentials = InMemoryCredentialStore()
        try await credentials.saveSecret("not-a-valid-token-secret", for: CredentialKey.oauthTokenSet(providerKey: "github"))

        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: credentials,
            clientConfigurations: [
                "github": OAuthConnectorClientConfiguration(
                    clientID: "github-client",
                    redirectURI: "kairo://oauth/github/callback",
                    scopes: ["repo"]
                )
            ]
        )

        let options = try await center.loginOptions()
        let github = try XCTUnwrap(options.first { $0.providerKey == "github" })

        XCTAssertEqual(github.readiness, .needsReauthorization)
        XCTAssertTrue(github.canStartAuthorization)
        XCTAssertTrue(github.grantedScopes.isEmpty)
    }

    func testOAuthConnectorLoginCenterBuildsAuthorizationSessionFromClientConfiguration() async throws {
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: InMemoryCredentialStore(),
            clientConfigurations: [
                "google": OAuthConnectorClientConfiguration(
                    clientID: "google-client",
                    redirectURI: "kairo://oauth/google/callback",
                    scopes: ["openid", "email"]
                )
            ]
        )

        let session = try await center.makeAuthorizationSession(
            for: "gmail-google-workspace",
            state: "state-123",
            codeVerifier: "verifier-123"
        )
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).compactMap { item in
            item.value.map { (item.name, $0) }
        })

        XCTAssertEqual(session.providerKey, "google")
        XCTAssertEqual(query["client_id"], "google-client")
        XCTAssertEqual(query["redirect_uri"], "kairo://oauth/google/callback")
        XCTAssertEqual(query["scope"], "openid email")
        XCTAssertEqual(query["state"], "state-123")
        XCTAssertEqual(query["code_challenge_method"], "S256")
    }

    func testOAuthConnectorCallbackPreviewRedactsAuthorizationCodeAndPersistsStatus() async throws {
        let fileURL = temporaryFileURL(named: "oauth-callbacks.json")
        let store = try await FileBackedOAuthConnectorCallbackStore(fileURL: fileURL)
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: InMemoryCredentialStore(),
            callbackStore: store
        )

        let preview = try await center.previewCallback(
            URL(string: "kairo://oauth/google/callback?code=sample-sensitive-code&state=state-123")!
        )

        XCTAssertEqual(preview.providerKey, "google")
        XCTAssertEqual(preview.integrationKey, "gmail-google-workspace")
        XCTAssertEqual(preview.state, "state-123")
        XCTAssertEqual(preview.authorizationCodeLength, "sample-sensitive-code".count)
        XCTAssertTrue(preview.requiresBackendTokenExchange)
        XCTAssertTrue(preview.settingsStatusText.contains("google"))
        XCTAssertTrue(preview.settingsStatusText.contains(KairoL10n.string("settings.oauth.callback.backendExchangeRequired")))
        XCTAssertFalse(preview.settingsStatusText.contains("sample-sensitive-code"))

        let latest = await store.latestPreview(for: "google")
        XCTAssertEqual(latest, preview)

        let storedJSON = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(storedJSON.contains("sample-sensitive-code"))
        XCTAssertTrue(storedJSON.contains(#""authorizationCodeLength":21"#))
    }

    func testOAuthConnectorAuthorizationServiceHandlesNonPKCEConnectorsAndStoresNamespacedTokens() async throws {
        let github = try XCTUnwrap(IntegrationRegistry().integration(for: "github")?.oauth)
        let credentials = InMemoryCredentialStore()
        let service = OAuthConnectorAuthorizationService(
            metadata: github,
            clientID: "github-client-id",
            redirectURI: "kairo://oauth/github/callback",
            credentialStore: credentials
        )

        let session = try await service.makeAuthorizationSession(state: "github-state", codeVerifier: "ignored-verifier")
        let components = try XCTUnwrap(URLComponents(url: session.authorizationURL, resolvingAgainstBaseURL: false))
        let queryNames = Set((components.queryItems ?? []).map(\.name))

        XCTAssertEqual(session.providerKey, "github")
        XCTAssertFalse(queryNames.contains("code_challenge"))
        XCTAssertFalse(queryNames.contains("code_challenge_method"))
        let authorizationCode = try await service.validateCallback(
            URL(string: "kairo://oauth/github/callback?code=abc&state=github-state")!,
            expectedState: "github-state"
        )
        XCTAssertEqual(authorizationCode, "abc")

        let tokens = OAuthTokenSet(accessToken: "dummy", refreshToken: "dummy", scopes: ["repo"])
        try await service.storeTokens(tokens)
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "github"))
        let loaded = try await service.loadTokens()

        XCTAssertNotNil(storedRaw)
        XCTAssertEqual(loaded, tokens)

        try await service.signOut()
        let tokensAfterSignOut = try await service.loadTokens()
        XCTAssertNil(tokensAfterSignOut)
    }

    func testOAuthConnectorLoginCenterExchangesChatGPTCallbackAndDoesNotPersistAuthorizationCode() async throws {
        let credentials = InMemoryCredentialStore()
        let httpClient = ChatBackendCapturingHTTPClient(body: """
        {
          "access_token": "access-token",
          "refresh_token": "refresh-token",
          "expires_in": 3600,
          "scope": "openid profile email"
        }
        """)
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: credentials,
            clientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ],
            tokenExchangeHTTPClient: httpClient
        )
        let session = try await center.makeAuthorizationSession(
            for: "chatgpt",
            state: "state-123",
            codeVerifier: "verifier-123"
        )

        let tokens = try await center.exchangeCallback(
            URL(string: "kairo://oauth/chatgpt/callback?code=auth-code-abc&state=state-123")!,
            expectedState: session.state,
            codeVerifier: session.codeVerifier
        )

        XCTAssertEqual(tokens.accessToken, "access-token")
        XCTAssertEqual(tokens.refreshToken, "refresh-token")
        XCTAssertEqual(tokens.scopes, ["openid", "profile", "email"])

        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.url?.absoluteString, "https://auth.openai.com/oauth/token")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/x-www-form-urlencoded")
        let requestBody = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
        XCTAssertTrue(requestBody.contains("grant_type=authorization_code"))
        XCTAssertTrue(requestBody.contains("client_id=chatgpt-client"))
        XCTAssertTrue(requestBody.contains("code=auth-code-abc"))
        XCTAssertTrue(requestBody.contains("code_verifier=verifier-123"))

        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "chatgpt"))
        XCTAssertNotNil(storedRaw)
        XCTAssertFalse(storedRaw?.contains("auth-code-abc") == true)
        let options = try await center.loginOptions()
        XCTAssertEqual(options.first { $0.providerKey == "chatgpt" }?.readiness, .connected)
    }

    @MainActor
    func testOAuthConnectorInteractiveLoginServiceCompletesChatGPTLoginFromSystemCallback() async throws {
        let credentials = InMemoryCredentialStore()
        let httpClient = ChatBackendCapturingHTTPClient(body: """
        {
          "access_token": "access-token",
          "scope": "openid profile"
        }
        """)
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: credentials,
            clientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ],
            tokenExchangeHTTPClient: httpClient
        )
        let runner = FakeOAuthWebAuthenticationRunner { authorizationURL, callbackScheme in
            let components = try XCTUnwrap(URLComponents(url: authorizationURL, resolvingAgainstBaseURL: false))
            let state = try XCTUnwrap(components.queryItems?.first { $0.name == "state" }?.value)
            return URL(string: "\(callbackScheme)://oauth/chatgpt/callback?code=auth-code-abc&state=\(state)")!
        }

        let tokens = try await OAuthConnectorInteractiveLoginService(
            loginCenter: center,
            webAuthenticationRunner: runner
        ).signIn(for: "chatgpt")

        XCTAssertEqual(tokens.accessToken, "access-token")
        XCTAssertEqual(runner.receivedCallbackScheme, "kairo")
        XCTAssertEqual(runner.receivedAuthorizationURL?.host, "auth.openai.com")
        let request = try await httpClient.lastRequest()
        let requestBody = String(data: try XCTUnwrap(request.httpBody), encoding: .utf8) ?? ""
        XCTAssertTrue(requestBody.contains("code=auth-code-abc"))
        let storedRaw = try await credentials.readSecret(for: CredentialKey.oauthTokenSet(providerKey: "chatgpt"))
        XCTAssertNotNil(storedRaw)
        XCTAssertFalse(storedRaw?.contains("auth-code-abc") == true)
    }

    func testOAuthConnectorLoginCenterRejectsPKCETokenExchangeWithoutVerifier() async throws {
        let center = OAuthConnectorLoginCenter(
            registry: IntegrationRegistry(),
            credentialStore: InMemoryCredentialStore(),
            clientConfigurations: [
                "chatgpt": OAuthConnectorClientConfiguration(
                    clientID: "chatgpt-client",
                    redirectURI: "kairo://oauth/chatgpt/callback"
                )
            ],
            tokenExchangeHTTPClient: ChatBackendCapturingHTTPClient(body: #"{"access_token":"unused"}"#)
        )

        do {
            _ = try await center.exchangeCallback(
                URL(string: "kairo://oauth/chatgpt/callback?code=auth-code-abc&state=state-123")!,
                expectedState: "state-123",
                codeVerifier: nil
            )
            XCTFail("Expected PKCE token exchange without a verifier to fail closed.")
        } catch let error as OAuthConnectorAuthorizationError {
            XCTAssertEqual(error, .missingCodeVerifier)
        }
    }

    func testChatGPTOAuthServiceValidatesCallbackAndStoresTokens() async throws {
        let credentials = InMemoryCredentialStore()
        let service = ChatGPTOAuthService(
            configuration: ChatGPTOAuthConfiguration(
                authorizationEndpoint: URL(string: "https://auth.example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://auth.example.com/oauth/token")!,
                clientID: "client-id",
                redirectURI: "kairo://oauth/callback",
                scopes: ["openid"]
            ),
            credentialStore: credentials
        )

        let code = try await service.validateCallback(URL(string: "kairo://oauth/callback?code=abc&state=expected")!, expectedState: "expected")
        XCTAssertEqual(code, "abc")

        try await service.storeTokens(OAuthTokenSet(accessToken: "access", refreshToken: "refresh", scopes: ["openid"]))
        let tokens = try await service.loadTokens()
        XCTAssertEqual(tokens?.accessToken, "access")
        XCTAssertEqual(tokens?.refreshToken, "refresh")

        try await service.signOut()
        let signedOutTokens = try await service.loadTokens()
        XCTAssertNil(signedOutTokens)
    }

    func testOAuthTokenSetStorageHelpersRoundTripAndRejectMalformedSecrets() throws {
        let tokenSet = OAuthTokenSet(
            accessToken: "access",
            refreshToken: "refresh",
            expiresAt: Date(timeIntervalSince1970: 42),
            scopes: ["repo"]
        )

        let encoded = try tokenSet.encodedForStorage()
        let decoded = try XCTUnwrap(OAuthTokenSet.decodeStoredSecret(encoded))

        XCTAssertEqual(decoded, tokenSet)
        XCTAssertNil(try OAuthTokenSet.decodeStoredSecret("not-base64"))
    }

    func testKairoEnvironmentConnectedOAuthProviderKeysIgnoreMalformedStoredTokens() async throws {
        let credentials = InMemoryCredentialStore()
        let validTokens = OAuthTokenSet(accessToken: "github-token", scopes: ["repo"])

        try await credentials.saveSecret(validTokens.encodedForStorage(), for: CredentialKey.oauthTokenSet(providerKey: "github"))
        try await credentials.saveSecret("not-a-valid-token-secret", for: CredentialKey.oauthTokenSet(providerKey: "google"))
        try await credentials.saveSecret(try OAuthTokenSet(accessToken: "   ", scopes: []).encodedForStorage(), for: CredentialKey.oauthTokenSet(providerKey: "slack"))

        let connected = try await KairoEnvironment.connectedOAuthProviderKeys(credentialStore: credentials)

        XCTAssertEqual(connected, ["github"])
    }

    func testConnectedOAuthProviderKeysIncludeCatalogOAuthSkillsAndLegacyUnmigratedConnectors() async throws {
        let credentials = InMemoryCredentialStore()
        let todoistTokens = OAuthTokenSet(accessToken: "todoist-token", scopes: ["data:read_write"])
        let githubTokens = OAuthTokenSet(accessToken: "github-token", scopes: ["repo"])
        let registry = IntegrationRegistry(integrations: [
            oauthIntegration(key: "github", displayName: "GitHub", providerKey: "github")
        ])
        let catalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .todoistTaskAPI))
        ])

        try await credentials.saveSecret(
            todoistTokens.encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "todoist")
        )
        try await credentials.saveSecret(
            githubTokens.encodedForStorage(),
            for: CredentialKey.oauthTokenSet(providerKey: "github")
        )

        let connected = try await KairoEnvironment.connectedOAuthProviderKeys(
            credentialStore: credentials,
            registry: registry,
            appIntegrationSkillCatalog: catalog
        )

        XCTAssertEqual(connected, ["github", "todoist"])
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func oauthIntegration(key: String, displayName: String, providerKey: String) -> AppIntegration {
        AppIntegration(
            key: key,
            displayName: displayName,
            category: .communication,
            surfaces: [.oauthAPI],
            requiredCapabilities: [.externalConnectors],
            oauth: OAuthConnectorMetadata(
                providerKey: providerKey,
                authorizationEndpoint: URL(string: "https://example.com/oauth/authorize")!,
                tokenEndpoint: URL(string: "https://example.com/oauth/token")!,
                defaultScopes: ["read"],
                requiresBackendTokenExchange: true,
                accountDataBoundary: "Test connector scopes only."
            ),
            sandboxNotes: "Test connector.",
            status: .requiresBackend
        )
    }
}

@MainActor
private final class FakeOAuthWebAuthenticationRunner: OAuthWebAuthenticationRunner {
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
