import XCTest
@testable import KairoCore

final class KairoAccessBackendAPITests: XCTestCase {
    func testAccessBackendAPIResolvesPermissionStatusesWithoutRequestingPrompts() async throws {
        let permissions = RecordingPermissionService(statuses: [
            .calendar: .denied,
            .reminders: .restricted,
            .notifications: .unknown,
            .contacts: .available
        ])
        let api = KairoAccessBackendService(permissionService: permissions)

        let capabilities = await api.capabilities()
        let statuses = Dictionary(uniqueKeysWithValues: capabilities.map { ($0.key, $0.status) })

        XCTAssertEqual(statuses[.calendar], .denied)
        XCTAssertEqual(statuses[.reminders], .restricted)
        XCTAssertEqual(statuses[.notifications], .unknown)
        XCTAssertEqual(statuses[.contacts], .available)
        XCTAssertTrue(capabilities.contains { $0.key == .chat && $0.status == .available })
        let requestedCapabilities = await permissions.requestedCapabilities()
        XCTAssertEqual(requestedCapabilities, [])
    }

    func testAccessBackendAPIForwardsExplicitPermissionRequests() async throws {
        let permissions = RecordingPermissionService(
            statuses: [.notifications: .unknown],
            requestResults: [.notifications: .denied]
        )
        let api = KairoAccessBackendService(permissionService: permissions)

        let initialStatus = await api.status(for: .notifications)
        let requestedStatus = try await api.request(.notifications)

        XCTAssertEqual(initialStatus, .unknown)
        XCTAssertEqual(requestedStatus, .denied)
        let requestedCapabilities = await permissions.requestedCapabilities()
        XCTAssertEqual(requestedCapabilities, [.notifications])
    }

    func testAccessBackendAPIResolvesBuiltInPhoneToolReadinessFromInjectedCatalog() async throws {
        let toolCatalog = BuiltInPhoneToolCatalog(tools: [
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .memorySave)),
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .reminderWrite)),
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .oauthConnectorSetupStatus)),
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .homeKitPreview))
        ])
        let permissions = RecordingPermissionService(statuses: [
            .memory: .available,
            .reminders: .unknown,
            .externalConnectors: .unknown,
            .homeKit: .unknown
        ])
        let api = KairoAccessBackendService(toolCatalog: toolCatalog, permissionService: permissions)

        let tools = await api.tools()
        let summaries = Dictionary(uniqueKeysWithValues: tools.map { ($0.toolID, $0) })

        XCTAssertEqual(summaries[.memorySave]?.readiness, .available)
        XCTAssertEqual(summaries[.memorySave]?.requiresConfirmation, true)
        XCTAssertEqual(summaries[.reminderWrite]?.readiness, .needsPermission)
        XCTAssertEqual(summaries[.oauthConnectorSetupStatus]?.readiness, .needsSetup)
        XCTAssertEqual(summaries[.oauthConnectorSetupStatus]?.canBeSuggestedAsExecutable, false)
        XCTAssertEqual(summaries[.homeKitPreview]?.readiness, .scaffolded)
        XCTAssertEqual(summaries[.homeKitPreview]?.executionKind, .scaffoldPreviewOnly)
    }

    func testAccessBackendAPIToolSummariesBlockExecutableSuggestionsWhenPermissionUnavailable() async throws {
        let toolCatalog = BuiltInPhoneToolCatalog(tools: [
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .calendarWrite)),
            try XCTUnwrap(BuiltInPhoneToolCatalog().tool(id: .emailHandoff))
        ])
        let permissions = RecordingPermissionService(statuses: [
            .calendar: .denied,
            .mail: .available
        ])
        let api = KairoAccessBackendService(toolCatalog: toolCatalog, permissionService: permissions)

        let tools = await api.tools()
        let summaries = Dictionary(uniqueKeysWithValues: tools.map { ($0.toolID, $0) })

        XCTAssertEqual(summaries[.calendarWrite]?.readiness, .unavailable)
        XCTAssertEqual(summaries[.calendarWrite]?.canBeSuggestedAsExecutable, false)
        XCTAssertEqual(summaries[.emailHandoff]?.readiness, .available)
        XCTAssertEqual(summaries[.emailHandoff]?.canBeSuggestedAsExecutable, true)
    }

    func testAccessBackendAPIResolvesAppIntegrationReadinessFromInjectedCatalog() async throws {
        let appIntegrationSkillCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .appleMailHandoff)),
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .gmailDraftAPI)),
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .draftsCreateHandoff))
        ])
        let permissions = RecordingPermissionService(statuses: [
            .mail: .available,
            .externalConnectors: .available,
            .documents: .available
        ])
        let api = KairoAccessBackendService(
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            permissionService: permissions
        )

        let integrations = await api.appIntegrations()
        let summaries = Dictionary(uniqueKeysWithValues: integrations.map { ($0.skillID, $0) })

        XCTAssertEqual(summaries[.appleMailHandoff]?.readiness, .available)
        XCTAssertEqual(summaries[.appleMailHandoff]?.executionMode, .openURL)
        XCTAssertEqual(summaries[.appleMailHandoff]?.canBeSuggestedAsExecutable, true)
        XCTAssertEqual(summaries[.gmailDraftAPI]?.readiness, .needsOAuth)
        XCTAssertEqual(summaries[.gmailDraftAPI]?.executionMode, .apiCall)
        XCTAssertEqual(summaries[.gmailDraftAPI]?.canBeSuggestedAsExecutable, false)
        XCTAssertEqual(summaries[.draftsCreateHandoff]?.readiness, .needsInstalledApp)
        XCTAssertEqual(summaries[.draftsCreateHandoff]?.canBeSuggestedAsExecutable, false)
    }

    func testAccessBackendAPIBlocksAppIntegrationExecutableSuggestionsWhenPermissionUnavailable() async throws {
        let appIntegrationSkillCatalog = AppIntegrationSkillCatalog(skills: [
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .googleMapsDirectionsHandoff)),
            try XCTUnwrap(AppIntegrationSkillCatalog().skill(id: .whatsappMessageHandoff))
        ])
        let permissions = RecordingPermissionService(statuses: [
            .location: .denied,
            .messages: .available
        ])
        let api = KairoAccessBackendService(
            appIntegrationSkillCatalog: appIntegrationSkillCatalog,
            permissionService: permissions
        )

        let integrations = await api.appIntegrations()
        let summaries = Dictionary(uniqueKeysWithValues: integrations.map { ($0.skillID, $0) })

        XCTAssertEqual(summaries[.googleMapsDirectionsHandoff]?.readiness, .unsupported)
        XCTAssertEqual(summaries[.googleMapsDirectionsHandoff]?.canBeSuggestedAsExecutable, false)
        XCTAssertEqual(summaries[.whatsappMessageHandoff]?.readiness, .available)
        XCTAssertEqual(summaries[.whatsappMessageHandoff]?.canBeSuggestedAsExecutable, true)
    }

    func testAccessPermissionStatusFallbackCopyDoesNotBypassSystemPermissions() throws {
        XCTAssertEqual(
            CapabilityStatus.denied.accessFallbackMessage,
            "Permission denied. Re-enable it in iOS Settings; Kairo will not bypass system permissions."
        )
        XCTAssertEqual(
            CapabilityStatus.restricted.accessFallbackMessage,
            "Permission restricted by iOS policy. Kairo will keep this capability unavailable."
        )
        XCTAssertEqual(
            CapabilityStatus.unsupported.accessFallbackMessage,
            "This capability is unavailable on this device or build."
        )
        XCTAssertEqual(
            CapabilityStatus.unknown.accessFallbackMessage,
            "Permission has not been requested yet. Kairo asks only when you start a matching action."
        )
        XCTAssertNil(CapabilityStatus.available.accessFallbackMessage)
    }
}

private actor RecordingPermissionService: PermissionService {
    private var statuses: [CapabilityKey: CapabilityStatus]
    private let requestResults: [CapabilityKey: CapabilityStatus]
    private var requests: [CapabilityKey] = []

    init(
        statuses: [CapabilityKey: CapabilityStatus],
        requestResults: [CapabilityKey: CapabilityStatus] = [:]
    ) {
        self.statuses = statuses
        self.requestResults = requestResults
    }

    func status(for capability: CapabilityKey) async -> CapabilityStatus {
        if let status = statuses[capability] {
            return status
        }
        return await StubPermissionService().status(for: capability)
    }

    func request(_ capability: CapabilityKey) async throws -> CapabilityStatus {
        requests.append(capability)
        let result = requestResults[capability] ?? statuses[capability] ?? .unknown
        statuses[capability] = result
        return result
    }

    func requestedCapabilities() -> [CapabilityKey] {
        requests
    }
}
