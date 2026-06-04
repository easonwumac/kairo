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
        XCTAssertTrue(dryRun.message.contains("No network request was sent"))
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

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }
}
