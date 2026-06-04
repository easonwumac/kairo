import XCTest
@testable import KairoCore

final class KairoMemoryBackendAPITests: XCTestCase {
    func testMemoryBackendAPIForwardsLifecycleAndExportThroughStore() async throws {
        let memoryID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let store = InMemoryMemoryStore()
        let api = KairoMemoryBackendService(memoryStore: store)
        let memory = MemoryRecord(
            id: memoryID,
            title: "Backend boundary",
            summary: "Memory API facade",
            content: "Kairo memory should be reachable through backend API.",
            source: .manual,
            tags: ["backend"]
        )

        try await api.save(memory)
        var listed = try await api.list(limit: 10)
        XCTAssertEqual(listed.map(\.id), [memoryID])

        let searched = try await api.search(query: "boundary", limit: 10)
        XCTAssertEqual(searched.map(\.id), [memoryID])

        let exported = try await api.export(limit: 10)
        XCTAssertEqual(exported.records.map(\.id), [memoryID])

        try await api.delete(id: memoryID)
        listed = try await api.list(limit: 10)
        XCTAssertTrue(listed.isEmpty)

        try await api.purgeDeleted()
        let purgedExport = try await api.export(limit: 10)
        XCTAssertTrue(purgedExport.records.isEmpty)
    }
}
