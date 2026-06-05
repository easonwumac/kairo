import Foundation

public protocol AgentToolInvocationActionParsing: Sendable {
    func isEmailDraftRequest(_ normalizedText: String) -> Bool
    func isMapDirectionsRequest(_ normalizedText: String) -> Bool
    func isMessageHandoffRequest(_ normalizedText: String) -> Bool
    func isPhoneCallHandoffRequest(_ normalizedText: String) -> Bool
    func isWebSearchHandoffRequest(_ normalizedText: String) -> Bool
    func isContactWriteRequest(_ normalizedText: String) -> Bool
    func emailDraft(from userText: String) -> EmailDraft
    func mapDirectionsDraft(from userText: String, normalizedText: String) -> MapDirectionsDraft
    func messageDraft(from userText: String) -> MessageDraft
    func phoneCallDraft(from userText: String) -> PhoneCallDraft
    func webSearchDraft(from userText: String) -> WebSearchDraft
    func isPhoneToken(_ value: String) -> Bool
    func normalize(_ value: String) -> String
}

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
        case .googleMapsDirectionsHandoff,
             .gmailDraftAPI,
             .whatsappMessageHandoff,
             .lineShareHandoff,
             .slackOpenHandoff,
             .notionPageAPI,
             .todoistTaskAPI,
             .draftsCreateHandoff:
            return nil
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

extension AgentToolInvocationPlanner: AgentToolInvocationActionParsing {}
