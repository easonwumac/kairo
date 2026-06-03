import Foundation

public struct AgentToolInvocationPlanner: Sendable {
    public var skillCatalog: AgentSkillCatalog
    public var integrationRegistry: IntegrationRegistry
    public var safetyPolicyEngine: SafetyPolicyEngine

    public init(
        skillCatalog: AgentSkillCatalog = .default,
        integrationRegistry: IntegrationRegistry = IntegrationRegistry(),
        safetyPolicyEngine: SafetyPolicyEngine = SafetyPolicyEngine()
    ) {
        self.skillCatalog = skillCatalog
        self.integrationRegistry = integrationRegistry
        self.safetyPolicyEngine = safetyPolicyEngine
    }

    public func plan(for request: AgentToolInvocationRequest) -> AgentToolInvocationPlan {
        guard request.allowsToolUse else {
            return AgentToolInvocationPlan(
                candidates: [],
                unsupportedMessage: "Local model fallback cannot use tools, browse the web, or perform account actions."
            )
        }

        let normalizedText = normalize(request.userText)
        guard !normalizedText.isEmpty else {
            return AgentToolInvocationPlan(candidates: [])
        }

        var candidates: [AgentToolInvocationCandidate] = []
        candidates.append(contentsOf: skillCatalog.installedSkills.compactMap { skill in
            candidate(for: skill, normalizedText: normalizedText)
        })
        candidates.append(contentsOf: integrationRegistry.oauthConnectors.compactMap { integration in
            candidate(for: integration, normalizedText: normalizedText)
        })
        if let emailCandidate = emailActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(emailCandidate)
        }
        if let mapDirectionsCandidate = mapDirectionsActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(mapDirectionsCandidate)
        }
        if let messageCandidate = messageHandoffActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(messageCandidate)
        }
        if let phoneCandidate = phoneCallHandoffActionCandidate(userText: request.userText, normalizedText: normalizedText) {
            candidates.append(phoneCandidate)
        }
        if let webSearchCandidate = webSearchHandoffActionCandidate(userText: request.userText, normalizedText: normalizedText) {
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

        return AgentToolInvocationPlan(candidates: uniqueCandidates(candidates))
    }
}
