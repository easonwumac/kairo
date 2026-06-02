import Foundation

public struct KairoEnvironment: Sendable {
    public let memoryStore: MemoryStore
    public let credentialStore: CredentialStore
    public let aiProvider: AIProvider
    public let permissionService: PermissionService
    public let auditLogger: AuditLogger

    public init(
        memoryStore: MemoryStore,
        credentialStore: CredentialStore,
        aiProvider: AIProvider,
        permissionService: PermissionService = StubPermissionService(),
        auditLogger: AuditLogger = InMemoryAuditLogger()
    ) {
        self.memoryStore = memoryStore
        self.credentialStore = credentialStore
        self.aiProvider = aiProvider
        self.permissionService = permissionService
        self.auditLogger = auditLogger
    }

    public static func preview() -> KairoEnvironment {
        let credentialStore = InMemoryCredentialStore()
        return KairoEnvironment(
            memoryStore: InMemoryMemoryStore(),
            credentialStore: credentialStore,
            aiProvider: MockAIProvider(),
            permissionService: StubPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }

    public static func live(appName: String = "Kairo") async throws -> KairoEnvironment {
        let paths = KairoPaths(appName: appName)
        let memoryStore = try await JSONFileMemoryStore(fileURL: paths.memoryStoreURL)
        let credentialStore = KeychainCredentialStore()
        let aiProvider = OpenAIProvider(credentialStore: credentialStore)

        return KairoEnvironment(
            memoryStore: memoryStore,
            credentialStore: credentialStore,
            aiProvider: aiProvider,
            permissionService: SystemPermissionService(),
            auditLogger: InMemoryAuditLogger()
        )
    }
}

public struct KairoPaths: Sendable {
    public let appName: String

    public init(appName: String = "Kairo") {
        self.appName = appName
    }

    public var applicationSupportDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base.appendingPathComponent(appName, isDirectory: true)
    }

    public var memoryStoreURL: URL {
        applicationSupportDirectory.appendingPathComponent("memory-store.json")
    }
}
