import XCTest
@testable import KairoCore

final class KairoLocalModelBackendAPITests: XCTestCase {
    func testLocalModelBackendAPIForwardsManagementCallsThroughCoreService() async throws {
        let service = try await makeBackendTestLocalModelSettingsService()
        let api = KairoLocalModelBackendService(localModelSettingsService: service)

        var status = try await api.status()
        XCTAssertEqual(status.availableModels.map(\.id), ["qwen-small", "llama-stale"])
        XCTAssertNil(status.selectedModelID)
        XCTAssertEqual(status.preference, .automatic)

        try await api.selectModel(id: "qwen-small")
        try await api.setPreference(.preferLocal)

        status = try await api.status()
        XCTAssertEqual(status.selectedModelID, "qwen-small")
        XCTAssertEqual(status.preference, .preferLocal)

        let cleanedModelIDs = try await api.cleanupStaleDownloadingRecords()
        XCTAssertEqual(cleanedModelIDs, ["llama-stale"])

        try await api.deleteModel(id: "qwen-small")
        status = try await api.status()
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.installedModels.contains { $0.modelID == "qwen-small" })
    }

    func testLocalModelBackendAPIFailsClosedWhenServiceIsUnavailable() async throws {
        let api = KairoLocalModelBackendService(localModelSettingsService: nil)

        do {
            _ = try await api.status()
            XCTFail("Expected local model API status to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }

        do {
            try await api.selectModel(id: "qwen-small")
            XCTFail("Expected local model API selection to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }

    func testEnvironmentBackendAPIExposesLocalModelManagementFacade() async throws {
        let environment = KairoEnvironment.preview()

        do {
            _ = try await environment.backendAPI.localModels.status()
            XCTFail("Expected preview backend local model API to fail closed without a configured service.")
        } catch let error as KairoLocalModelAPIError {
            XCTAssertEqual(error, .unavailable)
        }
    }
}
