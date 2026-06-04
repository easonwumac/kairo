import XCTest

final class AppReviewCopyTests: XCTestCase {
    func testAppReviewDeletionCopyDocumentsCurrentOnDeviceFlows() throws {
        let root = packageRootURL()
        let reviewNotes = try String(
            contentsOf: root.appendingPathComponent("docs/APP_REVIEW_NOTES.md"),
            encoding: .utf8
        )
        let privacyChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/PRIVACY_LABELS_CHECKLIST.md"),
            encoding: .utf8
        )
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )

        let requiredDeletionCopy = [
            "Data deletion flow for the current beta:",
            "Chat history: users delete a chat thread from Chat history.",
            "Memory records: users delete individual memories from Memory Center; exports include active records only, and deleted JSON records can be purged from disk.",
            "Local models: users delete downloaded models from Settings / Models, which also clears selected-model state when needed.",
            "API keys and OAuth tokens: users delete OpenAI API keys or disconnect OAuth connectors from Settings; secrets are stored in Keychain-backed storage.",
            "Audit logs: users clear the local metadata-only audit log from Settings / Privacy. This action does not delete chat history, memories, API keys, OAuth tokens, or downloaded models.",
            "Backend account deletion: not applicable in the current beta because Kairo has no backend account, server-side audit log, remotely stored chat history, or cloud memory sync."
        ]
        for copy in requiredDeletionCopy {
            XCTAssertTrue(reviewNotes.contains(copy), copy)
        }

        for source in [reviewNotes, privacyChecklist, readiness] {
            XCTAssertTrue(source.contains("Backend account deletion"))
            XCTAssertTrue(source.contains("no backend account"))
            XCTAssertFalse(source.localizedCaseInsensitiveContains("delete your backend account"))
            XCTAssertFalse(source.localizedCaseInsensitiveContains("server-side deletion request"))
            XCTAssertFalse(source.localizedCaseInsensitiveContains("cloud memory deletion request"))
            XCTAssertFalse(source.localizedCaseInsensitiveContains("delete all data from our servers"))
        }
    }

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        return url.deletingLastPathComponent()
    }
}
