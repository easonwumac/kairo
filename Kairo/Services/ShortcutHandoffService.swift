import Foundation

public struct ShortcutHandoffRequest: Equatable, Sendable {
    public var shortcutName: String
    public var input: ShortcutNodeInput
    public var callbackBaseURL: URL
    public var requestID: String

    public init(
        shortcutName: String,
        input: ShortcutNodeInput,
        callbackBaseURL: URL,
        requestID: String = UUID().uuidString
    ) {
        self.shortcutName = shortcutName
        self.input = input
        self.callbackBaseURL = callbackBaseURL
        self.requestID = requestID
    }
}

public struct ShortcutHandoffCallback: Equatable, Sendable {
    public var requestID: String
    public var output: ShortcutNodeOutput

    public init(requestID: String, output: ShortcutNodeOutput) {
        self.requestID = requestID
        self.output = output
    }
}

public enum ShortcutHandoffError: Error, Equatable {
    case emptyShortcutName
    case invalidCallbackURL
    case invalidRunShortcutURL
    case unsupportedCallbackURL
    case missingRequestID
    case missingOutput
    case invalidOutput
}

public struct ShortcutHandoffService: Sendable {
    public init() {}

    public func runShortcutURL(for request: ShortcutHandoffRequest) throws -> URL {
        let shortcutName = request.shortcutName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !shortcutName.isEmpty else {
            throw ShortcutHandoffError.emptyShortcutName
        }

        var input = request.input
        input.variables["kairoHandoffRequestID"] = request.requestID
        input.variables["kairoCallbackURL"] = try callbackURL(for: request).absoluteString

        var components = URLComponents()
        components.scheme = "shortcuts"
        components.host = "run-shortcut"
        components.queryItems = [
            URLQueryItem(name: "name", value: shortcutName),
            URLQueryItem(name: "input", value: "text"),
            URLQueryItem(name: "text", value: try input.encodedJSONString())
        ]

        guard let url = components.url else {
            throw ShortcutHandoffError.invalidRunShortcutURL
        }
        return url
    }

    public func parseCallback(_ url: URL) throws -> ShortcutHandoffCallback {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "kairo",
              components.host == "shortcuts",
              components.path == "/callback" else {
            throw ShortcutHandoffError.unsupportedCallbackURL
        }

        let query = queryValues(from: components.queryItems ?? [])
        guard let requestID = query["requestID"], !requestID.isEmpty else {
            throw ShortcutHandoffError.missingRequestID
        }
        guard let outputJSON = query["output"] else {
            throw ShortcutHandoffError.missingOutput
        }
        guard let data = outputJSON.data(using: .utf8),
              let output = try? JSONDecoder().decode(ShortcutNodeOutput.self, from: data) else {
            throw ShortcutHandoffError.invalidOutput
        }

        return ShortcutHandoffCallback(requestID: requestID, output: output)
    }

    private func callbackURL(for request: ShortcutHandoffRequest) throws -> URL {
        guard var components = URLComponents(url: request.callbackBaseURL, resolvingAgainstBaseURL: false),
              components.scheme == "kairo",
              components.host == "shortcuts",
              components.path == "/callback" else {
            throw ShortcutHandoffError.invalidCallbackURL
        }

        var queryItems = components.queryItems ?? []
        queryItems.removeAll { $0.name == "requestID" }
        queryItems.append(URLQueryItem(name: "requestID", value: request.requestID))
        components.queryItems = queryItems

        guard let url = components.url else {
            throw ShortcutHandoffError.invalidCallbackURL
        }
        return url
    }

    private func queryValues(from queryItems: [URLQueryItem]) -> [String: String] {
        var values: [String: String] = [:]
        for item in queryItems {
            values[item.name] = item.value
        }
        return values
    }
}
