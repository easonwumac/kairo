import Foundation

public protocol AgentVisibleHandoffCandidateProviding: Sendable {
    func candidates(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> [AgentToolInvocationCandidate]
}

public struct DefaultAgentVisibleHandoffCandidateProvider: AgentVisibleHandoffCandidateProviding {
    public init() {}

    public func candidates(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> [AgentToolInvocationCandidate] {
        [
            emailCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            mapDirectionsCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            messageCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            phoneCandidate(userText: userText, normalizedText: normalizedText, parser: parser),
            webSearchCandidate(userText: userText, normalizedText: normalizedText, parser: parser)
        ].compactMap { $0 }
    }

    private func emailCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard parser.isEmailDraftRequest(normalizedText) else {
            return nil
        }

        let action = AgentAction(
            kind: .composeEmailDraft,
            title: KairoL10n.string("chat.action.displayName.composeEmail"),
            rationale: KairoL10n.string("chat.action.rationale.email"),
            payload: .email(parser.emailDraft(from: userText)),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-compose-email-draft",
            title: KairoL10n.string("chat.action.displayName.composeEmail"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.mail],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.email"),
            action: action
        )
    }

    private func mapDirectionsCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard parser.isMapDirectionsRequest(normalizedText) else {
            return nil
        }

        let action = AgentAction(
            kind: .openMapDirections,
            title: KairoL10n.string("chat.action.displayName.openMaps"),
            rationale: KairoL10n.string("chat.action.rationale.maps"),
            payload: .mapDirections(parser.mapDirectionsDraft(from: userText, normalizedText: normalizedText)),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-map-directions",
            title: KairoL10n.string("chat.action.displayName.openMaps"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.location],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.maps"),
            action: action
        )
    }

    private func messageCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard !parser.isEmailDraftRequest(normalizedText), parser.isMessageHandoffRequest(normalizedText) else {
            return nil
        }

        let action = AgentAction(
            kind: .openMessageHandoff,
            title: KairoL10n.string("chat.action.displayName.openMessages"),
            rationale: KairoL10n.string("chat.action.rationale.messages"),
            payload: .message(parser.messageDraft(from: userText)),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-message-handoff",
            title: KairoL10n.string("chat.action.displayName.openMessages"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.messages],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.messages"),
            action: action
        )
    }

    private func phoneCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard !parser.isContactWriteRequest(normalizedText), parser.isPhoneCallHandoffRequest(normalizedText) else {
            return nil
        }

        let draft = parser.phoneCallDraft(from: userText)
        guard parser.isPhoneToken(draft.phoneNumber) else {
            return nil
        }

        let action = AgentAction(
            kind: .openPhoneCallHandoff,
            title: KairoL10n.string("chat.action.displayName.openPhone"),
            rationale: KairoL10n.string("chat.action.rationale.phone"),
            payload: .phoneCall(draft),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-phone-call-handoff",
            title: KairoL10n.string("chat.action.displayName.openPhone"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.phone],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.phone"),
            action: action
        )
    }

    private func webSearchCandidate(
        userText: String,
        normalizedText: String,
        parser: any AgentToolInvocationActionParsing
    ) -> AgentToolInvocationCandidate? {
        guard !parser.isMapDirectionsRequest(normalizedText),
              !parser.isEmailDraftRequest(normalizedText),
              !parser.isMessageHandoffRequest(normalizedText),
              !parser.isPhoneCallHandoffRequest(normalizedText),
              !parser.isContactWriteRequest(normalizedText),
              parser.isWebSearchHandoffRequest(normalizedText) else {
            return nil
        }

        let action = AgentAction(
            kind: .openWebSearchHandoff,
            title: KairoL10n.string("chat.action.displayName.openWebSearch"),
            rationale: KairoL10n.string("chat.action.rationale.web"),
            payload: .webSearch(parser.webSearchDraft(from: userText)),
            riskTier: .tier1Draft
        )

        return AgentToolInvocationCandidate(
            id: "action-open-web-search-handoff",
            title: KairoL10n.string("chat.action.displayName.openWebSearch"),
            source: .actionCatalog,
            skillKind: .custom,
            requiredCapabilities: [.web],
            riskTier: .tier1Draft,
            requiresConfirmation: true,
            handoffSummary: KairoL10n.string("chat.action.handoffSummary.web"),
            action: action
        )
    }
}
