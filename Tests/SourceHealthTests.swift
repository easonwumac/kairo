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

    func testSandboxActionSupportStaysSplitAcrossFocusedFiles() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let splitFiles = [
            "SandboxActionCatalog.swift": "public struct SandboxActionCatalog",
            "HomeKitControlDemoCatalog.swift": "public struct HomeKitControlDemoCatalog",
            "SandboxActionScheduling.swift": "public protocol NotificationScheduling",
            "SandboxActionExecutor.swift": "public actor SandboxActionExecutor"
        ]

        XCTAssertFalse(
            FileManager.default.fileExists(atPath: services.appendingPathComponent("SandboxActionSupport.swift").path),
            "Sandbox action support should stay split instead of returning to one monolithic file."
        )

        for (fileName, requiredSymbol) in splitFiles {
            let sourceURL = services.appendingPathComponent(fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), fileName)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            XCTAssertTrue(source.contains(requiredSymbol), fileName)
            XCTAssertLessThan(source.split(separator: "\n").count, 320, fileName)
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
