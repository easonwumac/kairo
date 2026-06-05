import Foundation

public enum CapabilityToolPolicy: String, Codable, CaseIterable, Sendable {
    case allow
    case askEveryTime
    case deny

    public var displayName: String {
        switch self {
        case .allow:
            return KairoL10n.string("access.policy.allow")
        case .askEveryTime:
            return KairoL10n.string("access.policy.askEveryTime")
        case .deny:
            return KairoL10n.string("access.policy.deny")
        }
    }
}

public protocol CapabilityToolPolicyProviding: Sendable {
    func policy(for capability: Capability) -> CapabilityToolPolicy
    func policy(for capabilityKey: CapabilityKey, permission: PermissionRequirement) -> CapabilityToolPolicy
}

public protocol CapabilityToolPolicyStoring: CapabilityToolPolicyProviding {
    func setPolicy(_ policy: CapabilityToolPolicy, for capabilityKey: CapabilityKey) throws
}

public struct DefaultCapabilityToolPolicyProvider: CapabilityToolPolicyProviding {
    public init() {}

    public func policy(for capability: Capability) -> CapabilityToolPolicy {
        policy(for: capability.key, permission: capability.permission)
    }

    public func policy(for capabilityKey: CapabilityKey, permission: PermissionRequirement) -> CapabilityToolPolicy {
        Self.defaultPolicy(for: permission)
    }

    public static func choices(for permission: PermissionRequirement) -> [CapabilityToolPolicy] {
        if supportsAskEveryTime(permission) {
            return [.allow, .askEveryTime, .deny]
        }
        return [.allow, .deny]
    }

    public static func defaultPolicy(for permission: PermissionRequirement) -> CapabilityToolPolicy {
        supportsAskEveryTime(permission) ? .askEveryTime : .allow
    }

    public static func normalized(_ policy: CapabilityToolPolicy, permission: PermissionRequirement) -> CapabilityToolPolicy {
        choices(for: permission).contains(policy) ? policy : defaultPolicy(for: permission)
    }

    private static func supportsAskEveryTime(_ permission: PermissionRequirement) -> Bool {
        switch permission {
        case .runtimePrompt, .oauth:
            return true
        case .none, .userInitiated, .entitlement, .unsupported:
            return false
        }
    }
}

public final class InMemoryCapabilityToolPolicyStore: CapabilityToolPolicyStoring, @unchecked Sendable {
    private let lock = NSLock()
    private var policiesByRawKey: [String: CapabilityToolPolicy]

    public init(policies: [CapabilityKey: CapabilityToolPolicy] = [:]) {
        self.policiesByRawKey = Dictionary(uniqueKeysWithValues: policies.map { ($0.key.rawValue, $0.value) })
    }

    public func policy(for capability: Capability) -> CapabilityToolPolicy {
        policy(for: capability.key, permission: capability.permission)
    }

    public func policy(for capabilityKey: CapabilityKey, permission: PermissionRequirement) -> CapabilityToolPolicy {
        lock.lock()
        let policy = policiesByRawKey[capabilityKey.rawValue]
        lock.unlock()
        return DefaultCapabilityToolPolicyProvider.normalized(
            policy ?? DefaultCapabilityToolPolicyProvider.defaultPolicy(for: permission),
            permission: permission
        )
    }

    public func setPolicy(_ policy: CapabilityToolPolicy, for capabilityKey: CapabilityKey) {
        lock.lock()
        policiesByRawKey[capabilityKey.rawValue] = policy
        lock.unlock()
    }
}

public final class FileBackedCapabilityToolPolicyStore: CapabilityToolPolicyStoring, @unchecked Sendable {
    private let fileURL: URL
    private let lock = NSLock()
    private var policiesByRawKey: [String: CapabilityToolPolicy]

    public init(fileURL: URL) throws {
        self.fileURL = fileURL
        if FileManager.default.fileExists(atPath: fileURL.path) {
            let data = try Data(contentsOf: fileURL)
            self.policiesByRawKey = try JSONDecoder().decode([String: CapabilityToolPolicy].self, from: data)
        } else {
            self.policiesByRawKey = [:]
        }
    }

    public func policy(for capability: Capability) -> CapabilityToolPolicy {
        policy(for: capability.key, permission: capability.permission)
    }

    public func policy(for capabilityKey: CapabilityKey, permission: PermissionRequirement) -> CapabilityToolPolicy {
        lock.lock()
        let policy = policiesByRawKey[capabilityKey.rawValue]
        lock.unlock()
        return DefaultCapabilityToolPolicyProvider.normalized(
            policy ?? DefaultCapabilityToolPolicyProvider.defaultPolicy(for: permission),
            permission: permission
        )
    }

    public func setPolicy(_ policy: CapabilityToolPolicy, for capabilityKey: CapabilityKey) throws {
        lock.lock()
        policiesByRawKey[capabilityKey.rawValue] = policy
        let snapshot = policiesByRawKey
        lock.unlock()

        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let data = try JSONEncoder().encode(snapshot)
        try data.write(to: fileURL, options: [.atomic])
    }
}

