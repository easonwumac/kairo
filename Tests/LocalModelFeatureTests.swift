import XCTest
import Foundation
import CryptoKit
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import KairoCore

final class LocalModelFeatureTests: XCTestCase {
    func testLocalModelCatalogFiltersDeprecatedAndOldSafetyPolicyModels() throws {
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "available", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "old-policy", safetyPolicyVersion: "2025.9"),
                makeLocalModelManifest(id: "deprecated", safetyPolicyVersion: "2026.2", deprecated: true)
            ]
        )

        let encoded = try catalog.encoded()
        let decoded = try LocalModelCatalog.decode(encoded)
        let available = decoded.availableModels(minimumSafetyPolicyVersion: "2026.1")

        XCTAssertEqual(available.map(\.id), ["available"])
    }

    func testDefaultLocalModelCatalogExposesPopularStarterModelsForSettings() throws {
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
        let localModelCatalogSource = try String(
            contentsOf: root.appendingPathComponent("Kairo/Services/LocalModelCatalog.swift"),
            encoding: .utf8
        )
        let catalog = LocalModelCatalog.kairoDefault
        let availableModels = catalog.availableModels(minimumSafetyPolicyVersion: catalog.minimumSafetyPolicyVersion)

        XCTAssertEqual(catalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertTrue(localModelCatalogSource.contains("static let kairoStarterModelIDs"))
        XCTAssertTrue(localModelCatalogSource.contains("kairoStarterModels"))
        XCTAssertEqual(availableModels.count, 2)
        XCTAssertEqual(availableModels.map(\.id), [
            "qwen3-5-0-8b-q4-k-m",
            "llama3-2-1b-instruct-q4-k-m"
        ])
        XCTAssertEqual(availableModels.map(\.displayName), [
            "Qwen3.5 0.8B Q4_K_M",
            "Llama 3.2 1B Instruct Q4_K_M"
        ])

        for model in availableModels {
            XCTAssertEqual(model.downloadURL.scheme, "https", model.id)
            XCTAssertEqual(model.downloadURL.host(), "huggingface.co", model.id)
            XCTAssertEqual(model.sha256.count, 64, model.id)
            XCTAssertLessThanOrEqual(model.minRAMGB, 6, model.id)
            XCTAssertEqual(model.runtime, .gguf, model.id)
            XCTAssertTrue(model.capabilities.contains(.offlineChat), model.id)
            XCTAssertTrue(model.disallowedCapabilities.contains(.webCurrentInfo), model.id)
            XCTAssertTrue(model.disallowedCapabilities.contains(.toolUse), model.id)
        }

        let qwenTiny = try XCTUnwrap(availableModels.first { $0.id == "qwen3-5-0-8b-q4-k-m" })
        let ggufBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .gguf })
        let mlxBenchmark = try XCTUnwrap(qwenTiny.benchmarkProfiles.first { $0.runtime == .mlx })
        XCTAssertEqual(ggufBenchmark.runtimePackage, "llama.cpp Metal")
        XCTAssertEqual(ggufBenchmark.promptTokens, 512)
        XCTAssertEqual(ggufBenchmark.generatedTokens, 128)
        XCTAssertEqual(ggufBenchmark.trials, 5)
        XCTAssertEqual(ggufBenchmark.promptTokensPerSecond, 8_810, accuracy: 0.1)
        XCTAssertEqual(ggufBenchmark.generationTokensPerSecond, 214, accuracy: 0.1)
        XCTAssertTrue(ggufBenchmark.supportsInAppDownload)
        XCTAssertTrue(ggufBenchmark.isReferenceOnlyForIOS)
        XCTAssertEqual(mlxBenchmark.runtimePackage, "mlx-lm")
        XCTAssertEqual(mlxBenchmark.artifactReference, "mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertEqual(mlxBenchmark.promptTokensPerSecond, 10_639, accuracy: 0.1)
        XCTAssertEqual(mlxBenchmark.generationTokensPerSecond, 286, accuracy: 0.1)
        XCTAssertEqual(mlxBenchmark.peakMemoryMB, 1_360)
        XCTAssertFalse(mlxBenchmark.supportsInAppDownload)
        XCTAssertTrue(mlxBenchmark.isReferenceOnlyForIOS)
        XCTAssertEqual(mlxBenchmark.sourceURL?.absoluteString, "https://huggingface.co/mlx-community/Qwen3.5-0.8B-OptiQ-4bit")
        XCTAssertEqual(qwenTiny.recommendedBenchmarkProfile?.runtime, .mlx)
        XCTAssertTrue(qwenTiny.benchmarkSummaryText?.contains("MLX ref") == true)
        XCTAssertTrue(qwenTiny.benchmarkSummaryText?.contains("PP 10639 tok/s") == true)
        XCTAssertTrue(qwenTiny.benchmarkSummaryText?.contains("TK 286 tok/s") == true)
        XCTAssertTrue(qwenTiny.benchmarkSummaryText?.contains("iPhone not verified") == true)

        XCTAssertFalse(availableModels.contains { $0.id == "smollm2-1-7b-instruct-q4-k-m" })
    }

    func testKairoUITestingLocalModelFactorySeedsAndSelectsInstalledModel() async throws {
        let rootDirectory = temporaryFileURL(named: "KairoUITestingLocalModels")
        let components = try await KairoUITestingLocalModelFactory(
            rootDirectory: rootDirectory,
            seedInstalledLocalModel: true,
            selectInstalledLocalModel: true,
            routePreference: .localOnly
        ).makeComponents()

        let status = await components.settingsService.status()

        XCTAssertEqual(status.selectedModelID, LocalModelManifest.qwen35Tiny.id)
        XCTAssertEqual(status.installedRecord?.status, .installed)
        XCTAssertEqual(status.preference, .localOnly)
        XCTAssertEqual(components.chatRuntimeAvailable, false)
    }

    func testKairoLiveLocalModelFactoryBuildsRoutedProviderFromPersistentInstallState() async throws {
        let rootDirectory = temporaryDirectory(named: "KairoLiveLocalModelFactory")
        let paths = KairoPaths(
            appName: "KairoLiveLocalModelFactoryTests",
            appGroupIdentifier: "group.kairo.tests"
        ) { _ in rootDirectory }
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: paths.localModelInstallRegistryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: LocalModelManifest.qwen35Tiny.id,
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: paths.localModelsDirectory.appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf"),
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let components = try await KairoLiveLocalModelFactory(
            paths: paths,
            credentialStore: InMemoryCredentialStore(),
            replyCheckRuntimeOverride: DeterministicLocalModelReplyCheckRuntime(
                responseText: "Live factory local reply",
                generationTokensPerSecond: 42
            )
        ).makeComponents()

        try await components.settingsService.selectModel(id: LocalModelManifest.qwen35Tiny.id)
        try await components.settingsService.setPreference(.localOnly)
        let status = await components.settingsService.status()
        let response = try await components.aiProvider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Summarize this offline"
        ))

        XCTAssertEqual(components.installedModelIDs, [LocalModelManifest.qwen35Tiny.id])
        XCTAssertEqual(status.selectedModelID, LocalModelManifest.qwen35Tiny.id)
        XCTAssertEqual(status.preference, .localOnly)
        XCTAssertEqual(response.message, "Live factory local reply")
        XCTAssertTrue(components.chatRuntimeAvailable)
    }

    func testLocalModelManifestTransparencyTextIsCompactForSettingsList() throws {
        let qwenTiny = LocalModelManifest.qwen35Tiny
        let text = qwenTiny.manifestTransparencyText

        XCTAssertEqual(text, "huggingface.co · GGUF · Apache-2.0 · iOS 17.0/A15+/4 GB · SHA e8e3882 · policy 2026.1")
        XCTAssertFalse(text.contains("Source:"))
        XCTAssertFalse(text.contains("Runtime:"))
        XCTAssertFalse(text.contains("License:"))
        XCTAssertFalse(text.contains("Requires:"))
    }

    func testLocalModelRuntimePillsKeepDownloadAndMLXStatusReadable() throws {
        let qwenTiny = LocalModelManifest.qwen35Tiny
        let llamaTiny = LocalModelManifest.llama32OneBInstruct

        XCTAssertEqual(qwenTiny.runtimePillTexts, [
            "Download GGUF",
            "A15+/4 GB",
            "MLX ref only"
        ])
        XCTAssertEqual(llamaTiny.runtimePillTexts, [
            "Download GGUF",
            "A15+/4 GB",
            "Device test pending"
        ])
    }

    func testLocalModelCatalogServiceFetchesStandaloneModelRepoCatalog() async throws {
        let indexURL = URL(string: "https://easonwumac.github.io/kairo-models/models.json")!
        let signedCatalog = try signedRemoteModelCatalogJSON(
            minimumSafetyPolicyVersion: "2026.2",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen3-5-0-8b-q4-k-m",
                    displayName: "Qwen3.5 0.8B Q4_K_M",
                    version: "1.1.0"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: indexURL,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        let catalog = try await service.fetchCatalog()
        let request = try await httpClient.lastRequest()

        XCTAssertEqual(LocalModelCatalogService.defaultIndexURL.absoluteString, "https://easonwumac.github.io/kairo-models/models.json")
        XCTAssertEqual(request.url?.absoluteString, "https://easonwumac.github.io/kairo-models/models.json")
        XCTAssertEqual(catalog.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(catalog.minimumSafetyPolicyVersion, "2026.2")
        XCTAssertEqual(catalog.models.first?.runtime, .gguf)
        XCTAssertEqual(catalog.models.first?.version, "1.1.0")
        XCTAssertEqual(catalog.models.first?.benchmarkProfiles, [])
    }

    func testLocalModelCatalogRefreshFallsBackToBuiltInCatalogWhenRemoteIsUnavailable() async throws {
        let httpClient = LocalModelMockHTTPClient(statusCode: 404, body: "not found")
        let service = LocalModelCatalogService(httpClient: httpClient)
        let builtInCatalog = LocalModelCatalog.kairoDefault

        let result = await service.refreshCatalog(with: builtInCatalog)

        XCTAssertEqual(result.source, .builtInFallback)
        XCTAssertNotNil(result.error)
        XCTAssertEqual(result.catalog.models.map(\.id), builtInCatalog.models.map(\.id))
        XCTAssertFalse(result.catalog.availableModels(minimumSafetyPolicyVersion: result.catalog.minimumSafetyPolicyVersion).isEmpty)
    }

    func testLocalModelCatalogRefreshUsesRemoteCatalogWhenVerificationPasses() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen3-5-0-8b-q4-k-m",
                    displayName: "Qwen3.5 0.8B Q4_K_M",
                    version: "1.2.0"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        let result = await service.refreshCatalog(with: .kairoDefault)

        XCTAssertEqual(result.source, .remote)
        XCTAssertNil(result.error)
        XCTAssertEqual(result.catalog.models.first { $0.id == "qwen3-5-0-8b-q4-k-m" }?.version, "1.2.0")
    }

    func testLocalModelCatalogServiceRejectsUnsafeRemoteModelDownloads() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "unsafe-model",
                    displayName: "Unsafe Model",
                    downloadURL: "http://example.com/unsafe.gguf"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected unsafe model catalog to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .unsafeDownloadURL(modelID: "unsafe-model", url: "http://example.com/unsafe.gguf"))
        }
    }

    func testLocalModelCatalogServiceRejectsDuplicateModelIDs() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small",
                    version: "1.0.0"
                ),
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small Shadow",
                    version: "9.9.9"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected duplicate model IDs to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .duplicateModelID("qwen-small"))
            XCTAssertEqual(error.localizedDescription, "Model catalog contains a duplicate model id: qwen-small.")
        }
    }

    func testLocalModelCatalogServiceRejectsBlankModelID() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "   ",
                    displayName: "Blank Model"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected blank model IDs to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .invalidModelID("   "))
            XCTAssertEqual(error.localizedDescription, "Model catalog contains an invalid model id:    .")
        }
    }

    func testLocalModelCatalogServiceRejectsMissingCapabilities() async throws {
        let manifestJSON = remoteModelManifestJSON(
            id: "qwen-small",
            displayName: "Qwen Small"
        ).replacingOccurrences(
            of: #""capabilities": ["drafts", "summarization", "simpleQuestionAnswer", "offlineChat"]"#,
            with: #""capabilities": []"#
        )
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                manifestJSON
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected model catalogs without capabilities to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .missingCapabilities(modelID: "qwen-small"))
            XCTAssertEqual(
                error.localizedDescription,
                "Model catalog must declare at least one capability for qwen-small."
            )
        }
    }

    func testLocalModelCatalogServiceRejectsInvalidSizeMetadata() async throws {
        let zeroFileSizeManifest = remoteModelManifestJSON(
            id: "zero-size-model",
            displayName: "Zero Size Model"
        ).replacingOccurrences(
            of: #""fileSizeBytes": 512"#,
            with: #""fileSizeBytes": 0"#
        )
        let impossibleInstallSizeManifest = remoteModelManifestJSON(
            id: "small-install-model",
            displayName: "Small Install Model"
        ).replacingOccurrences(
            of: #""installedSizeBytes": 1024"#,
            with: #""installedSizeBytes": 256"#
        )

        for (manifestJSON, expectedError) in [
            (
                zeroFileSizeManifest,
                LocalModelCatalogServiceError.invalidSizeMetadata(
                    modelID: "zero-size-model",
                    fileSizeBytes: 0,
                    installedSizeBytes: 1024
                )
            ),
            (
                impossibleInstallSizeManifest,
                LocalModelCatalogServiceError.invalidSizeMetadata(
                    modelID: "small-install-model",
                    fileSizeBytes: 512,
                    installedSizeBytes: 256
                )
            )
        ] {
            let signedCatalog = try signedRemoteModelCatalogJSON(
                modelsJSON: [
                    manifestJSON
                ]
            )
            let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
            let service = LocalModelCatalogService(
                indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
                httpClient: httpClient,
                trustStore: signedCatalog.trustStore
            )

            do {
                _ = try await service.fetchCatalog()
                XCTFail("Expected invalid model size metadata to fail closed.")
            } catch let error as LocalModelCatalogServiceError {
                XCTAssertEqual(error, expectedError)
            }
        }
    }

    func testLocalModelCatalogServiceRejectsUnsupportedRuntime() async throws {
        let unknownRuntimeManifest = remoteModelManifestJSON(
            id: "unknown-runtime-model",
            displayName: "Unknown Runtime Model"
        ).replacingOccurrences(
            of: #""runtime": "gguf""#,
            with: #""runtime": "unknown""#
        )
        let mlxRuntimeManifest = remoteModelManifestJSON(
            id: "mlx-runtime-model",
            displayName: "MLX Runtime Model"
        ).replacingOccurrences(
            of: #""runtime": "gguf""#,
            with: #""runtime": "mlx""#
        )

        for (manifestJSON, expectedError) in [
            (
                unknownRuntimeManifest,
                LocalModelCatalogServiceError.unsupportedRuntime(
                    modelID: "unknown-runtime-model",
                    runtime: .unknown
                )
            ),
            (
                mlxRuntimeManifest,
                LocalModelCatalogServiceError.unsupportedRuntime(
                    modelID: "mlx-runtime-model",
                    runtime: .mlx
                )
            )
        ] {
            let signedCatalog = try signedRemoteModelCatalogJSON(
                modelsJSON: [
                    manifestJSON
                ]
            )
            let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
            let service = LocalModelCatalogService(
                indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
                httpClient: httpClient,
                trustStore: signedCatalog.trustStore
            )

            do {
                _ = try await service.fetchCatalog()
                XCTFail("Expected unsupported model runtimes to fail closed.")
            } catch let error as LocalModelCatalogServiceError {
                XCTAssertEqual(error, expectedError)
            }
        }
    }

    func testLocalModelCatalogServiceRejectsNonHexChecksum() async throws {
        let invalidChecksum = String(repeating: "z", count: 64)
        let manifestJSON = remoteModelManifestJSON(
            id: "qwen-small",
            displayName: "Qwen Small"
        ).replacingOccurrences(
            of: String(repeating: "a", count: 64),
            with: invalidChecksum
        )
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                manifestJSON
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected non-hex SHA-256 checksums to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .invalidChecksum(modelID: "qwen-small", sha256: invalidChecksum))
        }
    }

    func testLocalModelCatalogServiceRejectsInvalidCatalogSignature() async throws {
        var signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        signedCatalog.json = signedCatalog.json.replacingOccurrences(of: "Qwen Small", with: "Tampered Qwen")
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected invalid catalog signature to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .invalidSignature)
        }

        let expiredCatalog = try signedRemoteModelCatalogJSON(
            signingKeyID: "kairo-models-expired",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "llama-small",
                    displayName: "Llama Small"
                )
            ],
            trustKeyOverride: { signingKey, signingKeyID in
                LocalModelTrustedSigningKey(
                    keyID: signingKeyID,
                    algorithm: "p256-sha256",
                    status: .active,
                    publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
                    validUntil: Date(timeIntervalSince1970: 1_600_000_000)
                )
            }
        )
        let expiredHTTPClient = LocalModelMockHTTPClient(statusCode: 200, body: expiredCatalog.json)
        let expiredService = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: expiredHTTPClient,
            trustStore: expiredCatalog.trustStore,
            currentDate: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        do {
            _ = try await expiredService.fetchCatalog()
            XCTFail("Expected expired signing key window to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .signingKeyExpired("kairo-models-expired"))
        }
    }

    func testLocalModelCatalogServiceRejectsCatalogWhenSigningKeyIsUnknown() async throws {
        let body = remoteModelCatalogJSON(
            signingKeyID: "unknown-key",
            signature: "signed-catalog-placeholder",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: body)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: LocalModelCatalogTrustStore(
                trustedKeys: [
                    LocalModelTrustedSigningKey(
                        keyID: "release-2026-q2",
                        algorithm: "p256-sha256",
                        status: .active
                    )
                ]
            )
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected unknown signing key to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .unknownSigningKey("unknown-key"))
        }
    }

    func testLocalModelCatalogServiceRejectsCatalogWhenSigningKeyIsRevoked() async throws {
        let body = remoteModelCatalogJSON(
            signingKeyID: "release-2026-q1",
            signature: "signed-catalog-placeholder",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: body)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: LocalModelCatalogTrustStore(
                trustedKeys: [
                    LocalModelTrustedSigningKey(
                        keyID: "release-2026-q1",
                        algorithm: "p256-sha256",
                        status: .revoked
                    ),
                    LocalModelTrustedSigningKey(
                        keyID: "release-2026-q2",
                        algorithm: "p256-sha256",
                        status: .active
                    )
                ]
            )
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected revoked signing key to be rejected.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .revokedSigningKey("release-2026-q1"))
        }
    }

    func testLocalModelCatalogServiceRejectsPendingPublicationSigningKeys() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            signingKeyID: "release-2026-q3",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ],
            trustKeyOverride: { signingKey, signingKeyID in
                LocalModelTrustedSigningKey(
                    keyID: signingKeyID,
                    algorithm: "p256-sha256",
                    status: .active,
                    publicationStatus: .pendingPublication,
                    publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
                )
            }
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected pending publication signing key to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .signingKeyPendingPublication("release-2026-q3"))
        }
    }

    func testLocalModelCatalogServiceRejectsReferenceUnsignedCatalogStatus() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            catalogSignatureStatus: "referenceUnsigned",
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ]
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected reference catalog status to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .nonProductionCatalogSignatureStatus("referenceUnsigned"))
            XCTAssertEqual(error.localizedDescription, "Model catalog is marked referenceUnsigned, not productionSigned.")
        }
    }

    func testDefaultLocalModelCatalogTrustStoreKeepsReleaseKeysPendingPublication() throws {
        let trustStore = LocalModelCatalogService.defaultTrustStore
        let activeReleaseKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-models-2026"))
        let revokedReleaseKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-models-2025"))

        XCTAssertEqual(activeReleaseKey.status, .active)
        XCTAssertEqual(activeReleaseKey.publicationStatus, .pendingPublication)
        XCTAssertTrue(activeReleaseKey.publicKeyBase64.isEmpty)
        XCTAssertEqual(revokedReleaseKey.status, .revoked)
        XCTAssertEqual(revokedReleaseKey.publicationStatus, .pendingPublication)
        XCTAssertTrue(revokedReleaseKey.publicKeyBase64.isEmpty)
    }

    func testLocalModelCatalogTrustStoreDecodesRotationMetadata() throws {
        let json = """
        {
          "trustedKeys": [
            {
              "keyID": "kairo-models-2026",
              "algorithm": "p256-sha256",
              "status": "revoked",
              "publicationStatus": "published",
              "publicKeyBase64": "abc123",
              "validFrom": "2026-01-01T00:00:00Z",
              "validUntil": "2026-12-31T00:00:00Z",
              "revokedAt": "2026-06-04T00:00:00Z",
              "revokedReason": "Rotated to kairo-models-2026-q3."
            }
          ]
        }
        """

        let trustStore = try JSONDecoder().decode(LocalModelCatalogTrustStore.self, from: Data(json.utf8))
        let trustedKey = try XCTUnwrap(trustStore.trustedKey(id: "kairo-models-2026"))
        let formatter = ISO8601DateFormatter()

        XCTAssertEqual(trustedKey.status, .revoked)
        XCTAssertEqual(trustedKey.publicationStatus, .published)
        XCTAssertEqual(trustedKey.publicKeyBase64, "abc123")
        XCTAssertEqual(trustedKey.validFrom, formatter.date(from: "2026-01-01T00:00:00Z"))
        XCTAssertEqual(trustedKey.validUntil, formatter.date(from: "2026-12-31T00:00:00Z"))
        XCTAssertEqual(trustedKey.revokedAt, formatter.date(from: "2026-06-04T00:00:00Z"))
        XCTAssertEqual(trustedKey.revokedReason, "Rotated to kairo-models-2026-q3.")

        let encodedJSON = String(data: try JSONEncoder().encode(trustStore), encoding: .utf8) ?? ""
        XCTAssertTrue(encodedJSON.contains(#""validFrom":"2026-01-01T00:00:00Z""#))
        XCTAssertTrue(encodedJSON.contains(#""validUntil":"2026-12-31T00:00:00Z""#))
        XCTAssertTrue(encodedJSON.contains(#""revokedAt":"2026-06-04T00:00:00Z""#))
        XCTAssertTrue(encodedJSON.contains(#""publicationStatus":"published""#))
    }

    func testLocalModelCatalogTrustStoreDecodesLegacyKeysAsActive() throws {
        let json = """
        {
          "trustedKeys": [
            {
              "keyID": "legacy-model-key",
              "algorithm": "p256-sha256"
            }
          ]
        }
        """

        let trustStore = try JSONDecoder().decode(LocalModelCatalogTrustStore.self, from: Data(json.utf8))
        let trustedKey = try XCTUnwrap(trustStore.trustedKey(id: "legacy-model-key"))

        XCTAssertEqual(trustedKey.status, .active)
        XCTAssertEqual(trustedKey.publicationStatus, .published)
        XCTAssertEqual(trustedKey.publicKeyBase64, "")
        XCTAssertNil(trustedKey.validFrom)
        XCTAssertNil(trustedKey.validUntil)
        XCTAssertNil(trustedKey.revokedAt)
        XCTAssertNil(trustedKey.revokedReason)
    }

    func testLocalModelCatalogServiceRejectsOutOfWindowSigningKeys() async throws {
        let signedCatalog = try signedRemoteModelCatalogJSON(
            modelsJSON: [
                remoteModelManifestJSON(
                    id: "qwen-small",
                    displayName: "Qwen Small"
                )
            ],
            trustKeyOverride: { signingKey, signingKeyID in
                LocalModelTrustedSigningKey(
                    keyID: signingKeyID,
                    algorithm: "p256-sha256",
                    status: .active,
                    publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString(),
                    validFrom: Date(timeIntervalSince1970: 1_800_000_000)
                )
            }
        )
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: signedCatalog.json)
        let service = LocalModelCatalogService(
            indexURL: URL(string: "https://easonwumac.github.io/kairo-models/models.json")!,
            httpClient: httpClient,
            trustStore: signedCatalog.trustStore,
            currentDate: { Date(timeIntervalSince1970: 1_700_000_000) }
        )

        do {
            _ = try await service.fetchCatalog()
            XCTFail("Expected future signing key window to fail closed.")
        } catch let error as LocalModelCatalogServiceError {
            XCTAssertEqual(error, .signingKeyNotYetValid("kairo-models-2026"))
        }
    }

    func testLocalModelCatalogMergesRemoteModelsWithoutDroppingBuiltInFallbacks() {
        let builtIn = LocalModelCatalog(
            generatedAt: Date(timeIntervalSince1970: 1),
            signingKeyID: "built-in",
            signature: "built-in-signature",
            sourceRepository: URL(string: "https://github.com/easonwumac/kairo"),
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "shared-model", version: "1.0", safetyPolicyVersion: "2026.1"),
                makeLocalModelManifest(id: "built-in-only", version: "1.0", safetyPolicyVersion: "2026.1")
            ]
        )
        let remote = LocalModelCatalog(
            generatedAt: Date(timeIntervalSince1970: 2),
            signingKeyID: "kairo-models-2026",
            signature: "remote-signature",
            sourceRepository: URL(string: "https://github.com/easonwumac/kairo-models"),
            minimumSafetyPolicyVersion: "2026.2",
            models: [
                makeLocalModelManifest(id: "shared-model", version: "2.0", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "remote-only", version: "1.0", safetyPolicyVersion: "2026.2")
            ]
        )

        let merged = builtIn.mergingRemoteCatalog(remote)

        XCTAssertEqual(merged.sourceRepository?.absoluteString, "https://github.com/easonwumac/kairo-models")
        XCTAssertEqual(merged.signingKeyID, "kairo-models-2026")
        XCTAssertEqual(merged.minimumSafetyPolicyVersion, "2026.2")
        XCTAssertEqual(merged.models.map(\.id), ["shared-model", "built-in-only", "remote-only"])
        XCTAssertEqual(merged.models.first?.version, "2.0")
        XCTAssertEqual(merged.models.last?.id, "remote-only")
    }

    func testFileBackedLocalModelInstallRegistryPersistsInstalledRecords() async throws {
        let fileURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = fileURL.deletingLastPathComponent().appendingPathComponent("model.gguf")
        let record = LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        )

        let firstRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        try await firstRegistry.upsert(record)

        let secondRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        let persisted = await secondRegistry.record(for: "qwen-small")
        let installedRecords = await secondRegistry.installedRecords()

        XCTAssertEqual(persisted?.modelID, record.modelID)
        XCTAssertEqual(persisted?.version, record.version)
        XCTAssertEqual(persisted?.status, .installed)
        XCTAssertEqual(persisted?.fileURL, record.fileURL)
        XCTAssertEqual(persisted?.installedSizeBytes, record.installedSizeBytes)
        XCTAssertEqual(persisted?.sha256, record.sha256)
        XCTAssertEqual(installedRecords.map(\.modelID), [record.modelID])
    }

    func testFileBackedLocalModelInstallRegistryRepairsRelocatedModelFileURLs() async throws {
        let fileURL = temporaryFileURL(named: "local-model-registry-relocated.json")
        let currentDirectory = fileURL.deletingLastPathComponent()
        let currentModelURL = currentDirectory.appendingPathComponent("qwen-small.gguf")
        let staleModelURL = currentDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("OldContainer")
            .appendingPathComponent("qwen-small.gguf")
        try FileManager.default.createDirectory(at: currentDirectory, withIntermediateDirectories: true)
        try Data("model-bytes".utf8).write(to: currentModelURL)

        let staleRecord = LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: staleModelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        try encoder.encode([staleRecord]).write(to: fileURL)

        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        let repairedRecord = await registry.record(for: "qwen-small")
        let installedRecords = await registry.installedRecords()

        XCTAssertEqual(repairedRecord?.fileURL, currentModelURL)
        XCTAssertEqual(installedRecords.map(\.fileURL), [currentModelURL])

        let reloadedRegistry = try await FileBackedLocalModelInstallRegistry(fileURL: fileURL)
        let persistedRepair = await reloadedRegistry.record(for: "qwen-small")
        XCTAssertEqual(persistedRepair?.fileURL, currentModelURL)
    }

    func testFileBackedLocalModelSettingsStorePersistsSelectedModelAndPreference() async throws {
        let fileURL = temporaryFileURL(named: "local-model-settings.json")
        let firstStore = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let initialSettings = await firstStore.settings()
        XCTAssertNil(initialSettings.selectedModelID)
        XCTAssertEqual(initialSettings.preference, .automatic)
        XCTAssertEqual(initialSettings.responseLanguage, .system)

        try await firstStore.save(LocalModelSettings(
            selectedModelID: "qwen-small",
            preference: .preferLocal,
            responseLanguage: .traditionalChinese
        ))

        let secondStore = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let persisted = await secondStore.settings()
        XCTAssertEqual(persisted.selectedModelID, "qwen-small")
        XCTAssertEqual(persisted.preference, .preferLocal)
        XCTAssertEqual(persisted.responseLanguage, .traditionalChinese)
    }

    func testFileBackedLocalModelSettingsStoreDefaultsLegacyResponseLanguageToSystem() async throws {
        let fileURL = temporaryFileURL(named: "local-model-settings-legacy-language.json")
        try FileManager.default.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data("""
        {
          "preference" : "preferLocal",
          "selectedModelID" : "qwen-small"
        }
        """.utf8).write(to: fileURL)

        let store = try await FileBackedLocalModelSettingsStore(fileURL: fileURL)
        let settings = await store.settings()

        XCTAssertEqual(settings.selectedModelID, "qwen-small")
        XCTAssertEqual(settings.preference, .preferLocal)
        XCTAssertEqual(settings.responseLanguage, .system)
    }

    func testProviderRoutePreferenceBuildsSettingsCopyAndOrdering() {
        XCTAssertEqual(ProviderRoutePreference.settingsChoices, [
            .automatic,
            .preferLocal,
            .preferCloud,
            .localOnly
        ])
        XCTAssertEqual(ProviderRoutePreference.automatic.settingsTitle, KairoL10n.string("settings.route.automatic.title"))
        XCTAssertEqual(ProviderRoutePreference.preferLocal.settingsTitle, KairoL10n.string("settings.route.preferLocal.title"))
        XCTAssertEqual(ProviderRoutePreference.preferCloud.settingsTitle, KairoL10n.string("settings.route.preferCloud.title"))
        XCTAssertEqual(ProviderRoutePreference.localOnly.settingsTitle, KairoL10n.string("settings.route.localOnly.title"))
        XCTAssertEqual(ProviderRoutePreference.localOnly.settingsDetailText, KairoL10n.string("settings.route.localOnly.detail"))
        XCTAssertEqual(ProviderRoutePreference.preferLocal.settingsDetailText, KairoL10n.string("settings.route.preferLocal.detail"))
    }

    func testChatProviderRouteStatusBuilderExplainsSelectedLocalModelAndWarnings() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let selectedStatus = ChatProviderRouteStatusBuilder.build(from: await service.status())

        XCTAssertEqual(selectedStatus.selectedOptionID, "local.qwen-small")
        XCTAssertEqual(selectedStatus.options.map(\.id), ["cloud.openai", "local.qwen-small"])
        XCTAssertEqual(selectedStatus.options.first { $0.id == "local.qwen-small" }?.isEnabled, false)
        XCTAssertNotNil(selectedStatus.warning)

        let selectedRuntimeReadyStatus = ChatProviderRouteStatusBuilder.build(
            from: await service.status(),
            localRuntimeAvailable: true
        )
        XCTAssertEqual(selectedRuntimeReadyStatus.selectedOptionID, "local.qwen-small")
        XCTAssertEqual(selectedRuntimeReadyStatus.options.first { $0.id == "local.qwen-small" }?.isEnabled, true)
        XCTAssertNil(selectedRuntimeReadyStatus.warning)

        let installedManifest = makeLocalModelManifest(id: "qwen-small")
        let installedRecord = LocalModelInstallRecord(
            modelID: "qwen-small",
            version: installedManifest.version,
            status: .installed,
            fileURL: URL(fileURLWithPath: "/tmp/qwen-small.gguf"),
            installedSizeBytes: installedManifest.installedSizeBytes,
            sha256: installedManifest.sha256
        )
        let localOnlyInstalledStatus = ChatProviderRouteStatusBuilder.build(from: LocalModelSettingsStatus(
            selectedModelID: "qwen-small",
            selectedModel: installedManifest,
            installedRecord: installedRecord,
            preference: .localOnly,
            availableModels: [installedManifest],
            installedModels: [installedRecord]
        ))

        XCTAssertEqual(localOnlyInstalledStatus.selectedOptionID, "local.qwen-small")
        XCTAssertEqual(localOnlyInstalledStatus.options.first { $0.id == "local.qwen-small" }?.isEnabled, false)
        XCTAssertNotNil(localOnlyInstalledStatus.warning)

        let localOnlyRuntimeReadyStatus = ChatProviderRouteStatusBuilder.build(
            from: LocalModelSettingsStatus(
                selectedModelID: "qwen-small",
                selectedModel: installedManifest,
                installedRecord: installedRecord,
                preference: .localOnly,
                availableModels: [installedManifest],
                installedModels: [installedRecord]
            ),
            localRuntimeAvailable: true
        )
        XCTAssertNil(localOnlyRuntimeReadyStatus.warning)
        XCTAssertEqual(localOnlyRuntimeReadyStatus.options.first { $0.id == "local.qwen-small" }?.isEnabled, true)

        let warningStatus = ChatProviderRouteStatusBuilder.build(from: LocalModelSettingsStatus(
            selectedModelID: nil,
            selectedModel: nil,
            installedRecord: nil,
            preference: .localOnly,
            availableModels: [makeLocalModelManifest(id: "qwen-small")],
            installedModels: []
        ))

        XCTAssertEqual(warningStatus.selectedOptionID, "local.none")
        XCTAssertEqual(warningStatus.options.map(\.id), ["cloud.openai", "local.none"])
        XCTAssertEqual(warningStatus.options.first { $0.id == "local.none" }?.isEnabled, false)
        XCTAssertNotNil(warningStatus.warning)
    }

    func testLocalModelRoutingAIProviderUsesSelectedLocalModelForEligiblePreferLocalWork() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let runtime = DeterministicLocalModelReplyCheckRuntime(
            runtimePackage: "deterministic-chat-runtime",
            responseText: "Runtime-backed local answer.",
            generationTokensPerSecond: 12.5
        )
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: MockAIProvider(),
            localModelSettingsService: service,
            localProvider: LocalModelRuntimeAIProvider(
                localModelSettingsService: service,
                runtime: runtime
            ),
            localRuntimeAvailable: true
        )

        let response = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply for this message."
        ))

        XCTAssertEqual(response.message, "Runtime-backed local answer.")
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testLocalModelRuntimeAIProviderPassesStoredRuntimeParameters() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(
                    id: "qwen-large-context",
                    safetyPolicyVersion: "2026.1",
                    contextWindow: 16_384
                )
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-large-context",
            version: "1.0",
            status: .installed,
            fileURL: registryURL.deletingLastPathComponent().appendingPathComponent("qwen-large-context.gguf"),
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let parameters = LocalModelRuntimeParameters(
            contextSize: 8_192,
            maxOutputTokens: 256,
            temperature: 0.6
        )
        try await service.selectModel(id: "qwen-large-context")
        try await service.setRuntimeParameters(parameters, for: "qwen-large-context")
        let runtime = RecordingLocalModelReplyRuntime()
        let provider = LocalModelRuntimeAIProvider(localModelSettingsService: service, runtime: runtime)

        let response = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Use the stored local parameters."
        ))

        XCTAssertEqual(response.message, "runtime parameters applied")
        let capturedParameters = await runtime.lastParameters()
        XCTAssertEqual(capturedParameters, parameters)
    }

    func testLocalModelRuntimeSeparatesThinkReasoningFromVisibleReply() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .localOnly,
            installedAndSelectedModelID: "qwen-small"
        )
        let runtime = DeterministicLocalModelReplyCheckRuntime(
            responseText: """
            <think>
            Internal chain of thought.
            </think>
            Visible local answer.
            """,
            generationTokensPerSecond: 12.5
        )
        let provider = LocalModelRuntimeAIProvider(
            localModelSettingsService: service,
            runtime: runtime
        )

        let response = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "hello"
        ))

        XCTAssertEqual(response.message, "Visible local answer.")
        XCTAssertEqual(response.reasoningText, "Internal chain of thought.")
        XCTAssertFalse(response.message.contains("<think>"))
    }

    func testLocalModelRoutingAIProviderFailsClosedWhenSelectedRuntimeIsUnavailable() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .localOnly,
            installedAndSelectedModelID: "qwen-small"
        )
        let cloudProvider = RecordingAIProvider()
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: cloudProvider,
            localModelSettingsService: service,
            localProvider: LocalModelRuntimeAIProvider(
                localModelSettingsService: service,
                runtime: UnavailableLocalModelReplyCheckRuntime(reason: "runtime unavailable for test")
            ),
            localRuntimeAvailable: true
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply."
        ))) { error in
            guard case .localInferenceUnavailable? = error as? AIProviderError else {
                XCTFail("Expected local inference to fail closed")
                return
            }
        }
        let completionCallCount = await cloudProvider.completionCalls()
        XCTAssertEqual(completionCallCount, 0)
    }

    func testLocalModelRoutingAIProviderFallsBackToCloudWhenPreferLocalRuntimeUnavailable() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let cloudProvider = RecordingAIProvider()
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: cloudProvider,
            localModelSettingsService: service,
            localProvider: LocalModelRuntimeAIProvider(
                localModelSettingsService: service,
                runtime: UnavailableLocalModelReplyCheckRuntime(reason: "runtime unavailable for test")
            ),
            localRuntimeAvailable: false
        )

        _ = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply."
        ))

        let completionCallCount = await cloudProvider.completionCalls()
        XCTAssertEqual(completionCallCount, 1)
    }

    func testLocalModelRoutingAIProviderKeepsToolRequestsOnCloudWhenPreferLocal() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .preferLocal,
            installedAndSelectedModelID: "qwen-small"
        )
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: MockAIProvider(),
            localModelSettingsService: service
        )

        let response = try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Use HomeKit to turn on the living room light."
        ))

        XCTAssertEqual(
            response.message,
            KairoL10n.string("chat.provider.mockPreviewResponse", "Use HomeKit to turn on the living room light.")
        )
        XCTAssertFalse(response.message.contains(KairoL10n.string("chat.provider.localFallback.generic")))
    }

    func testLocalModelRoutingAIProviderFailsClosedWhenLocalOnlyHasNoModel() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .localOnly,
            installedAndSelectedModelID: nil
        )
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: MockAIProvider(),
            localModelSettingsService: service
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply."
        ))) { error in
            XCTAssertEqual(error as? AIProviderError, .localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.localOnlyNoModel")
            ))
        }
    }

    func testLocalModelRoutingAIProviderDoesNotCallCloudWhenLocalOnlyHasNoModel() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .localOnly,
            installedAndSelectedModelID: nil
        )
        let cloudProvider = RecordingAIProvider()
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: cloudProvider,
            localModelSettingsService: service
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(AICompletionRequest(
            systemPrompt: "Test",
            userPrompt: "Draft a private reply."
        ))) { error in
            XCTAssertEqual(error as? AIProviderError, .localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.localOnlyNoModel")
            ))
        }

        let completionCallCount = await cloudProvider.completionCallCount
        XCTAssertEqual(completionCallCount, 0)
    }

    func testLocalModelSettingsServiceSelectsInstalledModelAndBuildsRoutingContext() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-small.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "old-policy", safetyPolicyVersion: "2025.9")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        try await service.setPreference(.preferLocal)
        try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertEqual(status.selectedModelID, "qwen-small")
        XCTAssertEqual(status.selectedModel?.id, "qwen-small")
        XCTAssertEqual(status.installedRecord?.fileURL, modelURL)
        XCTAssertEqual(status.installedModels.map(\.modelID), ["qwen-small"])
        XCTAssertEqual(status.availableModels.map(\.id), ["qwen-small"])

        let context = await service.routingContext(
            taskClass: .summarization,
            networkAvailable: false,
            minimumSafetyPolicyVersion: "2026.1"
        )
        XCTAssertEqual(context.preference, .preferLocal)
        XCTAssertFalse(context.networkAvailable)
        XCTAssertEqual(context.taskClass, .summarization)
        XCTAssertTrue(context.localModelInstalled)
        XCTAssertEqual(context.localContextWindow, 2048)
    }

    func testLocalModelSettingsServicePersistsRuntimeParametersPerModel() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-large-context.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(
                    id: "qwen-large-context",
                    safetyPolicyVersion: "2026.2",
                    contextWindow: 16_384
                ),
                makeLocalModelManifest(id: "qwen-default", safetyPolicyVersion: "2026.2")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-large-context",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        try await service.selectModel(id: "qwen-large-context", minimumSafetyPolicyVersion: "2026.1")
        try await service.setRuntimeParameters(
            LocalModelRuntimeParameters(contextSize: 16_384, maxOutputTokens: 256, temperature: 0.7),
            for: "qwen-large-context",
            minimumSafetyPolicyVersion: "2026.1"
        )

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertEqual(status.runtimeParametersByModelID["qwen-large-context"]?.contextSize, 16_384)
        XCTAssertEqual(status.runtimeParametersByModelID["qwen-large-context"]?.maxOutputTokens, 256)
        XCTAssertEqual(status.runtimeParametersByModelID["qwen-large-context"]?.temperature, 0.7)
        XCTAssertNil(status.runtimeParametersByModelID["qwen-default"])

        let context = await service.routingContext(
            taskClass: .summarization,
            networkAvailable: false,
            minimumSafetyPolicyVersion: "2026.1"
        )
        XCTAssertEqual(context.localContextWindow, 16_384)
    }

    func testLocalModelSettingsServiceDeletesInstalledModelFileRecordAndSelection() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen-small.gguf")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
            ]
        )
        try FileManager.default.createDirectory(at: modelURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("model-bytes".utf8).write(to: modelURL)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: 1024,
            sha256: "abc123"
        ))
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)
        try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")

        try await service.deleteModel(id: "qwen-small")

        XCTAssertFalse(FileManager.default.fileExists(atPath: modelURL.path))
        let deletedRecord = await registry.record(for: "qwen-small")
        XCTAssertNil(deletedRecord)
        let settings = await store.settings()
        XCTAssertNil(settings.selectedModelID)
        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.localModelInstalled)
    }

    func testLocalModelSettingsServiceRejectsUninstalledOrUnavailableSelections() async throws {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2"),
                makeLocalModelManifest(id: "deprecated", safetyPolicyVersion: "2026.2", deprecated: true)
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        do {
            try await service.selectModel(id: "qwen-small", minimumSafetyPolicyVersion: "2026.1")
            XCTFail("Expected uninstalled model selection to fail")
        } catch let error as LocalModelSelectionError {
            XCTAssertEqual(error, .modelNotInstalled("qwen-small"))
        }

        do {
            try await service.selectModel(id: "deprecated", minimumSafetyPolicyVersion: "2026.1")
            XCTFail("Expected unavailable model selection to fail")
        } catch let error as LocalModelSelectionError {
            XCTAssertEqual(error, .modelUnavailable("deprecated"))
        }

        let status = await service.status(minimumSafetyPolicyVersion: "2026.1")
        XCTAssertNil(status.selectedModelID)
        XCTAssertFalse(status.localModelInstalled)
    }

    func testLocalModelBenchmarkServiceRequiresDownloadedModelBeforeRunning() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let resultStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let service = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: resultStore,
            engine: DeterministicLocalModelBenchmarkEngine(
                runtime: .gguf,
                generationTokensPerSecond: 43,
                promptTokensPerSecond: 120
            )
        )

        do {
            _ = try await service.runBenchmark(
                modelID: "qwen3-5-0-8b-q4-k-m",
                prompt: "Benchmark Kairo local drafting.",
                generatedTokenTarget: 64
            )
            XCTFail("Expected benchmark to require a downloaded local model.")
        } catch let error as LocalModelBenchmarkError {
            XCTAssertEqual(error, .modelNotInstalled("qwen3-5-0-8b-q4-k-m"))
        }

        let persisted = await resultStore.latestResult(for: "qwen3-5-0-8b-q4-k-m")
        XCTAssertNil(persisted)
    }

    func testLocalModelBenchmarkServiceRunsInstalledQwenThroughInjectedEngineAndPersistsResult() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let resultStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let service = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: resultStore,
            engine: DeterministicLocalModelBenchmarkEngine(
                runtime: .gguf,
                generationTokensPerSecond: 43.5,
                promptTokensPerSecond: 121.3,
                firstTokenLatencyMS: 842,
                peakMemoryMB: 980
            )
        )

        let result = try await service.runBenchmark(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Benchmark Kairo local drafting.",
            generatedTokenTarget: 64
        )

        XCTAssertEqual(result.modelID, "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(result.runtime, .gguf)
        XCTAssertEqual(result.promptTokens, 32)
        XCTAssertEqual(result.generatedTokens, 64)
        XCTAssertEqual(result.promptTokensPerSecond, 121.3)
        XCTAssertEqual(result.generationTokensPerSecond, 43.5)
        XCTAssertEqual(result.firstTokenLatencyMS, 842)
        XCTAssertEqual(result.peakMemoryMB, 980)
        XCTAssertFalse(result.isReferenceOnlyForIOS)

        let latestResult = await resultStore.latestResult(for: "qwen3-5-0-8b-q4-k-m")
        let persisted = try XCTUnwrap(latestResult)
        XCTAssertEqual(persisted, result)
        let reloadedStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let reloadedResult = await reloadedStore.latestResult(for: "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(reloadedResult, result)
    }

    func testLocalModelBenchmarkServiceSurfacesRuntimeUnavailableReason() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let resultStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let service = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: resultStore,
            engine: UnavailableLocalModelBenchmarkEngine(reason: "Runtime not shipped in this beta.")
        )

        do {
            _ = try await service.runBenchmark(modelID: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected unavailable runtime to fail closed.")
        } catch let error as LocalModelBenchmarkError {
            XCTAssertEqual(error, .runtimeUnavailable("Runtime not shipped in this beta."))
        }
    }

    func testDefaultLocalModelBenchmarkUnavailableReasonNamesSimulatorQwenBoundary() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let service = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        )

        do {
            _ = try await service.runBenchmark(modelID: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected default unavailable runtime to fail closed.")
        } catch let error as LocalModelBenchmarkError {
            XCTAssertEqual(error, .runtimeUnavailable(KairoL10n.string("settings.models.runtimeUnavailable.iOSSimulatorQwen")))
        }
    }

    func testLocalModelReplyCheckRequiresDownloadedModelBeforeRunning() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let service = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: DeterministicLocalModelReplyCheckRuntime(
                responseText: "Local model reply is alive.",
                generationTokensPerSecond: 38
            )
        )

        do {
            _ = try await service.runReplyCheck(
                modelID: "qwen3-5-0-8b-q4-k-m",
                prompt: "Reply with one sentence."
            )
            XCTFail("Expected reply check to require a downloaded local model.")
        } catch let error as LocalModelReplyCheckError {
            XCTAssertEqual(error, .modelNotInstalled("qwen3-5-0-8b-q4-k-m"))
        }
    }

    func testLocalModelReplyCheckRunsInstalledQwenThroughInjectedRuntime() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let service = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: DeterministicLocalModelReplyCheckRuntime(
                responseText: "Local model reply is alive.",
                generationTokensPerSecond: 38.5
            )
        )

        let result = try await service.runReplyCheck(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Reply with one sentence."
        )

        XCTAssertEqual(result.modelID, "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(result.modelDisplayName, "Qwen3.5 0.8B Q4_K_M")
        XCTAssertEqual(result.runtime, .gguf)
        XCTAssertEqual(result.responseText, "Local model reply is alive.")
        XCTAssertEqual(result.generationTokensPerSecond, 38.5)
        XCTAssertTrue(result.summaryText.contains("38.5 gen tok/s"))
        XCTAssertTrue(result.summaryText.contains("Local model reply is alive."))
    }

    func testLocalModelReplyCheckSurfacesRuntimeUnavailableReason() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let service = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: UnavailableLocalModelReplyCheckRuntime(reason: "Runtime not shipped in this beta.")
        )

        do {
            _ = try await service.runReplyCheck(modelID: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected unavailable reply runtime to fail closed.")
        } catch let error as LocalModelReplyCheckError {
            XCTAssertEqual(error, .runtimeUnavailable("Runtime not shipped in this beta."))
        }
    }

    func testDefaultLocalModelReplyCheckUnavailableReasonNamesSimulatorQwenBoundary() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let service = LocalModelReplyCheckService(catalog: .kairoDefault, installRegistry: registry)

        do {
            _ = try await service.runReplyCheck(modelID: "qwen3-5-0-8b-q4-k-m")
            XCTFail("Expected default unavailable reply runtime to fail closed.")
        } catch let error as LocalModelReplyCheckError {
            XCTAssertEqual(error, .runtimeUnavailable(KairoL10n.string("settings.models.runtimeUnavailable.iOSSimulatorQwen")))
        }
    }

    func testLocalModelExternalCommandRuntimeRunsDownloadedQwenThroughLlamaCLI() async throws {
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let benchmarkURL = temporaryFileURL(named: "local-model-benchmarks.json")
        let modelURL = registryURL.deletingLastPathComponent().appendingPathComponent("qwen3-5-0-8b-q4-k-m.gguf")
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen3-5-0-8b-q4-k-m",
            version: LocalModelManifest.qwen35Tiny.version,
            status: .installed,
            fileURL: modelURL,
            installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
            sha256: LocalModelManifest.qwen35Tiny.sha256
        ))
        let commandRunner = LocalModelFakeCommandRunner(result: LocalModelCommandRunResult(
            stdout: "Local model reply is alive.\n",
            stderr: """
            llama_perf_context_print: prompt eval time = 80.00 ms / 16 tokens (5.00 ms per token, 200.00 tokens per second)
            llama_perf_context_print: eval time = 1200.00 ms / 48 runs (25.00 ms per token, 40.00 tokens per second)
            """,
            exitCode: 0,
            durationSeconds: 1.2
        ))
        let runtime = LocalModelExternalCommandRuntime(
            configuration: .llamaCLI(
                executableURL: URL(fileURLWithPath: "/tmp/llama-cli"),
                defaultGeneratedTokenTarget: 48
            ),
            commandRunner: commandRunner
        )
        let replyService = LocalModelReplyCheckService(
            catalog: .kairoDefault,
            installRegistry: registry,
            runtime: runtime
        )

        let reply = try await replyService.runReplyCheck(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Reply with one sentence."
        )

        XCTAssertEqual(reply.modelID, "qwen3-5-0-8b-q4-k-m")
        XCTAssertEqual(reply.runtime, .gguf)
        XCTAssertEqual(reply.runtimePackage, "llama.cpp CLI")
        XCTAssertEqual(reply.responseText, "Local model reply is alive.")
        XCTAssertEqual(reply.generatedTokens, 48)
        XCTAssertEqual(reply.generationTokensPerSecond, 40, accuracy: 0.1)
        XCTAssertTrue(reply.notes.contains("does not bundle weights"))

        let firstInvocation = try await commandRunner.invocation(at: 0)
        XCTAssertEqual(firstInvocation.executableURL.path, "/tmp/llama-cli")
        XCTAssertEqual(firstInvocation.arguments, [
            "-m",
            modelURL.path,
            "-p",
            "Reply with one sentence.",
            "-n",
            "48",
            "--no-display-prompt"
        ])

        let benchmarkStore = try await FileBackedLocalModelBenchmarkStore(fileURL: benchmarkURL)
        let benchmarkService = LocalModelBenchmarkService(
            catalog: .kairoDefault,
            installRegistry: registry,
            resultStore: benchmarkStore,
            engine: runtime
        )
        let benchmark = try await benchmarkService.runBenchmark(
            modelID: "qwen3-5-0-8b-q4-k-m",
            prompt: "Benchmark Kairo local drafting.",
            generatedTokenTarget: 32
        )

        XCTAssertEqual(benchmark.runtime, .gguf)
        XCTAssertEqual(benchmark.runtimePackage, "llama.cpp CLI")
        XCTAssertEqual(benchmark.promptTokens, 16)
        XCTAssertEqual(benchmark.generatedTokens, 48)
        XCTAssertEqual(benchmark.promptTokensPerSecond, 200, accuracy: 0.1)
        XCTAssertEqual(benchmark.generationTokensPerSecond, 40, accuracy: 0.1)
        XCTAssertFalse(benchmark.isReferenceOnlyForIOS)
        let secondInvocation = try await commandRunner.invocation(at: 1)
        XCTAssertEqual(secondInvocation.arguments, [
            "-m",
            modelURL.path,
            "-p",
            "Benchmark Kairo local drafting.",
            "-n",
            "32",
            "--no-display-prompt"
        ])
    }

    func testLocalModelExternalCommandRuntimeBuildsQwenMLXReferenceCommand() async throws {
        let modelURL = temporaryFileURL(named: "qwen3-5-0-8b-mlx")
        let commandRunner = LocalModelFakeCommandRunner(result: LocalModelCommandRunResult(
            stdout: """
            Prompt: 8 tokens, 512.0 tokens-per-sec
            Generation: 24 tokens, 286.0 tokens-per-sec
            Qwen MLX response is alive.
            """,
            stderr: "",
            exitCode: 0,
            durationSeconds: 0.2
        ))
        let runtime = LocalModelExternalCommandRuntime(
            configuration: .mlxLMGenerate(
                pythonExecutableURL: URL(fileURLWithPath: "/usr/bin/python3"),
                defaultGeneratedTokenTarget: 24
            ),
            commandRunner: commandRunner
        )
        let result = try await runtime.generateReply(
            model: .qwen35Tiny,
            installRecord: LocalModelInstallRecord(
                modelID: LocalModelManifest.qwen35Tiny.id,
                version: LocalModelManifest.qwen35Tiny.version,
                status: .installed,
                fileURL: modelURL,
                installedSizeBytes: LocalModelManifest.qwen35Tiny.installedSizeBytes,
                sha256: LocalModelManifest.qwen35Tiny.sha256
            ),
            prompt: "Ping Kairo.",
            parameters: .defaultValue
        )

        XCTAssertEqual(result.runtime, .mlx)
        XCTAssertEqual(result.runtimePackage, "mlx-lm")
        XCTAssertEqual(result.responseText, "Qwen MLX response is alive.")
        XCTAssertEqual(result.generatedTokens, 24)
        XCTAssertEqual(result.generationTokensPerSecond, 286, accuracy: 0.1)

        let invocation = try await commandRunner.invocation(at: 0)
        XCTAssertEqual(invocation.arguments, [
            "-m",
            "mlx_lm.generate",
            "--model",
            "mlx-community/Qwen3.5-0.8B-OptiQ-4bit",
            "--prompt",
            "Ping Kairo.",
            "--max-tokens",
            "24"
        ])
    }

    func testLocalModelSettingsStatusBuildsSettingsRowsForDownloadSelectAndSelected() throws {
        let selectedManifest = makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
        let downloadableManifest = makeLocalModelManifest(id: "llama-draft", safetyPolicyVersion: "2026.2")
        let installedRecord = LocalModelInstallRecord(
            modelID: selectedManifest.id,
            version: selectedManifest.version,
            status: .installed,
            fileURL: URL(fileURLWithPath: "/tmp/qwen-small.gguf"),
            installedSizeBytes: selectedManifest.installedSizeBytes,
            sha256: selectedManifest.sha256
        )
        let status = LocalModelSettingsStatus(
            selectedModelID: selectedManifest.id,
            selectedModel: selectedManifest,
            installedRecord: installedRecord,
            preference: .preferLocal,
            availableModels: [selectedManifest, downloadableManifest],
            installedModels: [installedRecord]
        )

        let rows = status.settingsRows
        let selectedRow = try XCTUnwrap(rows.first { $0.modelID == selectedManifest.id })
        let downloadableRow = try XCTUnwrap(rows.first { $0.modelID == downloadableManifest.id })

        XCTAssertEqual(rows.map(\.modelID), [selectedManifest.id, downloadableManifest.id])
        XCTAssertEqual(selectedRow.statusText, KairoL10n.string("settings.models.status.selected"))
        XCTAssertEqual(selectedRow.primaryAction, .selected)
        XCTAssertEqual(downloadableRow.statusText, KairoL10n.string("settings.models.status.downloadable"))
        XCTAssertEqual(downloadableRow.primaryAction, .download)
        XCTAssertTrue(selectedRow.canDelete)
        XCTAssertFalse(downloadableRow.canDelete)
        XCTAssertTrue(selectedRow.detailText.contains("0.8B"))
        XCTAssertTrue(selectedRow.detailText.contains("Q4"))
        XCTAssertTrue(selectedRow.detailText.contains("2K ctx"))
        XCTAssertFalse(selectedRow.detailText.contains("download"))
        XCTAssertFalse(selectedRow.detailText.contains("Apache"))
        XCTAssertNil(downloadableRow.benchmarkSummaryText)
    }

    func testLocalModelSettingsRowBuildsManifestTransparencyText() throws {
        let row = LocalModelSettingsRow(
            model: LocalModelManifest.qwen35Tiny,
            installRecord: nil,
            isSelected: false
        )

        XCTAssertEqual(
            row.manifestTransparencyText,
            "huggingface.co · GGUF · Apache-2.0 · iOS 17.0/A15+/4 GB · SHA e8e3882 · policy 2026.1"
        )
        XCTAssertEqual(
            row.runtimeFitText,
            "Download: GGUF · Fit: A15+/4 GB · MLX ref only"
        )
    }

    func testLocalModelSettingsRowExposesDownloadStorageAndPurposePolicy() throws {
        let row = LocalModelSettingsRow(
            model: LocalModelManifest.qwen35Tiny,
            installRecord: nil,
            isSelected: false
        )

        XCTAssertEqual(
            row.downloadApprovalText,
            "User-triggered download · 503.1 MB · Apache-2.0"
        )
        XCTAssertEqual(
            row.licenseApprovalText,
            "License approval required · Apache-2.0 · www.apache.org"
        )
        XCTAssertEqual(
            row.storagePolicyText,
            "Stored in Application Support/LocalModels · Excluded from iCloud backup"
        )
        XCTAssertEqual(
            row.purposeBoundaryText,
            "Offline chat, drafts, summaries, and Q&A only · no tools, web, account actions, or regulated advice"
        )
    }

    func testLocalModelSettingsRowsPreserveCatalogOrderForEqualActions() {
        let qwenManifest = makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.2")
        let llamaManifest = makeLocalModelManifest(id: "llama-draft", safetyPolicyVersion: "2026.2")
        let smolManifest = makeLocalModelManifest(id: "smollm-draft", safetyPolicyVersion: "2026.2")
        let status = LocalModelSettingsStatus(
            selectedModelID: nil,
            selectedModel: nil,
            installedRecord: nil,
            preference: .automatic,
            availableModels: [qwenManifest, llamaManifest, smolManifest],
            installedModels: []
        )

        XCTAssertEqual(status.settingsRows.map(\.modelID), [
            qwenManifest.id,
            llamaManifest.id,
            smolManifest.id
        ])
    }

    func testVerifiedLocalModelDownloaderInstallsModelAndUpdatesRegistry() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let httpClient = LocalModelMockHTTPClient(statusCode: 200, body: "model-bytes")
        let downloader = VerifiedLocalModelDownloader(
            httpClient: httpClient,
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let installedURL = try await downloader.download(manifest, progress: nil)

        XCTAssertEqual(installedURL.lastPathComponent, "qwen-small-1.0.gguf")
        XCTAssertEqual(try String(contentsOf: installedURL, encoding: .utf8), "model-bytes")
        let request = try await httpClient.lastRequest()
        XCTAssertEqual(request.url, manifest.downloadURL)
        let record = await registry.record(for: manifest.id)
        XCTAssertEqual(record?.status, .installed)
        XCTAssertEqual(record?.fileURL, installedURL)
        XCTAssertEqual(record?.installedSizeBytes, Int64("model-bytes".utf8.count))
        XCTAssertEqual(record?.sha256, manifest.sha256)
        XCTAssertNotNil(record?.lastVerifiedAt)
    }

    func testLocalModelDownloadProgressStateMapsPhasesAndCancellationSupport() {
        let preparing = LocalModelDownloadProgressState(modelID: "qwen-small", fractionCompleted: 0.05)
        let downloading = LocalModelDownloadProgressState(modelID: "qwen-small", fractionCompleted: 0.5)
        let verifying = LocalModelDownloadProgressState(modelID: "qwen-small", fractionCompleted: 0.95)

        XCTAssertEqual(preparing.phase, .preparing)
        XCTAssertEqual(downloading.phase, .downloading)
        XCTAssertEqual(verifying.phase, .verifying)
        XCTAssertTrue(preparing.allowsCancellation)
        XCTAssertEqual(verifying.displayText, "驗證中 95%")
    }

    func testVerifiedLocalModelDownloaderReportsProgressMilestones() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelMockHTTPClient(statusCode: 200, body: "model-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let progressRecorder = ProgressRecorder()
        _ = try await downloader.download(manifest) { progress in
            progressRecorder.append(progress)
        }

        let progressValues = progressRecorder.values()
        XCTAssertEqual(progressValues, [0.05, 0.55, 0.9, 1.0])
    }

    func testVerifiedLocalModelDownloaderCancelsAndCleansUpPartialState() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelCancellingHTTPClient(),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        do {
            _ = try await downloader.download(manifest, progress: nil)
            XCTFail("Expected download cancellation to throw.")
        } catch let error as LocalModelDownloadError {
            XCTAssertEqual(error, .cancelled)
        }

        let record = await registry.record(for: manifest.id)
        XCTAssertNil(record)
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelsDirectory.appendingPathComponent("qwen-small-1.0.gguf").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: modelsDirectory.appendingPathComponent("qwen-small-1.0.gguf.download").path))
    }

    func testLocalModelInstallRegistryCleansUpStaleDownloadingRecordsAfterRestart() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        try FileManager.default.createDirectory(at: modelsDirectory, withIntermediateDirectories: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let destinationURL = modelsDirectory.appendingPathComponent("qwen-small-1.0.gguf")
        let partialURL = destinationURL.appendingPathExtension("download")
        try Data("existing-model".utf8).write(to: destinationURL)
        try Data("partial-download".utf8).write(to: partialURL)
        try await registry.upsert(LocalModelInstallRecord(
            modelID: "qwen-small",
            version: "1.0",
            status: .downloading,
            fileURL: destinationURL,
            installedSizeBytes: 0,
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        ))

        let cleanedModelIDs = try await registry.cleanupStaleDownloadingRecords()

        let cleanedRecord = await registry.record(for: "qwen-small")
        XCTAssertEqual(cleanedModelIDs, ["qwen-small"])
        XCTAssertNil(cleanedRecord)
        XCTAssertTrue(FileManager.default.fileExists(atPath: destinationURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: partialURL.path))
    }

    func testVerifiedLocalModelDownloaderExcludesModelDirectoryAndInstalledFileFromBackup() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelMockHTTPClient(statusCode: 200, body: "model-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        let installedURL = try await downloader.download(manifest, progress: nil)

        let directoryValues = try modelsDirectory.resourceValues(forKeys: [.isExcludedFromBackupKey])
        let fileValues = try installedURL.resourceValues(forKeys: [.isExcludedFromBackupKey])
        XCTAssertEqual(directoryValues.isExcludedFromBackup, true)
        XCTAssertEqual(fileValues.isExcludedFromBackup, true)
    }

    func testVerifiedLocalModelDownloaderFailsClosedWhenChecksumDoesNotMatch() async throws {
        let registryURL = temporaryFileURL(named: "install-registry.json")
        let modelsDirectory = registryURL.deletingLastPathComponent().appendingPathComponent("Models", isDirectory: true)
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let downloader = VerifiedLocalModelDownloader(
            httpClient: LocalModelMockHTTPClient(statusCode: 200, body: "wrong-bytes"),
            installRegistry: registry,
            modelsDirectory: modelsDirectory
        )
        let manifest = makeLocalModelManifest(
            id: "qwen-small",
            version: "1.0",
            sha256: "357e5d6fafa34d27360fec24b4326d3534905e33c6acdee60198fb078b7b79e5"
        )

        do {
            _ = try await downloader.download(manifest, progress: nil)
            XCTFail("Expected checksum mismatch")
        } catch let error as LocalModelDownloadError {
            XCTAssertEqual(
                error,
                .checksumMismatch(
                    expected: manifest.sha256,
                    actual: "7c1d387f892b3c965dfc1951e2a92a2149cd103cef25c8ba5d0cc30a3a21063f"
                )
            )
        }

        let record = await registry.record(for: manifest.id)
        XCTAssertEqual(record?.status, .failed)
        XCTAssertEqual(
            record?.failureReason,
            KairoL10n.string(
                "settings.models.download.failure.checksumMismatch",
                manifest.sha256,
                "7c1d387f892b3c965dfc1951e2a92a2149cd103cef25c8ba5d0cc30a3a21063f"
            )
        )
        XCTAssertTrue((try? FileManager.default.contentsOfDirectory(at: modelsDirectory, includingPropertiesForKeys: nil))?.isEmpty ?? true)
    }

    func testLocalFallbackProviderReturnsPlaceholderWithoutActions() async throws {
        let provider = LocalFallbackProvider(installedModelID: "qwen-small")

        let response = try await provider.complete(AICompletionRequest(systemPrompt: "system", userPrompt: "Draft a note"))

        XCTAssertEqual(
            response.message,
            KairoL10n.string(
                "chat.provider.localFallback.response",
                KairoL10n.string("chat.provider.localFallback.named", "qwen-small"),
                KairoL10n.string("chat.provider.localFallback.quotedRequest", "Draft a note")
            )
        )
        XCTAssertTrue(response.proposedActions.isEmpty)
    }

    func testProviderRouterUsesInstalledLocalModelForOfflineEligiblePrompt() async throws {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "Summarize this note")
        let context = ProviderRoutingContext(
            networkAvailable: false,
            taskClass: .summarization,
            localModelInstalled: true,
            localRuntimeAvailable: true
        )

        let decision = router.decision(for: request, context: context)
        let response = try await router.complete(request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .local, reason: .cloudUnavailable))
        XCTAssertEqual(
            response.message,
            KairoL10n.string(
                "chat.provider.localFallback.response",
                KairoL10n.string("chat.provider.localFallback.named", "qwen-small"),
                KairoL10n.string("chat.provider.localFallback.quotedRequest", "Summarize this note")
            )
        )
    }

    func testProviderRouterBlocksLocalForToolUseInOfflineMode() async throws {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "Create a calendar event")
        let context = ProviderRoutingContext(
            networkAvailable: false,
            offlineModeEnabled: true,
            taskClass: .toolUse,
            requiresToolUse: true,
            localModelInstalled: true,
            localRuntimeAvailable: true
        )

        let decision = router.decision(for: request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .unavailable, reason: .toolRequired))
        do {
            _ = try await router.complete(request, context: context)
            XCTFail("Expected unsupported route")
        } catch let error as AIProviderError {
            XCTAssertEqual(error, .unsupported)
        }
    }

    func testProviderRouterRoutesCurrentInfoToCloudWhenAvailable() {
        let router = ProviderRouter(
            cloudProvider: MockAIProvider(),
            localProvider: LocalFallbackProvider(installedModelID: "qwen-small")
        )
        let request = AICompletionRequest(systemPrompt: "system", userPrompt: "What happened today?")
        let context = ProviderRoutingContext(
            networkAvailable: true,
            taskClass: .webCurrentInfo,
            requiresCurrentInfo: true,
            localModelInstalled: true,
            localRuntimeAvailable: true
        )

        let decision = router.decision(for: request, context: context)

        XCTAssertEqual(decision, ProviderRouteDecision(route: .cloud, reason: .localIncapable))
    }

    func testLocalModelRoutingProviderFailsClosedForPrivateChatWithoutLocalModel() async throws {
        let service = try await makeLocalModelSettingsService(
            preference: .automatic,
            installedAndSelectedModelID: nil
        )
        let cloudProvider = RecordingAIProvider()
        let provider = LocalModelRoutingAIProvider(
            cloudProvider: cloudProvider,
            localModelSettingsService: service
        )
        let request = AICompletionRequest(
            systemPrompt: "system",
            userPrompt: "Summarize this sensitive note",
            privacyMode: .privateChat
        )

        await XCTAssertThrowsErrorAsync(try await provider.complete(request)) { error in
            XCTAssertEqual(error as? AIProviderError, .localInferenceUnavailable(
                KairoL10n.string("chat.error.localInference.reason.privateNoModel")
            ))
        }
        let completionCallCount = await cloudProvider.completionCalls()
        XCTAssertEqual(completionCallCount, 0)
    }

    private func temporaryFileURL(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name)
    }

    private func temporaryDirectory(named name: String) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent(name, isDirectory: true)
    }

    private func makeLocalModelSettingsService(
        preference: ProviderRoutePreference,
        installedAndSelectedModelID: String?
    ) async throws -> LocalModelSettingsService {
        let settingsURL = temporaryFileURL(named: "local-model-settings.json")
        let registryURL = temporaryFileURL(named: "local-model-registry.json")
        let catalog = LocalModelCatalog(
            signingKeyID: "test-key",
            signature: "test-signature",
            minimumSafetyPolicyVersion: "2026.1",
            models: [
                makeLocalModelManifest(id: "qwen-small", safetyPolicyVersion: "2026.1")
            ]
        )
        let registry = try await FileBackedLocalModelInstallRegistry(fileURL: registryURL)
        let store = try await FileBackedLocalModelSettingsStore(fileURL: settingsURL)
        let service = LocalModelSettingsService(catalog: catalog, installRegistry: registry, settingsStore: store)

        if let modelID = installedAndSelectedModelID {
            try await registry.upsert(LocalModelInstallRecord(
                modelID: modelID,
                version: "1.0",
                status: .installed,
                fileURL: registryURL.deletingLastPathComponent().appendingPathComponent("\(modelID).gguf"),
                installedSizeBytes: 1024,
                sha256: "abc123"
            ))
            try await service.selectModel(id: modelID)
        }
        try await service.setPreference(preference)
        return service
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

    private func makeLocalModelManifest(
        id: String,
        version: String = "1.0",
        safetyPolicyVersion: String = "2026.1",
        deprecated: Bool = false,
        sha256: String = "abc123",
        contextWindow: Int = 2048
    ) -> LocalModelManifest {
        LocalModelManifest(
            id: id,
            displayName: "Qwen Small Test",
            family: "Qwen",
            version: version,
            parameterCount: "0.8B",
            quantization: "Q4",
            fileSizeBytes: 512,
            installedSizeBytes: 1024,
            contextWindow: contextWindow,
            tokenizerID: "qwen-test-tokenizer",
            licenseName: "Apache-2.0",
            licenseURL: URL(string: "https://example.com/license")!,
            minOSVersion: "17.0",
            minDeviceClass: "A15",
            minRAMGB: 4,
            supportedLocales: ["en", "zh-Hant"],
            capabilities: [.drafts, .summarization, .simpleQuestionAnswer, .offlineChat],
            disallowedCapabilities: [.toolUse, .webCurrentInfo, .codeExecution, .accountActions, .regulatedAdvice],
            downloadURL: URL(string: "https://example.com/model.gguf")!,
            sha256: sha256,
            safetyPolicyVersion: safetyPolicyVersion,
            deprecated: deprecated
        )
    }

    private func remoteModelCatalogJSON(
        catalogSignatureStatus: String = "productionSigned",
        signingKeyID: String = "kairo-models-2026",
        signature: String = "signed-catalog-placeholder",
        minimumSafetyPolicyVersion: String = "2026.1",
        modelsJSON: [String]
    ) -> String {
        """
        {
          "catalogSignatureStatus": "\(catalogSignatureStatus)",
          "schemaVersion": 1,
          "generatedAt": "2026-06-02T00:00:00Z",
          "signingKeyID": "\(signingKeyID)",
          "signature": "\(signature)",
          "sourceRepository": "https://github.com/easonwumac/kairo-models",
          "minimumSafetyPolicyVersion": "\(minimumSafetyPolicyVersion)",
          "models": [
            \(modelsJSON.joined(separator: ",\n"))
          ]
        }
        """
    }

    private func signedRemoteModelCatalogJSON(
        catalogSignatureStatus: String = "productionSigned",
        signingKeyID: String = "kairo-models-2026",
        minimumSafetyPolicyVersion: String = "2026.1",
        modelsJSON: [String],
        trustKeyOverride: ((P256.Signing.PrivateKey, String) -> LocalModelTrustedSigningKey)? = nil
    ) throws -> (json: String, trustStore: LocalModelCatalogTrustStore) {
        let signingKey = P256.Signing.PrivateKey()
        let unsignedJSON = remoteModelCatalogJSON(
            catalogSignatureStatus: catalogSignatureStatus,
            signingKeyID: signingKeyID,
            signature: "",
            minimumSafetyPolicyVersion: minimumSafetyPolicyVersion,
            modelsJSON: modelsJSON
        )
        let unsignedCatalog = try LocalModelCatalog.decode(Data(unsignedJSON.utf8))
        let signedCatalog = try LocalModelCatalog.signedForTesting(
            catalog: unsignedCatalog,
            keyID: signingKeyID,
            signingKey: signingKey
        )
        let trustStore = LocalModelCatalogTrustStore(trustedKeys: [
            trustKeyOverride?(signingKey, signingKeyID) ?? LocalModelTrustedSigningKey(
                keyID: signingKeyID,
                algorithm: "p256-sha256",
                status: .active,
                publicKeyBase64: signingKey.publicKey.derRepresentation.base64EncodedString()
            )
        ])
        return (String(data: try signedCatalog.encoded(), encoding: .utf8) ?? "{}", trustStore)
    }

    private func remoteModelManifestJSON(
        id: String,
        displayName: String,
        version: String = "1.0.0",
        downloadURL: String = "https://huggingface.co/example/model/resolve/main/model.gguf"
    ) -> String {
        """
        {
          "id": "\(id)",
          "displayName": "\(displayName)",
          "family": "Qwen",
          "version": "\(version)",
          "parameterCount": "0.8B",
          "quantization": "Q4_K_M",
          "runtime": "gguf",
          "fileSizeBytes": 512,
          "installedSizeBytes": 1024,
          "contextWindow": 2048,
          "tokenizerID": "qwen-test-tokenizer",
          "licenseName": "Apache-2.0",
          "licenseURL": "https://example.com/license",
          "minOSVersion": "17.0",
          "minDeviceClass": "A15",
          "minRAMGB": 4,
          "supportedLocales": ["en", "zh-Hant"],
          "capabilities": ["drafts", "summarization", "simpleQuestionAnswer", "offlineChat"],
          "disallowedCapabilities": ["toolUse", "webCurrentInfo", "codeExecution", "accountActions", "regulatedAdvice"],
          "downloadURL": "\(downloadURL)",
          "sha256": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
          "createdAt": "2026-06-02T00:00:00Z",
          "updatedAt": "2026-06-02T00:00:00Z",
          "safetyPolicyVersion": "2026.1",
          "deprecated": false
        }
        """
    }
}

private actor LocalModelMockHTTPClient: HTTPClient {
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
            throw LocalModelMockHTTPClientError.missingRequest
        }
        return capturedRequest
    }
}

private actor LocalModelCancellingHTTPClient: HTTPClient {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        _ = request
        throw CancellationError()
    }
}

private actor RecordingAIProvider: AIProvider {
    private(set) var completionCallCount = 0

    func complete(_ request: AICompletionRequest) async throws -> AICompletionResponse {
        _ = request
        completionCallCount += 1
        return AICompletionResponse(message: "unexpected cloud call")
    }

    func embed(_ request: AIEmbeddingRequest) async throws -> AIEmbeddingResponse {
        _ = request
        return AIEmbeddingResponse(vector: [0])
    }

    func completionCalls() -> Int {
        completionCallCount
    }
}

private actor RecordingLocalModelReplyRuntime: LocalModelReplyCheckRuntime {
    private var capturedParameters: LocalModelRuntimeParameters?

    func generateReply(
        model: LocalModelManifest,
        installRecord: LocalModelInstallRecord,
        prompt: String,
        parameters: LocalModelRuntimeParameters
    ) async throws -> LocalModelReplyCheckResult {
        _ = installRecord
        capturedParameters = parameters
        return LocalModelReplyCheckResult(
            modelID: model.id,
            modelDisplayName: model.displayName,
            runtime: .gguf,
            runtimePackage: "recording-runtime",
            prompt: prompt,
            responseText: "runtime parameters applied",
            generatedTokens: parameters.maxOutputTokens,
            generationTokensPerSecond: 1,
            measuredAt: Date(timeIntervalSince1970: 1_780_358_400),
            notes: "Recording local model runtime for parameter propagation tests."
        )
    }

    func lastParameters() -> LocalModelRuntimeParameters? {
        capturedParameters
    }
}

private final class ProgressRecorder: @unchecked Sendable {
    private var storage: [Double] = []
    private let lock = NSLock()

    func append(_ value: Double) {
        lock.lock()
        defer { lock.unlock() }
        storage.append(value)
    }

    func values() -> [Double] {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }
}

private enum LocalModelMockHTTPClientError: Error {
    case missingRequest
}

private actor LocalModelFakeCommandRunner: LocalModelCommandRunner {
    private let result: LocalModelCommandRunResult
    private var invocations: [Invocation] = []

    init(result: LocalModelCommandRunResult) {
        self.result = result
    }

    func run(
        executableURL: URL,
        arguments: [String],
        timeoutSeconds: Double
    ) async throws -> LocalModelCommandRunResult {
        invocations.append(Invocation(
            executableURL: executableURL,
            arguments: arguments,
            timeoutSeconds: timeoutSeconds
        ))
        return result
    }

    func invocation(at index: Int) throws -> Invocation {
        guard invocations.indices.contains(index) else {
            throw LocalModelFakeCommandRunnerError.missingInvocation(index)
        }
        return invocations[index]
    }

    struct Invocation: Equatable, Sendable {
        var executableURL: URL
        var arguments: [String]
        var timeoutSeconds: Double
    }
}

private enum LocalModelFakeCommandRunnerError: Error {
    case missingInvocation(Int)
}
