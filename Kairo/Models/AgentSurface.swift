import Foundation

public enum AgentSurface: String, Codable, CaseIterable, Sendable, Identifiable {
    case app
    case shareExtension
    case appIntent
    case shortcut
    case keyboard
    case widget
    case notification
    case homeKit
    case carMode

    public var id: String { rawValue }
}
