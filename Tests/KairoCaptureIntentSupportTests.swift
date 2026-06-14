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
