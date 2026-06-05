import Foundation

public struct AgentToolInvocationPlanner: Sendable {
    public var skillCatalog: AgentSkillCatalog
    public var integrationRegistry: any AppIntegrationRegistryProviding
    public var appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding
    public var appIntegrationActionMapper: any AppIntegrationActionMapping
    public var appIntegrationActionParser: any AgentToolInvocationActionParsing
    public var candidateFilter: any AgentToolCandidateFiltering
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        skillCatalog: AgentSkillCatalog = .default,
        integrationRegistry: any AppIntegrationRegistryProviding = IntegrationRegistry(),
        appIntegrationSkillCatalog: any AppIntegrationSkillCatalogProviding = AppIntegrationSkillCatalog(),
        appIntegrationActionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        appIntegrationActionParser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser(),
        toolCatalog: any BuiltInPhoneToolCatalogProviding = BuiltInPhoneToolCatalog(),
        candidateFilter: (any AgentToolCandidateFiltering)? = nil,
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.skillCatalog = skillCatalog
        self.integrationRegistry = integrationRegistry
        self.appIntegrationSkillCatalog = appIntegrationSkillCatalog
        self.appIntegrationActionMapper = appIntegrationActionMapper
        self.appIntegrationActionParser = appIntegrationActionParser
        self.candidateFilter = candidateFilter ?? PhoneToolCandidateFilter(
            actionGate: BuiltInPhoneToolActionGate(toolCatalog: toolCatalog)
        )
        self.safetyPolicyEngine = safetyPolicyEngine
    }

    public func plan(for request: AgentToolInvocationRequest) -> AgentToolInvocationPlan {
        guard request.allowsToolUse else {
            return AgentToolInvocationPlan(
                candidates: [],
                unsupportedMessage: KairoL10n.string("chat.provider.localFallback.toolsUnavailable")
            )
        }

        let normalizedText = normalize(request.matchingText)
        guard !normalizedText.isEmpty else {
            return AgentToolInvocationPlan(candidates: [])
        }

        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: skillCatalog.installedSkills.compactMap { skill in
            candidate(for: skill, normalizedText: normalizedText)
        })
        candidates.append(contentsOf: appIntegrationSkillCatalog.skills.compactMap { skill in
            candidate(for: skill, userText: request.userText, normalizedText: normalizedText)
        })
        let migratedIntegrationKeys = Set(appIntegrationSkillCatalog.skills.map(\.integrationKey))
        candidates.append(contentsOf: integrationRegistry.oauthConnectors.compactMap { integration in
            guard !migratedIntegrationKeys.contains(integration.key) else { return nil }
            return candidate(for: integration, normalizedText: normalizedText)
        })
        if let emailCandidate = emailActionCandidate(userText: request.userText, normalizedText: normalizedText),
           !candidates.containsAction(kind: emailCandidate.action?.kind) {
            candidates.append(emailCandidate)
        }
        if let mapDirectionsCandidate = mapDirectionsActionCandidate(userText: request.userText, normalizedText: normalizedText),
           !candidates.containsAction(kind: mapDirectionsCandidate.action?.kind) {
            candidates.append(mapDirectionsCandidate)
        }
        if let messageCandidate = messageHandoffActionCandidate(userText: request.userText, normalizedText: normalizedText),
           !candidates.containsAction(kind: messageCandidate.action?.kind) {
            candidates.append(messageCandidate)
        }
        if let phoneCandidate = phoneCallHandoffActionCandidate(userText: request.userText, normalizedText: normalizedText),
           !candidates.containsAction(kind: phoneCandidate.action?.kind) {
            candidates.append(phoneCandidate)
        }
        if let webSearchCandidate = webSearchHandoffActionCandidate(userText: request.userText, normalizedText: normalizedText),
           !candidates.containsAction(kind: webSearchCandidate.action?.kind) {
            candidates.append(webSearchCandidate)
        }
        if let contactCandidate = contactActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(contactCandidate)
        }
        if let calendarCandidate = calendarActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(calendarCandidate)
        }
        if let reminderCandidate = reminderActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(reminderCandidate)
        }
        if let notificationCandidate = notificationActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(notificationCandidate)
        }

        return AgentToolInvocationPlan(
            candidates: uniqueCandidates(candidates).filter(candidateFilter.allowsCandidate)
        )
    }
}
