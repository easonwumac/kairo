import XCTest
import Foundation
@testable import KairoCore

final class KairoShortcutNodeTests: XCTestCase {
    func testShortcutSaveMemoryNodeSavesTextAndReturnsStructuredOutput() async throws {
        let store = InMemoryMemoryStore()
        let runtime = ShortcutNodeRuntime(memoryStore: store)
        let input = ShortcutNodeInput(
            text: """
            Client asked about Kairo Shortcuts.
            TODO: Send prototype link
            - [ ] Draft follow-up reminder
            """,
            sourceName: "Shortcut Input"
        )

        let output = try await runtime.run(.saveMemory, input: input)

        let memoryID = try XCTUnwrap(output.memoryID)
        let saved = try await store.search(query: "Shortcuts", limit: 10)
        XCTAssertEqual(saved.map(\.id), [memoryID])
        XCTAssertEqual(saved.first?.source, .appIntent)
        XCTAssertEqual(output.kind, .saveMemory)
        XCTAssertEqual(output.fields["memoryID"], memoryID.uuidString)
        XCTAssertEqual(output.fields["taskCount"], "2")
        XCTAssertEqual(output.tasks.map(\.title), ["Send prototype link", "Draft follow-up reminder"])
        XCTAssertTrue(output.displayText.contains("Saved"))
        XCTAssertTrue(try output.encodedJSONString().contains(memoryID.uuidString))
    }

    func testShortcutSearchMemoryNodeReturnsMatchesForDownstreamShortcutSteps() async throws {
        let memory = MemoryRecord(
            title: "Kairo Shortcut Recipes",
            summary: "Daily briefing and shared text recipe notes.",
            content: "Use Shortcuts to pass text into Kairo and return structured output.",
            source: .appIntent
        )
        let store = InMemoryMemoryStore(seed: [memory])
        let runtime = ShortcutNodeRuntime(memoryStore: store)

        let output = try await runtime.run(.searchMemory, input: ShortcutNodeInput(query: "briefing", limit: 5))

        XCTAssertEqual(output.kind, .searchMemory)
        XCTAssertEqual(output.fields["matchCount"], "1")
        XCTAssertEqual(output.memoryMatches.map(\.id), [memory.id])
        XCTAssertEqual(output.memoryMatches.first?.title, "Kairo Shortcut Recipes")
        XCTAssertTrue(output.displayText.contains("1 memory"))
    }

    func testShortcutExtractTasksNodeBuildsReminderDraftsWithoutExecuting() async throws {
        let runtime = ShortcutNodeRuntime(memoryStore: InMemoryMemoryStore())
        let input = ShortcutNodeInput(
            text: """
            Meeting notes:
            Action: Review HomeKit capability matrix
            Reminder: Build OAuth login demo
            """
        )

        let output = try await runtime.run(.extractTasks, input: input)

        XCTAssertEqual(output.kind, .extractTasks)
        XCTAssertEqual(output.fields["taskCount"], "2")
        XCTAssertEqual(output.tasks.map(\.title), ["Review HomeKit capability matrix", "Build OAuth login demo"])
        XCTAssertEqual(output.reminderDrafts.map(\.title), ["Review HomeKit capability matrix", "Build OAuth login demo"])
        XCTAssertTrue(output.proposedActions.isEmpty)
        XCTAssertTrue(output.displayText.contains("2 tasks"))
    }
}
