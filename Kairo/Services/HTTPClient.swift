import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public protocol HTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionHTTPClient: HTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        return (data, httpResponse)
    }
}

public enum HTTPClientError: Error, Equatable {
    case invalidResponse
    case unacceptableStatusCode(Int, String)
}

public struct StaticHTTPResponse: Sendable {
    public var statusCode: Int
    public var body: Data
    public var headers: [String: String]

    public init(
        statusCode: Int = 200,
        body: Data,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) {
        self.statusCode = statusCode
        self.body = body
        self.headers = headers
    }

    public init(
        statusCode: Int = 200,
        body: String,
        headers: [String: String] = ["Content-Type": "application/json"]
    ) {
        self.init(statusCode: statusCode, body: Data(body.utf8), headers: headers)
    }
}

public struct StaticHTTPClient: HTTPClient {
    private let routes: [URL: StaticHTTPResponse]

    public init(routes: [URL: StaticHTTPResponse]) {
        self.routes = routes
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        guard let url = request.url else {
            throw HTTPClientError.invalidResponse
        }

        let route = routes[url] ?? StaticHTTPResponse(
            statusCode: 404,
            body: #"{"error":"No static response configured."}"#
        )
        guard let response = HTTPURLResponse(
            url: url,
            statusCode: route.statusCode,
            httpVersion: nil,
            headerFields: route.headers
        ) else {
            throw HTTPClientError.invalidResponse
        }
        return (route.body, response)
    }
}
