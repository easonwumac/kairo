import Foundation

public struct BackgroundTaskPolicy: Sendable {
    public var tasks: [BackgroundTaskDescriptor]
    public var maxRefreshInterval: TimeInterval

    public init(
        tasks: [BackgroundTaskDescriptor] = BackgroundTaskPolicy.defaultTasks,
        maxRefreshInterval: TimeInterval = 15 * 60
    ) {
        self.tasks = tasks
        self.maxRefreshInterval = maxRefreshInterval
    }

    public func descriptor(for identifier: String) -> BackgroundTaskDescriptor? {
        tasks.first { $0.identifier == identifier }
    }

    public func descriptors(for kind: BackgroundTaskKind) -> [BackgroundTaskDescriptor] {
        tasks.filter { $0.kind == kind }
    }

    public func plan(
        for request: BackgroundTaskRequest,
        now: Date = Date()
    ) -> BackgroundTaskPlan {
        guard let descriptor = descriptor(for: request.identifier) else {
            return BackgroundTaskPlan(
                request: request,
                decision: .reject,
                earliestBeginDate: nil,
                expirationBehavior: .stopAndReschedule,
                rationale: "No registered background task descriptor for \(request.identifier)."
            )
        }

        guard descriptor.allowedTriggers.contains(request.trigger) else {
            return BackgroundTaskPlan(
                request: request,
                decision: .reject,
                earliestBeginDate: nil,
                expirationBehavior: descriptor.expirationBehavior,
                rationale: "Trigger \(request.trigger.rawValue) is not allowed for \(descriptor.identifier)."
            )
        }

        guard !request.requiresContinuousExecution else {
            return BackgroundTaskPlan(
                request: request,
                decision: .reject,
                earliestBeginDate: nil,
                expirationBehavior: descriptor.expirationBehavior,
                rationale: "iOS does not allow Kairo to run as a continuous background daemon. Use BGTaskScheduler for bounded refresh/processing work."
            )
        }

        guard request.estimatedDuration <= descriptor.maxRuntime else {
            return BackgroundTaskPlan(
                request: request,
                decision: .deferred,
                earliestBeginDate: now.addingTimeInterval(descriptor.minimumInterval),
                expirationBehavior: descriptor.expirationBehavior,
                rationale: "Estimated work exceeds the bounded runtime budget for \(descriptor.kind.rawValue); split it into smaller checkpoints."
            )
        }

        let earliest = request.earliestBeginDate ?? now.addingTimeInterval(descriptor.minimumInterval)
        return BackgroundTaskPlan(
            request: request,
            decision: .schedule,
            earliestBeginDate: earliest,
            expirationBehavior: descriptor.expirationBehavior,
            rationale: "Schedule via BGTaskScheduler with identifier \(descriptor.identifier). Actual launch time is controlled by iOS."
        )
    }

    public static let defaultTasks: [BackgroundTaskDescriptor] = [
        BackgroundTaskDescriptor(
            identifier: "com.kairo.app.refresh",
            kind: .appRefresh,
            purpose: "Import queued Share Extension items, rotate lightweight caches, and prepare user-visible briefing drafts.",
            allowedTriggers: [.systemRefresh, .userInitiatedReschedule],
            requiredCapabilities: [.shareExtension, .memory, .notifications],
            minimumInterval: 15 * 60,
            maxRuntime: 25,
            requiresNetwork: false,
            requiresExternalPower: false,
            expirationBehavior: .saveCheckpointAndStop,
            sandboxNotes: "Use BGAppRefreshTaskRequest. Do not poll continuously or promise exact timing."
        ),
        BackgroundTaskDescriptor(
            identifier: "com.kairo.app.processing.local-model",
            kind: .processing,
            purpose: "Finish user-approved local model maintenance such as catalog validation or file cleanup.",
            allowedTriggers: [.userInitiatedReschedule, .afterUserConsent],
            requiredCapabilities: [.memory],
            minimumInterval: 60 * 60,
            maxRuntime: 10 * 60,
            requiresNetwork: true,
            requiresExternalPower: true,
            expirationBehavior: .saveCheckpointAndStop,
            sandboxNotes: "Use BGProcessingTaskRequest for bounded maintenance only. Large downloads must be user-visible and resumable."
        ),
        BackgroundTaskDescriptor(
            identifier: "com.kairo.app.processing.connectors",
            kind: .processing,
            purpose: "Perform bounded OAuth connector sync checkpoints after explicit account connection.",
            allowedTriggers: [.afterOAuthRefresh, .userInitiatedReschedule, .afterUserConsent],
            requiredCapabilities: [.externalConnectors],
            minimumInterval: 60 * 60,
            maxRuntime: 5 * 60,
            requiresNetwork: true,
            requiresExternalPower: false,
            expirationBehavior: .stopAndReschedule,
            sandboxNotes: "Connector sync is opportunistic. Prefer push/webhook or backend-assisted sync for reliable account updates."
        )
    ]
}

public struct BackgroundTaskDescriptor: Identifiable, Codable, Equatable, Sendable {
    public var id: String { identifier }
    public var identifier: String
    public var kind: BackgroundTaskKind
    public var purpose: String
    public var allowedTriggers: [BackgroundTaskTrigger]
    public var requiredCapabilities: [CapabilityKey]
    public var minimumInterval: TimeInterval
    public var maxRuntime: TimeInterval
    public var requiresNetwork: Bool
    public var requiresExternalPower: Bool
    public var expirationBehavior: BackgroundTaskExpirationBehavior
    public var sandboxNotes: String

    public init(
        identifier: String,
        kind: BackgroundTaskKind,
        purpose: String,
        allowedTriggers: [BackgroundTaskTrigger],
        requiredCapabilities: [CapabilityKey],
        minimumInterval: TimeInterval,
        maxRuntime: TimeInterval,
        requiresNetwork: Bool,
        requiresExternalPower: Bool,
        expirationBehavior: BackgroundTaskExpirationBehavior,
        sandboxNotes: String
    ) {
        self.identifier = identifier
        self.kind = kind
        self.purpose = purpose
        self.allowedTriggers = allowedTriggers
        self.requiredCapabilities = requiredCapabilities
        self.minimumInterval = minimumInterval
        self.maxRuntime = maxRuntime
        self.requiresNetwork = requiresNetwork
        self.requiresExternalPower = requiresExternalPower
        self.expirationBehavior = expirationBehavior
        self.sandboxNotes = sandboxNotes
    }
}

public enum BackgroundTaskKind: String, Codable, CaseIterable, Sendable {
    case appRefresh
    case processing
}

public enum BackgroundTaskTrigger: String, Codable, CaseIterable, Sendable {
    case systemRefresh
    case userInitiatedReschedule
    case afterUserConsent
    case afterOAuthRefresh
}

public enum BackgroundTaskExpirationBehavior: String, Codable, CaseIterable, Sendable {
    case saveCheckpointAndStop
    case stopAndReschedule
}

public struct BackgroundTaskRequest: Codable, Equatable, Sendable {
    public var identifier: String
    public var trigger: BackgroundTaskTrigger
    public var earliestBeginDate: Date?
    public var estimatedDuration: TimeInterval
    public var requiresContinuousExecution: Bool

    public init(
        identifier: String,
        trigger: BackgroundTaskTrigger,
        earliestBeginDate: Date? = nil,
        estimatedDuration: TimeInterval,
        requiresContinuousExecution: Bool = false
    ) {
        self.identifier = identifier
        self.trigger = trigger
        self.earliestBeginDate = earliestBeginDate
        self.estimatedDuration = estimatedDuration
        self.requiresContinuousExecution = requiresContinuousExecution
    }
}

public struct BackgroundTaskPlan: Codable, Equatable, Sendable {
    public var request: BackgroundTaskRequest
    public var decision: BackgroundTaskDecision
    public var earliestBeginDate: Date?
    public var expirationBehavior: BackgroundTaskExpirationBehavior
    public var rationale: String

    public init(
        request: BackgroundTaskRequest,
        decision: BackgroundTaskDecision,
        earliestBeginDate: Date?,
        expirationBehavior: BackgroundTaskExpirationBehavior,
        rationale: String
    ) {
        self.request = request
        self.decision = decision
        self.earliestBeginDate = earliestBeginDate
        self.expirationBehavior = expirationBehavior
        self.rationale = rationale
    }
}

public enum BackgroundTaskDecision: String, Codable, Sendable {
    case schedule
    case deferred
    case reject
}
