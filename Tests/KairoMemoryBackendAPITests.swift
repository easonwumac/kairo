import XCTest
import Foundation
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

    func testMemoryBackendAPIPurgesDeletedMemoryContentFromDisk() async throws {
        let fileURL = temporaryFileURL(named: "memory-backend-delete.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let api = KairoMemoryBackendService(memoryStore: store)
        let memory = MemoryRecord(
            title: "Disk delete",
            summary: "Backend purge",
            content: "Private memory content should leave disk after UI delete.",
            source: .manual
        )

        try await api.save(memory)
        try await api.delete(id: memory.id)
        var rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertTrue(rawText.contains(memory.content))

        try await api.purgeDeleted()
        rawText = try String(contentsOf: fileURL, encoding: .utf8)
        XCTAssertFalse(rawText.contains(memory.id.uuidString))
        XCTAssertFalse(rawText.contains(memory.content))
    }

    private func temporaryFileURL(named name: String) -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoMemoryBackendAPITests-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent(name)
    }
}
