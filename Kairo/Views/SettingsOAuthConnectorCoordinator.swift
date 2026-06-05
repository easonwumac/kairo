#if canImport(SwiftUI)
import Foundation

public enum SettingsOAuthAuthorizationOutcome: Sendable {
    case completed
    case fallback(OAuthConnectorAuthorizationSession)
}

public struct SettingsOAuthCallbackCompletion: Sendable {
    public var providerKey: String
    public var tokens: OAuthTokenSet
}

public enum SettingsOAuthConnectorCoordinatorError: Error, Equatable {
    case noPendingSession
}

public actor SettingsOAuthConnectorCoordinator {
    private let loginService: any OAuthConnectorLoginServicing
    private let webAuthenticationRunner: (any OAuthWebAuthenticationRunner)?
    private var pendingSessions: [String: OAuthConnectorAuthorizationSession] = [:]

    public init(
        loginService: any OAuthConnectorLoginServicing,
        webAuthenticationRunner: (any OAuthWebAuthenticationRunner)? = nil
    ) {
        self.loginService = loginService
        self.webAuthenticationRunner = webAuthenticationRunner
    }

    public func loginOptions() async throws -> [OAuthConnectorLoginOption] {
        try await loginService.loginOptions()
    }

    public func authorize(_ option: OAuthConnectorLoginOption) async throws -> SettingsOAuthAuthorizationOutcome {
        guard let webAuthenticationRunner else {
            let session = try await loginService.makeAuthorizationSession(for: option.integrationKey)
            pendingSessions[option.providerKey] = session
            return .fallback(session)
        }

        _ = try await OAuthConnectorInteractiveLoginService(
            loginCenter: loginService,
            webAuthenticationRunner: webAuthenticationRunner
        ).signIn(for: option.integrationKey)
        pendingSessions[option.providerKey] = nil
        return .completed
    }

    public func disconnect(providerKey: String) async throws {
        try await loginService.disconnect(providerKey: providerKey)
        pendingSessions[providerKey] = nil
    }

    public func previewCallback(_ callbackURL: URL) async throws -> OAuthConnectorCallbackPreview {
        try await loginService.previewCallback(callbackURL)
    }

    public func completeCallbackLogin(_ callbackURL: URL) async throws -> SettingsOAuthCallbackCompletion {
        guard let providerKey = Self.providerKey(from: callbackURL),
              let session = pendingSessions[providerKey] else {
            throw SettingsOAuthConnectorCoordinatorError.noPendingSession
        }

        let tokens = try await loginService.exchangeCallback(
            callbackURL,
            expectedState: session.state,
            codeVerifier: session.codeVerifier
        )
        pendingSessions[providerKey] = nil
        return SettingsOAuthCallbackCompletion(providerKey: providerKey, tokens: tokens)
    }

    func hasPendingSession(for providerKey: String) -> Bool {
        pendingSessions[providerKey] != nil
    }

    private static func providerKey(from callbackURL: URL) -> String? {
        guard let components = URLComponents(url: callbackURL, resolvingAgainstBaseURL: false),
              components.scheme == "kairo",
              components.host == "oauth" else {
            return nil
        }
        let pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
        guard pathComponents.count == 2,
              pathComponents[1] == "callback" else {
            return nil
        }
        return pathComponents[0]
    }
}
#endif
