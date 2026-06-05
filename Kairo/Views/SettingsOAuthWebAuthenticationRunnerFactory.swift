#if canImport(SwiftUI)
public struct SettingsOAuthWebAuthenticationRunnerFactory: Sendable {
    public init() {}

    @MainActor
    public func makeDefaultRunner() -> (any OAuthWebAuthenticationRunner)? {
        #if canImport(AuthenticationServices)
        return SystemOAuthWebAuthenticationRunner()
        #else
        return nil
        #endif
    }
}
#endif
