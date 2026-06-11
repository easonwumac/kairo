import Foundation

public struct AgentCoreDependencies: Sendable {
    public var memoryContextProvider: any AgentMemoryContextProviding
    public var wikiContextProvider: any AgentWikiContextProviding
    public var memoryWriter: any AgentMemoryWriting
    public var aiProvider: any AIProvider
    public var skillCatalogProvider: AgentSkillCatalogProvider
    public var toolContextProvider: any AgentCapabilityPromptContextProviding
    public var toolInvocationPlanner: any AgentToolInvocationPlanning
    public var toolPlanningRequestBuilder: any AgentToolPlanningRequestBuilding
    public var responseActionPlanner: any AgentResponseActionPlanning
    public var completionRequestBuilder: any AgentCompletionRequestBuilding

    public init(
        memoryContextProvider: any AgentMemoryContextProviding,
        wikiContextProvider: any AgentWikiContextProviding = EmptyAgentWikiContextProvider(),
        memoryWriter: any AgentMemoryWriting,
        aiProvider: any AIProvider,
        skillCatalogProvider: AgentSkillCatalogProvider,
        toolContextProvider: any AgentCapabilityPromptContextProviding,
        toolInvocationPlanner: any AgentToolInvocationPlanning,
        toolPlanningRequestBuilder: any AgentToolPlanningRequestBuilding,
        responseActionPlanner: any AgentResponseActionPlanning,
        completionRequestBuilder: any AgentCompletionRequestBuilding
    ) {
        self.memoryContextProvider = memoryContextProvider
        self.wikiContextProvider = wikiContextProvider
        self.memoryWriter = memoryWriter
        self.aiProvider = aiProvider
        self.skillCatalogProvider = skillCatalogProvider
        self.toolContextProvider = toolContextProvider
        self.toolInvocationPlanner = toolInvocationPlanner
        self.toolPlanningRequestBuilder = toolPlanningRequestBuilder
        self.responseActionPlanner = responseActionPlanner
        self.completionRequestBuilder = completionRequestBuilder
    }
}
