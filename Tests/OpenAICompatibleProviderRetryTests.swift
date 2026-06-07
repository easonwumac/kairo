import XCTest
@testable import KairoCore

final class OpenAICompatibleProviderRetryTests: XCTestCase {
    func testRetriesAfterTransientBadShapeAndSucceeds() async throws {
        let client = SequenceHTTPClient(responses: [
            (200, "{\"unexpected\":\"shape\"}"),
            (200, "{\"unexpected\":\"shape\"}"),
            (200, validOMLXResponse(message: "Hello after retries"))
        ])
        let provider = OpenAICompatibleProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: client,
            endpoint: "http://localhost:8000/v1",
            apiKey: "test-key",
            model: "test-model"
        )
        let response = try await provider.complete(AICompletionRequest(systemPrompt: "s", userPrompt: "hi"))
        XCTAssertEqual(response.message, "Hello after retries")
        let attempts = await client.invocationCount()
        XCTAssertEqual(attempts, 3)
    }

    func testGivesUpAfterTransportRetriesExhausted() async throws {
        let client = SequenceHTTPClient(responses: Array(repeating: (200, "{\"unexpected\":\"shape\"}"), count: 8))
        let provider = OpenAICompatibleProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: client,
            endpoint: "http://localhost:8000/v1",
            apiKey: "test-key",
            model: "test-model"
        )
        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "s", userPrompt: "hi"))
            XCTFail("expected throw")
        } catch let error as AIProviderError {
            switch error {
            case .requestFailed:
                let attempts = await client.invocationCount()
                XCTAssertEqual(attempts, 4)
            default:
                XCTFail("expected requestFailed, got \(error)")
            }
        }
    }

    func testHTTP4xxIsNotRetried() async throws {
        let client = SequenceHTTPClient(responses: [
            (400, "{\"error\":{\"message\":\"bad request\"}}")
        ])
        let provider = OpenAICompatibleProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: client,
            endpoint: "http://localhost:8000/v1",
            apiKey: "test-key",
            model: "test-model"
        )
        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "s", userPrompt: "hi"))
            XCTFail("expected throw")
        } catch is AIProviderError {
            let attempts = await client.invocationCount()
            XCTAssertEqual(attempts, 1, "4xx should not be retried")
        }
    }

    func testHTTP500IsRetried() async throws {
        let client = SequenceHTTPClient(responses: [
            (500, "server boom"),
            (200, validOMLXResponse(message: "Recovered"))
        ])
        let provider = OpenAICompatibleProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: client,
            endpoint: "http://localhost:8000/v1",
            apiKey: "test-key",
            model: "test-model"
        )
        let response = try await provider.complete(AICompletionRequest(systemPrompt: "s", userPrompt: "hi"))
        XCTAssertEqual(response.message, "Recovered")
        let attempts = await client.invocationCount()
        XCTAssertEqual(attempts, 2)
    }

    func testSurfacesErrorEnvelopeMessageWhenBodyShapeDiffers() async throws {
        let client = SequenceHTTPClient(responses: Array(repeating: (
            200,
            "{\"error\":{\"message\":\"model not loaded\",\"type\":\"invalid_request\"}}"
        ), count: 5))
        let provider = OpenAICompatibleProvider(
            credentialStore: InMemoryCredentialStore(),
            httpClient: client,
            endpoint: "http://localhost:8000/v1",
            apiKey: "test-key",
            model: "test-model"
        )
        do {
            _ = try await provider.complete(AICompletionRequest(systemPrompt: "s", userPrompt: "hi"))
            XCTFail("expected throw")
        } catch let AIProviderError.requestFailed(message) {
            XCTAssertEqual(message, "model not loaded")
        } catch {
            XCTFail("expected AIProviderError.requestFailed, got \(error)")
        }
    }

    private func validOMLXResponse(message: String) -> String {
        let escaped = message
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
        return """
        {"choices":[{"message":{"role":"assistant","content":"\(escaped)"}}],"usage":{"prompt_tokens":12,"completion_tokens":5,"total_tokens":17}}
        """
    }
}

private actor SequenceHTTPClient: HTTPClient {
    private var responses: [(Int, String)]
    private var invocations: Int = 0

    init(responses: [(Int, String)]) {
        self.responses = responses
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        invocations += 1
        let (status, body) = responses.isEmpty
            ? (500, "exhausted")
            : responses.removeFirst()
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"]
        )!
        return (Data(body.utf8), response)
    }

    func invocationCount() -> Int { invocations }
}
