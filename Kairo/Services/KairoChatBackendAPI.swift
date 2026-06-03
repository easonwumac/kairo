import Foundation

public protocol KairoChatAPI: Sendable {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse
}

public struct KairoChatBackendService: KairoChatAPI {
    private let agent: AgentCore

    public init(agent: AgentCore) {
        self.agent = agent
    }

    public func respond(
        to message: String,
        attachments: [ChatAttachment] = [],
        privacyMode: ChatPrivacyMode = .standard
    ) async throws -> AICompletionResponse {
        try await agent.respond(
            to: message,
            attachments: attachments,
            privacyMode: privacyMode
        )
    }
}
