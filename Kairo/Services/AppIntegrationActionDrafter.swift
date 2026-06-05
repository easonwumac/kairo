import Foundation

public protocol AppIntegrationActionDrafting: Sendable {
    func draftAction(for skill: AppIntegrationSkill, inputText: String) -> AgentAction?
}

public struct DefaultAppIntegrationActionDrafter: AppIntegrationActionDrafting {
    private let planner: AgentToolInvocationPlanner

    public init() {
        self.planner = AgentToolInvocationPlanner(
            integrationRegistry: IntegrationRegistry(integrations: []),
            appIntegrationSkillCatalog: AppIntegrationSkillCatalog(skills: [])
        )
    }

    public func draftAction(for skill: AppIntegrationSkill, inputText: String) -> AgentAction? {
        planner.visibleHandoffAction(
            for: skill,
            userText: inputText,
            normalizedText: planner.normalize(inputText)
        )
    }
}
