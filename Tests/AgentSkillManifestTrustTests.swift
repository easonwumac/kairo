import XCTest
import Foundation
import CryptoKit
@testable import KairoCore

final class AgentSkillManifestTrustTests: XCTestCase {
    func testAgentSkillManifestRequiresSignatureAndVerifiesChecksum() throws {
        let downloadableSkill = marketplaceWeatherSkill()
        let checksum = try AgentSkillManifest.sha256Hex(for: downloadableSkill)
        let manifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: checksum,
            signature: AgentSkillManifestSignature(
                keyID: "kairo-marketplace-2026",
                algorithm: .ed25519,
                value: "signed-weather-briefing"
            )
        )

        XCTAssertNoThrow(try manifest.validateForInstall())
        XCTAssertEqual(manifest.installableSkill.installationStatus, .installed)
        XCTAssertEqual(manifest.installableSkill.source, .marketplace)
        XCTAssertEqual(manifest.installableSkill.version, "1.0")

        let tamperedManifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: "invalid-checksum",
            signature: manifest.signature
        )
        XCTAssertThrowsError(try tamperedManifest.validateForInstall()) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .checksumMismatch)
        }

        let unsignedManifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: checksum,
            signature: nil
        )
        XCTAssertThrowsError(try unsignedManifest.validateForInstall()) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .missingSignature)
        }
    }

    func testAgentSkillManifestTrustStoreVerifiesPublicKeySignatureAndRejectsUnknownKeys() throws {
        let downloadableSkill = marketplaceWeatherSkill()
        var manifest = AgentSkillManifest(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            checksum: try AgentSkillManifest.sha256Hex(for: downloadableSkill),
            signature: nil
        )
        let signingKey = P256.Signing.PrivateKey()
        let signature = try signingKey.signature(for: manifest.signingPayloadData())
        manifest.signature = AgentSkillManifestSignature(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            value: signature.derRepresentation.base64EncodedString()
        )
        let trustedKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
        )
        let trustStore = AgentSkillManifestTrustStore(trustedKeys: [trustedKey])

        XCTAssertNoThrow(try manifest.validateForInstall(trustStore: trustStore))

        let emptyTrustStore = AgentSkillManifestTrustStore(trustedKeys: [])
        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: emptyTrustStore)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .unknownSigningKey("kairo-marketplace-2026"))
        }

        manifest.signature?.value = Data("tampered-signature".utf8).base64EncodedString()
        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: trustStore)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .invalidSignature)
        }
    }

    func testAgentSkillManifestTrustStoreRejectsRevokedAndOutOfWindowKeys() throws {
        let downloadableSkill = marketplaceWeatherSkill()
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let now = Date(timeIntervalSince1970: 1_767_225_600)
        let baseKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
            validFrom: now.addingTimeInterval(-60),
            expiresAt: now.addingTimeInterval(60)
        )

        XCTAssertNoThrow(try manifest.validateForInstall(
            trustStore: AgentSkillManifestTrustStore(trustedKeys: [baseKey]),
            currentDate: now
        ))

        let revokedKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
            status: .revoked,
            revokedAt: now,
            revokedReason: "Rotated after key compromise drill."
        )
        XCTAssertThrowsError(try manifest.validateForInstall(
            trustStore: AgentSkillManifestTrustStore(trustedKeys: [revokedKey]),
            currentDate: now
        )) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .revokedSigningKey("kairo-marketplace-2026"))
        }

        let futureKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
            validFrom: now.addingTimeInterval(60)
        )
        XCTAssertThrowsError(try manifest.validateForInstall(
            trustStore: AgentSkillManifestTrustStore(trustedKeys: [futureKey]),
            currentDate: now
        )) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .signingKeyNotYetValid("kairo-marketplace-2026"))
        }

        let expiredKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
            expiresAt: now
        )
        XCTAssertThrowsError(try manifest.validateForInstall(
            trustStore: AgentSkillManifestTrustStore(trustedKeys: [expiredKey]),
            currentDate: now
        )) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .signingKeyExpired("kairo-marketplace-2026"))
        }
    }

    func testAgentSkillManifestTrustStoreRejectsPendingPublicationSigningKeys() throws {
        let downloadableSkill = marketplaceWeatherSkill()
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let pendingKey = AgentSkillTrustedPublicKey(
            keyID: "kairo-marketplace-2026",
            algorithm: .p256SHA256,
            publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
            publicationStatus: .pendingPublication
        )

        XCTAssertThrowsError(try manifest.validateForInstall(
            trustStore: AgentSkillManifestTrustStore(trustedKeys: [pendingKey])
        )) { error in
            XCTAssertEqual(
                error as? AgentSkillManifestValidationError,
                .signingKeyPendingPublication("kairo-marketplace-2026")
            )
        }
    }

    func testDefaultAgentSkillManifestTrustStoreKeepsReleaseKeysPendingPublication() throws {
        let trustStore = AgentSkillManifestTrustStore.defaultRelease
        let activeReleaseKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-marketplace-2026"))
        let revokedReleaseKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-marketplace-2025"))

        XCTAssertEqual(activeReleaseKey.status, .active)
        XCTAssertEqual(activeReleaseKey.publicationStatus, .pendingPublication)
        XCTAssertTrue(activeReleaseKey.publicKeyBase64.isEmpty)
        XCTAssertEqual(revokedReleaseKey.status, .revoked)
        XCTAssertEqual(revokedReleaseKey.publicationStatus, .pendingPublication)
        XCTAssertTrue(revokedReleaseKey.publicKeyBase64.isEmpty)

        let downloadableSkill = marketplaceWeatherSkill()
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: downloadableSkill,
            packageVersion: "2026.6",
            keyID: activeReleaseKey.keyID,
            signingKey: signingKey
        )

        XCTAssertThrowsError(try manifest.validateForInstall(trustStore: trustStore)) { error in
            XCTAssertEqual(
                error as? AgentSkillManifestValidationError,
                .signingKeyPendingPublication(activeReleaseKey.keyID)
            )
        }
    }

    func testAgentSkillTrustStoreDecodesLegacyKeysAsActive() throws {
        let json = """
        {
          "trustedKeys": [
            {
              "keyID": "kairo-marketplace-2026",
              "algorithm": "p256SHA256",
              "publicKeyBase64": "abc123"
            }
          ]
        }
        """

        let trustStore = try JSONDecoder().decode(AgentSkillManifestTrustStore.self, from: Data(json.utf8))
        let trustedKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-marketplace-2026"))

        XCTAssertEqual(trustedKey.status, .active)
        XCTAssertEqual(trustedKey.publicationStatus, .published)
        XCTAssertNil(trustedKey.validFrom)
        XCTAssertNil(trustedKey.expiresAt)
        XCTAssertNil(trustedKey.revokedAt)
        XCTAssertNil(trustedKey.revokedReason)
    }

    func testAgentSkillTrustStoreDecodesISO8601RotationMetadata() throws {
        let json = """
        {
          "trustedKeys": [
            {
              "keyID": "kairo-marketplace-2025",
              "algorithm": "p256SHA256",
              "publicKeyBase64": "abc123",
              "status": "revoked",
              "publicationStatus": "pendingPublication",
              "validFrom": "2026-01-01T00:00:00Z",
              "expiresAt": "2026-06-01T00:00:00Z",
              "revokedAt": "2026-06-02T00:00:00Z",
              "revokedReason": "Rotated to kairo-marketplace-2026."
            }
          ]
        }
        """

        let trustStore = try JSONDecoder().decode(AgentSkillManifestTrustStore.self, from: Data(json.utf8))
        let trustedKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-marketplace-2025"))

        XCTAssertEqual(trustedKey.status, .revoked)
        XCTAssertEqual(trustedKey.publicationStatus, .pendingPublication)
        XCTAssertEqual(trustedKey.validFrom, ISO8601DateFormatter().date(from: "2026-01-01T00:00:00Z"))
        XCTAssertEqual(trustedKey.expiresAt, ISO8601DateFormatter().date(from: "2026-06-01T00:00:00Z"))
        XCTAssertEqual(trustedKey.revokedAt, ISO8601DateFormatter().date(from: "2026-06-02T00:00:00Z"))
        XCTAssertEqual(trustedKey.revokedReason, "Rotated to kairo-marketplace-2026.")

        let encoded = try JSONEncoder().encode(trustStore)
        let encodedJSON = String(decoding: encoded, as: UTF8.self)
        XCTAssertTrue(encodedJSON.contains(#""revokedAt":"2026-06-02T00:00:00Z""#))
        XCTAssertTrue(encodedJSON.contains(#""publicationStatus":"pendingPublication""#))
    }

    func testAgentSkillManagerUsesTrustStoreWhenProvided() async throws {
        let storeURL = temporaryFileURL(named: "trusted-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let skill = marketplaceWeatherSkill()
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey
        )
        let trustStore = trustStore(for: signingKey)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default, trustStore: trustStore)

        let installed = try await service.install(manifest: manifest)
        XCTAssertEqual(installed.installationStatus, .installed)

        let untrustedKey = P256.Signing.PrivateKey()
        let untrustedManifest = try AgentSkillManifest.signedForTesting(
            skill: AgentSkill.marketplaceTemplate(
                id: "marketplace-untrusted",
                displayName: "Untrusted Skill",
                summary: "A marketplace skill signed by an unknown key.",
                requiredCapabilities: [.externalConnectors],
                downloadURL: URL(string: "https://skills.kairo.app/untrusted.json")!
            ),
            packageVersion: "2026.6",
            keyID: "unknown-key",
            signingKey: untrustedKey
        )
        await XCTAssertThrowsErrorAsync(try await service.install(manifest: untrustedManifest)) { error in
            XCTAssertEqual(error as? AgentSkillManifestValidationError, .unknownSigningKey("unknown-key"))
        }
    }

    func testAgentSkillManagerInstallsSignedManifestFromJSONString() async throws {
        let storeURL = temporaryFileURL(named: "imported-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let manifest = try signedWeatherSkillManifest(version: "1.0", signingKey: signingKey)
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore(for: signingKey)
        )

        let installed = try await service.installManifest(jsonString: manifestJSON)
        let catalog = try await service.catalog()

        XCTAssertEqual(installed.id, "marketplace-weather-briefing")
        XCTAssertEqual(installed.installationStatus, .installed)
        XCTAssertEqual(catalog.skill(id: "marketplace-weather-briefing")?.source, .marketplace)
    }

    func testAgentSkillManagerRejectsInvalidManifestJSONString() async throws {
        let storeURL = temporaryFileURL(named: "invalid-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let service = AgentSkillManagerService(store: store, builtInCatalog: .default)

        await XCTAssertThrowsErrorAsync(try await service.installManifest(jsonString: "{not-json")) { error in
            XCTAssertEqual(error as? AgentSkillManifestImportError, .invalidJSON)
        }
    }

    func testAgentSkillManagerRejectsDowngradeAndAllowsSameOrNewerSignedManifestVersions() async throws {
        let storeURL = temporaryFileURL(named: "versioned-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore(for: signingKey)
        )

        let installed = try await service.install(manifest: signedWeatherSkillManifest(version: "2.0.0", signingKey: signingKey))
        XCTAssertEqual(installed.version, "2.0.0")

        let reinstalled = try await service.install(manifest: signedWeatherSkillManifest(version: "2.0", signingKey: signingKey))
        XCTAssertEqual(reinstalled.version, "2.0")

        let upgraded = try await service.install(manifest: signedWeatherSkillManifest(version: "2.1.0", signingKey: signingKey))
        XCTAssertEqual(upgraded.version, "2.1.0")

        await XCTAssertThrowsErrorAsync(try await service.install(manifest: signedWeatherSkillManifest(version: "2.0.9", signingKey: signingKey))) { error in
            XCTAssertEqual(error as? AgentSkillInstallError, .versionDowngrade(skillID: "marketplace-weather-briefing", installedVersion: "2.1.0", incomingVersion: "2.0.9"))
        }
    }

    func testAgentSkillManagerBuildsSignedManifestUpdatePreviewWithChangelog() async throws {
        let storeURL = temporaryFileURL(named: "preview-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore(for: signingKey)
        )
        _ = try await service.install(manifest: signedWeatherSkillManifest(version: "2.0.0", signingKey: signingKey))
        let updateManifest = try signedWeatherSkillManifest(
            version: "2.1.0",
            signingKey: signingKey,
            changelog: [
                "Adds storm alerts.",
                "Improves hourly summary."
            ]
        )

        let preview = try await service.previewInstall(manifest: updateManifest)

        XCTAssertEqual(preview.skillID, "marketplace-weather-briefing")
        XCTAssertEqual(preview.displayName, "Weather Briefing")
        XCTAssertEqual(preview.installedVersion, "2.0.0")
        XCTAssertEqual(preview.incomingVersion, "2.1.0")
        XCTAssertEqual(preview.packageVersion, "2026.6")
        XCTAssertEqual(preview.changelog, [
            "Adds storm alerts.",
            "Improves hourly summary."
        ])
        XCTAssertEqual(preview.installationChange, .update)
        XCTAssertEqual(preview.summary, "Update Weather Briefing from 2.0.0 to 2.1.0.")
    }

    func testAgentSkillManagerBuildsDowngradeBlockedPreviewFromManifestJSONString() async throws {
        let storeURL = temporaryFileURL(named: "preview-downgrade-agent-skills.json")
        let store = try await FileBackedAgentSkillStore(fileURL: storeURL)
        let signingKey = P256.Signing.PrivateKey()
        let service = AgentSkillManagerService(
            store: store,
            builtInCatalog: .default,
            trustStore: trustStore(for: signingKey)
        )
        _ = try await service.install(manifest: signedWeatherSkillManifest(version: "3.0.0", signingKey: signingKey))
        let downgradeManifestJSON = try AgentSkillManifest.encodeJSONString(signedWeatherSkillManifest(
            version: "2.9.0",
            signingKey: signingKey,
            changelog: ["Attempts to downgrade the installed skill."]
        ))

        let preview = try await service.previewInstall(jsonString: downgradeManifestJSON)

        XCTAssertEqual(preview.installedVersion, "3.0.0")
        XCTAssertEqual(preview.incomingVersion, "2.9.0")
        XCTAssertEqual(preview.installationChange, .downgradeBlocked)
        XCTAssertEqual(preview.summary, "Blocked downgrade for Weather Briefing from 3.0.0 to 2.9.0.")
    }

    private func marketplaceWeatherSkill() -> AgentSkill {
        AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://skills.kairo.app/weather-briefing.json")!
        )
    }

    private func trustStore(for signingKey: P256.Signing.PrivateKey) -> AgentSkillManifestTrustStore {
        AgentSkillManifestTrustStore(trustedKeys: [
            AgentSkillTrustedPublicKey(
                keyID: "kairo-marketplace-2026",
                algorithm: .p256SHA256,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func XCTAssertThrowsErrorAsync<T>(
        _ expression: @autoclosure () async throws -> T,
        _ errorHandler: (Error) -> Void,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected async expression to throw.", file: file, line: line)
        } catch {
            errorHandler(error)
        }
    }

    private func signedWeatherSkillManifest(
        version: String,
        signingKey: P256.Signing.PrivateKey,
        changelog: [String] = []
    ) throws -> AgentSkillManifest {
        var skill = marketplaceWeatherSkill()
        skill.version = version
        return try AgentSkillManifest.signedForTesting(
            skill: skill,
            packageVersion: "2026.6",
            keyID: "kairo-marketplace-2026",
            signingKey: signingKey,
            changelog: changelog
        )
    }
}
