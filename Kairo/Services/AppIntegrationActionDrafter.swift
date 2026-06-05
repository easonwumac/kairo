import Foundation

public protocol AppIntegrationActionDrafting: Sendable {
    func draftAction(for skill: AppIntegrationSkill, inputText: String) -> AgentAction?
}

public struct DefaultAppIntegrationActionDrafter: AppIntegrationActionDrafting {
    private let actionMapper: any AppIntegrationActionMapping
    private let parser: any AgentToolInvocationActionParsing

    public init(
        actionMapper: any AppIntegrationActionMapping = DefaultAppIntegrationActionMapper(),
        parser: any AgentToolInvocationActionParsing = DefaultAgentToolInvocationActionParser()
    ) {
        self.actionMapper = actionMapper
        self.parser = parser
    }

    public func draftAction(for skill: AppIntegrationSkill, inputText: String) -> AgentAction? {
        let normalizedText = parser.normalize(inputText)
        return actionMapper.visibleHandoffAction(
            for: skill,
            userText: inputText,
            normalizedText: normalizedText,
            parser: parser
        )
    }
}
