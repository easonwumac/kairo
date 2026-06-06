import Foundation

public protocol KairoChatAPI: Sendable {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse

    func respond(
        to message: String,
        attachments: [ChatAttachment],
        conversationID: String?,
        conversationHistory: [AIConversationTurn],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse
}

public extension KairoChatAPI {
    func respond(
        to message: String,
        attachments: [ChatAttachment],
        conversationID: String?,
        conversationHistory: [AIConversationTurn],
        privacyMode: ChatPrivacyMode
    ) async throws -> AICompletionResponse {
        _ = conversationID
        _ = conversationHistory
        return try await respond(
            to: message,
            attachments: attachments,
            privacyMode: privacyMode
        )
    }
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
        try await respond(
            to: message,
            attachments: attachments,
            conversationID: nil,
            conversationHistory: [],
            privacyMode: privacyMode
        )
    }

    public func respond(
        to message: String,
        attachments: [ChatAttachment],
        conversationID: String? = nil,
        conversationHistory: [AIConversationTurn] = [],
        privacyMode: ChatPrivacyMode = .standard
    ) async throws -> AICompletionResponse {
        try await agent.respond(
            to: message,
            attachments: attachments,
            conversationID: conversationID,
            conversationHistory: conversationHistory,
            privacyMode: privacyMode
        )
    }
}
