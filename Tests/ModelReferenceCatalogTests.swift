import XCTest

final class ModelReferenceCatalogTests: XCTestCase {
    func testModelReferenceCatalogIsMarkedUnsignedReferenceSeed() throws {
        let root = packageRootURL()
        let catalogURL = root.appendingPathComponent("Website/models/models.json")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        )
        let readme = try String(
            contentsOf: root.appendingPathComponent("Website/models/README.md"),
            encoding: .utf8
        )
        let readiness = try String(
            contentsOf: root.appendingPathComponent("docs/APP_STORE_READINESS.md"),
            encoding: .utf8
        )
        let catalogReleaseChecklist = try String(
            contentsOf: root.appendingPathComponent("docs/CATALOG_RELEASE_CHECKLIST.md"),
            encoding: .utf8
        )

        XCTAssertEqual(catalog["catalogSignatureStatus"] as? String, "referenceUnsigned")
        XCTAssertEqual(catalog["signature"] as? String, "unsigned-reference-catalog")
        XCTAssertEqual(catalog["sourceRepository"] as? String, "https://github.com/easonwumac/kairo-models")
        XCTAssertTrue(readme.contains("catalogSignatureStatus=referenceUnsigned"))
        XCTAssertTrue(readme.contains("not production signed catalog evidence"))
        XCTAssertTrue(readiness.contains("Website/skills/skills.json` and `Website/models/models.json` seeds are marked `catalogSignatureStatus=referenceUnsigned`"))
        XCTAssertTrue(catalogReleaseChecklist.contains("Website/skills/skills.json` and `Website/models/models.json`"))
        XCTAssertTrue(catalogReleaseChecklist.contains("not production signed catalog evidence"))
    }

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        return url.deletingLastPathComponent()
    }
}
