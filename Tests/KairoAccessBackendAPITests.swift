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
