import XCTest
@testable import KairoCore

#if canImport(AppIntents)
final class KairoCaptureIntentSupportTests: XCTestCase {
    func testTriageCaptureReturnsMemoryActionForRememberedText() async throws {
        let output = try await KairoCaptureIntentSupport.triage(
            text: "記住：AFM 適合短上下文分類。",
            sourceName: "Capture"
        )

        XCTAssertEqual(output.suggestionKinds.contains(.memorySave), true)
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
        XCTAssertEqual(decoded.proposedActions.first?.kind, .createReminderDraft)
        XCTAssertEqual(decoded.schemaVersion, 1)
    }
}
#endif
