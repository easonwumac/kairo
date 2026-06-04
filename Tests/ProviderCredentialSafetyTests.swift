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
        XCTAssertTrue(result.message.contains("No network request was sent"))
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

    func testOAuthConnectorReadinessProvidesSettingsCopyAndActionState() {
        XCTAssertEqual(OAuthConnectorLoginReadiness.connected.settingsStatusText, "已連線")
        XCTAssertEqual(OAuthConnectorLoginReadiness.readyToAuthorize.settingsStatusText, "可授權")
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsClientConfiguration.settingsStatusText, "需要 Client 設定")
        XCTAssertEqual(OAuthConnectorLoginReadiness.needsReauthorization.settingsStatusText, "需要重新授權")

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
        XCTAssertEqual(connectedOption.settingsDetailText, "已授權 scopes: repo")
    }
}
