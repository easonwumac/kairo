import XCTest
@testable import KairoCore

final class KairoActionInboxBackendAPITests: XCTestCase {
    func testShareMessageProducesTaskReminderDraftsWithoutImportingQueue() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let now = Date(timeIntervalSince1970: 1_717_392_000) // Monday, 2024-06-03 00:00:00 UTC
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.text("週五前整理 Kairo demo，補 Google Maps 和 Todoist 測試。", displayName: "Kairo demo note")
            ],
            sourceApplication: "ShareSheet",
            receivedAt: Date(timeIntervalSince1970: 10)
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let api = KairoActionInboxBackendService(
            shareIngestionQueue: queue,
            calendar: calendar,
            now: { now }
        )

        let inboxItems = try await api.pendingItems(limit: 10)

        let inboxItem = try XCTUnwrap(inboxItems.first)
        XCTAssertEqual(inboxItem.source, .shareExtension)
        XCTAssertEqual(inboxItem.sourceItemIDs, [item.id])
        XCTAssertEqual(inboxItem.attachments.map(\.kind), [.text])
        XCTAssertEqual(inboxItem.summary.bullets.count, 1)
        let reminderSuggestions = inboxItem.suggestions.filter { $0.kind == .reminderDraft }
        XCTAssertEqual(reminderSuggestions.count, 3)
        XCTAssertTrue(reminderSuggestions.allSatisfy(\.requiresConfirmation))
        XCTAssertTrue(reminderSuggestions.allSatisfy { $0.action?.kind == .createReminderDraft })
        XCTAssertTrue(reminderSuggestions.allSatisfy { $0.action?.requiresConfirmation == true })

        let reminderDrafts = reminderSuggestions.compactMap { suggestion -> ReminderDraft? in
            guard case let .reminder(draft) = suggestion.action?.payload else { return nil }
            return draft
        }
        XCTAssertEqual(reminderDrafts.count, 3)
        XCTAssertTrue(reminderDrafts.contains { $0.title.contains("Kairo demo") })
        XCTAssertTrue(reminderDrafts.contains { $0.title.contains("Google Maps") })
        XCTAssertTrue(reminderDrafts.contains { $0.title.contains("Todoist") })
        XCTAssertTrue(reminderDrafts.allSatisfy { draft in
            guard let dueDate = draft.dueDate else { return false }
            return calendar.component(.weekday, from: dueDate) == 6
        })

        let stillPending = try await queue.pendingItems(limit: 10)
        XCTAssertEqual(stillPending.map(\.id), [item.id])
    }

    func testBackendComposerExposesActionInboxAPI() async throws {
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [builder.text("TODO: Review Action Inbox")],
            sourceApplication: "ShareSheet"
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let environment = KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: InMemoryCredentialStore(),
            aiProvider: MockAIProvider(),
            shareIngestionQueue: queue
        )

        let inboxItems = try await environment.backendAPI.actionInbox.pendingItems(limit: 10)

        XCTAssertEqual(inboxItems.map(\.sourceItemIDs), [[item.id]])
        XCTAssertEqual(inboxItems.first?.suggestions.contains { $0.kind == .reminderDraft }, true)
    }
}
