import XCTest

final class SourceHealthTests: XCTestCase {
    func testLocalModelCoverageLivesInFocusedTestFile() throws {
        let root = packageRootURL()
        let focusedTestsURL = root.appendingPathComponent("Tests/LocalModelFeatureTests.swift")
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: focusedTestsURL.path),
            "Local model tests should live in Tests/LocalModelFeatureTests.swift instead of the KairoCoreTests monolith."
        )

        let coreTests = try String(contentsOf: root.appendingPathComponent("Tests/KairoCoreTests.swift"))
        XCTAssertFalse(coreTests.contains("testDefaultLocalModelCatalogExposesPopularStarterModelsForSettings"))
        XCTAssertFalse(coreTests.contains("testVerifiedLocalModelDownloaderInstallsModelAndUpdatesRegistry"))
        XCTAssertFalse(coreTests.contains("testLocalModelRoutingAIProviderUsesSelectedLocalModelForEligiblePreferLocalWork"))
    }

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        return url.deletingLastPathComponent()
    }
}
