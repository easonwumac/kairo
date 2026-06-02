import Foundation

public enum ShortcutNodeInvocationError: Error, Equatable, LocalizedError {
    case unsupportedNodeKind(String)
    case invalidInputJSON

    public var errorDescription: String? {
        switch self {
        case let .unsupportedNodeKind(rawValue):
            return "Unsupported Kairo Shortcut node kind: \(rawValue)."
        case .invalidInputJSON:
            return "Input JSON must be a valid ShortcutNodeInput payload."
        }
    }
}

public struct ShortcutNodeInvocationService: Sendable {
    private let runtime: ShortcutNodeRuntime

    public init(runtime: ShortcutNodeRuntime) {
        self.runtime = runtime
    }

    public func run(nodeKindRawValue: String, inputJSON: String) async throws -> String {
        guard let nodeKind = ShortcutNodeKind(rawValue: nodeKindRawValue) else {
            throw ShortcutNodeInvocationError.unsupportedNodeKind(nodeKindRawValue)
        }

        guard let data = inputJSON.data(using: .utf8) else {
            throw ShortcutNodeInvocationError.invalidInputJSON
        }

        let input: ShortcutNodeInput
        do {
            input = try JSONDecoder().decode(ShortcutNodeInput.self, from: data)
        } catch {
            throw ShortcutNodeInvocationError.invalidInputJSON
        }

        let output = try await runtime.run(nodeKind, input: input)
        return try output.encodedJSONString()
    }
}
