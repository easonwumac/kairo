import XCTest
@testable import KairoCore

final class KairoActionInboxBackendAPITests: XCTestCase {
    func testBriefingSnapshotSummarizesPendingActionInboxWork() async throws {
        let builder = ShareAttachmentBuilder()
        let items = [
            ShareIngestionItem(
                attachments: [builder.text("TODO: Review launch deck", displayName: "Task")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 10)
            ),
            ShareIngestionItem(
                attachments: [builder.text("記住：AFM 適合短上下文分類。", displayName: "Memory")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 20)
            ),
            ShareIngestionItem(
                attachments: [builder.text("搜尋網路 iOS 27 AFM AppIntents", displayName: "Research")],
                sourceApplication: "ShareSheet",
                receivedAt: Date(timeIntervalSince1970: 30)
            )
        ]
        let api = KairoActionInboxBackendService(
            shareIngestionQueue: InMemoryShareIngestionQueue(seed: items)
        )

        let inboxItems = try await api.pendingItems(limit: 10)
        let snapshot = KairoBriefingSnapshotBuilder().snapshot(from: inboxItems)

        XCTAssertEqual(snapshot.pendingCaptureCount, 3)
        XCTAssertEqual(snapshot.reminderDraftCount, 1)
        XCTAssertEqual(snapshot.memoryDraftCount, 1)
        XCTAssertEqual(snapshot.handoffCount, 1)
        XCTAssertEqual(snapshot.confirmationCount, 3)
        XCTAssertTrue(snapshot.hasPendingWork)
    }

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

    func testShareMessageProducesVisibleHandoffDrafts() async throws {
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.text("搜尋網路 AFM iOS 27 local inference performance", displayName: "Research")
            ],
            sourceApplication: "ShareSheet"
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let api = KairoActionInboxBackendService(shareIngestionQueue: queue)

        let inboxItems = try await api.pendingItems(limit: 10)
        let inboxItem = try XCTUnwrap(inboxItems.first)

        let searchSuggestion = try XCTUnwrap(inboxItem.suggestions.first { $0.kind == .webSearchHandoff })
        XCTAssertTrue(searchSuggestion.requiresConfirmation)
        XCTAssertEqual(searchSuggestion.action?.kind, .openWebSearchHandoff)
        guard case let .webSearch(draft) = searchSuggestion.action?.payload else {
            return XCTFail("Expected web search payload")
        }
        XCTAssertTrue(draft.query.contains("AFM"))
        XCTAssertTrue(draft.searchURL.contains("duckduckgo.com"))
    }

    func testShareMessageProducesMapsHandoffDraft() async throws {
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.text("走路去 台北 101", displayName: "Route")
            ],
            sourceApplication: "ShareSheet"
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let api = KairoActionInboxBackendService(shareIngestionQueue: queue)

        let inboxItems = try await api.pendingItems(limit: 10)
        let inboxItem = try XCTUnwrap(inboxItems.first)

        let mapsSuggestion = try XCTUnwrap(inboxItem.suggestions.first { $0.kind == .mapsHandoff })
        XCTAssertTrue(mapsSuggestion.requiresConfirmation)
        XCTAssertEqual(mapsSuggestion.action?.kind, .openMapDirections)
        guard case let .mapDirections(draft) = mapsSuggestion.action?.payload else {
            return XCTFail("Expected maps payload")
        }
        XCTAssertEqual(draft.destinationQuery, "台北 101")
        XCTAssertEqual(draft.mode, .walking)
    }

    func testShareMessageProducesMemorySaveDraft() async throws {
        let builder = ShareAttachmentBuilder()
        let item = ShareIngestionItem(
            attachments: [
                builder.text("記住：AFM 適合處理短上下文的分類和 JSON 修復。", displayName: "Memory")
            ],
            sourceApplication: "ShareSheet"
        )
        let queue = InMemoryShareIngestionQueue(seed: [item])
        let api = KairoActionInboxBackendService(shareIngestionQueue: queue)

        let inboxItems = try await api.pendingItems(limit: 10)
        let inboxItem = try XCTUnwrap(inboxItems.first)

        let memorySuggestion = try XCTUnwrap(inboxItem.suggestions.first { $0.kind == .memorySave })
        XCTAssertTrue(memorySuggestion.requiresConfirmation)
        XCTAssertEqual(memorySuggestion.action?.kind, .saveMemory)
        guard case let .text(content) = memorySuggestion.action?.payload else {
            return XCTFail("Expected memory text payload")
        }
        XCTAssertTrue(content.contains("AFM"))
    }
}
