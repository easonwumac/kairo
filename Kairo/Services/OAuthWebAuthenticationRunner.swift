import Foundation

@MainActor
public protocol OAuthWebAuthenticationRunner: AnyObject {
    func authenticate(authorizationURL: URL, callbackScheme: String) async throws -> URL
}

public enum OAuthWebAuthenticationError: Error, Equatable {
    case unavailable
    case missingCallbackURL
    case failedToStart
}

#if canImport(AuthenticationServices)
import AuthenticationServices
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif

@MainActor
public final class SystemOAuthWebAuthenticationRunner: NSObject, OAuthWebAuthenticationRunner {
    private var activeSession: ASWebAuthenticationSession?

    public override init() {}

    public func authenticate(authorizationURL: URL, callbackScheme: String) async throws -> URL {
        try await withCheckedThrowingContinuation { continuation in
            let session = ASWebAuthenticationSession(
                url: authorizationURL,
                callbackURLScheme: callbackScheme
            ) { [weak self] callbackURL, error in
                Task { @MainActor in
                    self?.activeSession = nil
                    if let callbackURL {
                        continuation.resume(returning: callbackURL)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(throwing: OAuthWebAuthenticationError.missingCallbackURL)
                    }
                }
            }
            session.presentationContextProvider = self
            activeSession = session
            guard session.start() else {
                activeSession = nil
                continuation.resume(throwing: OAuthWebAuthenticationError.failedToStart)
                return
            }
        }
    }
}

extension SystemOAuthWebAuthenticationRunner: ASWebAuthenticationPresentationContextProviding {
    public func presentationAnchor(for session: ASWebAuthenticationSession) -> ASPresentationAnchor {
        #if canImport(UIKit)
        let foregroundScenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .filter { $0.activationState == .foregroundActive }
        if let window = foregroundScenes
            .flatMap(\.windows)
            .first(where: \.isKeyWindow) {
            return window
        }
        return foregroundScenes.first?.windows.first ?? ASPresentationAnchor()
        #elseif canImport(AppKit)
        return NSApplication.shared.keyWindow ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }
}
#endif
