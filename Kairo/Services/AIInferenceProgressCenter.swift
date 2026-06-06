import Foundation

public struct AIInferenceProgressSnapshot: Equatable, Sendable {
    public var conversationID: String
    public var metrics: AIInferenceMetrics

    public init(conversationID: String, metrics: AIInferenceMetrics) {
        self.conversationID = conversationID
        self.metrics = metrics
    }
}

public actor AIInferenceProgressCenter {
    public static let shared = AIInferenceProgressCenter()

    private var continuations: [UUID: AsyncStream<AIInferenceProgressSnapshot>.Continuation] = [:]

    public init() {}

    public func stream() -> AsyncStream<AIInferenceProgressSnapshot> {
        let id = UUID()
        return AsyncStream { continuation in
            continuations[id] = continuation
            continuation.onTermination = { [weak self] _ in
                guard let self else { return }
                Task { await self.removeContinuation(id) }
            }
        }
    }

    public func publish(_ snapshot: AIInferenceProgressSnapshot) {
        for continuation in continuations.values {
            continuation.yield(snapshot)
        }
    }

    private func removeContinuation(_ id: UUID) {
        continuations[id] = nil
    }
}
