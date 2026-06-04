import XCTest

final class ModelReferenceCatalogTests: XCTestCase {
    func testModelReferenceCatalogIsMarkedUnsignedReferenceSeed() throws {
        let root = packageRootURL()
        let catalogURL = root.appendingPathComponent("Website/models/models.json")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(
            JSONSerialization.jsonObject(with: catalogData) as? [String: Any]
        )

        XCTAssertEqual(catalog["catalogSignatureStatus"] as? String, "referenceUnsigned")
        XCTAssertEqual(catalog["signature"] as? String, "unsigned-reference-catalog")
        XCTAssertEqual(catalog["sourceRepository"] as? String, "https://github.com/easonwumac/kairo-models")
    }

    private func packageRootURL() -> URL {
        var url = URL(fileURLWithPath: #filePath)
        while url.lastPathComponent != "Tests" {
            url.deleteLastPathComponent()
        }
        return url.deletingLastPathComponent()
    }
}
