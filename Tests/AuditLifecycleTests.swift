import XCTest
@testable import KairoCore

final class AuditLifecycleTests: XCTestCase {
    func testFileBackedAuditLoggerPersistsMetadataOnlyEvents() async throws {
        let fileURL = temporaryFileURL(named: "audit-log.json")
        let logger = try await FileBackedAuditLogger(fileURL: fileURL)
        let memoryID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!

        try await logger.record(AuditEvent(
            actionKind: .saveMemory,
            memoryIDs: [memoryID],
            capabilityKeys: [.memory],
            usedCloudModel: true,
            requiredConfirmation: true,
            userConfirmed: false,
            result: .proposed
        ))

        let reloaded = try await FileBackedAuditLogger(fileURL: fileURL)
        let events = try await reloaded.list(limit: 10)
        let rawText = try String(contentsOf: fileURL, encoding: .utf8)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.actionKind, .saveMemory)
        XCTAssertEqual(events.first?.memoryIDs, [memoryID])
        XCTAssertTrue(rawText.contains("saveMemory"))
        XCTAssertTrue(rawText.contains(memoryID.uuidString))
        XCTAssertFalse(rawText.contains("payload"))
        XCTAssertFalse(rawText.contains("Remember this private note"))
    }

    func testKairoPathsBuildsAuditLogURLBesideMemoryStore() {
        let paths = KairoPaths(appName: "KairoTests")

        XCTAssertEqual(paths.auditLogURL.lastPathComponent, "audit-log.json")
        XCTAssertEqual(paths.auditLogURL.deletingLastPathComponent(), paths.memoryStoreURL.deletingLastPathComponent())
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoAuditLifecycleTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
    }
}
