import Foundation

public protocol AuditLogger: Sendable {
    func record(_ event: AuditEvent) async throws
    func list(limit: Int) async throws -> [AuditEvent]
}

public actor InMemoryAuditLogger: AuditLogger {
    private var events: [AuditEvent] = []

    public init() {}

    public func record(_ event: AuditEvent) async throws {
        events.append(event)
    }

    public func list(limit: Int = 100) async throws -> [AuditEvent] {
        events
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(limit)
            .map { $0 }
    }
}
