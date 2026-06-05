import Foundation

public protocol AppIntegrationActionMapping: Sendable {
    func visibleHandoffAction(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentAction?
}

public struct DefaultAppIntegrationActionMapper: AppIntegrationActionMapping {
    public init() {}

    public func visibleHandoffAction(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentAction? {
        guard skill.availabilityStatus == .available,
              skill.executionMode == .openURL,
              skill.confirmationPolicy == .previewAndExplicitConfirmation else {
            return nil
        }

        switch skill.id {
        case .appleMailHandoff:
            guard parser.isEmailDraftRequest(normalizedText) else { return nil }
            return AgentAction(
                kind: .composeEmailDraft,
                title: KairoL10n.string("chat.action.displayName.composeEmail"),
                rationale: KairoL10n.string("chat.action.rationale.email"),
                payload: .email(parser.emailDraft(from: userText)),
                riskTier: skill.riskTier
            )
        case .appleMessagesHandoff:
            guard !parser.isEmailDraftRequest(normalizedText), parser.isMessageHandoffRequest(normalizedText) else { return nil }
            return AgentAction(
                kind: .openMessageHandoff,
                title: KairoL10n.string("chat.action.displayName.openMessages"),
                rationale: KairoL10n.string("chat.action.rationale.messages"),
                payload: .message(parser.messageDraft(from: userText)),
                riskTier: skill.riskTier
            )
        case .applePhoneHandoff:
            guard !parser.isContactWriteRequest(normalizedText), parser.isPhoneCallHandoffRequest(normalizedText) else { return nil }
            let draft = parser.phoneCallDraft(from: userText)
            guard parser.isPhoneToken(draft.phoneNumber) else { return nil }
            return AgentAction(
                kind: .openPhoneCallHandoff,
                title: KairoL10n.string("chat.action.displayName.openPhone"),
                rationale: KairoL10n.string("chat.action.rationale.phone"),
                payload: .phoneCall(draft),
                riskTier: skill.riskTier
            )
        case .safariWebSearchHandoff:
            guard !parser.isMapDirectionsRequest(normalizedText),
                  !parser.isEmailDraftRequest(normalizedText),
                  !parser.isMessageHandoffRequest(normalizedText),
                  !parser.isPhoneCallHandoffRequest(normalizedText),
                  !parser.isContactWriteRequest(normalizedText),
                  parser.isWebSearchHandoffRequest(normalizedText) else {
                return nil
            }
            return AgentAction(
                kind: .openWebSearchHandoff,
                title: KairoL10n.string("chat.action.displayName.openWebSearch"),
                rationale: KairoL10n.string("chat.action.rationale.web"),
                payload: .webSearch(parser.webSearchDraft(from: userText)),
                riskTier: skill.riskTier
            )
        case .appleMapsDirectionsHandoff:
            guard parser.isMapDirectionsRequest(normalizedText) else { return nil }
            return AgentAction(
                kind: .openMapDirections,
                title: KairoL10n.string("chat.action.displayName.openMaps"),
                rationale: KairoL10n.string("chat.action.rationale.maps"),
                payload: .mapDirections(parser.mapDirectionsDraft(from: userText, normalizedText: normalizedText)),
                riskTier: skill.riskTier
            )
        case .googleMapsDirectionsHandoff:
            guard parser.isMapDirectionsRequest(normalizedText) else { return nil }
            let draft = parser.mapDirectionsDraft(from: userText, normalizedText: normalizedText)
            guard let url = Self.googleMapsDirectionsURL(for: draft) else { return nil }
            return AgentAction(
                kind: .openURL,
                title: KairoL10n.string("chat.action.displayName.openURL"),
                rationale: KairoL10n.string("chat.action.rationale.googleMaps"),
                payload: .url(url.absoluteString),
                riskTier: skill.riskTier
            )
        case .gmailDraftAPI,
             .whatsappMessageHandoff,
             .lineShareHandoff,
             .slackOpenHandoff,
             .notionPageAPI,
             .todoistTaskAPI,
             .draftsCreateHandoff:
            return nil
        }
    }

    private static func googleMapsDirectionsURL(for draft: MapDirectionsDraft) -> URL? {
        let destination = draft.destinationQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !destination.isEmpty else { return nil }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/dir/"
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "destination", value: destination),
            URLQueryItem(name: "travelmode", value: draft.mode.googleMapsTravelMode)
        ]
        return components.url
    }
}

private extension MapDirectionsMode {
    var googleMapsTravelMode: String {
        switch self {
        case .driving:
            return "driving"
        case .walking:
            return "walking"
        case .transit:
            return "transit"
        }
    }
}

public struct NoOpAppIntegrationActionMapper: AppIntegrationActionMapping {
    public init() {}

    public func visibleHandoffAction(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentAction? {
        nil
    }
}
