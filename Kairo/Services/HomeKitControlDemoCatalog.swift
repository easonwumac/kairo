import Foundation

public struct HomeKitControlDemoCatalog: Codable, Equatable, Sendable {
    public var recipes: [HomeKitControlDemoRecipe]

    public init(recipes: [HomeKitControlDemoRecipe]) {
        self.recipes = recipes
    }

    public func recipe(id: String) -> HomeKitControlDemoRecipe? {
        recipes.first { $0.id == id }
    }

    public static let `default` = HomeKitControlDemoCatalog(recipes: [
        HomeKitControlDemoRecipe(
            id: "evening-scene",
            title: "Evening Scene",
            summary: "Preview a confirmed HomeKit scene handoff for winding down the living room.",
            sandboxNotes: "HomeKit entitlement, Home authorization, and explicit user confirmation are required before execution.",
            action: AgentAction(
                id: UUID(uuidString: "11111111-1111-4111-8111-111111111111")!,
                kind: .controlHome,
                title: "Run Evening Wind Down",
                rationale: "User confirmed Kairo may run a HomeKit scene.",
                payload: .homeControl(HomeControlRequest(
                    homeName: "Home",
                    roomName: "Living Room",
                    targetName: "Evening Wind Down",
                    command: .runScene
                )),
                riskTier: .tier3HighRiskExternal
            )
        ),
        HomeKitControlDemoRecipe(
            id: "desk-lamp",
            title: "Desk Lamp",
            summary: "Preview a confirmed HomeKit accessory write for a focused work setup.",
            sandboxNotes: "HomeKit entitlement, Home authorization, and visible confirmation protect accessory writes.",
            action: AgentAction(
                id: UUID(uuidString: "22222222-2222-4222-8222-222222222222")!,
                kind: .controlHome,
                title: "Turn On Desk Lamp",
                rationale: "User confirmed Kairo may update a HomeKit accessory.",
                payload: .homeControl(HomeControlRequest(
                    homeName: "Home",
                    roomName: "Office",
                    targetName: "Desk Lamp",
                    command: .setPower,
                    value: .bool(true)
                )),
                riskTier: .tier3HighRiskExternal
            )
        ),
        HomeKitControlDemoRecipe(
            id: "front-door-lock",
            title: "Front Door Lock Guard",
            summary: "Preview a security-device HomeKit write without executing it automatically.",
            sandboxNotes: "Locks and security devices stay high risk: HomeKit entitlement, Home authorization, visible preview, and explicit in-app confirmation are required.",
            action: AgentAction(
                id: UUID(uuidString: "33333333-3333-4333-8333-333333333333")!,
                kind: .controlHome,
                title: "Preview Front Door Lock Change",
                rationale: "User reviewed a high-risk HomeKit security-device action before any write.",
                payload: .homeControl(HomeControlRequest(
                    homeName: "Home",
                    roomName: "Entry",
                    targetName: "Front Door Lock",
                    command: .setPower,
                    value: .bool(false)
                )),
                riskTier: .tier3HighRiskExternal
            )
        )
    ])
}

public struct HomeKitControlDemoRecipe: Codable, Equatable, Identifiable, Sendable {
    public var id: String
    public var title: String
    public var summary: String
    public var sandboxNotes: String
    public var action: AgentAction

    public init(
        id: String,
        title: String,
        summary: String,
        sandboxNotes: String,
        action: AgentAction
    ) {
        self.id = id
        self.title = title
        self.summary = summary
        self.sandboxNotes = sandboxNotes
        self.action = action
    }

    public var targetSummary: String {
        guard case let .homeControl(request) = action.payload else {
            return "Unsupported HomeKit payload"
        }

        let location = [request.homeName, request.roomName].compactMap { $0 }.joined(separator: " / ")
        let prefix = location.isEmpty ? request.targetName : "\(location) / \(request.targetName)"
        return "\(prefix) · \(request.command.settingsTitle)"
    }

    public var confirmationSummary: String {
        guard case let .homeControl(request) = action.payload else {
            return "Confirm before Kairo runs this HomeKit action."
        }

        switch request.command {
        case .runScene:
            return "Confirm before Kairo runs the HomeKit scene."
        case .setPower, .setBrightness, .setTargetTemperature:
            let securityKeywords = ["lock", "door", "garage", "alarm", "camera"]
            if securityKeywords.contains(where: { request.targetName.localizedCaseInsensitiveContains($0) }) {
                return "Confirm in Kairo before any HomeKit security-device write."
            }
            return "Confirm before Kairo writes to the HomeKit accessory."
        }
    }
}

public extension HomeControlCommand {
    var settingsTitle: String {
        switch self {
        case .runScene:
            return "Run Scene"
        case .setPower:
            return "Set Power"
        case .setBrightness:
            return "Set Brightness"
        case .setTargetTemperature:
            return "Set Temperature"
        }
    }
}
