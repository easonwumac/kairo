import XCTest
@testable import KairoCore

#if canImport(AppIntents)
final class KairoCaptureIntentSupportTests: XCTestCase {
    func testOpenSectionIntentEnumMapsToRouterSections() {
        XCTAssertEqual(KairoOpenSectionAppEnum.chat.routeSection, .chat)
        XCTAssertEqual(KairoOpenSectionAppEnum.library.routeSection, .assets)
        XCTAssertEqual(KairoOpenSectionAppEnum.infoPages.routeSection, .pages)
        XCTAssertEqual(KairoOpenSectionAppEnum.memory.routeSection, .memory)
        XCTAssertEqual(KairoOpenSectionAppEnum.models.routeSection, .models)
        XCTAssertEqual(KairoOpenSectionAppEnum.permissions.routeSection, .access)
    }

    func testCaptureReviewRouteStoreConsumesIntentHandoffRoute() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let key = "kairo_intent_pending_route_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }

        KairoIntentRouteStore(defaults: defaults, key: key).save(.captureReview)

        let route = KairoIntentRouteStore(defaults: defaults, key: key).consume()
        XCTAssertEqual(route, .captureReview)
    }

    func testCaptureTextSupportQueuesCaptureAndReturnsStructuredRouteOutput() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        let routeKey = "kairo_intent_pending_route_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let routeStore = KairoIntentRouteStore(defaults: defaults, key: routeKey)

        let output = KairoCaptureIntentSupport.captureText(
            "  研究筆記：AFM pipeline 需要 staged prompts。  ",
            store: captureStore,
            routeStore: routeStore
        )
        let decoded = try JSONDecoder().decode(KairoCaptureIntentOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.queued)
        XCTAssertEqual(decoded.captureKind, .text)
        XCTAssertNotNil(decoded.captureID)
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertTrue(decoded.textPreview.contains("AFM pipeline"))
        XCTAssertEqual(routeStore.consume(), .captureReview)
        let captures = captureStore.consume()
        XCTAssertEqual(captures.map(\.id), [try XCTUnwrap(decoded.captureID)])
        XCTAssertEqual(captures.map(\.text), ["研究筆記：AFM pipeline 需要 staged prompts。"])
    }

    func testCaptureURLSupportQueuesURLAndRejectsUnsupportedSchemes() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        let routeKey = "kairo_intent_pending_route_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let routeStore = KairoIntentRouteStore(defaults: defaults, key: routeKey)

        let output = KairoCaptureIntentSupport.captureURL(
            URL(string: "https://example.com/afm")!,
            note: "Read later",
            store: captureStore,
            routeStore: routeStore
        )
        let rejected = KairoCaptureIntentSupport.captureURL(
            URL(string: "file:///tmp/private.txt")!,
            store: captureStore,
            routeStore: routeStore
        )

        XCTAssertTrue(output.queued)
        XCTAssertEqual(output.captureKind, .url)
        XCTAssertEqual(output.url, "https://example.com/afm")
        XCTAssertEqual(output.recommendedRoute, .captureReview)
        XCTAssertFalse(rejected.queued)
        XCTAssertEqual(rejected.captureID, nil)
        XCTAssertEqual(routeStore.consume(), .captureReview)
        let captures = captureStore.consume()
        XCTAssertEqual(captures.count, 1)
        XCTAssertEqual(captures.first?.kind, .url)
        XCTAssertEqual(captures.first?.url?.absoluteString, "https://example.com/afm")
    }

    func testCaptureAndTriageTextQueuesCaptureAndReturnsActionOutput() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        let routeKey = "kairo_intent_pending_route_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let routeStore = KairoIntentRouteStore(defaults: defaults, key: routeKey)

        let output = try await KairoCaptureIntentSupport.captureAndTriageText(
            "週五前整理 Kairo AFM demo",
            store: captureStore,
            routeStore: routeStore
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KairoCaptureAndTriageOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.queued)
        XCTAssertEqual(decoded.capture.queued, true)
        XCTAssertEqual(decoded.captureID, decoded.capture.captureID)
        XCTAssertEqual(decoded.triage?.triage, .createReminder)
        XCTAssertEqual(decoded.actionKinds, [.createReminderDraft])
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertEqual(routeStore.consume(), .captureReview)
        let captures = captureStore.consume()
        XCTAssertEqual(captures.map(\.id), [try XCTUnwrap(decoded.captureID)])
        XCTAssertEqual(captures.first?.text, "週五前整理 Kairo AFM demo")
    }

    func testPrepareInfoPageTextQueuesCaptureAndForcesInfoPageReview() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        let routeKey = "kairo_intent_pending_route_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let routeStore = KairoIntentRouteStore(defaults: defaults, key: routeKey)

        let output = try await KairoCaptureIntentSupport.prepareInfoPageText(
            "Plain device setup details without generic note keywords.",
            store: captureStore,
            routeStore: routeStore
        )
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KairoCaptureAndTriageOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.queued)
        XCTAssertEqual(decoded.capture.captureKind, .text)
        XCTAssertEqual(decoded.triage?.triage, .createInfoPage)
        XCTAssertEqual(decoded.actionKinds, [])
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertEqual(routeStore.consume(), .captureReview)
        let captures = captureStore.consume()
        XCTAssertEqual(captures.map(\.sourceName), ["InfoPage Capture"])
        XCTAssertEqual(captures.first?.text, "Plain device setup details without generic note keywords.")
    }

    func testCaptureAndTriageURLRejectsUnsupportedSchemeWithoutQueueingOrTriage() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        let routeKey = "kairo_intent_pending_route_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let routeStore = KairoIntentRouteStore(defaults: defaults, key: routeKey)

        let output = try await KairoCaptureIntentSupport.captureAndTriageURL(
            URL(string: "file:///tmp/private.txt")!,
            store: captureStore,
            routeStore: routeStore
        )

        XCTAssertFalse(output.queued)
        XCTAssertNil(output.captureID)
        XCTAssertNil(output.triage)
        XCTAssertEqual(output.actionKinds, [])
        XCTAssertNil(routeStore.consume())
        XCTAssertEqual(captureStore.consume(), [])
    }

    func testCaptureInboxStatusReportsPendingCapturesWithoutConsuming() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)

        let first = try XCTUnwrap(captureStore.saveText("First AFM note", sourceName: "Shortcut"))
        let second = try XCTUnwrap(captureStore.saveURL(
            URL(string: "https://example.com/afm")!,
            note: "Read later",
            sourceName: "Shortcut URL"
        ))

        let output = KairoCaptureIntentSupport.captureInboxStatus(store: captureStore)
        let decoded = try JSONDecoder().decode(KairoCaptureInboxStatusOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.hasPendingCaptures)
        XCTAssertEqual(decoded.pendingCount, 2)
        XCTAssertEqual(decoded.latestCaptureID, second.id)
        XCTAssertEqual(decoded.latestCaptureKind, .url)
        XCTAssertEqual(decoded.latestURL, "https://example.com/afm")
        XCTAssertEqual(decoded.captureIDs, [first.id, second.id])
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertEqual(captureStore.pending().map(\.id), [first.id, second.id])
    }

    func testCaptureInboxStatusReportsEmptyInboxWithoutReviewRoute() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)

        let output = KairoCaptureIntentSupport.captureInboxStatus(store: captureStore)

        XCTAssertFalse(output.hasPendingCaptures)
        XCTAssertEqual(output.pendingCount, 0)
        XCTAssertNil(output.latestCaptureID)
        XCTAssertEqual(output.captureIDs, [])
        XCTAssertEqual(output.textPreviews, [])
        XCTAssertEqual(output.recommendedRoute, .chat)
        XCTAssertEqual(output.recommendedDeepLink, KairoCaptureTriageRoute.chat.deepLinkString)
    }

    func testTriagePendingCapturesReturnsBatchSuggestionsWithoutConsumingInbox() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let reminder = try XCTUnwrap(captureStore.saveText("週五前整理 Kairo AFM demo", sourceName: "Shortcut"))
        let memory = try XCTUnwrap(captureStore.saveText("記住：AFM 適合短上下文分類。", sourceName: "Shortcut"))
        let url = try XCTUnwrap(captureStore.saveURL(
            URL(string: "https://example.com/research/afm-pipeline")!,
            note: nil,
            sourceName: "Shortcut URL"
        ))

        let output = try await KairoCaptureIntentSupport.triagePendingCaptures(store: captureStore)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KairoCaptureInboxTriageOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertEqual(decoded.pendingCount, 3)
        XCTAssertEqual(decoded.triagedCount, 3)
        XCTAssertEqual(decoded.needsReviewCount, 3)
        XCTAssertEqual(decoded.captureOnlyCount, 0)
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertEqual(decoded.items.map(\.captureID), [reminder.id, memory.id, url.id])
        XCTAssertEqual(decoded.items.map(\.triage), [.createReminder, .saveMemory, .createInfoPage])
        XCTAssertEqual(decoded.items[0].actionKinds, [.createReminderDraft])
        XCTAssertEqual(decoded.items[1].actionKinds, [.saveMemory])
        XCTAssertEqual(decoded.items[2].captureKind, .url)
        XCTAssertEqual(decoded.items[2].url, "https://example.com/research/afm-pipeline")
        XCTAssertTrue(decoded.actionKinds.contains(.createReminderDraft))
        XCTAssertTrue(decoded.actionKinds.contains(.saveMemory))
        XCTAssertEqual(captureStore.pending().map(\.id), [reminder.id, memory.id, url.id])
    }

    func testTriagePendingCapturesHonorsLimitAndRoutesPlainCapturesToChat() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let first = try XCTUnwrap(captureStore.saveText("Blue sky over the park.", sourceName: "Shortcut"))
        let second = try XCTUnwrap(captureStore.saveText("週五前整理 Kairo demo", sourceName: "Shortcut"))

        let output = try await KairoCaptureIntentSupport.triagePendingCaptures(limit: 1, store: captureStore)

        XCTAssertEqual(output.pendingCount, 2)
        XCTAssertEqual(output.triagedCount, 1)
        XCTAssertEqual(output.needsReviewCount, 0)
        XCTAssertEqual(output.captureOnlyCount, 1)
        XCTAssertEqual(output.recommendedRoute, .chat)
        XCTAssertEqual(output.items.map(\.captureID), [first.id])
        XCTAssertEqual(output.items.first?.triage, .captureOnly)
        XCTAssertEqual(captureStore.pending().map(\.id), [first.id, second.id])
    }

    func testTriagePendingCapturesReportsEmptyInbox() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)

        let output = try await KairoCaptureIntentSupport.triagePendingCaptures(store: captureStore)

        XCTAssertEqual(output.pendingCount, 0)
        XCTAssertEqual(output.triagedCount, 0)
        XCTAssertEqual(output.needsReviewCount, 0)
        XCTAssertEqual(output.items, [])
        XCTAssertEqual(output.recommendedRoute, .chat)
        XCTAssertEqual(output.recommendedDeepLink, KairoCaptureTriageRoute.chat.deepLinkString)
    }

    func testClearCaptureInboxRequiresExplicitConfirmation() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let capture = try XCTUnwrap(captureStore.saveText("Review AFM notes", sourceName: "Shortcut"))

        let output = KairoCaptureIntentSupport.clearCaptureInbox(confirmClear: false, store: captureStore)

        XCTAssertFalse(output.confirmed)
        XCTAssertFalse(output.cleared)
        XCTAssertEqual(output.clearedCount, 0)
        XCTAssertEqual(output.remainingCount, 1)
        XCTAssertEqual(output.clearedCaptureIDs, [])
        XCTAssertEqual(output.recommendedRoute, .captureReview)
        XCTAssertEqual(captureStore.pending().map(\.id), [capture.id])
    }

    func testClearCaptureInboxReturnsClearedCaptureSummaryWhenConfirmed() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let first = try XCTUnwrap(captureStore.saveText("First AFM note", sourceName: "Shortcut"))
        let second = try XCTUnwrap(captureStore.saveURL(
            URL(string: "https://example.com/afm")!,
            note: "Read later",
            sourceName: "Shortcut URL"
        ))

        let output = KairoCaptureIntentSupport.clearCaptureInbox(confirmClear: true, store: captureStore)
        let decoded = try JSONDecoder().decode(KairoCaptureInboxClearOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.confirmed)
        XCTAssertTrue(decoded.cleared)
        XCTAssertEqual(decoded.clearedCount, 2)
        XCTAssertEqual(decoded.remainingCount, 0)
        XCTAssertEqual(decoded.clearedCaptureIDs, [first.id, second.id])
        XCTAssertEqual(decoded.recommendedRoute, .chat)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.chat.deepLinkString)
        XCTAssertEqual(captureStore.pending(), [])
    }

    func testPendingCaptureEntityQueryReturnsSuggestedAndRequestedCaptures() async throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let first = try XCTUnwrap(captureStore.saveText("First AFM note", sourceName: "Shortcut"))
        let second = try XCTUnwrap(captureStore.saveURL(
            URL(string: "https://example.com/afm")!,
            note: "Read later",
            sourceName: "Shortcut URL"
        ))
        let query = KairoPendingCaptureQuery(store: captureStore)

        let suggested = try await query.suggestedEntities()
        let requested = try await query.entities(for: [second.id])

        XCTAssertEqual(suggested.map(\.id), [first.id, second.id])
        XCTAssertEqual(suggested.map(\.kind), [.text, .url])
        XCTAssertEqual(requested.map(\.id), [second.id])
        XCTAssertEqual(requested.first?.url, "https://example.com/afm")
        XCTAssertEqual(captureStore.pending().map(\.id), [first.id, second.id])
    }

    func testInspectPendingCaptureReturnsDetailsWithoutConsuming() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let capture = try XCTUnwrap(captureStore.saveText("Inspect AFM capture", sourceName: "Shortcut"))

        let output = KairoCaptureIntentSupport.inspectPendingCapture(id: capture.id, store: captureStore)
        let decoded = try JSONDecoder().decode(KairoPendingCaptureInspectOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.found)
        XCTAssertEqual(decoded.captureID, capture.id)
        XCTAssertEqual(decoded.captureKind, .text)
        XCTAssertEqual(decoded.sourceName, "Shortcut")
        XCTAssertEqual(decoded.text, "Inspect AFM capture")
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(captureStore.pending().map(\.id), [capture.id])
    }

    func testInspectPendingCaptureReportsMissingCaptureWithoutConsuming() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)

        let output = KairoCaptureIntentSupport.inspectPendingCapture(id: UUID(), store: captureStore)

        XCTAssertFalse(output.found)
        XCTAssertNil(output.captureID)
        XCTAssertEqual(output.recommendedRoute, .chat)
        XCTAssertEqual(captureStore.pending(), [])
    }

    func testDiscardPendingCaptureRequiresExplicitConfirmation() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let capture = try XCTUnwrap(captureStore.saveText("Discard AFM capture", sourceName: "Shortcut"))

        let output = KairoCaptureIntentSupport.discardPendingCapture(
            id: capture.id,
            confirmDiscard: false,
            store: captureStore
        )

        XCTAssertFalse(output.confirmed)
        XCTAssertFalse(output.discarded)
        XCTAssertTrue(output.found)
        XCTAssertEqual(output.remainingCount, 1)
        XCTAssertEqual(output.recommendedRoute, .captureReview)
        XCTAssertEqual(captureStore.pending().map(\.id), [capture.id])
    }

    func testDiscardPendingCaptureRemovesOnlySelectedCaptureWhenConfirmed() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)
        let first = try XCTUnwrap(captureStore.saveText("First AFM capture", sourceName: "Shortcut"))
        let second = try XCTUnwrap(captureStore.saveURL(
            URL(string: "https://example.com/afm")!,
            note: "Read later",
            sourceName: "Shortcut URL"
        ))

        let output = KairoCaptureIntentSupport.discardPendingCapture(
            id: first.id,
            confirmDiscard: true,
            store: captureStore
        )
        let decoded = try JSONDecoder().decode(KairoPendingCaptureDiscardOutput.self, from: Data(output.encodedJSONString().utf8))

        XCTAssertTrue(decoded.confirmed)
        XCTAssertTrue(decoded.discarded)
        XCTAssertTrue(decoded.found)
        XCTAssertEqual(decoded.discardedCaptureID, first.id)
        XCTAssertEqual(decoded.discardedCaptureKind, .text)
        XCTAssertEqual(decoded.remainingCount, 1)
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(captureStore.pending().map(\.id), [second.id])
    }

    func testDiscardPendingCaptureReportsMissingCaptureWhenConfirmed() throws {
        let suiteName = "KairoCaptureIntentSupportTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        let captureKey = "kairo_intent_pending_captures_test"
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let captureStore = KairoIntentCaptureStore(defaults: defaults, key: captureKey)

        let output = KairoCaptureIntentSupport.discardPendingCapture(
            id: UUID(),
            confirmDiscard: true,
            store: captureStore
        )

        XCTAssertTrue(output.confirmed)
        XCTAssertFalse(output.discarded)
        XCTAssertFalse(output.found)
        XCTAssertEqual(output.remainingCount, 0)
        XCTAssertEqual(output.recommendedRoute, .chat)
    }

    func testTriageCaptureReturnsMemoryActionForRememberedText() async throws {
        let output = try await KairoCaptureIntentSupport.triage(
            text: "記住：AFM 適合短上下文分類。",
            sourceName: "Capture"
        )

        XCTAssertEqual(output.suggestionKinds.contains(.memorySave), true)
        XCTAssertEqual(output.triage, .saveMemory)
        XCTAssertEqual(output.recommendedRoute, .captureReview)
        XCTAssertEqual(output.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertEqual(output.actionKinds, [.saveMemory])
        XCTAssertEqual(output.proposedActions.first?.kind, .saveMemory)
        guard case let .text(content) = output.proposedActions.first?.payload else {
            return XCTFail("Expected memory text payload")
        }
        XCTAssertTrue(content.contains("AFM"))
    }

    func testTriageCaptureReturnsWebSearchActionWithoutReminderNoise() async throws {
        let output = try await KairoCaptureIntentSupport.triage(
            text: "搜尋網路 AFM iOS 27 local inference",
            sourceName: "Capture"
        )

        XCTAssertEqual(output.actionKinds, [.openWebSearchHandoff])
        XCTAssertEqual(output.triage, .openHandoff)
        XCTAssertEqual(output.recommendedRoute, .captureReview)
        XCTAssertFalse(output.suggestionKinds.contains(.reminderDraft))
        guard case let .webSearch(draft) = output.proposedActions.first?.payload else {
            return XCTFail("Expected web search payload")
        }
        XCTAssertTrue(draft.query.contains("AFM"))
    }

    func testTriageCaptureOutputEncodesSuggestedActionsJSON() async throws {
        let output = try await KairoCaptureIntentSupport.triage(
            text: "週五前整理 Kairo demo",
            sourceName: "Capture"
        )

        let encoded = try output.encodedJSONString()
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(KairoCaptureTriageOutput.self, from: Data(encoded.utf8))

        XCTAssertEqual(decoded.actionKinds, [.createReminderDraft])
        XCTAssertEqual(decoded.triage, .createReminder)
        XCTAssertEqual(decoded.recommendedRoute, .captureReview)
        XCTAssertEqual(decoded.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertEqual(decoded.proposedActions.first?.kind, .createReminderDraft)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }

    func testTriageCaptureReturnsInfoPageTriageForResearchNoteWithoutActionDraft() async throws {
        let output = try await KairoCaptureIntentSupport.triage(
            text: "研究筆記：AFM prompt pipeline 先分類，再抽取事實，最後產生 JSON。",
            sourceName: "Capture"
        )

        XCTAssertEqual(output.triage, .createInfoPage)
        XCTAssertEqual(output.recommendedRoute, .captureReview)
        XCTAssertEqual(output.recommendedDeepLink, KairoCaptureTriageRoute.captureReview.deepLinkString)
        XCTAssertTrue(output.actionKinds.isEmpty)
        XCTAssertTrue(output.proposedActions.isEmpty)
    }

    func testTriageCaptureReturnsChatRouteForCaptureOnlyText() async throws {
        let output = try await KairoCaptureIntentSupport.triage(
            text: "Blue sky over the park.",
            sourceName: "Capture"
        )

        XCTAssertEqual(output.triage, .captureOnly)
        XCTAssertEqual(output.recommendedRoute, .chat)
        XCTAssertEqual(output.recommendedDeepLink, KairoCaptureTriageRoute.chat.deepLinkString)
        XCTAssertEqual(output.actionKinds, [])
    }
}
#endif
