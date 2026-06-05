import Foundation

extension AgentToolInvocationPlanner {
    func visibleHandoffAction(
        for skill: AppIntegrationSkill,
        userText: String,
        normalizedText: String
    ) -> AgentAction? {
        guard skill.availabilityStatus == .available,
              skill.executionMode == .openURL,
              skill.confirmationPolicy == .previewAndExplicitConfirmation else {
            return nil
        }

        switch skill.id {
        case .appleMailHandoff:
            guard isEmailDraftRequest(normalizedText) else { return nil }
            return AgentAction(
                kind: .composeEmailDraft,
                title: KairoL10n.string("chat.action.displayName.composeEmail"),
                rationale: KairoL10n.string("chat.action.rationale.email"),
                payload: .email(emailDraft(from: userText)),
                riskTier: skill.riskTier
            )
        case .appleMessagesHandoff:
            guard !isEmailDraftRequest(normalizedText), isMessageHandoffRequest(normalizedText) else { return nil }
            return AgentAction(
                kind: .openMessageHandoff,
                title: KairoL10n.string("chat.action.displayName.openMessages"),
                rationale: KairoL10n.string("chat.action.rationale.messages"),
                payload: .message(messageDraft(from: userText)),
                riskTier: skill.riskTier
            )
        case .applePhoneHandoff:
            guard !isContactWriteRequest(normalizedText), isPhoneCallHandoffRequest(normalizedText) else { return nil }
            let draft = phoneCallDraft(from: userText)
            guard isPhoneToken(draft.phoneNumber) else { return nil }
            return AgentAction(
                kind: .openPhoneCallHandoff,
                title: KairoL10n.string("chat.action.displayName.openPhone"),
                rationale: KairoL10n.string("chat.action.rationale.phone"),
                payload: .phoneCall(draft),
                riskTier: skill.riskTier
            )
        case .safariWebSearchHandoff:
            guard !isMapDirectionsRequest(normalizedText),
                  !isEmailDraftRequest(normalizedText),
                  !isMessageHandoffRequest(normalizedText),
                  !isPhoneCallHandoffRequest(normalizedText),
                  !isContactWriteRequest(normalizedText),
                  isWebSearchHandoffRequest(normalizedText) else {
                return nil
            }
            return AgentAction(
                kind: .openWebSearchHandoff,
                title: KairoL10n.string("chat.action.displayName.openWebSearch"),
                rationale: KairoL10n.string("chat.action.rationale.web"),
                payload: .webSearch(webSearchDraft(from: userText)),
                riskTier: skill.riskTier
            )
        case .appleMapsDirectionsHandoff:
            guard isMapDirectionsRequest(normalizedText) else { return nil }
            return AgentAction(
                kind: .openMapDirections,
                title: KairoL10n.string("chat.action.displayName.openMaps"),
                rationale: KairoL10n.string("chat.action.rationale.maps"),
                payload: .mapDirections(mapDirectionsDraft(from: userText, normalizedText: normalizedText)),
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
