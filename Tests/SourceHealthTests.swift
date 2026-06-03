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

    func testUITestHelpersStaySplitFromSmokeScenarios() throws {
        let root = packageRootURL()
        let uiTests = root.appendingPathComponent("KairoUITests", isDirectory: true)
        let smokeURL = uiTests.appendingPathComponent("KairoAppSmokeUITests.swift")
        let helpersURL = uiTests.appendingPathComponent("KairoAppSmokeUITests+Helpers.swift")

        XCTAssertTrue(
            FileManager.default.fileExists(atPath: helpersURL.path),
            "Reusable UI navigation/search helpers should live outside the smoke scenario file."
        )

        let smokeSource = try String(contentsOf: smokeURL, encoding: .utf8)
        let helperSource = try String(contentsOf: helpersURL, encoding: .utf8)
        XCTAssertLessThan(smokeSource.split(separator: "\n").count, 720, "Keep smoke scenarios readable.")
        XCTAssertTrue(helperSource.contains("extension KairoAppSmokeUITests"))
        XCTAssertTrue(helperSource.contains("func openAccessAndVerifyHomeKitDemos()"))
        XCTAssertTrue(helperSource.contains("func findStaticText("))
        XCTAssertTrue(helperSource.contains("func relaunchForUITesting("))
    }

    func testShortcutDemoCatalogStaysSplitAcrossFocusedFiles() throws {
        let root = packageRootURL()
        let services = root.appendingPathComponent("Kairo/Services", isDirectory: true)
        let splitFiles = [
            "ShortcutDemoCatalog.swift": "public struct ShortcutDemoCatalog",
            "ShortcutDemoRecipeDefinitions.swift": "static let officialRecipes",
            "ShortcutDemoEmailDefinitions.swift": "static let communicationRecipes",
            "ShortcutDemoHomeDefinitions.swift": "static let homeRecipes",
            "ShortcutDemoModels.swift": "public struct ShortcutDemoRecipe",
            "ShortcutDemoRecipeRunner.swift": "public actor ShortcutDemoRecipeRunner"
        ]

        for (fileName, requiredSymbol) in splitFiles {
            let sourceURL = services.appendingPathComponent(fileName)
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path), fileName)
            let source = try String(contentsOf: sourceURL, encoding: .utf8)
            XCTAssertTrue(source.contains(requiredSymbol), fileName)
        }

        let catalogSource = try String(
            contentsOf: services.appendingPathComponent("ShortcutDemoCatalog.swift"),
            encoding: .utf8
        )
        XCTAssertFalse(catalogSource.contains("daily-briefing"))

        let lineBudgets = [
            "ShortcutDemoCatalog.swift": 80,
            "ShortcutDemoModels.swift": 220,
            "ShortcutDemoRecipeDefinitions.swift": 500,
            "ShortcutDemoEmailDefinitions.swift": 260,
            "ShortcutDemoHomeDefinitions.swift": 140,
            "ShortcutDemoRecipeRunner.swift": 120
        ]
        for (fileName, maxLines) in lineBudgets {
            let source = try String(contentsOf: services.appendingPathComponent(fileName), encoding: .utf8)
            XCTAssertLessThan(source.split(separator: "\n").count, maxLines, fileName)
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
