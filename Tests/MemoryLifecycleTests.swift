import XCTest
@testable import KairoCore

final class MemoryLifecycleTests: XCTestCase {
    func testJSONFileMemoryStoreExportsOnlyActiveMemories() async throws {
        let fileURL = temporaryFileURL(named: "memory-store.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let active = MemoryRecord(
            title: "Active",
            summary: "Export me",
            content: "This active memory can be exported by the user.",
            source: .manual
        )
        let deleted = MemoryRecord(
            title: "Deleted",
            summary: "Do not export",
            content: "This deleted memory should not appear in export.",
            source: .manual
        )

        try await store.save(active)
        try await store.save(deleted)
        try await store.delete(id: deleted.id)

        let export = try await store.export(limit: 10)

        XCTAssertEqual(export.schemaVersion, 1)
        XCTAssertEqual(export.records.map(\.id), [active.id])
        XCTAssertFalse(export.records.contains { $0.id == deleted.id })
    }

    func testJSONFileMemoryStorePurgesDeletedMemoryContentFromDisk() async throws {
        let fileURL = temporaryFileURL(named: "memory-store.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let memory = MemoryRecord(
            title: "Sensitive",
            summary: "Sensitive summary",
            content: "Sensitive private content should not remain after purge.",
            source: .manual
        )

        try await store.save(memory)
        try await store.delete(id: memory.id)
        XCTAssertTrue(try String(contentsOf: fileURL, encoding: .utf8).contains(memory.content))

        try await store.purgeDeleted()
        let rawText = try String(contentsOf: fileURL, encoding: .utf8)
        let listed = try await store.list(limit: 10)

        XCTAssertTrue(listed.isEmpty)
        XCTAssertFalse(rawText.contains(memory.id.uuidString))
        XCTAssertFalse(rawText.contains(memory.content))
    }

    func testInMemoryMemoryStoreCanEraseMemoryImmediately() async throws {
        let store = InMemoryMemoryStore()
        let memory = MemoryRecord(
            title: "Erase",
            summary: "Erase me",
            content: "Erase this memory now.",
            source: .manual
        )

        try await store.save(memory)
        try await store.erase(id: memory.id)

        let export = try await store.export(limit: 10)
        XCTAssertTrue(export.records.isEmpty)
    }

    func testJSONFileMemoryStoreFindsNaturalLanguageKeywordMatches() async throws {
        let fileURL = temporaryFileURL(named: "memory-store.json")
        let store = try await JSONFileMemoryStore(fileURL: fileURL)
        let launch = MemoryRecord(
            title: "Launch plan",
            summary: "Send beta invites after the QA pass.",
            content: "The Kairo beta launch plan depends on QA sign-off.",
            source: .manual
        )
        let groceries = MemoryRecord(
            title: "Groceries",
            summary: "Buy oat milk.",
            content: "Personal errands.",
            source: .manual
        )

        try await store.save(launch)
        try await store.save(groceries)

        let results = try await store.search(query: "What should I remember about the launch?", limit: 10)

        XCTAssertEqual(results.map(\.id), [launch.id])
    }

    func testKairoLiveStoreFactoryBuildsPersistentMemoryAndChatStores() async throws {
        let rootDirectory = temporaryDirectory(named: "KairoLiveStoreFactory")
        let paths = KairoPaths(
            appName: "KairoLiveStoreFactoryTests",
            appGroupIdentifier: "group.kairo.tests"
        ) { _ in rootDirectory }
        let firstComponents = try await KairoLiveStoreFactory(paths: paths).makeComponents()
        let memory = MemoryRecord(
            title: "Factory memory",
            summary: "Persists through live store factory.",
            content: "Persistent memory content",
            source: .manual
        )
        let thread = ChatThread(messages: [
            ChatMessage(role: .user, text: "Persist this chat thread")
        ])

        try await firstComponents.memoryStore.save(memory)
        try await firstComponents.chatHistoryStore.saveThread(thread)

        let reloadedComponents = try await KairoLiveStoreFactory(paths: paths).makeComponents()
        let reloadedMemories = try await reloadedComponents.memoryStore.list(limit: 10)
        let reloadedThreads = try await reloadedComponents.chatHistoryStore.listThreads(limit: 10)

        XCTAssertEqual(reloadedMemories.map(\.id), [memory.id])
        XCTAssertEqual(reloadedThreads.map(\.id), [thread.id])
        XCTAssertEqual(reloadedThreads.first?.messages.first?.text, "Persist this chat thread")
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoMemoryLifecycleTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name)
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("KairoMemoryLifecycleTests-\(UUID().uuidString)", isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }
}
