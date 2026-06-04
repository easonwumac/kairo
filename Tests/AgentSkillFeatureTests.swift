import XCTest
import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KairoCore

final class AgentSkillFeatureTests: XCTestCase {
    func testAgentToolInvocationPlannerSuggestsPhoneCallHandoffShortcutSkill() throws {
        let planner = AgentToolInvocationPlanner(skillCatalog: .default)

        let plan = planner.plan(for: AgentToolInvocationRequest(userText: "Call Alex about the Kairo TestFlight"))
        let candidate = try XCTUnwrap(plan.candidates.first { $0.skillID == "shortcut-phone-call-handoff" })

        XCTAssertEqual(candidate.source, .installedSkill)
        XCTAssertEqual(candidate.skillKind, .shortcutWorkflow)
        XCTAssertTrue(candidate.handoffSummary.contains("preparePhoneCallHandoff"))
        XCTAssertTrue(candidate.handoffSummary.localizedCaseInsensitiveContains("phone"))
    }

    func testSkillMarketplaceIndexListsDownloadableSkillsWithSafetyMetadata() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let data = try Data(contentsOf: root.appendingPathComponent("Website/skills/skills.json"))
        let index = try JSONDecoder().decode(SkillMarketplaceIndex.self, from: data)

        XCTAssertEqual(index.marketplaceVersion, "2026.6")
        XCTAssertEqual(index.sourceRepository, "https://github.com/easonwumac/kairo-skills")
        XCTAssertEqual(index.catalogSignatureStatus, "referenceUnsigned")
        XCTAssertGreaterThanOrEqual(index.skills.count, 3)
        XCTAssertTrue(index.skills.allSatisfy { !$0.permissions.isEmpty })
        XCTAssertTrue(index.skills.allSatisfy { !$0.changelog.isEmpty })
        XCTAssertTrue(index.skills.allSatisfy { !$0.screenshots.isEmpty })
        XCTAssertTrue(index.skills.allSatisfy { !$0.riskTier.isEmpty })
        XCTAssertTrue(index.skills.allSatisfy { $0.compatibilityRequirements != nil })

        let weatherSkill = try XCTUnwrap(index.skills.first { $0.id == "marketplace-weather-briefing" })
        XCTAssertEqual(weatherSkill.displayName, "Weather Briefing")
        XCTAssertEqual(weatherSkill.version, "2.1.0")
        XCTAssertEqual(weatherSkill.author, "Kairo Marketplace")
        XCTAssertEqual(weatherSkill.manifestURL, "manifests/weather-briefing.json")
        XCTAssertEqual(weatherSkill.installSurface, "Access Skill Manager")
        XCTAssertTrue(weatherSkill.permissions.contains("externalConnectors"))
        XCTAssertTrue(weatherSkill.changelog.contains("Adds storm alerts."))
        XCTAssertEqual(weatherSkill.compatibilityRequirements?.requiredOAuthProviderKeys, ["google"])

        let homeKitSkill = try XCTUnwrap(index.skills.first { $0.id == "marketplace-homekit-scene-guard" })
        XCTAssertEqual(homeKitSkill.compatibilityRequirements?.minimumIOSVersion, "17.0")
        XCTAssertEqual(homeKitSkill.compatibilityRequirements?.requiredEntitlements, ["com.apple.developer.homekit"])
    }

    func testSkillMarketplaceReferenceSeedIsNotProductionSignedCatalogEvidence() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let catalogURL = root.appendingPathComponent("Website/skills/skills.json")
        let catalogData = try Data(contentsOf: catalogURL)
        let catalog = try XCTUnwrap(JSONSerialization.jsonObject(with: catalogData) as? [String: Any])
        let skills = try XCTUnwrap(catalog["skills"] as? [[String: Any]])

        XCTAssertEqual(catalog["catalogSignatureStatus"] as? String, "referenceUnsigned")
        XCTAssertEqual(catalog["sourceRepository"] as? String, "https://github.com/easonwumac/kairo-skills")
        XCTAssertNil(catalog["signature"])
        XCTAssertNil(catalog["publicKeyBase64"])
        XCTAssertNil(catalog["publicationStatus"])
        XCTAssertFalse(skills.isEmpty)

        for entry in skills {
            let manifestPath = try XCTUnwrap(entry["manifestURL"] as? String)
            let manifestURL = root.appendingPathComponent("Website/skills/\(manifestPath)")
            let manifestData = try Data(contentsOf: manifestURL)
            let manifest = try XCTUnwrap(JSONSerialization.jsonObject(with: manifestData) as? [String: Any])
            let signature = try XCTUnwrap(manifest["signature"] as? [String: Any])

            XCTAssertEqual(signature["keyID"] as? String, "kairo-marketplace-2026")
            XCTAssertEqual(signature["value"] as? String, "static-demo-signature")
            XCTAssertNil(signature["publicKeyBase64"])
            XCTAssertEqual(manifest["checksumAlgorithm"] as? String, "sha256")
        }
    }

    func testSkillMarketplaceManifestIsImportableBySkillManager() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let data = try Data(contentsOf: root.appendingPathComponent("Website/skills/skills.json"))
        let index = try JSONDecoder().decode(SkillMarketplaceIndex.self, from: data)

        for entry in index.skills {
            let manifestJSON = try String(
                contentsOf: root.appendingPathComponent("Website/skills/\(entry.manifestURL)"),
                encoding: .utf8
            )
            let manifest = try AgentSkillManifest.decodeJSONString(manifestJSON)

            XCTAssertEqual(manifest.skill.id, entry.id)
            XCTAssertEqual(manifest.skill.version, entry.version)
            XCTAssertEqual(manifest.packageVersion, index.marketplaceVersion)
            XCTAssertEqual(manifest.signature?.keyID, "kairo-marketplace-2026")
            XCTAssertNoThrow(try manifest.validateForInstall())
            XCTAssertEqual(manifest.installableSkill.source, .marketplace)
            XCTAssertEqual(manifest.installableSkill.installationStatus, .installed)
            XCTAssertEqual(manifest.skill.compatibilityRequirements, entry.compatibilityRequirements)
        }

        let manifestJSON = try String(
            contentsOf: root.appendingPathComponent("Website/skills/manifests/weather-briefing.json"),
            encoding: .utf8
        )

        let manifest = try AgentSkillManifest.decodeJSONString(manifestJSON)

        XCTAssertEqual(manifest.skill.id, "marketplace-weather-briefing")
        XCTAssertEqual(manifest.skill.version, "2.1.0")
        XCTAssertEqual(manifest.packageVersion, "2026.6")
        XCTAssertEqual(manifest.signature?.keyID, "kairo-marketplace-2026")
        XCTAssertEqual(manifest.skill.compatibilityRequirements.requiredOAuthProviderKeys, ["google"])
        XCTAssertEqual(manifest.changelog, [
            "Adds storm alerts.",
            "Improves hourly summary.",
            "Documents approved provider API boundaries."
        ])
        XCTAssertNoThrow(try manifest.validateForInstall())
        XCTAssertEqual(manifest.installableSkill.source, .marketplace)
        XCTAssertEqual(manifest.installableSkill.installationStatus, .installed)
    }

    func testAgentSkillMarketplaceCatalogServiceFetchesStandaloneRepoCatalog() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API and returns a compact daily plan.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            },
            {
              "id": "marketplace-homekit-scene-guard",
              "displayName": "HomeKit Scene Guard",
              "summary": "Wraps confirmed HomeKit scene and accessory controls.",
              "version": "1.1.0",
              "author": "Kairo Marketplace",
              "category": "Home",
              "kind": "homeKitControl",
              "permissions": ["homeKit"],
              "riskTier": "Tier 3: confirmed home control",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/homekit-scene-guard.json",
              "screenshots": ["assets/homekit-scene-card.svg"],
              "changelog": ["Adds scene and accessory metadata."],
              "compatibilityRequirements": {
                "minimumIOSVersion": "17.0",
                "requiredEntitlements": ["com.apple.developer.homekit"]
              }
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        let remoteCatalog = try await service.fetchCatalog()
        let request = try await httpClient.lastRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://easonwumac.github.io/kairo-skills/skills.json")
        XCTAssertEqual(remoteCatalog.sourceRepository.absoluteString, "https://github.com/easonwumac/kairo-skills")
        XCTAssertEqual(remoteCatalog.marketplaceVersion, "2026.6")
        XCTAssertEqual(remoteCatalog.catalogSignatureStatus, .productionSigned)
        XCTAssertEqual(remoteCatalog.catalog.skills.map(\.id), [
            "marketplace-weather-briefing",
            "marketplace-homekit-scene-guard"
        ])
        let weather = try XCTUnwrap(remoteCatalog.catalog.skill(id: "marketplace-weather-briefing"))
        XCTAssertEqual(weather.version, "2.1.0")
        XCTAssertEqual(weather.author, "Kairo Marketplace")
        XCTAssertEqual(weather.kind, .custom)
        XCTAssertEqual(weather.installationStatus, .available)
        XCTAssertEqual(weather.requiredCapabilities, [.externalConnectors])
        XCTAssertEqual(
            weather.downloadURL?.absoluteString,
            "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json"
        )
        let homeKit = try XCTUnwrap(remoteCatalog.catalog.skill(id: "marketplace-homekit-scene-guard"))
        XCTAssertEqual(homeKit.compatibilityRequirements.minimumIOSVersion, "17.0")
        XCTAssertEqual(homeKit.compatibilityRequirements.requiredEntitlements, ["com.apple.developer.homekit"])
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsReferenceUnsignedIndex() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "referenceUnsigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected reference marketplace catalog status to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(error, .nonProductionCatalogSignatureStatus("referenceUnsigned"))
            XCTAssertEqual(error.localizedDescription, "Marketplace catalog is marked referenceUnsigned, not productionSigned.")
        }
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsBlankSkillID() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "   ",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected blank marketplace skill id to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(error, .invalidSkillID("   "))
            XCTAssertEqual(error.localizedDescription, "Marketplace catalog contains an invalid skill id:    .")
        }
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsNonHTTPSManifestURL() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "http://example.com/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected non-HTTPS marketplace manifest URL to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(
                error,
                .invalidManifestURL(
                    skillID: "marketplace-weather-briefing",
                    manifestURL: "http://example.com/weather-briefing.json"
                )
            )
        }
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsExternalManifestHost() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "https://example.com/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected external marketplace manifest host to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(
                error,
                .invalidManifestURL(
                    skillID: "marketplace-weather-briefing",
                    manifestURL: "https://example.com/weather-briefing.json"
                )
            )
        }
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsEscapedManifestPath() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "../weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected escaped marketplace manifest path to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(
                error,
                .invalidManifestURL(
                    skillID: "marketplace-weather-briefing",
                    manifestURL: "https://easonwumac.github.io/weather-briefing.json"
                )
            )
        }
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsDuplicateSkillIDs() async throws {
        let body = """
        {
          "marketplaceVersion": "2026.6",
          "sourceRepository": "https://github.com/easonwumac/kairo-skills",
          "generatedAt": "2026-06-02T00:00:00Z",
          "catalogSignatureStatus": "productionSigned",
          "skills": [
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing",
              "summary": "Summarizes weather through an approved provider API.",
              "version": "2.1.0",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Adds storm alerts."]
            },
            {
              "id": "marketplace-weather-briefing",
              "displayName": "Weather Briefing Duplicate",
              "summary": "Attempts to shadow the same marketplace skill id.",
              "version": "9.9.9",
              "author": "Kairo Marketplace",
              "category": "External API",
              "kind": "custom",
              "permissions": ["externalConnectors"],
              "riskTier": "Tier 3: external data request",
              "requiresConfirmation": true,
              "installSurface": "Access Skill Manager",
              "manifestURL": "manifests/weather-briefing-duplicate.json",
              "screenshots": ["assets/weather-briefing-card.svg"],
              "changelog": ["Attempts duplicate id."]
            }
          ]
        }
        """
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: body)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected duplicate marketplace skill IDs to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(error, .duplicateSkillID("marketplace-weather-briefing"))
            XCTAssertEqual(
                error.localizedDescription,
                "Marketplace catalog contains a duplicate skill id: marketplace-weather-briefing."
            )
        }
    }

    func testAgentSkillMarketplaceCatalogServiceFetchesManifestForDownloadableSkill() async throws {
        let skill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json")!
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: skill, packageVersion: "2026.6")
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: manifestJSON)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        let fetchedManifest = try await service.fetchManifest(for: skill)
        let request = try await httpClient.lastRequest()

        XCTAssertEqual(request.url?.absoluteString, "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json")
        XCTAssertEqual(fetchedManifest.skill.id, "marketplace-weather-briefing")
        XCTAssertEqual(fetchedManifest.packageVersion, "2026.6")
        XCTAssertNoThrow(try fetchedManifest.validateForInstall())
    }

    func testAgentSkillMarketplaceCatalogServiceRejectsMismatchedManifestSkillID() async throws {
        let requestedSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Summarizes weather through an approved provider API.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://easonwumac.github.io/kairo-skills/manifests/weather-briefing.json")!
        )
        let unexpectedSkill = AgentSkill.marketplaceTemplate(
            id: "marketplace-homekit-scene-guard",
            displayName: "HomeKit Scene Guard",
            summary: "Wraps confirmed HomeKit scene controls.",
            requiredCapabilities: [.homeKit],
            downloadURL: URL(string: "https://easonwumac.github.io/kairo-skills/manifests/homekit-scene-guard.json")!,
            kind: .homeKitControl
        )
        let manifest = try AgentSkillManifest.signedForTesting(skill: unexpectedSkill, packageVersion: "2026.6")
        let manifestJSON = try AgentSkillManifest.encodeJSONString(manifest)
        let httpClient = AgentSkillMockHTTPClient(statusCode: 200, body: manifestJSON)
        let service = AgentSkillMarketplaceCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-skills/skills.json")!,
            httpClient: httpClient
        )

        do {
            _ = try await service.fetchManifest(for: requestedSkill)
            XCTFail("Expected mismatched marketplace manifest skill id to fail closed.")
        } catch let error as AgentSkillMarketplaceCatalogError {
            XCTAssertEqual(
                error,
                .manifestSkillMismatch(
                    expectedSkillID: "marketplace-weather-briefing",
                    actualSkillID: "marketplace-homekit-scene-guard"
                )
            )
        }
    }

    func testAgentSkillCatalogMergesRemoteMarketplaceWithoutReplacingInstalledSkills() {
        var installedWeather = AgentSkill.marketplaceTemplate(
            id: "marketplace-weather-briefing",
            displayName: "Weather Briefing",
            summary: "Installed user copy.",
            requiredCapabilities: [.externalConnectors],
            downloadURL: URL(string: "https://example.com/weather.json")!
        )
        installedWeather.installationStatus = .installed
        installedWeather.version = "2.0.0"
        let existingCatalog = AgentSkillCatalog(skills: AgentSkillCatalog.default.skills + [installedWeather])
        var remoteWeather = installedWeather
        remoteWeather.installationStatus = .available
        remoteWeather.version = "2.1.0"
        remoteWeather.summary = "Remote update."
        let remoteHomeKit = AgentSkill.marketplaceTemplate(
            id: "marketplace-homekit-scene-guard",
            displayName: "HomeKit Scene Guard",
            summary: "New remote skill.",
            requiredCapabilities: [.homeKit],
            downloadURL: URL(string: "https://easonwumac.github.io/kairo-skills/manifests/homekit-scene-guard.json")!,
            kind: .homeKitControl
        )

        let merged = existingCatalog.mergingMarketplaceCatalog(AgentSkillCatalog(skills: [remoteWeather, remoteHomeKit]))

        XCTAssertEqual(merged.skill(id: "marketplace-weather-briefing")?.installationStatus, .installed)
        XCTAssertEqual(merged.skill(id: "marketplace-weather-briefing")?.version, "2.0.0")
        XCTAssertEqual(merged.skill(id: "marketplace-homekit-scene-guard")?.installationStatus, .available)
        XCTAssertEqual(merged.skill(id: "marketplace-homekit-scene-guard")?.kind, .homeKitControl)
    }

    private struct SkillMarketplaceIndex: Decodable {
        var marketplaceVersion: String
        var sourceRepository: String
        var catalogSignatureStatus: String
        var skills: [SkillMarketplaceEntry]
    }

    private struct SkillMarketplaceEntry: Decodable {
        var id: String
        var displayName: String
        var version: String
        var author: String
        var permissions: [String]
        var riskTier: String
        var manifestURL: String
        var installSurface: String
        var changelog: [String]
        var screenshots: [String]
        var compatibilityRequirements: AgentSkillCompatibilityRequirements?
    }
}

private actor AgentSkillMockHTTPClient: HTTPClient {
    private let statusCode: Int
    private let body: String
    private var capturedRequest: URLRequest?

    init(statusCode: Int, body: String) {
        self.statusCode = statusCode
        self.body = body
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        capturedRequest = request
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(body.utf8), response)
    }

    func lastRequest() throws -> URLRequest {
        guard let capturedRequest else {
            throw AgentSkillMockHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private enum AgentSkillMockHTTPClientError: Error {
    case missingRequest
}
